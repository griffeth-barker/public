<#
.SYNOPSIS
  This function lists recently lockouts for the specified Active Directory domain user.
.DESCRIPTION
  This function identifies the primary domain controller in the domain environment, then queries
  it's Security event log for Event Id 4740 (an account was locked out). The event's data is parsed
  and a table is returned with the specified user's most recent lockouts.
.PARAMETER User
  This parameter is required and does not accept pipeline input
  This parameter should be the samAccountName of the Active Directory domain user for which you'd like
  to find recent lockouts.
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Updated by      : Barker, Griffeth (barkergriffeth@gmail.com)
  Change Date     : 2023-03-28
  Purpose/Change  : Initial development

  The below function can be inserted into your PowerShell profile to enable you to use Get-ADUserLockouts
  in your terminal session when needed.
.EXAMPLE 
 Get-ADUSerLockouts -User jsmith
#>

function Get-ADUserLockouts {

  # Parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$User
  )
  
  # Import the Active Directory module
  Import-Module ActiveDirectory
  
  # Get the domain controller that holds the PDC role
  $PDC = (Get-ADDomainController -Discover -Service PrimaryDC).HostName
  
  # Query the Security logs for 4740 events (account lockout)
  $lockouts = Get-WinEvent -ComputerName "$PDC" -FilterHashtable @{
    LogName='Security'; Id=4740
  } |
  Where-Object {$_.Properties[0].Value -eq $user} |
    Select-Object TimeCreated, @{
      Name='Account Name';
      Expression={$_.Properties[0].Value}
    },
    @{
      Name='Workstation';
      Expression={$_.Properties[1].Value}
    }

  if ($null -eq $lockouts) {
  
    Write-Host "The user has no recent lockouts to display." -ForegroundColor Green
    
  } 
  else {
  
    Write-Host "The user has the following recent lockouts:" -ForegroundColor Red
    $lockouts
    
  }
  
}
