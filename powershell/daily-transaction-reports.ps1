<#
.SYNOPSIS
  This script generates prior day transaction reports.
.DESCRIPTION
  This script connects to an SFTP server for a third-party vendor, downloads account transaction files
  for each account, parses the transactions, and outputs PDF reports for each account to a network
  share for review by accounting personnel.

  This was borne out of necessity when a prior company switched vendors. Their previous vendor had a
  paid product that did nice reporting for the accounting team, but the new vendor did not. This script
  replicates what they had with the prior vendor by taking a single CSV file full of transactions,
  splitting them up by account, and then generating PDF reports for those accounts on a daily basis.
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

  This script requires:
    - WinSCP installed
    - PAGEANT installed and configured with the valid SSH key decrypted

  This script is intended to be run unattended, on a daily schedule.
.EXAMPLE
  .\daily-transaction-reports.ps1
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
Write-Host "Checking for C:\VendorSFTP..."
$WorkingDir = "C:\VendorSFTP"
if (Test-Path -Path $WorkingDir) {
  Write-Host "Found $WorkingDir - proceeding..."
}
else {
  Write-Host "Could not find $WorkingDir - creating it now..."
  New-Item -Path "C:\" -Name "VendorSFTP" -ItemType "directory" -Force
  Write-Host "Created $WorkingDir - proceeding..."
}
Set-Location -Path $WorkingDir

# Check for current year destination folder for each account
$map_year_paths = @(
  "\\contoso.com\VendorName\AccountName1\$sys_year",
  "\\contoso.com\VendorName\AccountName2\$sys_year",
  "\\contoso.com\VendorName\AccountName3\$sys_year",
  "\\contoso.com\VendorName\AccountName4\$sys_year",
  "\\contoso.com\VendorName\AccountName5\$sys_year",
  "\\contoso.com\VendorName\AccountName6\$sys_year",
  "\\contoso.com\VendorName\AccountName7\$sys_year",
)
Write-Host "Checking for account folders ..."
foreach ($map_year_path in $map_year_paths) { 
  Write-Host "Checking for $map_year_path ..."
  if (Test-Path -Path $map_year_path) {
    Write-Host "Found $map_year_path - proceeding ..."
  }
  else {
    Write-Host "Could not find $map_year_path - creating it now ..."
    $map_path_root = $map_year_path.split("\")[4]
    New-Item -Path "\\contoso.com\VendorName\$map_path_root" -Name "$sys_year" -ItemType "directory" -Force
    Write-Host "Created $map_year_path - proceeding..."
  }
}
Write-Host "Checking for Vendor folders ..."
foreach ($map_year_path in $map_year_paths) { 
  Write-Host "Checking for $map_year_path\Vendor ..."
  if (Test-Path -Path "$map_year_path\$sys_year\Vendor") {
    Write-Host "Found $map_year_path\Vendor - proceeding ..."
  }
  else {
    Write-Host "Could not find $map_year_path\Vendor - creating it now ..."
    $map_path_root = $map_year_path.split("\")[4]
    New-Item -Path "\\contoso.com\VendorName\$map_path_root\$sys_year" -Name "Vendor" -ItemType "directory" -Force
    Write-Host "Created $map_year_path\Vendor - proceeding..."
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
$sftp_host = "sftp.vendor.com"
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
Write-Host "[$(Get-Timestamp)] Obtaining daily file..."
try {

  $remote_file_path = (
    Get-WinSCPChildItem -WinSCPSession $sftp_session -Path "/Previous_Day_Files" | Sort-Object LastWriteTime -Descending | Where-Object {
      $_.Name -like "CSV*"
    } | Select-Object * -First 1).FullName
  $remote_file_name = (
    Get-WinSCPChildItem -WinSCPSession $sftp_session -Path "/Previous_Day_Files" | Sort-Object LastWriteTime -Descending | Where-Object {
      $_.Name -like "CSV*"
    } | Select-Object * -First 1).Name

  Receive-WinSCPItem -WinSCPSession $sftp_session -RemotePath $remote_file_path -LocalPath "$workingDir\$remote_file_name.csv"

  Write-Host "[$(Get-Timestamp)] Obtaining daily file... SUCCESS!"

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
      $map = "\\contoso.com\VendorName\AccountName\$sys_year\Vendor"
      $acct_friendly_name = "AccountName"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber2 {
      $map = "\\contoso.com\VendorName\AccountName\$sys_year\Vendor"
      $acct_friendly_name = "AccountName"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber3 {
      $map = "\\contoso.com\VendorName\AccountName\$sys_year\Vendor"
      $acct_friendly_name = "AccountName"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber4 {
      $map = "\\contoso.com\VendorName\AccountName\$sys_year\Vendor"
      $acct_friendly_name = "AccountName"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber5 {
      $map = "\\contoso.com\VendorName\AccountName\$sys_year\Vendor"
      $acct_friendly_name = "AccountName"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber6 {
      $map = "\\contoso.com\VendorName\AccountName\$sys_year\Vendor"
      $acct_friendly_name = "AccountName"
      $acct_num_last4 = $account.ToString().Substring(($account.ToString().Length - 4))
    }
    AccountNumber7 {
      $map = "\\contoso.com\VendorName\AccountName\$sys_year\Vendor"
      $acct_friendly_name = "AccountName"
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
  } -FilePath "$map\PriorDayTrans_$($account)_$(Get-Date -Format yyyyMMdd).pdf"

  Start-Sleep -Seconds 5

}

Remove-Item "C:\VendorSFTP\conv_temp*.csv" -Confirm:$false -Force
