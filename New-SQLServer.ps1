<#
.SYNOPSIS

Script to create a SQL server in AWS from an existing CloudFormation template that creates a SQL server.  This works only 
for the specific template by Johan Kritzinger.
Copyright Johan Kritzinger

.DESCRIPTION

Contains 3 functions, currently all are run.
1. Calls CloudFormation with the supplied template URL, passing all parameters through to the template.
2. Adds the computer created to an AWSComputers AWS group to allow caching of credentials on the AWS RODC

.PARAMETER ComputerName

Windows name of the computer to be created and added to AD.  Also used to connect throughout the script

.EXAMPLE

Set up a SQL server in Availability Zone a

.\New-SQLServer.ps1 -ComputerName $ComputerName -StackName $StackName -AZ "a" -DomainAdminPassword $DomainAdminPassword

.EXAMPLE

Set up a SQL server without a D: drive 

.\New-SQLServer.ps1 -ComputerName $ComputerName -StackName $StackName -AZ "a" -DomainAdminPassword $DomainAdminPassword -DontCreateDDrive

.NOTES

Needs to be run as a Domain Admin and AWS Credentials and Region have to be set before running.

#>



[CmdletBinding() ]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$ComputerName,

    [string]$DomainAdminPassword = "<Password here>",

    [string]$StackName,

    [parameter(ValueFromPipeline=$true)]
    [string]$TemplateURL= "https://s3-eu-west-1.amazonaws.com/your-bucket-for-templates/Domain-SQLInstance.template",

    [string]$SQLServiceAccount = "DOMAIN\sa_SQLServer",
    [string]$SQLServiceAccountPw = "<Password>",

    [ValidateSet('2014','2008R2','2008_SP3')]
    [string]$SQLVersion = "2008R2",

    [string]$DomainAdminUser = "AWSDirectory",
    [string]$KeyName = "<key name>",
    [string]$SecurityGroup = "sg-xxxxxxxx",
    [string]$InstanceType = "m3.medium",
    [string]$EbsOptimized,
    [ValidateSet('gp2','standard','io1')]
    [string]$VolumeType = "gp2",
    [string]$Iops = "2500",
    [string]$DomainDNSName = "domain.local",
    [string]$DomainNetBIOSName = "domain",
    [string]$AZ = "b",
    [switch]$DontCreateDDrive,
    [string]$DDriveSize = "150",
    [string]$EnvType = "Test",
    [string]$DBAEmail = "ITDevAlerts@domain.com",
    [string]$DBAOperator = "ITDevAlerts",
    [string]$OUPath = "OU=Servers,OU=Computers,DC=domain,DC=local",
    [string]$SQLCollation = "Latin1_General_CI_AS",
    [switch]$BuildExpress,
    [string]$SkipUpdates = "False",
    [string]$S3SourceBucketName = "unique-bucket-name-sources"

)
BEGIN {}
PROCESS {
    

    # Create stack
    Function Create-Stack {
        [string]$msg = [string](Get-Date) + " - Creating Stack"
        Write-Host $msg
        $cfnstack = New-CFNStack -StackName $StackName -TemplateURL $TemplateURL -Parameters @(
            @{ ParameterKey="ServerName";ParameterValue=$ComputerName },
            @{ ParameterKey="DomainAdminPassword";ParameterValue=$DomainAdminPassword },
            @{ ParameterKey="DomainAdminUser";ParameterValue=$DomainAdminUser },
            @{ ParameterKey="KeyName";ParameterValue=$KeyName },
            @{ ParameterKey="SecurityGroup";ParameterValue=$SecurityGroup },
            @{ ParameterKey="InstanceType";ParameterValue=$InstanceType },
            @{ ParameterKey="EbsOptimized";ParameterValue=$EbsOptimized },
            @{ ParameterKey="VolumeType";ParameterValue=$VolumeType },
            @{ ParameterKey="Iops";ParameterValue=$Iops },
            @{ ParameterKey="DomainDNSName";ParameterValue=$DomainDNSName },
            @{ ParameterKey="DomainNetBIOSName";ParameterValue=$DomainNetBIOSName },
            @{ ParameterKey="DontCreateDDrive";ParameterValue=$DontCreateDDrive },
            @{ ParameterKey="DDriveSize";ParameterValue=$DDriveSize },
            @{ ParameterKey="ImageId";ParameterValue=$StdImage },
            @{ ParameterKey="AZ";ParameterValue=$AZ },
            @{ ParameterKey="SkipUpdates";ParameterValue=$SkipUpdates  },
            @{ ParameterKey="SQLServiceAccount";ParameterValue=$SQLServiceAccount  },
            @{ ParameterKey="SQLServiceAccountPw";ParameterValue=$SQLServiceAccountPw  },
            @{ ParameterKey="OUPath";ParameterValue=$OUPath },
           @{ ParameterKey="S3SourceBucketName";ParameterValue=$S3SourceBucketName },
            @{ ParameterKey="SQLCollation";ParameterValue=$SQLCollation }
        ) -Tags @( @{Key="EnvType";Value=$EnvType } ) -Capabilities CAPABILITY_IAM

        # Load these modules waiting
        Import-Module ActiveDirectory
        # Import-Module sqlps -DisableNameChecking

        # Wait on completion
        while ((Get-CFNStack -StackName $StackName).StackStatus -notlike "CREATE_COMPLETE") {
            sleep 30
            if ((Get-CFNStack -StackName $StackName).StackStatus -like "ROLLBACK*") {
                Throw "System rolling back"
            }
        }
        $msg = [string](Get-Date) + " - Stack created"
        Write-Host $msg 
    }
    Function Add-AD {
        # Add computer to correct group to cache credentials
        $ADCOmputer = Get-ADComputer $ComputerName
        try {
            Get-ADGroup AWSComputers | Add-ADGroupMember -Members $ADCOmputer
        } catch { "Couldn't add to AWSComputers group" } finally {}

    }


    if ($BuildExpress) {
        switch ($SQLVersion) {
            # Fetch correct AMI
            '2014' {
                $StdImage = (Get-EC2Image -Owners amazon | ? { $_.Name -like "Windows_Server-2012-R2*" -and $_.Name -like "*English*" -and $_.Name -like "*Express*" } | Select-Object -Last 1  ImageId).ImageId
            }
            "2008R2" {
                $StdImage = (Get-EC2Image -Owners amazon | ? { $_.Name -like "Windows_Server-2012*" -and $_.Name -like "*English*" -and $_.Name -like "*Express*"  -and $_.Name -like "*2008_R2*" } | Select-Object -Last 1  ImageId).ImageId
            }
            "2008_SP3"  {
                $StdImage = (Get-EC2Image -Owners amazon | ? { $_.Name -like "Windows_Server*" -and $_.Name -like "*English*" -and $_.Name -like "*Express*"  -and $_.Name -like "*2008_SP3*" } | Select-Object -Last 1 ImageId).ImageId
            }
        }  
         $EbsOptimized = "False"  

    } else {
        switch ($SQLVersion) {
            '2014' {
                $StdImage = (Get-EC2Image -Owners amazon | ? { $_.Name -like "Windows_Server-2012-R2*" -and $_.Name -like "*English*" -and $_.Name -like "*Standard*" } | Select-Object -Last 1  ImageId).ImageId
            }
            "2008R2" {
                $StdImage = (Get-EC2Image -Owners amazon | ? { $_.Name -like "Windows_Server-2012*" -and $_.Name -like "*English*" -and $_.Name -like "*Standard*"  -and $_.Name -like "*2008_R2*"} | Select-Object -Last 1  ImageId).ImageId
            }
            "2008_SP3"  {
                $StdImage = (Get-EC2Image -Owners amazon | ? { $_.Name -like "Windows_Server*" -and $_.Name -like "*English*" -and $_.Name -like "*Standard*"  -and $_.Name -like "*2008_SP3*"} | Select-Object -Last 1 ImageId).ImageId
            }
        }    
    }
    if (!$EbsOptimized) {
        # Only catching a few of the possible instance types that can't do EBS Optimized
        if (($InstanceType -eq "m3.medium") -or ($InstanceType -eq "m3.large")) {
           $EbsOptimized = "False"
        } else {
          $EbsOptimized = "True"
        }
    } 
    if (!$StackName) { $StackName = $ComputerName }
    Try {
        Create-Stack
        # Wait until the AD computer is visible and the DNS name is there
        Do { 
          try { 
             $adComputer = Get-ADComputer $ComputerName -ErrorAction SilentlyContinue 
             Write-Host "."
          } catch { 
            Start-Sleep 20
          }
        } Until ($adComputer)

        Add-AD

    } 
    Catch {
        Write-Error $_
    }
    Finally {
        $msg = [string](Get-Date) + " - Completed"
        Write-Host $msg
        if ($SQLVersion -like "2008_SP3") {
           Read-Host "Change System Locale and Time Zone and press enter to confirm"
        }
    }
   
} 

END {}
