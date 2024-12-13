<#
.SYNOPSIS
  This script sends reminder notifications to users whose password is about to expire.
.DESCRIPTION
  This script gets a list of user objects from Active Directory whose DistinguishedName property contains "Users" (to
  avoid service accounts and resource accounts; you can roll your own filter for this though), and selects only the accounts 
  whose msDS-UserPasswordExpiryTime property falls within the specified TimeSpan. It then sends a notification to each user's 
  primary email address with instructions to change their password.
.PARAMETER TimeSpan
  An integer indicating the time span for user password expirations to notify.
  This parameter is required and does not accept pipeline input.
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Updated by      : Griffeth Barker (github@griff.systems)
  Change Date     : 2024-12-10
  Purpose/Change  : Initial development

  This script is intended to be run via the Windows Task Scheduled on a server.
  This script requires the ActiveDirectory PowerShell module and permissions to query Active Directory.
.EXAMPLE
  # Send email notifications to users with passwords expiring within the next 30 days.
 .\Invoke-ADPasswordExpiryReminder.ps1 -TimeSpan 30
.EXAMPLE
  # Send email notifications to users with passwords expiring within the next 7 days.
 .\Invoke-ADPasswordExpiryReminder.ps1 -TimeSpan 7
#>

[CmdletBinding()]
Param (
  [Parameter()]
  [ValidateRange(0,30)]
  [int]$TimeSpan
  )

Begin {
  ## MAINTENANCE BLOCK ####################################
  # Update these variables to fit your organization's needs
  $orgSearchBase = "OU=Users,DC=example,DC=local"
  $orgName = "Example Corp"
  $orgSmtpServer = "smtp.example.local"
  $orgHelpdeskEmail = "helpdesk@example.local"
  $orgHelpdeskPhone = "+1 (555) 555-5555"
  ## END MAINTENANCE BLOCK ###############################

  $logDir = "C:\Admin\Logs"
  $logFile = "Invoke-ADPasswordExpiryReminder_$(Get-Date -Format "yyyymmddMMss").log"
  if (-not (Test-Path "$logDir")) {
    New-Item -Path "$logDir" -ItemType Directory -Confirm:$false | Out-Null
  }

  Start-Transcript -Path "$logDir\$logFile" -Force

  if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    throw "The ActiveDirectory Powershell module is not available. Please install it before running this script."
  }
  try {
    Import-Module ActiveDirectory
    Write-Output "Successfully imported ActiveDirectory PowerShell module."
  }
  catch {
    Write-Error $_.Exception
  }
  function Get-ADPasswordExpiryUser {
    Get-ADUser -SearchBase "$orgSearchBase" -Filter {Enabled -eq $True -and PasswordNeverExpires -eq $False} -Properties DisplayName, msDS-UserPasswordExpiryTimeComputed, mail | `
    Where-Object {
      $_.DistinguishedName -like "*Users*" -and `
      [datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed") -lt (Get-Date).AddDays($TimeSpan) -and `
      [datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed") -ge (Get-Date) -and `
      $null -ne $_.mail
    }
  }
}

Process {
  try {
    $userList = Get-ADPasswordExpiryUser -TimeSpan $TimeSpan
    Write-Output "Found $($userList.Count) users with passwords expiring within the next $TimeSpan days."
  {
  catch {
    Write-Error $_.Exception
  }
  foreach ($u in $userList) {
    $expiration = [datetime]::FromFileTime($u."msDS-UserPasswordExpiryTimeComputed")
    $expdays = (New-Timespan -Start (Get-Date) -End $expiration).Days
    $ddisplay = if ($expdays -eq 1) {
      "day"
    } else {
      "days"
    }
    $msg = @"
<body>
  <p>Dear $($u.DisplayName),</p>
  <p>In $($expdays) $($ddisplay), the password for $($u.SamAccountName) expires. Once expired, you will not be able to log on to the network, nor will you be able to send or receive email.</p>
  <p><b>Passwords:</b></p>
  <ul>
      <li>Must be at least 16 characters in length.</li>
      <li>Must contain three of the following: upper case letters, lower case letters, numbers, and symbols.</li>
      <li>Expire in one year.</li>
  </ul>
  <p><b>Please ensure your new password is something new and significantly different than previous passwords.</b></p>
  <p>Once you have changed your network password, you need to update it on all devices on which it is stored, such as tablets and smartphones (e.g. iPad, iPhone, Android phone). Failure to do so will cause the system to lock your account.</p>
  <p>If your password is already expired, or you have questions or need further assistance, please contact us using the information below.
  <br />
  <p>Thank you,</p>
  <p><b>IT HelpDesk Team</b></p>
  <p>$($orgName)</p>
  <a href="mailto:$($orgHelpdeskEmail)">$($orgHelpdeskEmail)</a>
  <p>$($orgHelpdeskPhone)</p>
</body>
"@
    $msgParams = @{
      To = "$($u.mail)"
      From = "$orgHelpdeskEmail"
      Subject = "Reminder: Your network password will expire soon"
      Body = $msg
      BodyAsHtml = $true
      SmtpServer = "$orgSmtpServer"
    }
    try {
      Send-MailMessage @msgParams
      Write-Output "Sent notification to $($u.mail) about password expiry in $($expdays) $($ddisplay)."
    }
    catch {
      Write-Error $_.Exception
    }
  }
}

End {
  Get-ChildItem -Path "$logDir" -Filter "Invoke-ADPasswordExpiryReminder_*.log" -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Confirm:$false -Verbose
  Stop-Transcript
}
