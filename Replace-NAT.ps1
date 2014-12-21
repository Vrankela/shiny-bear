﻿<#
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
Initialize-AWSDefaults
Replace-NAT -NatTemplateURL https://s3-eu-west-1.amazonaws.com/johankritzinger-cfn-templates/templates/natInstance.template -SubnetID subnet-c62b2a80


.NOTES

Ensure you have the correct rights.  

#>

[CmdletBinding() ]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$NATtemplateURL,
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$SubnetID,
    [string]$ForwardHost,
    [string]$NATStackName = "NATInstance",
    
    [string]$PublicIP,
    [string]$PrivateRouteTable,
                           
    [string]$KeyName,
    

    [string]$EnvType = "Prod",
    [string]$InstanceType = "t2.micro",
    [string]$SSHPort,
    [int]$ForwardPort,
    [string]$VPC,
    [switch]$NoRouteUpdate,
    [switch]$RouteUpdateOnly

)
BEGIN {}
PROCESS {
    # Try to guess reasonable values if not provided
   
    if (!$KeyName) {
        # If there's only one, use that
        $KeyPair = Get-EC2KeyPair
        if ($KeyPair.Length -eq 1) {
            $KeyName = $KeyPair.KeyName
        } else {
          if ($KeyPair.Length -eq 0) {
             Write-Host "You do not have a Key Pair in your account, so won't be able to access the instance" -ForegroundColor Red 
          } else {
            Throw "Can't determine what Key Pair to use, please specify KeyName"
          }
        }
    }
    if (!$PublicIP) {
        # If there isn't one, it won't be needed

        # If there is one assigned to a NAT...., use that

    }
    
    if (!$PrivateRouteTable) {
      # Find a routing table with no route via igw
      "Guessing Route Table"
      $rtt = Get-EC2RouteTable
      $mnrtt = $rtt | ? {$_.Routes.GatewayID -like "igw*" }
      [string[]]$PrivateRouteTable = ($rtt | ? {$_.RouteTableId -ne $mnrtt.RouteTableId }).RouteTableId
      if ($PrivateRouteTable.Length -gt 1 ) {
        Throw "More than one possible PrivateRouteTable, please specify"
      }
      [string]$PrivateRouteTable = $PrivateRouteTable
    }

    if (!$VPC) {
        [string[]]$VPC = (Get-EC2Vpc).VpcId
        if ($VPC.Length -ne 1 ) {
            Throw "VPC not specified and you have more than one"
        }
    }

    $VpcCidr = (Get-EC2Vpc).CidrBlock

	if (!$RouteUpdateOnly) {
	   # Check if the instance exists - can't create another
	   if (Get-CFNStack | ? { $_.StackName -eq $NATStackName} ) { $NATStackName = $NATStackName + "2" }

	   New-CFNStack -StackName $NATStackName -TemplateURL $NATtemplateURL -Parameters @(
		    @{ ParameterKey="ServerName";ParameterValue=$NATStackName },
		    @{ ParameterKey="InstanceType";ParameterValue=$InstanceType },
		    @{ ParameterKey="KeyName";ParameterValue=$KeyName },
		    @{ ParameterKey="ForwardHost";ParameterValue=$ForwardHost },
		    @{ ParameterKey="InstanceSubnet";ParameterValue=$SubnetID },
		    @{ ParameterKey="VpcCidr";ParameterValue=$VpcCidr },
		    @{ ParameterKey="VPC";ParameterValue=$VPC },
		    @{ ParameterKey="ForwardPort";ParameterValue=$ForwardPort },
		    @{ ParameterKey="SSHPort";ParameterValue=$SSHPort }

		    
		) -Tags @( @{Key="EnvType";Value=$EnvType } )


		# Wait on completion
	   while ((Get-CFNStack -StackName $NATStackName).StackStatus -notlike "CREATE_COMPLETE") {
		    sleep 30
		    if ((Get-CFNStack -StackName $NATStackName).StackStatus -like "ROLLBACK*") {
		        Throw "System rolling back"
		    }
	   }
	   Write-Host "Stack created"
	}
	if (!$NoRouteUpdate) {
		# Get the instance ID
		[string]$instanceId = ((Get-CFNStack -StackName $NATStackName).Outputs | ? {$_.OutputKey -like "InstanceId"}).OutputValue
		
		if ($instanceId) {
            if ($PublicIP) {
    			# Associate the EIP
	    		Register-EC2Address -InstanceId $instanceId -PublicIp $PublicIP
		    }
			# Update the routing table
			set-ec2route -routetableid $PrivateRouteTable -DestinationCidrBlock "0.0.0.0/0" -InstanceId $instanceId
		} else {
		   Throw "Error - the Stack doesn't seem to exist or doesn't contain an InstanceId!"
		}
	}
} 


END {}
