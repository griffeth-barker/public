<#
.SYNOPSIS
  This script will check to see if the registry key for SMB signing enforcement is set correctly, and if not, fix it.
.DESCRIPTION
  This script checks the RequireSecuritySignature DWORD value for LanManWorkstation parameters, expecting "1". If "0" is found, it is corrected.
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2022-04-26
  Purpose/Change: Initial script development
  
.EXAMPLE
  NA
#>

# Check current SMB signing configuration
$CurrentSmbSigning = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManWorkstation\Parameters").RequireSecuritySignature

# Enforce SMB signing if it is not already enforced, otherwise if it is already enforced quit without making changes
if (0 -eq $CurrentSmbSigning) {
  Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManWorkstation\Parameters" -Name "RequireSecuritySignature" -Value "1"
}
elseif (0 -ne $CurrentSmbSigning) {
  Exit
}
