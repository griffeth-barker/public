<#
.SYNOPSIS
  This super simple script returns a list of snapshots for review.
.DESCRIPTION
  This super simple script returns a list of snapshots for review.
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
    Write-Host "Failed to import PowerCLI module" -ForegroundColor Red
  }
  
  # Connect to vCenter
  try {
    Connect-VIServer -Server $vcenterServer -Force -ErrorAction Stop | Out-Null
  }
  catch {
    Write-Host "Failed to connect to vSphere" -ForegroundColor Red
  }  

# Create result table
$ResultTable = New-Object System.Data.Datatable
[void]$ResultTable.Columns.Add("ID")
[void]$ResultTable.Columns.Add("VM")
[void]$ResultTable.Columns.Add("Created")
[void]$ResultTable.Columns.Add("Description")
[void]$ResultTable.Columns.Add("Size")

# Get list of snapshots
try {
    $Snapshots = Get-VM | Get-Snapshot | Select-Object ID,VM,Created,Description,@{Label="Size";Expression={"{0:N2} GB" -f ($_.SizeGB)}}

    foreach ($Snapshot in $Snapshots) {
        $SnapID = $Snapshot.ID
        $SnapVM = $Snapshot.VM.Name
        $SnapCreated = $Snapshot.Created
        $SnapDesc = $Snapshot.Description
        $SnapSize = $Snapshot.Size
        [void]$ResultTable.Rows.Add($SnapID,$SnapVM,$SnapCreated,$SnapDesc,$SnapSize)
    }
}
catch {
    Write-Host "Failed to get list of snapshots" -ForegroundColor Red
}

# Disconnect from vCenter
Disconnect-VIServer -Server $vcenterServer -Force -Confirm:$false | Out-Null

# Final output for PowerShell Universal
Clear-Host
$ResultTable
