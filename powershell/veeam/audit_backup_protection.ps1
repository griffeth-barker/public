<#
.SYNOPSIS
  This script checks gets and cross-references lists of virtual machines between vCenter and Veeam Backup & Replication.
.DESCRIPTION
  This script checks gets a list of VMs from vCenter and a list of backed up VMs from Veeam Backup & Replication, then
  cross-references the VM name to verify if the VM is in a backup job or not. Those VMs whose names are not in BOTH lists are
  then added to a table which is converted to a CSV file and emailed to the report recipients.
.PARAMETER
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Updated by:     Griffeth Barker (barkergriffeth@gmail.com)
  Change Date:    11-15-2022
  Purpose/Change: Initial development

  This script must be run from a node where Veeam Backup & Replication is installed.

  The list of VMs obtained from vSphere is filtered using a tag on the virtual machines. 
  VMs tagged with "Backup-NO" will be excluded from the check that this script performs.
.EXAMPLE
  NA
#>

# Timestamp function for logging
function Get-TimeStamp {
  return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
}

# Script setup
$FileTime = Get-Date -format yyyy-MM-dd_HHmm

Write-Host "Checking for existence of C:\temp ..." -Foreground Gray
$WorkingDir = "C:\temp"
if (Test-Path -Path $WorkingDir){
  Write-Host "Validated working directory." -ForegroundColor DarkGreen
}
else {
  Write-Host "Could not find C:\temp - creating it now..." -ForegroundColor DarkYellow
  New-Item -Path "C:\" -Name "temp" -ItemType "directory" -Force
  Write-Host "Created C:\temp - proceeding." -ForegroundColor DarkGreen
}

Start-Transcript -Path "C:\temp\audit_backup_protection_$FileTime.log"

$recipients = (
  "your_recipient@domain.local"
)
$sender = "yoursender@domain.local"
$SmtpServer = "yoursmtpserver.domain.local"
$vCenterServer = "yourvcenter.domain.local"
$VeeamServer = "yourveeamserver.domain.local"

$ProtectedTable = New-Object System.Data.Datatable
[void]$ProtectedTable.Columns.Add("Name")
[void]$ProtectedTable.Columns.Add("Status")

$UnprotectedTable = New-Object System.Data.Datatable
[void]$UnprotectedTable.Columns.Add("Name")
[void]$UnprotectedTable.Columns.Add("Status")

Write-Host "[$(Get-Timestamp)] Checking for VMware PowerCLI module..."
if (Get-Module -ListAvailable | Where-Object {$_.Name -like "VMware.*"}) {
  Write-Host "[$(Get-Timestamp)] Found VMware PowerCLI module..." -ForegroundColor Gray
} 
else {
  Write-Host "[$(Get-Timestamp)] VMware PowerCLI module not found." -ForegroundColor DarkYellow
  Write-Host "[$(Get-Timestamp)] Attempting to install VMware.PowerCLI..." -ForegroundColor DarkYellow
  Install-Module VMware.PowerCLI -Scope CurrentUser -SkipPublisherCheck -Force
}

if (Get-Module -ListAvailable -Name "[$(Get-Timestamp)] Veeam.Backup.PowerShell") {
  Write-Host "[$(Get-Timestamp)] Found Veeam Backup PowerShell module..." -ForegroundColor Gray
} 
else {
  Write-Host "[$(Get-Timestamp)] Could not find Veeam.Backup.PowerShell module. Please ensure you are running the script from a node where Veeam Backup & Replication Console is installed." -ForegroundColor DarkYellow
  Break
}

# Get array of VMs from vCenter
Write-Host "[$(Get-Timestamp)] Connecting to vCenter..." -ForegroundColor Gray
Connect-VIServer -Server $vCenterServer -Force
Write-Host "[$(Get-Timestamp)] Getting VM names..." -ForegroundColor Gray
$VMs = (Get-VM).Name | Sort-Object
$FilteredList = @()
foreach ($VM in $VMs){
  $VMtags = Get-TagAssignment -Entity $VM
  if ($null -eq $VMtags){
    Write-Host "[$(Get-Timestamp)] Adding $VM to Filtered List..." -ForegroundColor Gray
    $FilteredList += $VM
  }
  else {
    Write-Host "[$(Get-Timestamp)] Skipping $VM due to tag filtering..." -ForegroundColor DarkYellow
  }
}

# Get array of servers backed up by Veeam
Write-Host "[$(Get-Timestamp)] Connecing to Veeam backup server..." -ForegroundColor Gray
Connect-VBRServer -Server $VeeamServer
Write-Host "[$(Get-Timestamp)] Getting backed up nodes..." -ForegroundColor Gray
$Backups = @((Get-VBRJob -Name *).GetObjectsInJob())
$Backup = @($Backups | Select-Object Name | Sort-Object Name)

# Compare the two arrays and add VMs to reporting tables based on backup status
Write-Host "[$(Get-Timestamp)] Cross-referencing..." -ForegroundColor Gray
foreach ($Listed in $FilteredList){
  # $VMname = $Listed.name
  $Check = $Backup.Name.Contains("$Listed")
  if ($Check -eq $true){
    Write-Host "[$(Get-Timestamp)] $Listed is backed up by Veeam Backup & Replication." -ForegroundColor DarkGreen
    [void]$ProtectedTable.Rows.Add($Listed,"Protected")
  }
  else {
    Write-Host "[$(Get-Timestamp)] $Listed is NOT backed up by Veeam Backup & Replication!" -ForegroundColor DarkRed
    [void]$UnprotectedTable.Rows.Add($Listed,"Not Protected")
  }
}

# Reporting
Write-Host "[$(Get-Timestamp)] Generating report..." -ForegroundColor Gray
$AttachmentPath = "C:\temp\unprotected-servers-$FileTime.csv"
$UnprotectedTable | Export-Csv -Path "$AttachmentPath" -NoTypeInformation -Force

$body = "
  Attached is a report of vCenter nodes that are not protected by a backup job in Veeam Backup & Replication.
  Please review the report and add/remove nodes from backup jobs as appropriate.
"

Write-Host "[$(Get-Timestamp)] Sending report..." -ForegroundColor Gray
Send-MailMessage -to "$recipients" -From $Sender -subject "Report - Server Backup Protection Audit" -Body $body -SmtpServer $SmtpServer -Attachments $AttachmentPath

# Script cleanup
Write-Host "[$(Get-Timestamp)] Disconnecting from vCenter and Veeam..." -ForegroundColor Gray
Disconnect-VIServer -Server "$vCenterServer" -Force -Confirm:$false
Disconnect-VBRServer
Write-Host "[$(Get-Timestamp)] Cleaning up temporary files..." -ForegroundColor Gray
Remove-Item -Path "C:\temp\unprotected-servers-*" -Force
