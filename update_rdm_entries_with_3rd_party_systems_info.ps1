<#
.SYNOPSIS
  This script updates RDM entries with facts from our other systems.
.DESCRIPTION
  This script loops through each Remote Desktop Manager session entry (filtered to only include SSH Shell
  and Remote Desktop Protocol sessions) and gets the CI ID from ManageEngine CMDB and the Node ID from
  SolarWinds Orion. These values are populated into CUSTOM_FIELD1 and CUSTOM_FIELD2 in the RDM session
  entries; the IT Asset Management URL and Homepage URL for the entry are set to the appropriate format
  for each platform so the node's webpage can display in the Dashboard tabs for the entry.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Griffeth Barker (barkergriffeth@gmail.com)
  Modified Date:  03-22-2023
  Purpose/Change: Initial development

  This script must be run from a node where Remote Desktop Manager is installed and the MSSQL data source 
  "JEI-RDM" is configured. The user running the script must have 2FA configured for this instance and be
  already authenticated into the application.

  Several log files are generated at C:\temp to help track down any issues should they arise.
.EXAMPLE
  None
#>

################################################################################################################
# SCRIPT SETUP                                                                                                 #
################################################################################################################

# Timestamp function for logging
function Get-TimeStamp {
    return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
  }

# Script setup
Write-Host "[$(Get-Timestamp)] Setting up..." -ForegroundColor DarkYellow
Write-Host "[$(Get-Timestamp)] Checking for existence of C:\temp ..."
$WorkingDir = "C:\temp"
if (Test-Path -Path $WorkingDir){
  Write-Host "[$(Get-Timestamp)] Validated working directory." -ForegroundColor DarkGreen
}
else {
  Write-Host "[$(Get-Timestamp)] Could not find C:\temp - creating it now..." -ForegroundColor DarkYellow
  New-Item -Path "C:\" -Name "temp" -ItemType "directory" -Force
  Write-Host "[$(Get-Timestamp)] Created C:\temp - proceeding." -ForegroundColor DarkGreen
}

$FileDate = Get-Date -Format 'yyyyMMdd-HHmm'
Start-Transcript -Path "C:\temp\update-rdm-entries-$FileDate.log" -Force
 
$CmdbLogPath = "C:\temp\update-rdm-entries-$FileDate-cmdb-errors.log"
$SwLogPath = "C:\temp\manageupdate-rdm-entries-$FileDate-sw-errors.log"
$RdmLogPath = "C:\temp\manageupdate-rdm-entries-$FileDate-rdm-errors.log"
New-Item -Path "$CmdbLogPath" -Force | Out-Null
New-Item -Path "$SwLogPath" -Force | Out-Null
New-Item -Path "$RdmLogPath" -Force | Out-Null

# Be sure to update these variables to match your environment
$YourDomain = "yourdomain.here"
$ManageEngineApiToken = "your_token_here"
$ManageEngineServer = "your_server_fqdn_here"
$SolarWindsApiToken = "your_token_here"
$SolarWindsServer = "your_server_fqdn_here"

################################################################################################################
# DOING THE NEEDFUL                                                                                            #
################################################################################################################

# Get SSH and RDP entries in RemoteDesktopManager
Write-Host "[$(Get-Timestamp)] Importing RemoteDesktopManage PowerShell module..." 
try {
    Import-Module -Name RemoteDesktopManager
    Write-Host "[$(Get-Timestamp)] Importing RemoteDesktopManager PowerShell module - Success!" -ForegroundColor Green
}
catch {
    Write-Host "[$(Get-Timestamp)] Importing RemoteDesktopManager PowerShell module - Failed! Script will exit." -ForegroundColor Red
    Pause
    Exit
}

Write-Host "[$(Get-Timestamp)] Getting list of RDM entries to update..."
try {
    $RdmList = Get-RDMSession | Where-Object {$_.ConnectionType -like "RDP*" -or $_.ConnectionType -like "SSH*" -and $_.Name -notlike "*test*" -and $_.Name -notlike "*LAB*" -and $_.Group -notlike "*RemoteApps*"}
    $RdmArray = @()
    foreach ($Rdm in $RdmList) {  
        if ($Rdm.Name -like "$*"){
            $RdmName = $Rdm.HostResolved
        }
        else {
            $RdmName = $Rdm.Name
            }
        $RdmArray += $RdmName
    }
    Write-Host "[$(Get-Timestamp)] Getting list of RDM entries to update - success!" -ForegroundColor Green
}
catch {
    Add-Content -Path ""
    Write-Host "[$(Get-Timestamp)] Getting list of RDM entries to update - failed! Script will exit." -ForegroundColor Red
    Pause
    Exit
}

# Loop through each entry, gather facts, and update RDM entries
foreach ($Rdm in $RdmArray){
    Write-Host "[$(Get-Timestamp)] $Rdm - Beginning processing!" -BackgroundColor Yellow
    try {
        # Get the CI ID from ManageEngine
        Write-Host "[$(Get-Timestamp)] $Rdm - Getting CI ID from ManageEngine..."
        $Sdpurl = "https://$ManageEngineServer/api/v3/reports/execute_query"
        $Sdptechnician_key = @{"authtoken"="$ManageEngineApiToken"}
        $Sdpinput_data = @"
{
"query": "SELECT CIID FROM Resources WHERE RESOURCENAME='$Rdm' OR RESOURCENAME='$Rdm.bhwk.com';"
}
"@
        $Sdpdata = @{ 'input_data' = $Sdpinput_data}
        $Sdpresponse = Invoke-RestMethod -Uri $Sdpurl -Method post -Body $Sdpdata -Headers $Sdptechnician_Key -ContentType "application/x-www-form-urlencoded"
        $CIID = $Sdpresponse.execute_query.data.CIID
        Write-Host "[$(Get-Timestamp)] $Rdm - Getting CI ID from ManageEngine - success!" -ForegroundColor Green
    }
    catch {
        Write-Host "[$(Get-Timestamp)] $Rdm - Getting CI ID from ManageEngine - failed!" -ForegroundColor Yellow
        Add-Content -Path "$CmdbLogPath" -Value "$Rdm"
    }

    # Get the Node ID from SolarWinds
    Write-Host "[$(Get-Timestamp)] $Rdm - Getting Node ID from SolarWinds..."
    try {
        # Begin temporary workaround for certificate issue on jeisolar.bhwk.com #######################################
        if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type){
        $certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
        Add-Type $certCallback
        }
        [ServerCertificateValidationCallback]::Ignore()
        # End temporary workaround ####################################################################################

        $SwHeaders = @{}
        $SwHeaders.Add("Authorization", "Basic $SolarWindsApiToken")
        # Note that the line below will search for both the short NETBIOS name as well as the FQDN of the node, just in case
        # It is expected that nodes are entered into our systems using only the short form, however some systems will automatically
        # append the domain, so this takes care of that issue.
        $SwUrl = "https://$SolarWindsServer:17778/SolarWinds/InformationService/v3/Json/Query?query=SELECT+NodeId+FROM+Orion.Nodes+WHERE+NodeName='$Rdm'+OR+NodeName='$Rdm.$YourDomain'"
        $SwResponse = Invoke-RestMethod -Uri $SwUrl -Method Get -Headers $SwHeaders
        $NodeID = $SwResponse.results.nodeid
        Write-Host "[$(Get-Timestamp)] $Rdm - Getting Node ID from SolarWinds - success!" -ForegroundColor Green 
    }
    catch {
        Write-Host "[$(Get-Timestamp)] $Rdm - Getting Node ID from SolarWinds - failed!" -ForegroundColor Yellow
        Add-Content -Path "$SwLogPath" -Value "$Rdm"
    }

    # Update the RDM Entry
    Write-Host "[$(Get-Timestamp)] $Rdm - Updating RDM entry..."
    try {
        # Filtered here to make sure you don't go trying to edit Website entries for nodes that may have multiple types
        # of entries, since the fields we are attempting to update do not exist on Web and other entry types.
        $EditSession = Get-RDMSession -Name "$Rdm" | Where-Object {$_.ConnectionType -eq "SSHShell" -or $_.ConnectionType -eq "RDPConfigured"}

        # You will need to manually replace $ManageEngineServer in the below here/now string. The here/now string
        # is used because we do not want to script to attempt to resolve $CUSTOM_FIELD1$, thus $ManageEngineServer
        # will not resolve as declared at the beginning of the script.
        $EditSession.MetaInformation.InventoryManagementUrl = @'
https://$ManageEngineServer/ViewCIDetails.do?ciId=$CUSTOM_FIELD1$&
'@

        # You will need to manually replace $SolarWindsServer in the below here/now string. The here/now string
        # is used because we do not want to script to attempt to resolve $CUSTOM_FIELD2$, thus $SolarWindsServer
        # will not resolve as declared at the beginning of the script.
        $EditSession.MetaInformation.ServerHomePageUrl = @'
https://$SolarWindsServer/Orion/NetPerfMon/NodeDetails.aspx?NetObject=N:$CUSTOM_FIELD2$
'@
    
        $EditSession.MetaInformation.InventoryManagementTitle = "CMDB"
        $EditSession.MetaInformation.CustomField1Title = "ManageEngine CI ID"
        $EditSession.MetaInformation.CustomField1Value = "$CIID"
        $EditSession.MetaInformation.CustomField2Title = "SolarWinds Node ID"   
        $EditSession.MetaInformation.CustomField2Value = "$NodeID"
        $EditSession.MetaInformation.ServerHomePageTitle = "SolarWinds"
    
        # Save the changes to the entry
        Write-Host "[$(Get-Timestamp)] $Rdm - Saving the RDM entry..."
        Set-RDMSession -Session $EditSession
    
        Write-Host "[$(Get-Timestamp)] $Rdm - Saving the RDM entry - success!" -BackgroundColor Green
    }
    catch {
        Write-Host "[$(Get-Timestamp)] $Rdm - Saving the RDM entry - failed!" -BackgroundColor Yellow
        Add-Content -Path "$RdmLogPath" -Value "$Rdm"
    }
}
Write-Host "[$(Get-Timestamp)] Done updating RDM entries! Please review the log files at 'C:\temp' for any items that failed to update." -BackgroundColor Green

################################################################################################################
# SCRIPT CLEANUP                                                                                               #
################################################################################################################

# Remove any empty log files (if there were no errors, these won't matter)
if ($null -eq (Get-Content -Path $CmdbLogPath)){
    Write-Host "[$(Get-Timestamp)] There were no errors obtaining CI IDs from ManageEngine. The empty log file will be removed."
    Remove-Item -Path "$CmdbLogPath" -Force -Confirm:$false
}
if ($null -eq (Get-Content -Path $SwLogPath)){
    Write-Host "[$(Get-Timestamp)] There were no errors obtaining Node IDs from SolarWinds. The empty log file will be removed."
    Remove-Item -Path "$SwLogPath" -Force -Confirm:$false
}
if ($null -eq (Get-Content -Path $RdmLogPath)){
    Write-Host "[$(Get-Timestamp)] There were no errors updating RDM session entries. The empty log file will be removed."
    Remove-Item -Path "$RdmLogPath" -Force -Confirm:$false
}

# End the transcript that acts as the main log file
Stop-Transcript
