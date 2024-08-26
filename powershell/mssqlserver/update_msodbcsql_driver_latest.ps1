<#
.SYNOPSIS
  This script updates the Microsoft SQL Server ODBC Driver.
.DESCRIPTION
  This script will check the current version family for the Microsoft SQL Server ODBC Driver (17/18) and
  download the latest update, then install it.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Griffeth Barker (barkergriffeth@gmail.com)
  Creation Date:  2023-11-15
  Purpose/Change: Initial development

  This script is intended to be run via SCCM.
.EXAMPLE
  None
#>

# This is the working directory on the computer where the files will be downloaded.
$workingdir = "C:\temp"

# Check for C:\temp as working directory.
if (!(Test-Path -Path $workingdir)) {
  New-Item -Path "C:\" -Name "temp" -ItemType Directory -Force
}

# Get the current SQL ODBC driver version
$prepatch_version = (Get-CimInstance -class Win32_Product | Where-Object { $_.Name -like "Microsoft ODBC Driver * for SQL Server" }).Version
$version_family = $prepatch_version.split(".")[0]

# Get content of Microsoft Learn webpage for the ODBC Driver for SQL Servers
$webpage = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server?view=sql-server-ver16'

# Download the appropriate update
try {
  $URL = "$(($webpage.links.outerhtml | Select-String -SimpleMatch "Download Microsoft ODBC Driver $version_family for SQL Server (x64)" | Out-String).split('"')[1])"
  $Path = "$workingdir\msodbcsql.msi"
  (New-Object System.Net.WebClient).DownloadFile($URL, $Path)
}
catch {
  Write-Output "FAILED: Could not download installer"
  Exit 1
}

# Install the update
try {
  Start-Process msiexec.exe -Wait -ArgumentList '/i "C:\temp\msodbcsql.msi" /q'

  $postpatch_version = (Get-CimInstance -class Win32_Product | Where-Object { $_.Name -like "Microsoft ODBC Driver * for SQL Server" }).Version

  Write-Output "CHANGED: $prepatch_version -> $postpatch_version"
  Exit 0
}
catch {
  Write-Output "FAILED: Could not run installer"
  Exit 1
}

# Clean up installer
Remove-Item -Path "$workingdir\msodbcsql.msi" -Force -Confirm:$false | Out-Null
