<#
.SYNOPSIS
  This script checks for desired configuration state of virtual machines.
.DESCRIPTION
  This script will check for several desired configurations on each virtual machine:
    - CPU hot-add enabled
    - RAM hot-add enabled
    - VMware tools version
    - VMXNET3 NIC type
    - VMware Paravirtualized SCSI adapter
  and report VMs that have configurations which do not match the desired configuration state.

  Your desired state may be different, in which case the script will require thorough modification.
.PARAMETER
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Updated by:     Griffeth Barker (barkergriffeth@gmail.com)
  Change Date:    10-01-2022
  Purpose/Change: Initial development

  This script must be run from a node where VMware PowerCLI is installed.
.EXAMPLE
  None
#>

# Script setup
$Date = Get-Date -Format yyyy-MM-dd

$Recipients = (
  "yourrecipient@domain.local"
)
$Sender = "yoursender@domain.local"
$SmtpServer = "yoursmtpserver.domain.local"

$vCenterServer = "yourvcenterserver.domain.local"

$VmDscTable = New-Object System.Data.Datatable
[void]$VmDscTable.Columns.Add("VM Name")
[void]$VmDscTable.Columns.Add("VMware Tools Status")
[void]$VmDscTable.Columns.Add("CPU Hotplug")
[void]$VmDscTable.Columns.Add("RAM Hotplug")
[void]$VmDscTable.Columns.Add("NIC Type")
[void]$VmDscTable.Columns.Add("SCSI Type")

# Connect to vCenter
Write-Host "Connecting to vCenter..." -ForegroundColor DarkYellow
Connect-VIServer -Server $vCenterServer -Force

# Get list of VMs for site
$VMs = Get-VM -Name * | Select-Object Name

# Get current VM configuration for each VM
foreach ($VM in $VMs){
  try {
    $VMname = $VM.name
    Write-Host "Getting current configuration for VM '$VMname'..." -ForegroundColor DarkYellow
    Write-Host "Getting VMware Tools Status..." -ForegroundColor Gray
    $Tools = (Get-VM -Name "$VMname").ExtensionData.Guest.ToolsVersionStatus
    Write-Host "Getting Hotplug configuration..." -ForegroundColor Gray
    $CpuPlug = (Get-VM -Name "$VMname").CpuHotAddEnabled
    $RamPlug = (Get-VM -Name "$VMname").MemoryHotAddEnabled
    Write-Host "Getting NIC type..." -ForegroundColor Gray
    $Nic = Get-VM -Name "$VMname" | Get-NetworkAdapter | Select-Object Type
    Write-Host "Getting SCSI controller type..." -ForegroundColor Gray
    $Scsi = Get-VM -Name "$VMname" | Get-ScsiController | Select-Object Type
    [void]$VmDscTable.Rows.Add($VMname,$Tools,$CpuPlug,$RamPlug,$Nic.Type,$Scsi.Type)
    Write-Host "Got current configuration!" -ForegroundColor DarkGreen
  }
  catch {
    Write-Host "Failed to get current VM configuration for $VMname!" -ForegroundColor DarkRed
  }
}

# Generate report
Write-Host "Generating report..." -ForegroundColor DarkYellow
$AttachmentPath = "C:\temp\vm-desired-configuration-report_$Date.csv"
$VmDscTable | Export-Csv -LiteralPath "$AttachmentPath" -NoTypeInformation -Force

$Body = "
Attached is the Virtual Machine Desired Configuration Check, run on $Date.

VMware Tools
If needed, update VMware tools on any out-of-date VMs at the next maintenance window. Reference this article if needed:
https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.vsphere.update_manager.doc/GUID-0B9FF31B-3702-4BD2-B925-9DAC98051338.html
This requires a reboot!

CPU and RAM Hotplug
If needed, enable CPU and Memory hotplug on any VMs where it is not enabled at the next maintenance window. Reference this article if needed:
https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-285BB774-CE69-4477-9011-598FEF1E9ACB.html
The process for enabled CPU hotplug vs. RAM hotplug are essentially the same. This requires the VM to be powered off!

SCSI Controller
If needed, change the SCSI controller type to Paravirtual if it is configured otherwise. Reference this article if needed:
https://kb.vmware.com/s/article/1010398
This can be done non-disruptively. Do note that workstation OSes may be running in AHCI mode instead.

NIC Type
If needed, change the type of NIC to VMXNET3 if it is configured otherwise. Reference this article if needed:
https://www.vladan.fr/how-to-change-e1000-into-vmxnet3-without-changing-a-mac-address
This can be done with the VM on, but may disrupt network connectivity. Remember to remove the 'ghost' NIC afterwards.

Non-disruptive changes should be completed as soon as possible, and changes requiring reboots or other disruptions should have 
tasks scheduled in the Maintenance Windows planner for the next upcoming maintenance window.
"

# Send report
Write-Host "Sending email report..." -ForegroundColor DarkYellow
try {
  Send-MailMessage -To $Recipients -From $sender -subject "Report - Virtual Machines Desired Configuration" -Body $Body -SmtpServer $SmtpServer -Attachments $AttachmentPath
  Write-Host "Emailed report successfully!" -ForegroundColor DarkGreen
  Write-Host "Cleaning up temporary files..." -ForegroundColor DarkYellow
  Remove-Item -Path "$AttachmentPath" -Force
}
catch {
  Write-Host "Failed to email report. You can find the report file at $AttachmentPath" -ForegroundColor DarkRed
}
