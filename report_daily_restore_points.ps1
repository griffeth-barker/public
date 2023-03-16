<#
.SYNOPSIS
  This script retrieves restore point information from Veeam Backup and Replication site server.
.DESCRIPTION
  This script retrieves for each backed up node the node name, last time it was scheduled to back up,
  the date of it's most recent restore point, the size of that restore point, and how long it would take
  to restore that restore point. This information is then tabulated and sent in an email to the Service 
  Desk, with an inline HTML report as well as a .csv attachment. 
.PARAMETER
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Griffeth Barker (barkergriffeth@gmail.com)
  Creation Date:  02-25-2023
  Purpose/Change: Initial script development

  This script must be run from a node where the Veeam Backup and Replication console is installed, and
  with network access to the target Veeam Backup and Replication site server.

  The script will look for old attachments/logs from prior runs during each execution and automatically 
  clean up any old attachments whose creation date exceeds a month.
.EXAMPLE
  NA
#>

##########################################################################################################
# Script setup                                                                                           #
##########################################################################################################

# Timestamp function for logging
function Get-TimeStamp {
    
  return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
  
}

# Specify date format and site code
Write-Host "[$(Get-Timestamp)] Setting up..." -ForegroundColor Yellow
$date = Get-Date -Format 'yyyy-MM-dd'

# Check for existence of C:\ps and create it if missing (this is used for attachments)
Write-Host "[$(Get-Timestamp)] Checking for existence of 'C:\ps'..." -ForegroundColor White
if (Test-Path -Path C:\ps){
Write-Host "[$(Get-Timestamp)] Validated working directory." -ForegroundColor DarkGreen
}
else {
Write-Host "[$(Get-Timestamp)] Could not find C:\ps - creating it now..." -ForegroundColor DarkYellow
New-Item -Path "C:\" -Name "ps" -ItemType "directory" -Force
Write-Host "[$(Get-Timestamp)] Created C:\ps - proceeding." -ForegroundColor DarkGreen
}

# Start script transcript
Start-Transcript -Path "C:\ps\daily-restore-point-report_$Date.log" -Force

# Mail settings
$mailrecipients = (
  "yourrecipient@domain.local"
)
$mailsender = "yoursender@domain.local"
$mailsmtp = "yoursmtpserver.domain.local"

##########################################################################################################
# Do the needful                                                                                         #
##########################################################################################################
Write-Host "[$(Get-Timestamp)] Beginning fact-finding..." -ForegroundColor Yellow

# Create the report table object used to house the output data
Write-Host "[$(Get-Timestamp)] Creating system datatable object..." -ForegroundColor White
$ReportTable = New-Object System.Data.DataTable
#[void]$ReportTable.Columns.Add("Status")
[void]$ReportTable.Columns.Add("Node")
[void]$ReportTable.Columns.Add("Description")
[void]$ReportTable.Columns.Add("Last Run")
[void]$ReportTable.Columns.Add("Latest RP")
[void]$ReportTable.Columns.Add("RP Type")
[void]$ReportTable.Columns.Add("Size (GB)")
[void]$ReportTable.Columns.Add("Hours to Restore")

# Get list of backup jobs
Write-Host "[$(Get-Timestamp)] Getting list of backup jobs..." -ForegroundColor White
try {
  $JobList = Get-VBRJob -Name * | Where-Object {$_.info.IsScheduleEnabled} | Select-Object Name, Id, @{Name='LastRun'; Expression={$_.LatestRunLocal.ToString('yyyy-MM-dd')}}
  Write-Host "[$(Get-Timestamp)] Got list of backup jobs." -ForegroundColor Green
}
catch {
  Write-Host "[$(Get-Timestamp)] Failed to get list of backup jobs." -ForegroundColor Red
  Send-MailMessage -To $mailrecipients -From $mailsender -Subject "$Site Daily Restore Point Report for $Date failed to generate" -Body "The Daily Restore Point Report for $Date failed to generate. Please investigate and remediate." -SmtpServer $mailsmtp
  Exit
}

# Loop through all backup jobs and gather facts
Write-Host "[$(Get-Timestamp)] Looping through jobs..." -ForegroundColor White
foreach ($job in $joblist){
  $jobname = $job.name
  $jobtime = $job.LastRun
  
  Write-Host "[$(Get-Timestamp)] Working on $jobname..." -ForegroundColor White
  # This bit here can be removed if you do not describe your jobs as daily and weekly
  $jobdesc = (Get-VBRJob -Name $jobname | Select-Object Description).Description
  if ($jobdesc -like "Daily*") {
      $jobfreq = "Daily"
  }
  if ($jobdesc -like "Weekly*") {
      $jobfreq = "Weekly"
  }
  
  # Get list of nodes in backup jobs
  Write-Host "[$(Get-Timestamp)] $jobname - Getting nodes in backup job..." -ForegroundColor White
  try {
      $Objects = Get-VBRJobObject -Job $jobname | Sort-Object name
      Write-Host "[$(Get-Timestamp)] $jobname - Got nodes in backup job." -ForegroundColor Green
  }
  catch {
  Write-Host "[$(Get-Timestamp)] Failed to get list of nodes in backup jobs." -ForegroundColor Red
  Send-MailMessage -To $recipients -From $sender -Subject "Daily Restore Point Report for $Date failed to generate" -Body "The Daily Restore Point Report for $Date failed to generate. Please investigate and remediate." -SmtpServer $smtp
  Exit
}

  # Loop through all nodes and gather facts
  foreach ($object in $objects) {
      $jobname = $job.name
      $jobtime = $job.lastrun
      $objectname = $object.name

      # Get facts about latest restore point for the node
      Write-Host "[$(Get-Timestamp)] $objectname - Getting latest restorepoint..." -ForegroundColor White
      $backup = Get-VBRBackup -Name $jobname
      Write-Host "[$(Get-Timestamp)] $objectname - Calculating size of most recent restore point..." -ForegroundColor White
      $ApproxSize = ((Get-VBRRestorePoint -Backup $backup -Name $objectname | Sort-Object "Creation Time" | Select-Object ApproxSize -First 1).ApproxSize)/1073741824
      $ApproxSizeR = [math]::Round($ApproxSize,2)
      Write-Host "[$(Get-Timestamp)] $objectname - Calculating estimated time to restore from most recent restore point..." -ForegroundColor White
      # The below calculation was based on an environment I was working in
      $HTR = $ApproxSizeR/400
      $HTRR = [math]::Round($HTR,2)
      $LatestRP = (Get-VBRRestorePoint -Backup $jobname -Name $objectname | Sort-Object CreationTime -Descending | Select-Object CreationTime -First 1).CreationTime.ToString('yyyy-MM-dd')
      $RPType = (Get-VBRRestorePoint -Backup $jobname -Name $objectname | Sort-Object CreationTime -Descending | Select-Object Type -First 1).Type

      # Write facts to reporting table
      Write-Host "[$(Get-Timestamp)] $objectname - Writing facts to the datatable..." -ForegroundColor White
      [void]$ReportTable.Rows.Add($objectname,$jobfreq,$jobtime,$latestrp,$RPType,$approxsizer,$htrr)
  }
}

##########################################################################################################
# Generate inline and attached reports                                                                   #
##########################################################################################################
Write-Host "[$(Get-Timestamp)] Generating inline and attachment reports..." -ForegroundColor Yellow

# CSS styling for inline HTML report
Write-Host "[$(Get-Timestamp)] Setting CSS for inline HTML report..." -ForegroundColor White
$header = @"
<style>

  body {

      font-family: Calibri;
      font-size: 12pt;

  }

  table, tr, td {

      font-family: Calibri;
      font-size: 11pt;
      border: 1px solid #132a36;
      border-collapse: collapse;
      margin: 10px;
      padding: 1px;

  }

  th {

      font-family: Calibri;
      font-size: 13pt;
      font-weight: bold;
      color: #ffffff;
      border: 1px solid #123a36;
      background: #47627a;
      border-collapse: collapse; 
      margin: 10px;
      padding: 5px;

  }

  tbody tr:nth-child(even) {
      background: #f0f0f2;
  }
</style>

"@

# HTML Pre-content for inline HTML report (email message body before the table)
Write-Host "[$(Get-Timestamp)] Generating pre-table content for HTML email message..." -ForegroundColor White
$preContent = @"
Please find below the Daily Restore Point Report for $Date.
"@

# HTML Post-content for inline HTML report (email message body after the table)
Write-Host "[$(Get-Timestamp)] Generating post-table content for HTML email message..." -ForegroundColor White
$postContent = @"
Please review the report and remediate any issues.
"@

# Compile HTML object
Write-Host "[$(Get-Timestamp)] Compiling HTML object for mail message..." -ForegroundColor White
try {
  $html = $ReportTable | Sort-Object "Last Run" -Descending | ConvertTo-Html -Property Status,Node,Description,"Last Run","Latest RP","RP Type","Size (GB)","Hours to Restore" -Head $header -PreContent $preContent -PostContent $postContent
  Write-Host "[$(Get-Timestamp)] Compiled HTML object." -ForegroundColor Green
}
catch {
  Write-Host "[$(Get-Timestamp)] Failed to compile HTML object." -ForegroundColor Red
}

# Generate .csv attachment
Write-Host "[$(Get-Timestamp)] Generating attachment for HTML email message..." -ForegroundColor White
try {
  $ReportTable | Sort-Object "Last Run" -Descending | Export-Csv -NoTypeInformation -Path "C:\ps\$Site-daily-restore-point-report_$date.csv" -Force
  $attachment = "C:\ps\$Site-daily-restore-point-report_$date.csv"
  Write-Host "[$(Get-Timestamp)] Generated attachment." -ForegroundColor Green
}
catch {
  Write-Host "[$(Get-Timestamp)] Failed to generate attachment." -ForegroundColor Red
}


# Send email
Write-Host "[$(Get-Timestamp)] Sending HTML email message..." -ForegroundColor White
try {
  Send-MailMessage -SmtpServer $mailsmtp -To $mailrecipients -From $mailsender -Subject "Daily Restore Point Report for $date" -Body ($html | out-string) -BodyAsHtml -Attachments $attachment
  Write-Host "[$(Get-Timestamp)] Emailed report!" -ForegroundColor Green
}
catch {
  Write-Host "[$(Get-Timestamp)] Failed to email report." -ForegroundColor Red
}
##########################################################################################################
# Script cleanup                                                                                         #
##########################################################################################################

# Find any previously generated attachments/logs and delete them if their creation date exceeds one month
Write-Host "[$(Get-Timestamp)] Cleaning up..." -ForegroundColor Yellow
Get-ChildItem 'C:\ps' -Recurse -Force -ea 0 |
Where-Object { !$_.PsIsContainer -and $_.Extension -eq "csv" -or $_.Extension -eq "log" -and $_.LastWriteTime -lt (Get-Date).AddDays(-31) } |
ForEach-Object {
  $_ | Remove-Item -Verbose -Force
}

# End session transcript
Stop-Transcript
