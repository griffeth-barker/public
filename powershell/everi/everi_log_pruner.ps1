<#
.SYNOPSIS
  This script cleans up bloated logs related to Everi services.
.DESCRIPTION
  This script gets a list of log directories related to Everi services, iterates through them and deletes log files older than 32 days.
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2024-05-22
  Purpose/Change: Initial script development
  
  This script is intended to be run via the Windows Task Scheduler on a monthly basis.
  
  This script writes output to the Windows Event Log.
  Event IDs:
     - 1000: Debloat run start
     - 2001: Attempting to enumerate log directories
     - 2002: Successful enumeration of log directories
     - 2003: Failed enumeration of log directories
     - 2004: Successful removal of log file
     - 2005: Failed removal of log file
     - 3000: Debloat run end
.EXAMPLE
  NA
#>

# Define Everi installation location
$installLocation = "C:\Everi_Services"

# Logging parameters
$evtx_logname = "Log Pruner for Everi Services"
$evtx_computername = $env:computername
$evtx_sources = @(
    "Windows Task Scheduler",
    "Pipeline",
    "Script Output"
)

# Check for event log and create it if missing
try {
    Get-EventLog -LogName $evtx_logname | Select-Object -First 0
}
catch {
    New-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source $evtx_sources
}

# Write event log for beginning of script's funcionality
Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Windows Task Scheduler" -EntryType Information -Message "Beginning a debloat run of Everi logs." -EventId 1000

# Enumerate relevant log directories
try {
    Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Script Output" -EntryType Information -Message "Attempting to enumerate relevant log directories." -EventId 2001
    $logPaths = @(
        Get-ChildItem -Path $installLocation -Depth 2 | Where-Object { $_.FullName -like "*\log" -or $_.FullName -like "*\logs" -and $_.PsIsContainer } | Select-Object FullName
    )
    Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Script Output" -EntryType Information -Message "Successfully enumerated relevant log directories:

    $($logPaths.FullName | Format-List | Out-String)
    " -EventId 2002
}
catch {
    Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Script Output" -EntryType Error "Failed to enumerate relevant log directories. Script exited with exit code 1." -EventId 2003
    Exit 1
}

# Iterate through log files and delete any with LastWriteTime property exceeding 32 days from today
foreach ($logPath in $logPaths) {
    try {
        # For some reason, Everi has non-log files in some of their logging directories. DO NOT REMOVE THE -LIKE "*.LOG" CONDITION BELOW.
        Get-ChildItem -Path $logPath.FullName -Recurse -Force -ea 0 | Where-Object { !$_.PsIsContainer -and $_.FullName -like "*.log" -and $_.LastWriteTime -lt (Get-Date).AddDays(-32) } | ForEach-Object {
            $_ | Remove-Item -Verbose -Force -Confirm:$false 
            Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Script Output" -EntryType Information -Message "Successfully deleted $($_.FullName)." -EventId 2004
        }
    }
    catch {
        Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Script Output" -EntryType Warning -Message "Failed to delete $($_.FullName)." -EventId 2005
    }
}

# Write event log for end of script's functionality
Write-EventLog -LogName $evtx_logname -ComputerName $evtx_computername -Source "Windows Task Scheduler" -EntryType Information -Message "Finished a debloat run of Everi logs." -EventId 3000
