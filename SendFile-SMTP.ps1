<#
.SYNOPSIS

Script to send a .eml file using an SMTP connection.

.DESCRIPTION

Reads the file specified in filename.  Connects to the specified SMTP server and sends it.
The file needs to be a valid email file.
based on http://www.leeholmes.com/blog/2009/10/28/scripting-network-tcp-connections-in-powershell/

.PARAMETER filename

Filename of a file that contains legal mime suitable for sending, e.g. an .eml file

.PARAMETER smtpServer

Host name or IP address of the SMTP server

.PARAMETER mailfrom

Needs to be reported to SMTP server, can be used for authentication.  Will be overwritten by value in .eml file

.PARAMETER rcptto

Needs to be reported to SMTP server.  Will be overwritten by value in .eml file

#>

[CmdletBinding() ]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$filename,
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$smtpServer,
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$mailfrom,
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]$rcptto,

    [string]$port = "25",
    [string]$localhost = "localhost"

)
BEGIN {}
PROCESS {

$currentInput = Get-Content $filename -Raw

$socket = new-object System.Net.Sockets.TcpClient($smtpServer, $port)
$stream = $socket.GetStream() 
$writer = new-object System.IO.StreamWriter $stream

$writer.WriteLine("EHLO $localhost")
$writer.Flush() 
$writer.WriteLine("MAIL FROM: $mailfrom")
$writer.Flush() 
$writer.WriteLine("RCPT TO: $rcptto")
$writer.Flush() 
$writer.WriteLine("DATA")
$writer.Flush() 
foreach($line in $currentInput) {
        $writer.WriteLine($line)
        $writer.Flush() 
}
$writer.WriteLine("`r`n.`r`n")
$writer.Flush() 

}
END {}
