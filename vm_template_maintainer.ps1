<#
.SYNOPSIS
  This script maintains "template" VMs.
.DESCRIPTION
  This script maintains "template" VMs by performing the following actions for each VM:
     - Powers on the VM
     - Configures registry settings
     - Disables firewall for domain environment
     - Disables User Account Control
     - Disables IPv6
     - Remediates various vulnerabilities
     - Updates Windows
     - Shuts down the VM
  Only one server at a time is worked on to reduce consumption of cluster resources.
  
  Note that vulnerability remediations in this or any other script in the repository are
  not guaranteed to fully or partially mitigate any vulnerability. Please consult official
  documentation on comprehensive mitigation of any vulnerability.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Updated by:     Griffeth Barker (barkergriffeth@gmail.com)
  Change Date:    11-29-2022
  Purpose/Change: Initial development

  This script must be run from a node where VMware PowerCLI is installed.
  
  Note that this script is intended to be used in environments where "template" VMs are used to
  clone new servers from; it is not in its current state able to check out actual templates and
  maintain them.
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
$DomainSuffix = "yourdomain.local"

$NotificationArray = @()

Connect-VIServer -Server $vCenterServer -Force

# List of "template" VMs
$TemplateVMs = Get-VM | Where-Object {$_.Name -like "*Template*"} | Select-Object Name

# Begin ForEach loop ########################################################################################
foreach ($Template in $TemplateVMs){
    # Get Name and Hostname of the VM/Guest
    $TemplateHostName = (Get-VMGuest -VM "$Template").HostName

    # Temporarily allow all for WSman trusted hosts (this is changed to *.domain.local at the end of the loop)
    Set-Item wsman:\localhost\Client\TrustedHosts -Value *

    Write-Host "Working on $Template..." -ForegroundColor DarkYellow
    
    # Power on the VM
    Write-Host "Powering on VM and waiting 30 seconds for boot..." -ForegroundColor Gray
    Start-VM -VM "$Template"
    Start-Sleep -Seconds 30

    # Begin Invoke-Command ########################################################################
    Write-Host "Beginning auto-maintenance of $Template..." -ForegroundColor Black -BackgroundColor DarkYellow
    Invoke-Command -ComputerName $TemplateHostName -Credential Administrator -ScriptBlock {

        # Preparations
        Write-Host "Setting execution policy..." -ForegroundColor Gray
        try {
          Set-ExecutionPolicy Bypass -Scope Process -Force
          Write-Host "Set execution policy successfully!" -ForegroundColor Gray          
        }
        catch {
          Write-Host "Failed to set execution policy!" -ForegroundColor DarkRed
        }

        Write-Host "Enabling PowerShell Remoting and Windows Remote Management..." -ForegroundColor Gray
        try {
          Enable-PSRemoting
          Write-Host "PowerShell Remoting & Windows Remote Management configured!" -ForegroundColor Gray 
        }
        catch {
          Write-Host "Failed to configure PowerShell Remoting & Windows Remote Management!" -ForegroundColor DarkRed
        }

        # Smartcards 
        # The below setup is for Yubikeys using ED25519 keys; this section can be removed if you do not use these.
        Write-Host "Configuring smart cards..." -ForegroundColor Gray
        try {
          New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SmartCardCredentialProvider" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SmartCardCredentialProvider" -name "EnumerateECCCerts" -value "1" -PropertyType "DWord" -Force | Out-Null
          New-Item "HKLM:\SOFTWARE\Yubico\ykmd" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SOFTWARE\Yubico\ykmd" -name "BlockPUKOnMGMUpgrade" -value "0" -PropertyType "DWord" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SOFTWARE\Yubico\ykmd" -name "NewKeyTouchPolicy" -value "3" -PropertyType "DWord" -Force | Out-Null
          Write-Host "Smart card registry keys configured!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to configure smart card registry keys!" -ForegroundColor DarkRed
        }

        # Disable Windows Firewall for Domain environment
        # This can be helpful for initial configuration; you should always consider enabling your firewall and creating appropriate rules
        # for your traffic for security purposes.
        Write-Host "Disabling Windows Firewall for Domain environment..." -ForegroundColor Gray
        try {
          Set-NetFirewallProfile -Profile Domain -Enabled False
          Write-Host "Windows Firewall disabled!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to disable Windows Firewall!" -ForegroundColor DarkRed
        }

        # Disable IPv6 on all network adapters
        # This can be excluded if you currently use, or plan to use, IPv6 in your environment.
        Write-Host "Disabling IPv6 for all NICs..." -ForegroundColor Gray
        $GuestNICs = Get-NetAdapterBinding | Where-Object ComponentID -EQ 'ms_tcpip6'
        foreach ($GuestNIC in $GuestNICS){
          try {
            Disable-NetAdapterBinding -Name $GuestNIC.Name -ComponentID 'ms_tcpip6'
            Write-Host "IPv6 disabled!" -ForegroundColor Gray
          }
          catch {
            Write-Host "Failed to disable IPv6!" -ForegroundColor DarkRed
          }
        }

        # Disable UAC
        # Obviously the recommended security configuration would be to have UAC enabled, however 
        # many organizations who run legacy or other software which requires this disabled may find this is a setting
        # they change frequently.
        Write-Host "Disabling User Account Control (ConsentAdminBehavior)..." -ForegroundColor Gray
        try {
          Set-ItemProperty -Path "REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value "0" -Force
          Write-Host "UAC Disabled!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to disable UAC!" -ForegroundColor DarkRed
        }

        # Enable TLS 1.2
        Write-Host "Enabling TLS 1.2..." -ForegroundColor Gray        
        try {
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Force | Out-Null    
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -name "Enabled" -value "1" -PropertyType "DWord" -Force | Out-Null    
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -name "DisabledByDefault" -value 0 -PropertyType "DWord" -Force | Out-Null    
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -Force | Out-Null    
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -name "Enabled" -value "1" -PropertyType "DWord" -Force | Out-Null    
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -name "DisabledByDefault" -value 0 -PropertyType "DWord" -Force | Out-Null 
          Write-Host "TLS 1.2 has been enabled!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to enable TLS 1.2!" -ForegroundColor DarkRed
        }

        # Disable SSL 2.0
        Write-Host "Disabling SSL 2.0..." -ForegroundColor Gray
        try {
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" -Force | Out-Null  
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" -name "Enabled" -value "0" -PropertyType "DWord" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" -name "DisabledByDefault" -value 1 -PropertyType "DWord" -Force | Out-Null            
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" -Force | Out-Null            
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" -name "Enabled" -value "0" -PropertyType "DWord" -Force | Out-Null            
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" -name "DisabledByDefault" -value 1 -PropertyType "DWord" -Force | Out-Null
          Write-Host "SSL 2.0 has been disabled!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to Disable SSL 2.0!" -ForegroundColor DarkRed
        }

        # Disable SSL 3.0
        Write-Host "Disabling SSL 3.0..." -ForegroundColor Gray
        try {
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -Force | Out-Null    
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -name "Enabled" -value "0" -PropertyType "DWord" -Force | Out-Null    
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -name "DisabledByDefault" -value 1 -PropertyType "DWord" -Force | Out-Null    
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" -Force | Out-Null    
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" -name "Enabled" -value "0" -PropertyType "DWord" -Force | Out-Null    
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" -name "DisabledByDefault" -value 1 -PropertyType "DWord" -Force | Out-Null
          Write-Host "SSL 3.0 has been disabled!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to disable SSL 3.0!" -ForegroundColor DarkRed
        }

        # Disable TLS 1.0
        Write-Host "Disabling TLS 1.0..." -ForegroundColor Gray
        try {
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" -name "Enabled" -value "0" -PropertyType "DWord" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" -name "DisabledByDefault" -value 1 -PropertyType "DWord" -Force | Out-Null
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -name "Enabled" -value "0" -PropertyType "DWord" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -name "DisabledByDefault" -value 1 -PropertyType "DWord" -Force | Out-Null
          Write-Host "TLS 1.0 has been disabled!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to disable TLS 1.0!" -ForegroundColor DarkRed
        }

        # Disable TLS 1.1
        Write-Host "Disabling TLS 1.1..." -ForegroundColor Gray
        try {
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" -name "Enabled" -value "0" -PropertyType "DWord" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" -name "DisabledByDefault" -value 1 -PropertyType "DWord" -Force | Out-Null
          New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" -name "Enabled" -value "0" -PropertyType "DWord" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" -name "DisabledByDefault" -value 1 -PropertyType "DWord" -Force | Out-Null
          Write-Host "TLS 1.1 has been disabled." -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to disable TLS 1.1!" -ForegroundColor DarkRed
        }

        # Enable RDP
        # Write-Host "Enabling Remote Desktop..." -ForegroundColor Gray
        # New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value "0" -PropertyType "DWORD"
        # Write-Host "Remote Desktop enabled!" -ForegroundColor Gray

        # CVE-2017-8529 Remediation - IE Print Disclosure
        Write-Host "Remediating CVE-2017-8529 (IE Print Disclosure)..." -ForegroundColor Gray
        try {
          New-Item -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl" -Name "FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX"
          New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX" -Name "iexplore.exe" -Value "1" -PropertyType "DWORD" -Force
          New-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\FeatureControl" -Name "FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX"
          New-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX" -Name "iexplore.exe" -Value "1" -PropertyType "DWORD" -Force
          Write-Host "Remediated CVE-2017-8529!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to remediate CVE-2017-8529!" -ForegroundColor DarkRed
        }

        # CVE-2022-30190 Remediation - MSDT Follina
        Write-Host "Remediating CVE-2022-30190 (MSDT Follina)..." -ForegroundColor Gray
        try {
          $dir = "C:\temp"
          mkdir $dir
          reg export HKEY_CLASSES_ROOT\ms-msdt C:\temp\ms-msdt.reg
          reg delete HKEY_CLASSES_ROOT\ms-msdt /f
          Write-Host "Remediated CVE-2022-30190!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to remediate CVE-2022-30190!" -ForegroundColor DarkRed
        }

        # CVE-2013-3900  Remediation - WinVerifyTrust (EnableCertPaddingCheck)
        Write-Host "Remediating CVE-2013-3900 (WinVerifyTrust)..." -ForegroundColor Gray
        try {
          New-Item "HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust" -Force | Out-Null
          New-Item "HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config" -Force | Out-Null
          New-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config" -name "EnableCertPaddingcheck" -value "1" -PropertyType "DWord" -Force | Out-Null
          New-Item "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust" -Force | Out-Null
          New-Item "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" -Force | Out-Null
          New-ItemProperty -path "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" -name "EnableCertPaddingcheck" -value "1" -PropertyType "DWord" -Force | Out-Null
          Write-Host "Remediated CVE-2013-3900!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to remediate CVE-2013-3900!" -ForegroundColor DarkRed
        }

        # CVE-2016-2115 Remediation - SMB Signing
        Write-Host "Remediating CVE-2016-2115 (SMB Signing)..." -ForegroundColor Gray
        try {
          $CurrentSmbSigning = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManWorkstation\Parameters").RequireSecuritySignature
          if (0 -eq $CurrentSmbSigning){
          Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManWorkstation\Parameters" -Name "RequireSecuritySignature" -Value "1"
          }
          elseif (0 -ne $CurrentSmbSigning){
          Exit
          }
          Write-Host "Remediated CVE-2016-2115!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to remediate CVE-2016-2115!" -ForegroundColor DarkRed
        }

        # CVE-2017-5753/CVE-2017-5715 - Spectre/Meltdown/Zombie
        Write-Host "Remediating CVE-2017-5753 and CVE-2017-2715 (Spectre/Meltdown/Zombie)..." -ForegroundColor Gray
        try {
          New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverride" -Value "72" -PropertyType "DWORD";New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverrideMask" -Value "3" -PropertyType "DWORD"
          Write-Host "Remediated CVE-2017-5753 and CVE-2017-2715!" -ForegroundColor Gray
        }
        catch {
          Write-Host "Failed to remediate CVE-2017-5753 and CVE-2017-2715!" -ForegroundColor DarkRed
        }

        # Force Windows Updates from Microsoft
        Write-Host "Forcing Windows Update from Microsoft..." -ForegroundColor Gray
        try {
          try {                
              Import-Module PSWindowsupdate -ErrorAction 1 -verbose                
              }
          catch {
              Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
              Install-Module PSWindowsupdate -force -Confirm:$false -verbose
              Import-Module PSWindowsUpdate
              }
          
          Import-Module PSWindowsUpdate
          $updatelist = 0
          Write-Host "Cleared update list ($updatelist)." -ForegroundColor Gray
          $updatelist = Invoke-Command -ScriptBlock {Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process;get-windowsupdate -WindowsUpdate -verbose}
          Invoke-Command -ScriptBlock {Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process;$date = get-date -f MM-dd-yyyy-HH-mm-ss;Invoke-WUJob -runnow -Script "Set-ExecutionPolicy -ExecutionPolicy Bypass;ipmo PSWindowsUpdate;get-windowsupdate -MicrosoftUpdate -verbose; Install-WindowsUpdate -Microsoftupdate -AcceptAll -autoreboot | Out-File C:\PSWindowsUpdate-$date.log" -Confirm:$false -Verbose} -Verbose
      } # End of Invoke-Command ################################################################
      catch {
        Write-Host "Failed to force Windows Updates from Microsoft!" -ForegroundColor DarkRed
      }
        
        # Reset WSman trusted hosts
        Write-Host "Resetting WSman trusted hosts configuration..." -ForegroundColor Gray
        Set-Item wsman:\localhost\Client\TrustedHosts -Value "*.$DomainSuffix" -Confirm:$false
        Write-Host "Trusted hosts reset!" -ForegroundColor Gray

        # Shut down template VM
        Write-Host "Waiting 30 minutes for updates to finish installing..." -ForegroundColor Gray
        Start-Sleep -Seconds 1800
        Write-Host "Shutting down $Template and waiting 30 seconds..." -ForegroundColor Gray
        Shutdown-VMGuest -VM "$Template" -Confirm:$false

        $NotificationArray += $Template
        Write-Host "Done auto-maintaining $Template!" -ForegroundColor Black -BackgroundColor DarkGreen

    } # End of ForEach loop #################################################################################
  }
Disconnect-VIServer -Server $vCenterServer

# Send email notification
Write-Host "Sending email notification..." -ForegroundColor DarkYellow
$body = "
This message is to notify you that auto-maintenance for the following 'template' virtual machines was completed:
$NotificationArray
"

try {
  Send-MailMessage -To $Recipients -From $Sender -subject "Notification - Template VM auto-maintenance completed" -Body $Body -SmtpServer $SmtpServer
  Write-Host "Emailed notification successfully!" -ForegroundColor DarkGreen
}
catch {
  Write-Host "Failed to email notification!" -ForegroundColor DarkRed
}
