<#
.SYNOPSIS
  This script creates registry keys which mitigate CVE-2013-3900 to remediate a vulnverability which could allow attackers to run arbitrary
  code on the system.
.DESCRIPTION
  This script creates two registry keys and sets their values:
    - HKEY_LOCAL_MACHINE\Software\Microsoft\Cryptography\Wintrust\Config\EnableCertPaddingCheck
    - HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config\EnableCertPaddingCheck

  For more information, see https://msrc.microsoft.com/update-guide/vulnerability/CVE-2013-3900
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2022-11-04
  Purpose/Change: Initial development

  This script can be run via SCCM.
.EXAMPLE
  .\security_enable_certificate_padding_check.ps1
#>

try {
  # 32-bit keys
  New-Item "HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust" -Force | Out-Null
  New-Item "HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config" -Force | Out-Null
  New-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config" -name "EnableCertPaddingcheck" -value "1" -PropertyType "DWord" -Force | Out-Null

  # 64-bit keys
  New-Item "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust" -Force | Out-Null
  New-Item "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" -Force | Out-Null
  New-ItemProperty -path "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" -name "EnableCertPaddingcheck" -value "1" -PropertyType "DWord" -Force | Out-Null

  # Console output
  Write-Host "Registry keys applied successfully!" -ForegroundColor DarkGreen
}
catch {
  Write-Host "Failed to apply registry keys." -ForegroundColor DarkRed
}
