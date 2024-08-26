<#
.SYNOPSIS
  This script is used to review backup status of virtual machines.
.DESCRIPTION
  This script gets a filtered list of virtual machines in VMware vSphere including
  their names and the values of the custom attribute used to track Veeam last backup.
  This information is returned in a comma-separated values file.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2023-10-02
  Purpose/Change: Initial development

  This script assumes that you are using VMware vSphere and Veeam Backup & Replication.
  This script assumes that Veeam Backup & Replication is configured to write the last successful
  backup information to a custom VM attribute in vSphere called 'veeam.lastbackup'.
.EXAMPLE
  .\vmware_veeam_protection_audit.ps1
#>

# Your vCenter Server
$vcenterServer = "changeme"

# Connect to vSphere
# This relies on passthrough authentication from your Windows session.
Connect-VIServer -Server $vcenterServer -Force

# Get filtered list of virtual machines
# I've included some helpful default filtering here to prevent checks against virtual machines that probably 
#aren't backed up (temporary VMs, test VMs, templates, and the backup VMs themselves).
$VMs = Get-VM | Where-Object { 
  $_.Name -notlike "Temp*" -and `
  $_.Name -notlike "*tmp*" -and `
  $_.Name -notlike "*vproxy*" -and `
  $_.Name -notlike "*test*" -and `
  $_.Name -notlike "*LAB*" -and `
  $_.Name -notlike "*template*"

} | Select-Object Name, @{
      Name       = 'Last Backup'; 
      Expression = {
        $_.CustomFields | Where-Object { 
          $_.Key -eq 'veeam.lastbackup'
      } | Select-Object -Expand Value
  }
} | Sort-Object Name

# Create empty data table for final reporting
$reporting_table = New-Object -TypeName System.Data.DataTable
[void]$reporting_table.Columns.Add("VM Name")
[void]$reporting_table.Columns.Add("Last Backup")
[void]$reporting_table.Columns.Add("Server")
[void]$reporting_table.Columns.Add("Job")
[void]$reporting_table.Columns.Add("Repository")
[void]$reporting_table.Columns.Add("Comments")

# Iterate through list of virtual machine and write data to reporting table
foreach ($VM in $VMs) {
  $backup_info = [regex]::Matches($VM.'Last Backup', '\[([^\]]*)\]')
  if ($backup_info) {
    [void]$reporting_table.Rows.Add(
      $VM.Name,
      $backup_info[0].Value,
      $backup_info[1].Value,
      $backup_info[2].Value,
      $backup_info[3].Value
    )
  }
  if (!$backup_info) {
    [void]$reporting_table.Rows.Add(
      $VM.Name,
      "CHECK ME!"
    ) 
  }
}

$reporting_table | Sort-Object 'Last Backup' -Descending | Export-Csv -Path "C:\temp\vmware_veeam_protection_audit.csv" -NoTypeInformation -Force
