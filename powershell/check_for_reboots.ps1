<#
.SYNOPSIS
  This script checks the uptime of servers at a site to see if they rebooted during the maintenance window as they should have.
.DESCRIPTION
  This script checks the uptime of servers at a site to see if they rebooted during the maintenance window as they should have.
.PARAMETER
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Updated by:     Griffeth Barker (barkergriffeth@gmail.com)
  Change Date:    10-12-2022
  Purpose/Change: Initial development

  This script requires that all target nodes have WinRM/PSRemoting enabled and configured.
.EXAMPLE
  None
#>

# Script setup
$Recipients = (
    "yourrecipient@domain.local"
)
$Sender = "yoursender@domain.local"
$SmtpServer = "yoursmtpserver.domain.local"

$MaintenanceDate = Get-Date -Format yyyy-MM-dd
$ErrorMessage = "Error"

$ServersOU = "OU=Servers,OU=Site,DC=domain,DC=local"

Write-Host "Checking for C:\temp ..." -ForegroundColor DarkYellow
$WorkingDir = "C:\temp"
if (Test-Path -Path $WorkingDir){
  Write-Host "Found C:\temp - proceeding..." -ForegroundColor DarkGreen
}
else {
  Write-Host "Could not find C:\temp - creating it now..." -ForegroundColor DarkYellow
  New-Item -Path "C:\" -Name "temp" -ItemType "directory" -Force
  Write-Host "Created C:\temp - proceeding." -ForegroundColor DarkGreen
}

$RebootsTable = New-Object System.Data.Datatable
[void]$RebootsTable.Columns.Add("Server Name")
[void]$RebootsTable.Columns.Add("Last Boot")

# Get list of servers for the specified site from Active Directory
Write-Host "Getting list of site's servers from Active Directory..." -ForegroundColor DarkYellow
$Servers = (Get-ADComputer -Filter 'Name -like "*"' -Properties Name -SearchBase $ServersOU).Name
Write-Host "Got list of site's servers!" -ForegroundColor DarkGreen

# Get last boot up time for each server in list and add it to the reporting table
Write-Host "Getting last boot up times for site's servers..." -ForegroundColor DarkYellow
foreach ($server in $servers){
    try {
      Write-Host "$Server - Getting last boot up time..." -ForegroundColor Gray
      $Check = Invoke-Command -ComputerName $server -ScriptBlock {(Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime} -ErrorAction SilentlyContinue
      [void]$RebootsTable.Rows.Add($Server,$Check)
      Write-Host "$Server - Got last reboot time!" -ForegroundColor DarkGreen
    }
    catch {
      [void]$RebootsTable.Rows.Add($Server,$ErrorMessage)
      Write-Host "$Server - Failed to get last bootup time...please check WinRM configuration and node availability!" -ForegroundColor DarkRed
    }
}

# Generate and send report
Write-Host "Generating report..." -ForegroundColor DarkYellow
try {
  $AttachmentPath = "C:\temp\reboot_check_$MaintenanceDate.csv"
  $RebootsTable | Sort-Object "Last Boot"
  $RebootsTable | Export-Csv -Path "$AttachmentPath" -NoTypeInformation -Force
  Write-Host "Generated report!" -ForegroundColor DarkGreen
}
catch {
  Write-Host "Failed to generate report. Please check filesystem permissions and working directory." -ForegroundColor DarkRed
  Break
}

$Body = "
Attached is the report of last boot times for $SiteName's servers for the maintenance window on $MaintenanceDate. 

Please ensure all of the site's servers have rebooted during the maintenance window. 
If any have not rebooted, please reboot them by the end of the maintenance window.
"
Write-Host "Sending email report to $Recipients..." -ForegroundColor DarkYellow
try {
  Send-MailMessage -to "$recipients" -From $Sender -subject "Report - Maintenance Window Reboots - $MaintenanceDate" -Body $body -SmtpServer $SmtpServer -Attachments $AttachmentPath
  Write-Host "Sent report successfully!" -ForegroundColor DarkGreen
}
catch {
  Write-Host "Failed to send email report. Please check script syntax and availability of SMTP server." -ForegroundColor DarkRed
  Break
}

# Script cleanup
Write-Host "Cleaning up temporary files..." -ForegroundColor DarkYellow
Remove-Item "$AttachmentPath" -Force
