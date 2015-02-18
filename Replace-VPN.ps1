<#
.SYNOPSIS

Script to replace or create a VPN instance based on a compatible Cloudformation template.

.DESCRIPTION

The VPN instance created by the template will allow AWS EC2 instances in subnets associated with the 
"PrivateRouteTable" access to your private network. 

This script will replace the functionality of an existing VPN instance with a new one, either after updating
the template or to change settings.  It will grab the existing IP and change the routing table.

.PARAMETER VPNtemplateURL

URL of a compatible Cloudformation template.

.EXAMPLE
Initialize-AWSDefaults
./Replace-VPN.ps1 -VPNTemplateURL https://s3-eu-west-1.amazonaws.com/johankritzinger-cfn-templates/templates/vpnInstance.template -PrivateCIDR "172.16.150.0/24" -PrivateVPNIP "46.208.107.1" -PSK "kdiadnhfasd7jegHD8ehgHd83jmd733H8"
 

.NOTES

Ensure you have the correct rights.  

#>

[CmdletBinding() ]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$VPNtemplateURL,

    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$PrivateCIDR,
    
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$PrivateVPNIP,

    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$PSK,

    [string]$SubnetID,
    [string]$ExternalIP,
    [string]$ServerName = "VPNInstance",
    [string]$PrivateRouteTable,
    [string]$KeyName,
    [string]$EnvType = "Prod",
    [string]$InstanceType = "t2.micro",
    [string]$VPC,
    [switch]$NoRouteUpdate,
    [switch]$RouteUpdateOnly,
    [switch]$Force
)
BEGIN {}
PROCESS {
    # Try to guess reasonable values if not provided
    if (!$SubnetID) {
        $SubnetID = (Get-EC2Subnet | ? {$_.MapPublicIpOnLaunch -eq $True} | select -First 1).SubnetId
        "Guessing SubnetId: $SubnetID"
    }
   
    if (!$KeyName) {
        # If there's only one, use that
        $KeyPair = Get-EC2KeyPair
        if ($KeyPair.Length -eq 1) {
            $KeyName = $KeyPair.KeyName
            "Guessing key pair: $KeyName"
        } else {
          if ($KeyPair.Length -eq 0) {
             Write-Host "You do not have a Key Pair in your account, so won't be able to access the instance" -ForegroundColor Red 
          } else {
            Throw "Can't determine what Key Pair to use, please specify KeyName"
          }
        }
    }
    # Check if there's an existing VPN instance
    $oldStack = Get-CFNStack | ? {($_.StackName -like "VPN*")}
    $oldIntanceId = ($oldStack.Outputs | ? {($_.OutputKey -eq "InstanceId")}).OutputValue

    if (!$ExternalIP) {
        # Use the one assigned to the old instance, if it has one
        $ExternalIP = (Get-EC2Address | ? { $_.InstanceId -eq $oldIntanceId}).PublicIp
    }
	if (!$ExternalIP) {
	  "No suitable public IP, creating one"
	  $ExternalIP = (New-EC2Address).PublicIp
	} else {
      "Guessing public IP: $ExternalIP"
	}
    
    if (!$PrivateRouteTable) {
      # Find a routing table with no route via igw
      $rtt = Get-EC2RouteTable
      $mnrtt = $rtt | ? {$_.Routes.GatewayID -like "igw*" }
      [string[]]$PrivateRouteTable = ($rtt | ? {$_.RouteTableId -ne $mnrtt.RouteTableId }).RouteTableId
      if ($PrivateRouteTable.Length -gt 1 ) {
        Throw "More than one possible PrivateRouteTable, please specify"
      }
      [string]$PrivateRouteTable = $PrivateRouteTable
      "Guessing Route Table: $PrivateRouteTable"
    }

    if (!$VPC) {
        "Checking VPC"
        [string[]]$VPC = (Get-EC2Vpc).VpcId
        if ($VPC.Length -ne 1 ) {
            Throw "VPC not specified and you have more than one"
        }
    }

    $VpcCidr = (Get-EC2Vpc).CidrBlock

	if (!$RouteUpdateOnly) {
	   # Check if the instance exists - can't create another
	   if (Get-CFNStack | ? { $_.StackName -eq $ServerName} ) { $ServerName = $ServerName + "2" }

       "Creating Stack"
	   New-CFNStack -StackName $ServerName -TemplateURL $VPNtemplateURL -Parameters @(
		    @{ ParameterKey="ServerName";ParameterValue=$ServerName },
		    @{ ParameterKey="InstanceType";ParameterValue=$InstanceType },
		    @{ ParameterKey="KeyName";ParameterValue=$KeyName },
		    @{ ParameterKey="SubnetID";ParameterValue=$SubnetID },
		    @{ ParameterKey="VPCCIDR";ParameterValue=$VpcCidr },
		    @{ ParameterKey="VPC";ParameterValue=$VPC },
		    @{ ParameterKey="PrivateCIDR";ParameterValue=$PrivateCIDR },
		    @{ ParameterKey="PrivateVPNIP";ParameterValue=$PrivateVPNIP },
            @{ ParameterKey="PSK";ParameterValue=$PSK },
		    @{ ParameterKey="ExternalIP";ParameterValue=$ExternalIP }
		) -Tags @( @{Key="EnvType";Value=$EnvType } )

		# Wait on completion
	   while ((Get-CFNStack -StackName $ServerName).StackStatus -notlike "CREATE_COMPLETE") {
		    sleep 30
		    if ((Get-CFNStack -StackName $ServerName).StackStatus -like "ROLLBACK*") {
		        Throw "System rolling back"
		    }
	   }
	   Write-Host "Stack created"
	}
	if (!$NoRouteUpdate) {
		# Get the instance ID
		[string]$instanceId = ((Get-CFNStack -StackName $ServerName).Outputs | ? {$_.OutputKey -like "InstanceId"}).OutputValue
		
		if ($instanceId) {
            if ($ExternalIP) {
    			# Associate the EIP
	    		Register-EC2Address -InstanceId $instanceId -PublicIp $ExternalIP
		    }
			# Update the routing table
			set-ec2route -routetableid $PrivateRouteTable -DestinationCidrBlock "0.0.0.0/0" -InstanceId $instanceId
		} else {
		   Throw "Error - the Stack doesn't seem to exist or doesn't contain an InstanceId!"
		}
        if ( $oldStack ) {
            if ($Force -or (Read-Host "Do you want to delete the old instance? (Y/n)") -like "Y*") {
                "Deleting old stack"
                Remove-CFNStack -StackName $oldStack.StackName -Force
            }
        }
	}
} 
END {}
