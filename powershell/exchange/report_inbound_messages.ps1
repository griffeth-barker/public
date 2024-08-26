<#
.SYNOPSIS
  This script generates a report of ExchangeOnline users and their inbound mail volume.
.DESCRIPTION
  This script gets a list of ExchangeOnline users. For each of these users, the count of
  inbound messages from internal addresses and the count of inbound messages from external
  addresses is reported.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Modified Date:  2023-12-13
  Purpose/Change: Initial development

  This script must be run in the context of a user who is a Microsoft 365 account with 
  administrative permissions to ExchangeOnline.
.EXAMPLE
  None
#>

#############################################################################################
# SCRIPT MAINTENANCE BLOCK                                                                  #
#                                                                                           #
# Frequently changed items can be found here for you to update as needed.                   #
#############################################################################################

# Working directory
$working_dir = "C:\temp"

# Report runner
# This is used to connect to ExchangeOnline and is determined based on the execution
# context of the console in which the script is run. This can be overridden by commenting
# out the below line and specifying a specific user principle name.
# $report_runner = "userprincipalname@example.tld"
$report_runner = "$($env:username)" + "@" + "$(($env:userdnsdomain).ToLower())"

# Microsoft Online Domain
# Specify your Microsot 365 tenant's FQDN here.
$m365_org_domain = "changeme.onmicrosoft.com"

# Your organization's domain
# This is used as part of determining if the messages are internal or external.
$orgDomain = "changeme.com"

#############################################################################################
# DEPENDENCY CHECKS                                                                         #
#                                                                                           #
# Any prerequisites will be checked. If any are not satisfied, the script will exit.        #
#############################################################################################

# Check for ExchangeOnlineManagement PowerShell Module
# If import fails, attempt installation and import. Failing that, exit the script.
Write-Host "Checking for ExchangeOnlineManagement PowerShell Module dependency..."
try {
  Import-Module -Name ExchangeOnlineManagement -Force
  Write-Host "Checking for ExchangeOnlineManagement PowerShell Module dependency...OK"
}
catch {
  try {
    Install-Module -Name ExchangeOnlineManagement -Force -Confirm:$false
    Import-Module -Name Active-Directory -Force -Confirm:$false
    Write-Host "Checking for ExchangeOnlineManagement PowerShell Module dependency...OK"
  }
  catch {
    Write-Output "Checking for ExchangeOnlineManagement PowerShell Module dependency...FAILED"
    Write-Host "The script will now exit (1)"
    Exit 1
  }
}

# Check for working directory
Write-Host "Checking for $working_dir..."
if (!(Test-Path -Path "$working_dir")) {
  Write-Host "Creating $working_dir..."
  try {
    New-Item -Path "C:\" -ItemType Directory -Name "temp"
    Write-Host "Creating $working_dir...OK"
  }
  catch {
    Write-Output "Creating $working_dir...FAILED"
    Write-Host "The script will now exit (1)"
    Exit 1
  }
} else {
  Write-Host "Checking for $working_dir...OK"
}

#############################################################################################
# REPORT GENERATION                                                                         #
#                                                                                           #
# Connect to ExchangeOnline, gather facts, and export report.                               #
#############################################################################################

# Create reporting table
$report_table = New-Object -Type System.Data.DataTable
[void]$report_table.Columns.Add("Display Name")
[void]$report_table.Columns.Add("Primary SMTP Address")
[void]$report_table.Columns.Add("Office")
[void]$report_table.Columns.Add("Inbound - Internal")
[void]$report_table.Columns.Add("Inbound - External")
[void]$report_table.Columns.Add("Inbound - Total")

# Connect to ExchangeOnline
# For more information on the authentication for ExchangeOnline, see:
# https://learn.microsoft.com/en-us/powershell/exchange/connect-to-exchange-online-powershell?view=exchange-ps
Write-Host "Connecting to ExchangeOnline as $report_runner..."
try {
  Connect-ExchangeOnline -UserPrincipalName $report_runner -Organization $m365_org_domain -ShowBanner:$false 
  Write-Host "Connecting to ExchangeOnline as $report_Runner...OK"
}
catch {
  Write-Output "Connecting to ExchangeOnline as $report_runner...FAILED"
  Write-Host "The script will now exit (1)"
  Exit 1
}

# Define the date range for the report
$end_date = Get-Date
$start_date = $end_date.AddDays(-7)

# Get all mailboxes
Write-Host "Getting all mailboxes for inspection..."
try {
  $mailboxes = Get-Mailbox -ResultSize Unlimited
  Write-Host "Getting all mailboxes for inspection...OK"
}
catch {
  Write-Output "Getting all mailboxes for inspection...FAILED"
  Write-Host "The script will now exit (1)"
  Exit 1
}

# Get count of total mailboxes, and set progress index to 0
$mailboxes_count = $mailboxes.Count
$mailboxes_index = 0

# Iterate through mailboxes and gather facts
foreach ($mailbox in $mailboxes) {
  # Increment the progress index for the graphical progress bar
  $mailboxes_index++

  # Display/update the graphical progress bar
  Write-Progress -Activity "Iterating through $mailboxes_count mailboxes..." -CurrentOperation "Gathering facts for $($mailbox.PrimarySmtpAddress)..." -PercentComplete (($mailboxes_index / $mailboxes_count) * 100)

  # Get message trace data
  $messages = Get-MessageTrace -RecipientAddress $mailbox.PrimarySmtpAddress -StartDate $start_date -EndDate $end_date -PageSize 5000

  # Count internal and external messages
  # These are differentiated based on the SenderAddress property of the message reported by
  # the message trace. If the SenderAddress ends with our domain, then it is considered internal
  # and if the SenderAddress does not end with our domain, then it is considered external.
  $internal_count = ($messages | Where-Object { $_.SenderAddress -like "*@$orgDomain" }).Count
  $external_count = ($messages | Where-Object { $_.SenderAddress -notlike "*@$orgDomain" }).Count
  $total_count = $internal_count + $external_count

  # Add results to the reporting table
  [void]$report_table.Rows.Add($mailbox.DisplayName, $mailbox.PrimarySmtpAddress, $mailbox.Office, $internal_count, $external_count, $total_count)
}

# Disconnect from ExchangeOnline
Write-Host "Disconnecting from ExchangeOnline..."
try {
  Disconnect-ExchangeOnline -Confirm:$false | Out-Null
  Write-Host "Disconnecting from ExchangeOnline...OK"
}
catch {
  Write-Output "Disconnecting from ExchangeOnline...FAILED"
  Write-Host "The script will continue; you may want to investigate your connection to ExchangeOnline."
}

# Export report to working directory
$report_table | Export-Csv -Path "$working_dir\exchangeonline_inbound_messages_report.csv" -NoTypeInformation -Force

# Prompt asking if script runner wants to open the location of the report
switch (Read-Host "Would you like to open the exported report's location? (y/n)") {
  y {
    Write-Host "Opening report location."
    Start-Process explorer.exe -ArgumentList "$working_dir" -WorkingDirectory "$working_dir"
    Write-Host "The script will now exit (0)"
    Exit 0
  }
  n {
    Write-Host "The report can be found at $working_dir\."
    Write-Host "The script will now exit (0)"
    Exit 0
  }
}
