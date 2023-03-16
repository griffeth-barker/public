<#
.SYNOPSIS
  This script sets the IT Asset Management URL for each RDM entry to the the direct link the node's
  CMDB page in ManageEngine.
.DESCRIPTION
  This script queries the ManageEngine database for a filtered list of Configuration Items' names and IDs,
  then updates the RDM entry for each node to enable the IT Asset Management tab on the Dashboard and set
  the URL to the CMDB page for that node.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Griffeth Barker
  Modified Date:  03-15-2023
  Purpose/Change: Initial development

  This script is intended for use in environments where Devolutions Remote Desktop Manager is configured 
  with a shared MSSQL data source.

  This script must be run from a node where Remote Desktop Manager is installed and the data source is 
  already configured. If the data source requieres 2FA, the user will need to be authenticated to the
  data source prior to running the script.
.EXAMPLE
  None
#>

# Timestamp function for logging
function Get-TimeStamp {
    
    return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
    
  }

##########################################################################################################
# SCRIPT SETUP                                                                                           #
##########################################################################################################

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
Start-Transcript -Path "$WorkingDir\set_asset_url_for_rdm_entries_$Date.log"

$ServiceDeskUrl = "your.managenegine.url"
$ServiceDeskToken = "your_auth_token_here"

##########################################################################################################
# DO THE NEEDFUL                                                                                         #
##########################################################################################################

# Query CMDB for a list of CI names and IDs
Write-Host "[$(Get-Timestamp)] Getting Names and IDs of all CIs in CMDB..."
$url = "https://$ServiceDeskUrl/api/v3/reports/execute_query"
$technician_key = @{"authtoken"="$ServiceDeskToken"}
$input_data = @'
{
"query": "SELECT RESOURCENAME AS Name, CIID AS ID FROM Resources WHERE (ResourceStateId='1') OR (ResourceStateId='2') ORDER BY RESOURCENAME;"
}
'@
$data = @{ 'input_data' = $input_data}
$response = Invoke-RestMethod -Uri $url -Method post -Body $data -Headers $technician_Key -ContentType "application/x-www-form-urlencoded"
$response

$SdpArray = $response.execute_query.data

# Sanitize the data by removing domain suffixes and put into a clean table
$SdpSanitized = New-Object System.Data.DataTable
[void]$SdpSanitized.Columns.Add("name")
[void]$SdpSanitized.Columns.Add("id")
foreach ($Sdp in $SdpArray){
    $SdpName = $Sdp.name.replace(".bhwk.com","") 
    $SdpId = $Sdp.id
    [void]$SdpSanitized.Rows.Add($SdpName,$SdpId)
}

# Get list of RDM entries
Write-Host "[$(Get-Timestamp)] Importing RemoteDesktopManager PowerShell module..."
Import-Module -Name RemoteDesktopManager -Force
$RdmArray = @()

Write-Host "[$(Get-Timestamp)] Getting filtered list of RDM session entries..."
$RdmList = Get-RDMSession | Where-Object {$_.ConnectionType -like "RDP*" -or $_.ConnectionType -like "SSH*" -and $_.Name -notlike "*test*" -and $_.Name -notlike "*LAB*" -and $_.Group -notlike "*RemoteApps*"} | Sort-Object

foreach ($Rdm in $RdmList) {  
    # This bit catches any entries that are using an $RDM_VARIABLE$ in this field, and will instead set the name to what the variable resolves to
    if ($Rdm.Name -like "$*"){
        $RdmName = $Rdm.HostResolved
    }
    else {
        $RdmName = $Rdm.Name
        }
    $RdmArray += $RdmName
}

# Loop through RDM entries
foreach ($Rdm in $RdmArray){

    Write-Host "[$(Get-Timestamp)] $Rdm - checking..."

    # Check if there is a matching entry in CMDB for the RDM Session
    if (($Rdm -in $SdpSanitized.Name) -eq $true) {

        Write-Host "[$(Get-Timestamp)] $Rdm - Match found, updating entry..." -ForegroundColor Green
        # CMDB management URL format
        $AssetMgmtURL = @'
https://$ServiceDeskUrl/ViewCIDetails.do?ciId=$CUSTOM_FIELD1$&
'@
        # Get the Asset ID number from the Service Desk output
        $AssetID = ($SdpSanitized | Where-Object {$_.Name -eq "$Rdm"}).id

        # Get the RDM session
        $connection = Get-RDMSession -Name $Rdm

        # Set the Asset ID
        $connection.MetaInformation.CustomField1Value = $AssetID

        # Set the Asset management info
        $connection.MetaInformation.InventoryManagementTitle = "CMDB"
        $connection.MetaInformation.InventoryManagementType = "Custom"
        $connection.MetaInformation.InventoryManagementUrl = $AssetMgmtURL

        # Save changes to the RDM session
        try {
            Set-RDMSession -Session $connection
            Write-Host "[$(Get-Timestamp)] $Rdm - Successfully updated!" -ForegroundColor Green
        }
        catch {
            Write-Host "[$(Get-Timestamp)] $Rdm - Failed to update entry!" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[$(Get-Timestamp)] $Rdm - No match found, no modifications will be made." -ForegroundColor Yellow
    }
}

##########################################################################################################
# SCRIPT CLEANUP                                                                                         #
##########################################################################################################

Stop-Transcript
