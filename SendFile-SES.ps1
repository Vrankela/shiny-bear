<#
.SYNOPSIS

Script to send a .eml file using send-sesrawemail via Amazon SES

.DESCRIPTION

Reads the file specified in filename, converts to memorystream and sends it.  The file needs to be a valid email file.

.PARAMETER filename

Filename of a file that contains legal mime suitable for sending, e.g. an .eml file

.PARAMETER region

AWS region - SES doesn't seem to use your default region - it needs to be specified.

#>

[CmdletBinding() ]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$filename,

    [string]$region="eu-west-1"
)

BEGIN {}
PROCESS {
    Set-DefaultAWSRegion -Region $region

    [string]$message = Get-Content $filename -Raw

    $memStream = New-Object System.IO.MemoryStream
    $writeStream = New-Object System.IO.StreamWriter $memStream
    $writeStream.WriteLine($message)
    $writeStream.Flush()
    $memStream.Seek(0,"Begin")

    Send-SESRawEmail -RawMessage_Data $memStream
}
END {}
