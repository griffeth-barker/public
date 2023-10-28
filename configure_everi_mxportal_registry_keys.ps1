<#
.SYNOPSIS
  This script imports necessary registry keys to set up Everi MXPortal for users of the server.
.DESCRIPTION
  The Everi MXPortal application utilizes registry keys stored in each user's HKEY_CURRENT_USER
  hive, which is only loaded while they are actiely logged on. This script loads each user's
  offline hive (NTUSER.DAT from their C:\Users\username path), then creates the needed registry
  keys, then unloads the hive.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2023-04-29
  Purpose/Change: Initial script development

  I am not affiliated with, nor sponsored by Everi and this is not an official script. This,
  like many scripts, was born out of necessity as Everi's desktop application for MXPortal
  requires a name and key configuration to access slot meter data, and these are configured
  via keys in the registry. The keys are stored in each user's CurrentUser hive, so I needed
  a solution to configure the default CurrentUser hive so new users logging onto the RDS server
  where the application is installed would get the proper configuration, and that existing users
  who alrady had their CurrentUser hive created could have the requisite keys added as well.
.EXAMPLE
  None
#>

# Determine the site
# The site information was provided by Everi, and can be found in LastPass.
# The $multi_site variable lets the loop know whether it needs to process multiple configurations.
switch ($env:computername).Substring(0,3)) {
  Site1 {
    $multi_site = $false
    $site_property_name = "changeme"
    $site_property_key = "changeme"
  }
  Site2 {
    $multi_site = $false
    $site_property_name = "changeme"
    $site_property_key = "changeme"
  }
  Site3 {
    $multi_site = $true
    $site_property1_name = "changeme"
    $site_property1_key = "changeme"
    $site_property2_name = "changeme"
    $site_property2_key = "changeme"
  }
  Site4 {
    $multi_site = $true
    $site_property1_name = "changeme"
    $site_property1_key = "changeme"
    $site_property2_name = "changeme"
    $site_property2_key = "changeme"
  }
}

# Enumerate user profile directories
$user_profiles = (Get-ChildItem -Path "C:\Users\" | Select-Object FullName).FullName

# Check for HKU PSDrive and create it if missing
try {
  Get-PSDrive HKU: -ErrorAction Stop
}
catch {
  New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
}
Set-Location HKU:\

# Loop through users' offline registry hives and import needed registry keys
foreach ($user_profile in $user_profiles) {
  $user_name = $user_profile.split("\")[2]
  Write-Host "Working on configuration for $user_profile"
  REG LOAD HKU\tmpusrhive $user_profile\NTUSER.DAT
  Start-Sleep -Seconds 5
  if ((Test-Path -Path HKU:\tmpusrhive\SOFTWARE\Everi\MXPortal\Properties) -eq $false){
    New-Item -Path HKU:\tmpusrhive\SOFTWARE -Name "Everi" -ItemType Key
    Start-Sleep -Seconds 1
    New-Item -Path HKU:\tmpusrhive\SOFTWARE\Everi -Name "MXPortal" -ItemType Key    
    Start-Sleep -Seconds 1
    New-Item -Path HKU:\tmpusrhive\SOFTWARE\Everi\MXPortal -Name "Properties" -ItemType Key
    Start-Sleep -Seconds 1
    if ($multi_site -eq $true) {
      New-ItemProperty -Path HKU:\tmpusrhive\SOFTWARE\Everi\MXPortal\Properties -Name "$site_property1_name" -PropertyType "String" -Value "$site_property1_key"
      Start-Sleep -Seconds 1
      New-ItemProperty -Path HKU:\tmpusrhive\SOFTWARE\Everi\MXPortal\Properties -Name "$site_property2_name" -PropertyType "String" -Value "$site_property2_key"
      Start-Sleep -Seconds 1
    }
    else {
      New-ItemProperty -Path HKU:\tmpusrhive\SOFTWARE\Everi\MXPortal\Properties -Name "$site_property_name" -PropertyType "String" -Value "$site_property_key"
      Start-Sleep -Seconds 1
    }
  }
  else {
    Write-Host "Skipping configuration for $user_name because the HKU:\tmpusrhive\SOFTWARE\Everi\MXPortal\Properties key already exists."
  }
  REG UNLOAD HKU\tmpusrhive
  Start-Sleep -Seconds 5
}
