<#
.SYNOPSIS
  This script performs a backup of all ESXi host configurations.
.DESCRIPTION
  This script creates a backup of each ESXi host's configuration and exports it to the specified path using VMware PowerCLI.
.PARAMETER
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Griffeth Barker
  Creation Date:  7-1-2022
  Purpose/Change: Initial script development
  
  You will need to use New-VICredentialStoreItem prior to running the script to create the credential file that the script
  will use to authenticate with vCenter.
.EXAMPLE
  None
#>

# Declare the backup directory/target
$BackupDirectory = "\\path\where\you\want\backups\saved"

# Import PowerCLI module
try {
  Import-Module -Name "VMware.VimAutomation.Core" -ErrorAction Stop
}
catch {
  Exit
}

# Connect to vCenter
try {
  $ScriptCreds = Get-VICredentialStoreItem -File "\\path\to\credential.xml"
  Connect-VIServer -Server $ScriptCreds.Host -User $ScriptCreds.User -Password $ScriptCreds.Password -Force -ErrorAction Stop
}
catch {
  Exit
}

# Create result table
$ResultTable = New-Object System.Data.Datatable
[void]$ResultTable.Columns.Add("Host")
[void]$ResultTable.Columns.Add("UUID")
[void]$ResultTable.Columns.Add("Status")

# Discover and delete backup files whose age exceeds 7 days. These backups are still availble in Veeam.
Get-ChildItem $BackupDirectory -Recurse -Force -ea 0 |
Where-Object { !$_.PsIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
ForEach-Object {
    $_ | Remove-Item -Verbose -Force
}

# Get list of all ESXi hosts in vCenter
$VmHosts = (Get-VmHost -Name "*").Name | Sort-Object

# Loop through the list and for each ESXi host, back up the configuration, as well as list the host's UUID
foreach ($VmHost in $VmHosts){
  try {
    $VmHostProps = Get-VmHost -Name $VmHost | Select-Object Name,@{n="HostUUID";e={$_.ExtensionData.hardware.systeminfo.uuid}}
    Get-VmHostFirmware -VmHost $VmHost -BackupConfiguration -DestinationPath "$BackupDirectory" -ErrorAction Stop
    [void]$ResultTable.Rows.Add($VmHost,$VmHostProps.HostUUID,"Success")
  }
  catch {
    [void]$ResultTable.Rows.Add($VmHost,$VmHostProps.HostUUID,"Failed")
  }
}

# Disconnect from vCenter
Disconnect-VIServer -Server $ScriptCreds.Host -Confirm:$false 

# Final output for PowerShell Universal to access
Clear-Host
$ResultTable
