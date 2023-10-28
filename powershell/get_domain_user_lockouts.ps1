<#
.SYNOPSIS
  This script gets a list of recent lockouts of the specified domain user.
.DESCRIPTION
  This script locates the primary domain controller and then queries it for recent lockouts of the specified domain user.
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2023-10-14
  Purpose/Change: Initial script development

  This script must be run by an account with at least the Account Operator permission in Active Directory.
.EXAMPLE
  None
#>

# Read input of the username to investigate
[string]$user = Read-Host "Username to investigate"

# Import the Active Directory module
Import-Module ActiveDirectory

# Get the domain controller that holds the PDC role
$PDC = (Get-ADDomainController -Discover -Service PrimaryDC).HostName

# Query the Security logs for 4740 events (account lockout)
$lockouts = Get-WinEvent -ComputerName "$PDC" -FilterHashtable @{LogName='Security'; Id=4740} |
Where-Object {$_.Properties[0].Value -eq $user} |
Select-Object TimeCreated,
    @{Name='Account Name' ; Expression={$_.Properties[0].Value}},
    @{Name='Workstation'; Expression={$_.Properties[1].Value}}

# If the user has recent lockouts, display them, otherwise return no recent lockouts message
if ($null -eq $lockouts) {
    Write-Host "The user has no recent lockouts to display." -ForegroundColor Green
}
else {
    Write-Host "The user has the following recent lockouts:" -ForegroundColor Red
    $lockouts
}
