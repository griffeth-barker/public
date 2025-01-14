<#
.SYNOPSIS
  This script removes the specified users from all groups.
.DESCRIPTION
  This script removes the specified users from all Active Directory groups of which they are a member.
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Griffeth Barker (github@griff.systems)
  Creation Date:  2025-01-14
  Purpose/Change: Initial script development
.PARAMETER User
  An array of distinguished names of Active Directory users who need to be removed from all groups.
  This parameter is mandatory, does not have a default value, and accepts pipeline input.
.EXAMPLE
  # Provide an inline array of distinguished names
  & .\Remove-UserGroupMemberships.ps1 -User @("CN=John Smith,OU=Disabled Users,DC=DomainName,DC=tld","CN=Jane Doe,OU=Disabled Users,DC=DomainName,DC=tld")
.EXAMPLE
  # Provide a variable containing an array of distinguished names
  $array = @("CN=John Smith,OU=Disabled Users,DC=DomainName,DC=tld","CN=Jane Doe,OU=Disabled Users,DC=DomainName,DC=tld")
  & .\Remove-UserGroupMemberships.ps1 -User $array
.EXAMPLE
  # Provide a text file containing a list of distinguished names
  & .\Remove-UserGroupMemberships.ps1 -User @(Get-Content -Path "C:\path\to\users.txt")
.EXAMPLE
  # Provide an array of distinguished names from the pipeline
  @(Get-Content -Path "C:\path\to\users.txt") | .\Remove-UserGroupMemberships.ps1
.EXAMPLE
  # Provide an array of distinguished names from the pipeline
  @(Get-ADUser -Filter { your_filter_here } | Select-Object -ExpandProperty DistinguishedName) | .\Remove-UserGroupMemberships.ps1
#>

#Requires -Modules ActiveDirectory

[CmdletBinding()]
param (
  [Parameter(mandatory = $true, ValueFromPipeline = $true)]
  [array]$User
)

begin {
  $logDir = ".\logs"
  $logFile = "$($MyInvocation.MyCommand.Name.Replace(".ps1","_"))" + "$(Get-Date -Format "yyyyMMddmmss").log"
  if (-not (Test-Path "$logDir")) {
    New-Item -Path "$logDir" -ItemType Directory -Confirm:$false | Out-Null
  }
  Start-Transcript -Path "$logDir\$logFile" -Force

  $reportingTable = New-Object System.Data.DataTable
  [void]$reportingTable.Columns.Add("DistinguishedName")
  [void]$reportingTable.Columns.Add("MemberOf")
}

process {
  foreach ($distinguishedName in $User) {
    Write-Output "Working on $distinguishedName"
    $userGroups = @(Get-ADUser -Identity $distinguishedName -Properties MemberOf | Select-Object -ExpandProperty MemberOf)
    foreach ($grp in $userGroups) {
      [void]$reportingTable.Rows.Add($distinguishedName, $($userGroups -join ",").ToString())
      Write-Output "Removing $distinguishedName from $grp"
      try {
        Remove-ADGroupMember -Identity "$grp" -Members "$distinguishedName" -Confirm:$false
        Write-Output "Removing $distinguishedName from $grp : Success"
      }
      catch {
        Write-Output "Removing $distinguishedName from $grp : Error"
        Write-Output $_.Exception.Message
      }
    }
  }

  $reportingTable | Sort-Object DistinguishedName | Export-Csv -Path ("$logdir\$($MyInvocation.MyCommand.Name.Replace(".ps1","_"))" + "$(Get-Date -Format "yyyyMMddmmss").csv") -NoTypeInformation
}

end {
  Stop-Transcript
}
