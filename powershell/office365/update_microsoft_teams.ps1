<#
.SYNOPSIS
  This script reinstalls Microsoft Teams using the latest version.
.DESCRIPTION
  This script reinstalls Microsoft Teams using the latest version by:
    - Getting currently installed version
    - Checking latest available version
    - Comparing the two above versions and if an update is available;
        - Downloads the new version
        - Installs the new version
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2023-08-01
  Purpose/Change: Initial script development
.EXAMPLE
  NA
#>

# Check for temp folder
$WorkingDir = "C:\temp"
if (Test-Path -Path $WorkingDir){
  # Continue
}
else {
  New-Item -Path "C:\" -Name "temp" -ItemType "directory" -Force
}

# Get currently installed Teams version
$installed_version = (Get-Content $env:UserProfile"\AppData\Roaming\Microsoft\Teams\settings.json" | ConvertFrom-Json).Version

# Get latest available Teams version
$Url = "https://teams.microsoft.com/desktopclient/update/$installed_version/windows/x64?ring=general"

$updateCheckResponse = Invoke-WebRequest -Uri $Url -UseBasicParsing
$updateCheckJson = $updateCheckResponse | ConvertFrom-Json
$updateCheckJson

# Compare versions
if ($updateCheckJson.isUpdateAvailable -eq $true) {
    Write-Host "Microsoft Teams version is out-of-date."
    $new_version = $updateCheckJson.releasesPath.Split("/")[4]

    # Download latest installer
    Write-Host "Downloading installer..."
    Invoke-WebRequest -Uri "https://statics.teams.cdn.office.net/production-windows-x64/$new_version/Teams_windows_x64.exe" -OutFile "C:\temp\Teams_windows_x64.exe"

    # Install latest version
    Write-Host "Installing..."
    Start-Process -FilePath "C:\temp\Teams_windows_x64.exe" -Wait

    # Clean up
    Start-Sleep -Seconds 5
    Remove-Item -Path "C:\temp\Teams_Windows_x64.exe" -Force
}
else {
    Write-Host "Microsoft Teams client is already up-to-date."
}
