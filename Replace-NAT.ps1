<#
.SYNOPSIS

Script to replace a NAT instance based on a compatible Cloudformation template.

.DESCRIPTION

The NAT instance created by the template will allow AWS EC2 instances in subnets associated with the 
"PrivateRouteTable" access to the internet.  In addition, it sets up an incoming NAT the "ForwardHost"
on the "ForwardPort" and changes the ssh server to run on port "SSHPort".

This script will replace the functionality of an existing NAT instance with a new one, either after updating
the template or to change settings.  It will grab the existing IP and change the routing table.

.PARAMETER NATtemplateURL

URL of a compatible Cloudformation template.

.EXAMPLE



.NOTES

Ensure you have the correct

#>

[CmdletBinding() ]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]﻿$NATtemplateURL,

    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$KeyName,

    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$SubnetID,

    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$SecurityGroup,

    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$PublicIP,

    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$PrivateRouteTable,
                           
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$ForwardHost,

    [string]$NATStackName = "NATInstance"
    [string]$EnvType = "Prod"
    [string]$InstanceType = "t2.micro",
    [string]SSHPort = "5022",
    [string]ForwardPort = "22",

)
BEGIN {}
PROCESS {
	# Check if the instance exists - can't create another
	if (Get-CFNStack | ? { $_.StackName -eq $NATStackName} ) { $NATStackName = $NATStackName + "2" }

	New-CFNStack -StackName $NATStackName -TemplateURL $NATtemplateURL -Parameters @(
		    @{ ParameterKey="ServerName";ParameterValue=$NATStackName },
		    @{ ParameterKey="InstanceType";ParameterValue=$InstanceType },
		    @{ ParameterKey="KeyName";ParameterValue=$KeyName },
		    @{ ParameterKey="SecurityGroup";ParameterValue=$KSecurityGroup },
		    @{ ParameterKey="ForwardHost";ParameterValue=$ForwardHost },
		    @{ ParameterKey="InstanceSubnet";ParameterValue=$SubnetID },
		    @{ ParameterKey="ForwardPort";ParameterValue=$ForwardPort }
		    
		) -Tags @( @{Key="EnvType";Value=$EnvType } )


	# Wait on completion
		while ((Get-CFNStack -StackName $NATStackName).StackStatus -notlike "CREATE_COMPLETE") {
		    sleep 30
		    if ((Get-CFNStack -StackName $NATStackName).StackStatus -like "ROLLBACK*") {
		        Throw "System rolling back"
		    }
		}
		Write-Host "Stack created"

	# Replace EIP with existing EIP to allow incoming NAT	
	# Get the instance ID
	$instanceId = ((Get-CFNStack -StackName $NATStackName).Outputs | ? {$_.OutputKey -like "InstanceId"}).OutputValue

	# Associate the EIP
	Register-EC2Address -InstanceId $instanceId -PublicIp 

	# Delete the temporary EIP
	$PublicIP = ((Get-CFNStack -StackName $NATStackName).Outputs | ? {$_.OutputKey -like "PublicIP"}).OutputValue

	Remove-EC2Address -AllocationId (Get-EC2Address -PublicIps $PublicIP).AllocationId -Force

	# Update the routing table
	set-ec2route -routetableid $PrivateRouteTable -DestinationCidrBlock "0.0.0.0/0" -InstanceId $instanceId
} 


END {}
