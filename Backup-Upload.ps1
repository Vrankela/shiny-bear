# This script assumes backups are stored in a folder structure as used by the Ola Holgren Maintenance Solution

$BucketName = "unique-sql-backup-name"
$BucketBackup = "Backups"
[string]$NotificationARN = "arn:aws:sns:eu-west-1:xxxxxxxx:Infrastructure_notifications"

$CompName = $env:ComputerName

if (Test-Path "D:\SQLBackups\$CompName"\$CompName) {
  $LocalBackupLocation = "D:\SQLBackups"
} 
if (Test-Path "E:\SQLBackups\$CompName") {
  $LocalBackupLocation = "E:\SQLBackups\$CompName"
}



# Calculate where to put it
$currentDate =Get-Date
$backupTarget = "Daily"

if ($currentDate.DayOfWeek -like "Saturday" ) {
  $backupTarget = "Weekly"
}
if ($currentDate.Day -eq 1) {
  $backupTarget = "Monthly"
}


cd $LocalBackupLocation 
# Assumes use of Maintenance Schedule


$displayDate = Get-Date -Format yyyyMMdd
$displayYesterday = get-date ((Get-Date).AddDays(-1)) -Format yyyyMMdd

# Get all the files to upload
# 
$fileList = gci | % { dir $_/Full/*.bak }

$maxSize = 0
# Copy each file to bucket
foreach ($file in $fileList) {
    $maxSize = ($maxSize, $file.Length | Measure -Max).Maximum
    $localfile = $file.FullName
    $filename = $file.Name
    $key = $BucketBackup + "/" + $backupTarget + "/" + $filename 
    if (!(Get-S3Object -BucketName $BucketName -KeyPrefix $BucketBackup | ? { $_.Key -like "*$filename " })) {
        Write-S3Object -File $localfile -BucketName $BucketName -Key $key -ServerSideEncryption AES256
    }
}

$backupDrive = $LocalBackupLocation.Substring(0,2)
$freeSpace = (Get-WmiObject Win32_LogicalDisk | ? { $_.DeviceId -like $LocalBackupLocation.Substring(0,2)}).FreeSpace
if ($freeSpace -lt 2*$maxSize) {
    $message = "Free space less than 2* largest backup file on " + $env:ComputerName
    $subject = "Backup drive space: " + $env:ComputerName
    Publish-SNSMessage -TargetArn $NotificationARN -Message $message  -Subject $subject
}
