<#
.SYNOPSIS
  This script is a basic application watchdog.
.DESCRIPTION
  This script acts as an application watchdog. It checks for a running instance of the specified application and
	if there is no current instance of it, starts the application.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author         :   Barker, Griffeth (barkergriffeth@gmail.com)
  Change Date    :   2024-07-20
  Purpose/Change :   Initial development

  This script was originally born out of necessity for an archaic and awful application our team had to support.
	For sanitization purposes, I've replaced the specified application with Notepad++ as an exmaple.
.EXAMPLE
  .\application_watchdog.ps1
#>

$displayStart = '20:28:00'
$displayEnd = '20:29:00'
$processName = 'notepad++'
$processPath = 'C:\Program Files\Notepad++\notepad++.exe'

while ($true) {
	# LIVE HOURS
	if (((Get-Date) -gt $displayStart) -and ((Get-Date) -lt $displayEnd)) {
		if ((Get-Process -Name $processName).Count -lt 1) {
			Start-Process -Path $processPath
		}
	}
}
