<#
.SYNOPSIS
  This script helps free up licenses that are still being held by users who have been disabled.
.DESCRIPTION
  This script gets a list of users receiving an M365 license via group membership of E3_Users or E5_Users security groups 
  and whose accounts are disabled, thus indicating a stale license to be freed up.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Modified Date:  2023-11-08
  Purpose/Change: Initial development

  This script requires the Active Directory PowerShell module.

  This script assumes that you have group license assignment configured in your tenant and you are using on-premises-synced
  Active Directory groups for your license assignments.
.EXAMPLE
  .\get_stale_m365_licensees.ps1
#>

# Check for ActiveDirectory PowerShell Module
Write-Host "Checking for ActiveDirectory PowerShell Module dependency..."
try {
  Import-Module -Name ActiveDirectory -Force
  Write-Host "Checking for ActiveDirectory PowerShell Module dependency...OK"
}
catch {
  try {
    Install-Module -Name ActiveDirectory -Force
    Import-Module -Name Active-Directory -Force
    Write-Host "Checking for ActiveDirectory PowerShell Module dependency...OK"
  }
  catch {
    Write-Output "Checking for ActiveDirectory PowerShell Module dependency...FAILED"
  }
}

# Read user input from console to determine which type of M365 license to review
switch (Read-Host "Which license would you like to review? (E3, E5)") {
  E3 {
    $entitlement_group = "M365_E3_Licensed_Users"
  }
  E5 {
    $entitlement_group = "M365_E5_Licensed_Users"
  }
}

# Get a list of users in the specified license group
Write-Host "Getting members of $entitlement_group..."
try {
  $licensed_users = @((Get-ADGroupMember -Id "$entitlement_group").SamAccountName)
  Write-Host "Getting members of $entitlement_group...OK"
}
catch {
  Write-Output "Getting members of $entitlement_group...FAILED"
  Exit 1
}

# Empty array to populate with stale licensees
$to_remove = New-Object System.Data.DataTable
[void]$to_remove.Columns.Add("SamAccountName")
[void]$to_remove.Columns.Add("Enabled")
[void]$to_remove.Columns.Add("CanonicalName")
[void]$to_remove.Columns.Add("Description")

# Interate through the group members and if the account is disabled and still a member
# of the security group providing the license, add the username to the $to_remove array
Write-Host "Finding accounts with stale licenses..."
foreach ($user in $licensed_users) {
  $account_status = Get-ADUser -Id $user -Properties SamAccountName,Enabled,CanonicalName,Description | Select-Object SamAccountName,Enabled,CanonicalName,Description
  if (($account_status.Enabled -ne $true) -and ($account_status.CanonicalName -like "bhwk.com/Disabled_Users/*")) {
		[void]$to_remove.Rows.Add($account_status.SamAccountName, $account_status.Enabled, $account_status.CanonicalName,$account_status.Description)
  }
}

# Print the $to_remove array to the terminal
if ($to_remove.count -eq 0) {
  Write-Output "There are no stale licenses. If we are low on licenses, a purchase may be necessary."
  Write-Host "The script will now exit (0)"
  Exit 0
}
else {
  Write-Host "The following users are disabled, but are still receiving an M365 license via membership of $entitlement_group." -ForegroundColor Yellow
  $to_remove | Format-Table -AutoSize

  switch (Read-Host "Would you like to remove the stale license from all the users listed above? (y/n)") {
    y {
      foreach ($to in $to_remove) {
        Write-Host "Removing $($to.SamAccountName) from $entitlement_group..."
        try {
          Remove-ADGroupMember -Identity $entitlement_group -Members $to.SamAccountName -Confirm:$false
          Write-Host "Removing $($to.SamAccountName) from $entitlement_group...OK"
        }
        catch {
          Write-Host "Removing $($to.SamAccountName) from $entitlement_group...FAILED"
        }
      }
    }
    n {
      Write-Output "No changes have been made."
    }
  }
}
