<#
.SYNOPSIS
  This script generates a list of Active Directory users' home directory sizes.
.DESCRIPTION
  This script queries Active Directory for a list of users whose HomeDirectory attribute has a UNC path listed. It
  then obtains the size of each of those users' home directories and outputs the information into an array, which is
  then exported to a CSV file.
  
  This script can be helpful when determining what home drives are being used, how much is being stored, etc. This was
  used for planning before a migration to OneDrive in my case.

  This script was written to be console friendly for monitoring and creates the following files:
     - [Resource] homedrives.csv
         - This file is created by the script to determine which homedrives are relevant.
     - [Log] Get-HomeDrives-Transcript-$FileDate.log
         - This file is created by the script to provide a log of actions performed by the script.
     - [Result] Get-HomeDrives-Errors-$FileDate.txt
         - This file is created by the script to indicate any directories the script was unable to size.
     - [Result] Get-HomeDrives-Report-$FileDate.csv
         - This file is is intended result of the script, containing a list of user home directories and their sizes.
.PARAMETER <Parameter_Name>
  N/A
.INPUTS
  None
.OUTPUTS
  N/A
.NOTES
  Author:         Griffeth Barker (barkergriffeth@gmail.com)
  Creation Date:  8-6-2022
  Purpose/Change: Initial script development
  
  This script requires the PSFolderSize and ActiveDirectory modules; the script will check for these modules and attempt
  to install them if they are missing.

  Note that home directory sizes showing '0' technically have items in them, but they sum up to less than 1 MB, which is
  the smallest order of size this script addresses. A directory is truly empty if the size is ' ' (null). 

  The script can be adusted to address smaller or larger orders by subsituting SizeMB with SizeKB or SizeGB in the loop
  if desired. For documentation on the PSFolderSize module, use `Get-Help Get-FolderSize`.
  
  You will need to set the Search Base for the Active Directory query prior to running the script.

  PSFolderSize was written by gngrninja and is published under the MIT license. You can find the project at 
  https://github.com/gngrninja/PSFolderSize.
.EXAMPLE
  .\Get-HomeDrives.ps1
#>

# Start script log
$FileDate = Get-Date -Format "yyyy-MM-dd-HHmm"
$FriendlyDate = Get-Date -DisplayHint DateTime
$WorkingDirectory = "C:\temp\Get-HomeDrives-$FileDate"
Write-Host "[$FriendlyDate] Beginning transcript. Should problems arise you can review the transcript at C:\temp." -ForegroundColor Gray
Start-Transcript -Path "$WorkingDirectory\Get-HomeDrives-transcript-$FileDate.log" -Force

# Import the ActiveDirectory module
Write-Host "[$FriendlyDate] Attempting to import the ActiveDirectory module..." -ForegroundColor Gray
try {
    Import-Module -Name 'ActiveDirectory' -Force
    Write-Host "[$FriendlyDate] ActiveDirectory module import was successful!" -ForegroundColor DarkGreen
}
catch {
    try {
        Write-Host "[$FriendlyDate] ActiveDirectory module not found. Attempting to install it for you..." -ForegroundColor Yellow
        Install-Module -Name 'ActiveDirectory' -Force
        Write-Host "[$FriendlyDate] ActiveDirectory module was successfully installed! Importing module and continuing..." -ForegroundColor DarkGreen
        Import-Module -Name 'Active Directory' -Force
    }
    catch {
        Write-Host "[$FriendlyDate] Unable to install ActiveDirectory module. Please install the module manually then retry the script." -ForegroundColor DarkRed
        Write-Host "[$FriendlyDate] The script will now stop after striking the return key."
        Pause
        Exit
    }
}

# Import the PSFolderSize module
Write-Host "[$FriendlyDate] Attempting to import the PsFolderSize module..." -ForegroundColor Gray
try {
    Import-Module -Name 'PSFolderSize' -Force
    Write-Host "[$FriendlyDate] PsFolderSize module import was successful!" -ForegroundColor DarkGreen
}
catch {
    try {
        Write-Host "[$FriendlyDate] PsFolderSize module not found. Attempting to install it for you..." -ForegroundColor Yellow
        Install-Module -Name 'PSFolderSize' -Force
        Write-Host "[$FriendlyDate] PsFolderSize module was successfully installed! Importing module and continuing..." -ForegroundColor DarkGreen
        Import-Module -Name 'PSFolderSize' -Force
    }
    catch {
        Write-Host "[$FriendlyDate] Unable to install PsFolderSize module. Please install the module manually then retry the script." -ForegroundColor DarkRed
        Write-Host "[$FriendlyDate] The script will now stop after striking the return key."
        Pause
        Exit
    }
}

# Obtain a list of AD users who have home directories listed
Write-Host "[$FriendlyDate] Obtaining list of Active Directory users with home drives..." -ForegroundColor Gray
try {
    Get-AdUser -Filter * -SearchBase "dc=domain,dc=local" -Properties * | Where-Object {$_.Enabled -eq $true} | Where-Object {$_.Enabled -eq $true} | Where-Object {$_.HomeDirectory -like "\\*"} | Select-Object samAccountName,HomeDrive,HomeDirectory | Export-Csv -Path "$WorkingDirectory\homedrives-$FileDate.csv" -NoTypeInformation -Force
    Write-Host "[$FriendlyDate] Obtained list of Active Directory users with home drives!" -ForegroundColor DarkGreen
}
catch {
    Write-Host "[$FriendlyDate] Failed to obtain list of Active Directory users with home drives. Please verify you have permission to query Active Directory and that your device can contact a domain controller." -ForegroundColor DarkRed
    Write-Host "[$FriendlyDate] The script will now stop after striking the return key."
    Pause
    Exit
}

# Import the CSV of users with homedrives, select the homedrive path, and create empty array
Write-Host "[$FriendlyDate] Importing CSV of Active Directory users with home drives and getting sizes..." -ForegroundColor Gray
$homedrives = (Import-Csv -Path "$WorkingDirectory\homedrives.csv").HomeDirectory
$FinalResult = @()
$ErrorItems = @()

# For each homedrive, get the size and write an object into the array
foreach($homedrive in $homedrives){
    try {
        $FriendlyDate = Get-Date -DisplayHint DateTime
        Write-Host "[$FriendlyDate] Getting size of $homedrive..." -ForegroundColor Gray
        $split1 = $homedrives.split("\")[5] #This separates the last bit of the UNC path to get the actual folder name
        $results = Get-FolderSize $homedrive -FolderName $split1 -ErrorAction Stop | Select-Object FolderName,FullPath,SizeMB #The PSFolderSize PSmodule is required for this to work
        $FinalResult += New-Object PsObject -Property @{
            FolderName = $homedrive
            Size = $Results.SizeMB
    }
    Write-Host "[$FriendlyDate] Got size of $homedrive successfully!" -ForegroundColor DarkGreen
}
    catch {
        Write-Host "[$FriendlyDate] Failed to get size for $homedrive; path recorded. You may want to investigate this further." -ForegroundColor DarkRed
        $ErrorItems += New-Object PsObject -Property @{
            FolderName = $homedrive
    }

}
}


Write-Host "[$FriendlyDate] Done getting sizes of home drives." -ForegroundColor DarkGreen
Write-Host " "
Write-Host "[$FriendlyDate] Generating CSV report..." -ForegroundColor Gray

# Write out the array to a CSV file
try {
    $FinalResult | Export-Csv -Path "$WorkingDirectory\Get-HomeDrives-Report-$FileDate.csv" -NoTypeInformation -Force
    Write-Host "[$FriendlyDate] Successfully generated report. Please find the report at $WorkingDirectory." -ForegroundColor DarkGreen
}
catch {
    Write-Host "[$FriendlyDate] Failed to write out the report. The script will now end after striking the return key." -ForegroundColor DarkRed
    Pause
    Exit
}

# Write out the list of errored items to a text file
Write-Host "[$FriendlyDate] Writing out error items to $WorkingDirectory\Get-HomeDrives-Errors-$FileDate.txt"
$ErrorItems | Out-File "$WorkingDirectory\Get-HomeDrives-Errors-$FileDate.txt" -Force
Write-Host "[$FriendlyDate] The script has completed and will exit after striking the return key." -ForegroundColor DarkGreen
Pause

# End script log
Stop-Transcript

# Exit the script
Exit
