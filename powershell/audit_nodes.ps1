<#
.SYNOPSIS
  This script retrieves a list of nodes from several systems and compares them to determine which nodes
	are missing from what systems.
.DESCRIPTION
  This script retrieves an array of Configuration Items (CIs) from ManageEngine Service Desk Plus via the
  CMDB REST API, retrieves an array of monitored nodes from SolarWinds Orion using the SWIS REST API, and
  retrieves a list of Session Entries from the Remote Desktop Manager data source using the RDM PowerShell
  module. Each item in the array from CMDB is compared against the arrays from SW and RDM to see if the
  CI has an entry in each. The results are reported in a comma-separated values file as an email attachment.
.PARAMETER
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Griffeth Barker (barkergriffeth@gmail.com)
  Modified Date:  03-10-2023
  Purpose/Change: Initial development

  This script must be run from a node where Remote Desktop Manager is installed and the appropriate MSSQL
	data source is configured. If 2FA is enforced for the data source, then the user must be authenticated
	to the date source prior to running this script.
.EXAMPLE
  None
#>

# Timestamp function for logging
function Get-TimeStamp {
  return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
}

# Script setup
Write-Host "[$(Get-Timestamp)] Setting up..." -ForegroundColor DarkYellow
Write-Host "[$(Get-Timestamp)] Checking for existence of C:\temp ..." -Foreground Gray
$WorkingDir = "C:\temp"
if (Test-Path -Path $WorkingDir){
  Write-Host "[$(Get-Timestamp)] Validated working directory." -ForegroundColor DarkGreen
}
else {
  Write-Host "[$(Get-Timestamp)] Could not find C:\temp - creating it now..." -ForegroundColor DarkYellow
  New-Item -Path "C:\" -Name "temp" -ItemType "directory" -Force
  Write-Host "[$(Get-Timestamp)] Created C:\temp - proceeding." -ForegroundColor DarkGreen
}

$Date = Get-Date -format yyyy-MM-dd
Start-Transcript -Path "$WorkingDir\audit_nodes_$Date.log"

$recipients = (
  "change_this@domain.local"
)
$sender = "change_this@domain.local"
$SmtpServer = "change.this.local"

$ManageEngineServer = "change.this.local"
$SolarWindsServer = "change.this.local"

$YourDomainSuffix = "change.local"

$ManageEngineToken = "your_auth_token_here"
$SolarWindsToken = "your_auth_token_here"

# Create system data table that will stage the output data
$ResultTable = New-Object System.Data.Datatable
[void]$ResultTable.Columns.Add("CMDB(Key)")
[void]$ResultTable.Columns.Add("SW")
[void]$ResultTable.Columns.Add("RDM")
Write-Host "[$(Get-Timestamp)] Setup completed!" -ForegroundColor DarkGreen

# Get array of CMDB nodes
Write-Host "[$(Get-Timestamp)] Getting list of nodes from ManageEngine ServiceDesk Plus CMDB..." -ForegroundColor DarkYellow
try {
    Write-Host "[$(Get-Timestamp)] Calling ManageEngine ServiceDesk Plus CMDB REST API..." -ForegroundColor DarkYellow
    $SdpHeaders = @{}
    $SdpHeaders.Add("authtoken", "$ManageEngineToken")
    $SdpHeaders.Add("Content-Type", "application/x-www-form-urlencoded")

    $SdpReqUrl = "https://$ManageEngineServer/api/cmdb/ci"
    $SdpBody = 'OPERATION_NAME=read&INPUT_DATA=<?xml version="1.0" encoding="UTF-8"?> <API version="1.0" locale="en"> <citype> <name>All Assets</name> <criterias> <criteria> <parameter> <name compOperator="IS">CI Type</name> <value>Firewall</value> </parameter> <reloperator>OR</reloperator> <parameter> <name compOperator="IS">CI Type</name> <value>Switch</value> </parameter> <reloperator>OR</reloperator> <parameter> <name compOperator="CONTAINS">CI Type</name> <value>Server</value> </parameter> </criteria> </criterias> <returnFields> <name>CI Name</name> </returnFields> <range> <startindex>1</startindex> <limit>9999</limit> </range> </citype> </API>'

    $SdpResponse = Invoke-RestMethod -Uri $SdpReqUrl -Method Post -Headers $SdpHeaders -ContentType 'application/x-www-form-urlencoded' -Body $SdpBody
    $SdpResponse | ConvertTo-Json
		
		# This output is filtered to exclude CIs that you may not want to audit (templates, powered off servers, lab items, etc.)
    $SdpResults = @($SdpResponse.API.response.operation.Details.'field-values'.record | Where-Object {$_.value -notlike "*Template*" -and $_.value -notlike "*Test*" -and $_.value -notlike "WIN-*" -and $_.value -notlike "*TurnedOff*" -and $_.value -notlike "*Lab*"})
    
		# The below line sanitizes the result in case your instance of CMDB uses FQDN in the Name field instead of the short NetBIOS name
		$SdpArray = @($SdpResults.value.Replace(".$YourDomainSuffix","") | Sort-Object)
    Write-Host "[$(Get-Timestamp)] Got list of ManageEngine ServiceDesk Plus CMDB nodes!" -ForegroundColor DarkGreen
}
catch {
    Write-Host "[$(Get-Timestamp)] Failed to get list of CMDB nodes! Script will exit after striking Enter key..." -ForegroundColor DarkRed
    Pause
    Stop-Transcript
    Break
}

# Get array of RDM nodes
Write-Host "[$(Get-Timestamp)] Getting array of RDM Entries..." -ForegroundColor DarkYellow
try {
  Write-Host "[$(Get-Timestamp)] Importing RemoteDesktopManager PowerShell module..."
  Import-Module -Name RemoteDesktopManager -Force
  $RdmArray = @()
	
	# This output is similarly filtered like from earlier
  $RdmList = Get-RDMSession | Where-Object {$_.ConnectionType -like "RDP*" -or $_.ConnectionType -like "SSH*" -and $_.Name -notlike "*test*" -and $_.Name -notlike "*LAB*" -and $_.Group -notlike "*RemoteApps*"}
  
	# This catches any RDM session entries that are using an $RDM_VARIABLE$ in the Name field, and will instead "resolve" those to actual values
	foreach ($Rdm in $RdmList) {  
      if ($Rdm.Name -like "$*"){
          $RdmName = $Rdm.HostResolved
      }
      else {
          $RdmName = $Rdm.Name
          }
      $RdmArray += $RdmName
  }
    Write-Host "[$(Get-Timestamp)] Success!" -ForegroundColor DarkGreen
}
catch {
    Write-Host "[$(Get-Timestamp)] Failed to get RDM entries!" -ForegroundColor Red
    Pause
    Stop-Transcript
    Break
}

# Get array of SolarWinds nodes
Write-Host "[$(Get-Timestamp)] Getting array of nodes from SolarWinds Orion..." -ForegroundColor DarkYellow

try {
    Write-Host "[$(Get-Timestamp)] Calling SolarWinds Information Service (SWIS) REST API..." -ForegroundColor DarkYellow
    $SwHeaders = @{}
    $SwHeaders.Add("Authorization", "Basic $SolarWindsToken")
    $SwUrl = "https://$SolarWindsServer:17778/SolarWinds/InformationService/v3/Json/Query?query=SELECT+NodeName+FROM+Orion.Nodes"
    $SwResponse = Invoke-RestMethod -Uri $SwUrl -Method Get -Headers $SwHeaders
    $SwResponse | ConvertTo-Json
    $SwArray = @($SwResponse.results.NodeName | Sort-Object)
    Write-Host "[$(Get-Timestamp)] Got list of SolarWinds nodes!" -ForegroundColor DarkGreen
}
catch {
    Write-Host "[$(Get-Timestamp)] Failed to get array of nodes from SolarWinds! Script will exit after striking Enter key..." -ForegroundColor DarkRed
    Pause
    Stop-Transcript
    Break
}

# Audit of nodes and reporting
foreach ($Sdp in $SdpArray){
  Write-host "[$(Get-Timestamp)] $Sdp - auditing..."
  # Check for node in SolarWinds
  $SwCheck = $Sdp -in $SwArray

  # Check for RDM Entry
  $RdmCheck = $Sdp -in $RdmArray

  # Filter results to report only items missing from one or more systems
  if ($SwCheck -eq $true -and $RdmCheck -eq $true){
    # Do nothing
  }
  else {
    # Write results to the data table
    [void]$ResultTable.Rows.Add($Sdp,$SwCheck,$RdmCheck)
  }
}

# Generate report
Write-Host "[$(Get-Timestamp)] Generating report..." -ForegroundColor DarkYellow
$AttachmentPath = "C:\temp\nodes-audit_$Date.csv"
$ResultTable | Export-Csv -LiteralPath "$AttachmentPath" -NoTypeInformation -Force
$Body = "Attached is the report for the node audit. Please review the report and ensure all nodes are in all of the following systems appropriately."

# Send report and clean up
Write-Host "[$(Get-Timestamp)] Sending email report and cleaning up temporary files..." -ForegroundColor DarkYellow
try {
  Send-MailMessage -To $Recipients -From $Sender -subject "Report - Nodes Audit $Date" -Body $Body -SmtpServer $SmtpServer -Attachments $AttachmentPath
  Write-Host "[$(Get-Timestamp)] Emailed report successfully!" -ForegroundColor DarkGreen
  Write-Host "[$(Get-Timestamp)] Cleaning up temporary files..." -ForegroundColor DarkYellow
  Remove-Item -Path "$AttachmentPath" -Force
  Write-Host "[$(Get-Timestamp)] Done!" -ForegroundColor DarkGreen
}
catch {
  Write-Host "[$(Get-Timestamp)] Failed to email report. You can find the report file at $AttachmentPath" -ForegroundColor DarkRed
}
Stop-Transcript
