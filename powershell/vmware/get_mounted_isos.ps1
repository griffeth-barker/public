<#
.SYNOPSIS
  This super simple script gets a list of virtual machines that have ISOs mounted.
.DESCRIPTION
  This super simple script gets a list of virtual machines that have ISOs mounted.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author         :   Barker, Griffeth (barkergriffeth@gmail.com)
  Change Date    :   2023-06-09
  Purpose/Change :   Sanitize for sharing
.EXAMPLE
  .\get_mounted_isos.ps1
#>

# Your vCenter server
$vcenterServer = "changeme"

# Connect to vSphere
# This relies on passthrough authentication from your Windows session.
Connect-VIServer -Server $vcenterServer -Force

# Create result table
$ResultTable = New-Object System.Data.Datatable
[void]$ResultTable.Columns.Add("VM")
[void]$ResultTable.Columns.Add("Mounted ISO")

# Get list of VMs with ISOs mounted
$VMs = Get-VM
foreach ($VM in $VMs) {
    $Drive = $null
    $Drive = get-vm $vm.name | Get-CDDrive | Where-Object {$_.ISOPath -ne $null} 
    if ($Drive -ne $null) {
        $path = $Drive.IsoPath
        $Name = $VM.name
        [void]$ResultTable.Rows.Add($Name,$Path)
    }
}

# Output
$ResultTable
