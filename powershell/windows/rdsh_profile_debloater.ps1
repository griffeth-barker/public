<#
.SYNOPSIS
  This script cleans up user profile bloat on RDS session hosts.
.DESCRIPTION
  This script cleans up user profile bloat on Remote Desktop Services session hosts. Intended to be run as
  a logoff script by a GPO with loopback processing enabled, this script will remove all files from the user's
  cache, Google Chrome cache, local temp directory, and will delete files in their Downloads directly older 
  than 7 days. Additionally, it will empty the user's recycle bin and clears their terminal services cache.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author         :   Barker, Griffeth (barkergriffeth@gmail.com)
  Change Date    :   2024-08-19
  Purpose/Change :   Add Chrome Service Worker CacheStorage to targetDirs

  This script is intended to be stored in the domain's NETLOGON share and applied via Group Policy Object with
  loopback processing enabled.

  This script can optionally output to the Windows Event Log. This functionality requires administrative privileges,
  whereas the script usually does not. You can enable this functionality by uncommenting the relevant lines and then
  commenting out the existing lines related to the logging function. Be sure to adjust how you call the script if so.
    Event IDs:
     - 1000: Debloat run start
     - 2001: Attempting to stop Google Chrome
     - 2002: Removal of files from user's cache directories
     - 2003: Removal of files older than specified date range from user's Downloads directory
     - 3000: Debloat run end
.EXAMPLE
  .\rdsh_profile_debloater.ps1
#>

# Function for logging and logging parameters
function Write-CustomLog {
  Param ([string]$LogString)
  $Stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $LogMessage = "$Stamp $LogString"
  Add-Content $LogFile -value $LogMessage
}

$Logfile = "$env:USERPROFILE\cleanup_profile_script.log"


# # Logging parameters
# $evtx_logname = "RDSH User Profile Debloater"
# $evtx_computername = $env:computername
# $evtx_sources = @(
#     "Group Policy",
#     "Pipeline",
#     "Script Output"
# )

# # Check for event log and create it if missing
# try {
#     Get-EventLog -LogName $evtx_logname | Select-Object -First 0
# }
# catch {
#     New-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source $evtx_sources
# }

# Directories where all files should be removed
$targetDirs = @(
  'AppData\Local\Temp',
  'AppData\Local\Microsoft\Terminal Server Client\Cache',
  'AppData\Local\Microsoft\Windows\WER',
  'AppData\Local\Microsoft\Windows\AppCache',
  'AppData\Local\CrashDumps'
  'AppData\Local\Google\Chrome\User Data\Default\Cache',
  'AppData\Local\Google\Chrome\User Data\Default\Cache2\entries',
  'AppData\Local\Google\Chrome\User Data\Default\Cookies',
  'AppData\Local\Google\Chrome\User Data\Default\Media Cache',
  'AppData\Local\Google\Chrome\User Data\Default\Cookies-Journal',
  'AppData\Local\Google\Chrome\User Data\Default\Service Worker\CacheStorage'
)

# Directories where only files older than specified range should be removed
$datedDirs = @(
  'Downloads'
)
$datedDirsThreshold = (Get-Date).AddDays(-7)

# Reader-friendly username for current user including domain name.
$currentUser = $env:UserDomain + "\"+ $env:UserName

Write-CustomLog "Starting profile cleanup script run for $currentUser"
#Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Group Policy" -EntryType Information -Message "Beginning a debloat run of user profile for $currentUser" -EventId 1000

# Check size of user profile before debloating
# This can take a long time for larger user profiles and is optional. Use only if you want the reporting.
#$profileSizePre = "{0:N2} GB" -f (Get-ChildItem -Path $env:USERPROFILE -Force -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1Gb

# Stop Google Chrome process to allow Chrome cache cleanup
Write-CustomLog "Stopping Chrome.exe Process for $currentUser"
#Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Script Output" -EntryType Information -Message "Stopping Google Chrome for $currentUser" -EventId 2001
Get-Process -Name chrome -ErrorAction SilentlyContinue | Where-Object {$_.SI -eq (Get-Process -PID $PID).SessionId} | Stop-Process
Start-Sleep -Seconds 5

# Execute cleanup of directories where all files should be removed
foreach ($targetDir In $targetDirs) {
  if ((Test-Path -Path "$env:USERPROFILE\$targetDir") -eq $true) {
      Write-CustomLog "Clearing $env:USERPROFILE\$targetDir"
      #Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Script Output" -EntryType Information -Message "Clearing $env:USERPROFILE\$targetDir" -EventId 2002
      Remove-Item -Path "$env:USERPROFILE\$targetDir" -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$false -Verbose 4>&1 | Add-Content $Logfile
  }
}

# Execute cleanup of directories where files older than specified range should be removed
foreach ($datedDir In $datedDirs) {
  if ((Test-Path -Path "$env:USERPROFILE\$datedDir") -eq $true) {
      Write-CustomLog "Clearing $env:USERPROFILE\$datedDir"
      #Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Group Policy" -EntryType Information -Message "Clearing $env:USERPROFILE\$datedDir" -EventId 2003
      Get-ChildItem -Path "$env:USERPROFILE\$datedDir" -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_.LastWriteTime -lt $datedDirsThreshold)} | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Verbose 4>&1 | Add-Content $Logfile
  }
}

# Empty user's Recycle Bin
Clear-RecycleBin -Force -Confirm:$false

# Check size of user profile after debloating
# This can take a long time for larger user profiles and is optional. Use only if you want the reporting.
#$profileSizePost = "{0:N2} GB" -f (Get-ChildItem -Path $env:USERPROFILE -Force -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1Gb

Write-CustomLog "End profile cleanup script"
#Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Group Policy" -EntryType Information -Message "Completed a debloat run of user profile for $currentUser" -EventId 3000
