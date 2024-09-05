<#
.SYNOPSIS
  This script receives daily files from a third party vendor's SFTP server.
.DESCRIPTION
  This script conencts to the third party's SFTP server, locates the daily transaction files
  containing the previous day's transactions (based on a LastWriteTime of the current date), and
  copies those files to the designated directory.

  This script requires the appropriate SSH key for the SFTP site to be added and decrypted in PAGEANT,
  and that PAGEANT is running on the server running the script. This could be modified to use the
  inbuilt OpenSSH client in Windows, provided the environment and vendor supports that.

  This script is intended to be run unattended, on a daily schedule.
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2023-04-18
  Purpose/Change: Initial script development

  This script makes use of the iText Community for .NET, which is free and open-source, published on
  GitHub using the AGPL license.  The usage of this script should not require the purchase of a 
  commercial license. See GitHub for additional information.  https://github.com/itext/itext7-dotnet

  This script is provided here not so much for the purpose of someone re-using it elsewhere, but more so
  to show a problem and how it was solved.
.EXAMPLE
  None
#>

##########################################################################################################
# Script setup                                                                                           #
##########################################################################################################

# Function to generate timestamps for logging.
function Get-TimeStamp {
  return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date) 
}

# Get current year
$sys_year = Get-Date -Format yyyy

# Check for temporary working directory and create it if missing.
Write-Host "Checking for C:\VendorNameSFTP..."
$WorkingDir = "C:\VendorNameSFTP"
if (Test-Path -Path $WorkingDir) {
  Write-Host "Found $WorkingDir - proceeding..."
}
else {
  Write-Host "Could not find $WorkingDir - creating it now..."
  New-Item -Path "C:\" -Name "VendorNameSFTP" -ItemType "directory" -Force
  Write-Host "Created $WorkingDir - proceeding..."
}
Set-Location -Path $WorkingDir

# Check for current year destination folder for each account
$map_year_paths = @(
  "\\contoso.com\VendorName\Account1Name\$sys_year",
  "\\contoso.com\VendorName\Account2Name\$sys_year",
  "\\contoso.com\VendorName\Account3Name\$sys_year",
  "\\contoso.com\VendorName\Account4Name\$sys_year",
  "\\contoso.com\VendorName\Account5Name\$sys_year",
  "\\contoso.com\VendorName\Account6Name\$sys_year",
  "\\contoso.com\VendorName\Account7Name\$sys_year"
)
Write-Host "Checking for account folders ..."
foreach ($map_year_path in $map_year_paths) { 
  $DFSNameSpace = $map_year_path.split("\")[3]
  Write-Host "Checking for $map_year_path ..."
  if (Test-Path -Path $map_year_path) {
    Write-Host "Found $map_year_path - proceeding ..."
  }
  else {
    Write-Host "Could not find $map_year_path - creating it now ..."
    $map_path_root = $map_year_path.split("\")[4]
    New-Item -Path "\\contoso.com\$DFSNameSpace\$map_path_root" -Name "$sys_year" -ItemType "directory" -Force
    Write-Host "Created $map_year_path - proceeding..."
  }
}

# Begin logging.
$FileDate = Get-Date -Format 'yyyyMMdd-HHmm'
Start-Transcript -Path "$WorkingDir\sftp_daily_copy_$FileDate.log" -Force

# Check for PSWritePDF module.
Write-Host "Importing PSWritePDF module..."
try {
  Import-Module -Name PSWritePDF -Force -ErrorAction Stop
  Write-Host "PowerShell-PDF module imported!"
}
catch {
  Write-Host "PowerShell-PDF module not found. Attempting to install..."
  try {
    Install-Module -Name PSWritePDF -Force
    Write-Host "PowerShell-PDF module installed! Importing..."
  }
  catch {
    Write-Host "Failed to find or obtain and install PSWritePDF module!"
    Write-Host "PDFs will not be generated, but CSV files will still be retrieved."
  }
}

# Check for WinSCP module and install it if missing, then import.
try {
  Write-Host "Importing WinSCP module..."
  Import-Module -Name "WinSCP" -ErrorAction Stop
  Write-Host "Found WinSCP module!"
}
catch {
  try {
    Write-Host "Failed to find WinSCP module. Attempting to install it now..."
    Install-Module -Name "WinSCP" -Force -ErrorAction Stop
    Import-Module -Name "WinSCP" -Force -ErrorAction Stop
  }
  catch {
    Write-Host "Failed to find, install, or import WinSCP module."
    Write-Host "The script will continue, however PDFs will not be generated."
    Write-Host "The daily CSV file will still be obtained."
  }
}



##########################################################################################################
# Doing the needful                                                                                      #
##########################################################################################################

# Define variables for SFTP connection.
# Note that because the defined user does not have a password, but rather an SSH key, a new PSCredential
# is created using the username and a null value, rather than an empty string. This can be reconfigured 
# as needed based on the available credentials.
$sftp_user = "changeme"
$sftp_host = "changeme"
$sftp_creds = New-Object System.Management.Automation.PSCredential("$sftp_user", (New-Object System.Security.SecureString))
$sftp_host_fprint = "changeme"

# Establish SFTP connection.
Write-Host "[$(Get-Timestamp)] SFTP session connecting..."
try {
  $sftp_session = New-WinSCPSession -SessionOption (
    New-WinSCPSessionOption -HostName $sftp_host -Protocol Sftp -Credential $sftp_creds -SshHostKeyFingerprint $sftp_host_fprint
  )
  Write-Host "[$(Get-Timestamp)] SFTP session established!"
}
catch {
  $sftpSessionErrorMessage = $_.exception.Message
  Write-Host "[$(Get-Timestamp)] There was a problem connecting to the SFTP server."
  Write-Host "[$(Get-Timestamp)] $SftpSessionErrorMessage"
}

# Download the file with transactions from the previous day
Write-Host "[$(Get-Timestamp)] Obtaining daily files..."
try {

  # Download daily CSV file
  $remote_file_path = (
    Get-WinSCPChildItem -WinSCPSession $sftp_session -Path "/Previous_Day_Files" | Sort-Object LastWriteTime -Descending | Where-Object {
      $_.Name -like "CSV*"
    } | Select-Object * -First 1).FullName
  $remote_file_name = (
    Get-WinSCPChildItem -WinSCPSession $sftp_session -Path "/Previous_Day_Files" | Sort-Object LastWriteTime -Descending | Where-Object {
      $_.Name -like "CSV*"
    } | Select-Object * -First 1).Name

  Receive-WinSCPItem -WinSCPSession $sftp_session -RemotePath $remote_file_path -LocalPath "$workingDir\$remote_file_name.csv"
  Copy-Item -Path "$workingDir\$remote_file_name.csv" -Destination "\\contoso.com\VendorName\CSV-BAI\$sys_year\$remote_file_name.csv"


  # Download daily BAI file
  $remote_bai_path = (
    Get-WinSCPChildItem -WinSCPSession $sftp_session -Path "/Previous_Day_Files" | Sort-Object LastWriteTime -Descending | Where-Object {
      $_.Name -like "2913980*"
    } | Select-Object * -First 1).FullName
  $remote_bai_name = (
    Get-WinSCPChildItem -WinSCPSession $sftp_session -Path "/Previous_Day_Files" | Sort-Object LastWriteTime -Descending | Where-Object {
      $_.Name -like "2913980*"
    } | Select-Object * -First 1).Name

  Receive-WinSCPItem -WinSCPSession $sftp_session -RemotePath $remote_bai_path -LocalPath "\\contoso.com\VendorName\CSV-BAI\$sys_year\$remote_bai_name"

  Write-Host "[$(Get-Timestamp)] Obtaining daily files... SUCCESS!"

  Close-WinSCPSession -WinSCPSession $sftp_session -Confirm:$false

}
catch {

  $SftpSessionErrorMessage = $_.exception.Message
  Write-Host "[$(Get-Timestamp)] Obtaining daily file... FAILED."
  Write-Host "[$(Get-Timestamp)] $SftpSessionErrorMessage"

}

# Datatable of unified transactions
$transactions = Import-Csv -Path "$workingDir/$remote_file_name.csv"

# Array of account numbers from the CSV file
[array]$accounts = $transactions.'Account Number' | Select-Object -Unique

# Iterate through the accounts
foreach ($account in $accounts) {
    
  # Per-account settings
  switch ($account) {
    AccountNumber1 {
      $map = "\\contoso.com\VendorName\Account1Name\$sys_year"
      $acct_friendly_name = "AccountNumber1Name"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber2 {
      $map = "\\contoso.com\VendorName\Account2Name\$sys_year"
      $acct_friendly_name = "AccountNumber2Name"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber3 {
      $map = "\\contoso.com\VendorName\Account3Name\$sys_year"
      $acct_friendly_name = "AccountNumber3Name"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber4 {
      $map = "\\contoso.com\VendorName\Account4Name\$sys_year"
      $acct_friendly_name = "AccountNumber4Name"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber5 {
      $map = "\\contoso.com\VendorName\Account5Name\$sys_year"
      $acct_friendly_name = "AccountNumber5Name"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber6 {
      $map = "\\contoso.com\VendorName\Account6Name\$sys_year"
      $acct_friendly_name = "AccountNumber6Name"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber7 {
      $map = "\\contoso.com\VendorName\Account7Name\$sys_year"
      $acct_friendly_name = "AccountNumber7Name"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
  }

  # Datatable for staging only transactions from the current account in the loop
  $datatable = New-Object System.Data.Datatable
  [void]$datatable.Columns.Add("Date")
  [void]$datatable.Columns.Add("Tran Code")
  [void]$datatable.Columns.Add("Tran Desc")
  [void]$datatable.Columns.Add("Bank Ref")
  [void]$datatable.Columns.Add("Debit Amt")
  [void]$datatable.Columns.Add("Credit Amt")
  [void]$datatable.Columns.Add("Ledger Bal")

  # Iterate through the transactions in the unified datatable and add only relevant transactions to the staging datatable
  foreach ($transaction in $transactions) {

    if ($transaction.'Account Number' -eq $account) {

      # Debit/Credit handling
      switch ($transaction."DB\CR") {
        "D" {
          if ($null -eq $transaction."Amount") {
            $debit_amt = "-"
          }
          else {
            $debit_amt = $transaction."Amount"
          }
        }
        "C" {
          if ($null -eq $transaction."Amount") {
            $credit_amt = "-"
          }
          else {
            $credit_amt = $transaction."Amount"
          }
        }
      }

      # Null value handling
      if ($null -eq $transaction."Tran Code") {
        $transaction."Tran Code" = "-"
      }
      else { 
        $transaction."Tran Code" = $transaction."Tran Code"
      }

      if ($null -eq $transaction."Bank Reference") {
        $transaction."Bank Reference" = "-"
      }
      else {
        $transaction."Bank Reference" = $transaction."Bank Reference"
      }

      if ($null -eq $transaction."Tran Desc") {
        $transaction."Tran Desc" = "-"
      }
      else {
        $transaction."Tran Desc" = $transaction."Tran Desc"
      }

      [void]$datatable.Rows.Add($transaction.'Report Date', $transaction.'Tran Code', $transaction.'Tran Desc', $transaction.'Bank Reference', $debit_amt, $credit_amt,$transaction.'Ledger Balance')
      $debit_amt = $null
      $credit_amt = $null

    } 

  }

  $datatable | Export-Csv -NoTypeInformation -Path "$workingdir\conv_temp.csv"
  $datatable_sanitized = Import-Csv -Path "$workingdir\conv_temp.csv"

  Write-Host "Creating PDF for $account at $map\" -BackgroundColor Yellow

  New-PDF -MarginLeft 10 -MarginRight 10 -MarginTop 10 -MarginBottom 10 -PageSize TABLOID -Rotate {
    New-PDFText -Text "$acct_friendly_name - Account Ending *$acct_num_last4" -Font HELVETICA_BOLD -FontColor BLACK -FontBold $true
    New-PDFText -Text "Transactions (Prior Day)" -Font HELVETICA -FontColor BLACK -FontBold $true
    New-PDFTable -DataTable $datatable_sanitized
    New-PDFText -Text "This PDF was generated automatically." -Font HELVETICA_OBLIQUE -FontColor BLACK
  } -FilePath "$map\WAB_PriorDayTrans_$($account)_$(Get-Date -Format yyyyMMdd).pdf"

  Start-Sleep -Seconds 5

}

Remove-Item "C:\VendorNameSFTP\conv_temp*.csv" -Confirm:$false -Force
