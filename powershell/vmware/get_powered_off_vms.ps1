<#
.SYNOPSIS
  This super simple script returns a list of powered off VMs for review.
.DESCRIPTION
  This super simple script returns a list of powered off VMs for review and exports the list to a file.
.PARAMETER <Parameter_Name>
  N/A
.INPUTS
  N/A
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2022-07-01
  Purpose/Change: Initial script development
.EXAMPLE
  NA
#>

# Your vCenter server
$vcenterServer = "changeme"

# Import PowerCLI module
try {
  Import-Module -Name "VMware.VimAutomation.Core" -ErrorAction Stop | Out-Null
}
catch {
  Exit
}

# Connect to vCenter
# This relies on passthrough authentication from your Windows session.
try {
  Connect-VIServer -Server $vcenterServer -Force -ErrorAction Stop | Out-Null
}
catch {
  Exit
}

# Create result table
$ResultTable = New-Object System.Data.Datatable
[void]$ResultTable.Columns.Add("VM")

$VMs = (Get-VM | Where-Object {$_.PowerState -eq "PoweredOff" -and $_.Name -notlike "*Template*" -and $_.Name -notlike "*Delete*" -and $_.Name -notlike "*Lab*"} | Select-Object Name) | Sort-Object Name

foreach ($VM in $VMs){
    $VMname = $VM.Name
    [void]$ResultTable.Rows.Add("$VMname")
}

Clear-Host
$ResultTable | Format-Table
