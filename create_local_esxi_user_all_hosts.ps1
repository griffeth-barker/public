<#
.SYNOPSIS
  This script will create a local account with ReadOnly permissions on all ESXi hosts attached to vCenter.
.DESCRIPTION
  This script gets a list of ESXi hosts attached to vCenter then iterates through the list:
    - Check if the specified account exits and create it if missing
    - Check if the specified permissions exist, and create them if missing
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author         : Barker, Griffeth (barkergriffeth@gmail.com)
  Change Date    : 2023-10-17
  Purpose/Change : Initial development

  This script should be run in the context of your domain privileged account if using LDAP/Active Directory SSO for vCenter. Alternatively,
  ensure you run it using credentials for an account in vCenter that will have permissions to make the modifications on all the hosts.

  This script was written with the intention of being run individually at each physical site, as in the original production environment for
  which it was written, each site's ESXi networks cannot communicate cross-site with one another for security purposes. When I ran this script
  I copied it to and then invoked it on a utilieis server at each of the sites. 
  
  You'll see that there is a bit of inefficiency in the script due to an awkward transitory phase for the ESXi environments at the sites at
  the time that this was originall written. I intend to revise this to be a bit cleaner and more generic in a future iteration.

  Huge credit to: LucD on the VMware Forums for the excellent foundation that I built off of to solve my need.
  https://communities.vmware.com/t5/VMware-PowerCLI-Discussions/Create-a-PowerCLI-script-to-create-a-local-User-account-on-each/td-p/502347
.EXAMPLE
  None
#>

# Your vCenter Server
$vcenter_server = "yourvcenter"

# Import the VMware PowerCLI module(s)
try {
    Import-Module -Name VMware.PowerCLI -Force -ErrorAction Stop
}
catch {
    Install-Module -Name VMware.PowerCLI -Scope AllUsers -AllowClobber -Force -Confirm:$false
    Import-Module -Name VMware.PowerCLI -Force
}

# Failures array
$report = New-Object -TypeName System.Data.DataTable
[void]$report.Columns.Add("Host")
[void]$report.Columns.Add("User Exists")
[void]$report.Columns.Add("Permission Exists")

# Connect to vCenter to get list of ESX hosts
Write-Host "Connect to vCenter"
try {
    Connect-VIServer -Server $vcenter_server -Force
    Write-Host "Connect to vCenter success"
}
catch {
    Write-Host "Connect to vCenter failure"
    Break
}

# Determine at which site the script is being run and get list of site's ESXi hosts
#
# This is needed because each site's ESX networks cannot talk to the ESX networks at other sites. This is
# by design, as there is no reason for them to have communication, and this increases security.
#
# This switch reads the hostname of the computer on which the script is being run and then sets the necessary
# variables to run the script only for hosts at that site based on the first three letters of the hostname.
Write-Host "Determine site context"
$site = switch (($env:computername).Substring(0,3)){
    # Site 1
    AAA {
        $vmhosts = Get-VMHost | Where-Object {
            $_.Name -like "AAA*" -or
            $_.Name -like "AAB*" -or
            $_.Name -like "10.1.*"
        }
    }
    # DSite 2
    BBB {
        $vmhosts = Get-VMHost | Where-Object {
            $_.Name -like "BBB*" -or
            $_.Name -like "BBC*" -or
            $_.Name -like "10.2.*"
        }
    }
    # Site 3
    CCC {
        $vmhosts = Get-VMHost | Where-Object {
            $_.Name -like "CCC*" -or
            $_.Name -like "10.3.*"
        }
    }
    # Site 4
    DDD {
        $vmhosts = Get-VMHost | Where-Object {
            $_.Name -like "DDD*" -or
            $_.Name -like "10.4.*"
        }
    }
    # Site 5
    EEE {
        $vmhosts = Get-VMHost | Where-Object {
            $_.Name -like "EEE*" -or
            $_.Name -like "EEF*" -or
            $_.Name -like "10.5.*"
        }
    }
}
Write-Host "Determined site context: $site"

# Iterate through list of ESX hosts
Write-Host "Iterate through site's ESXi hosts"
foreach ($vmhost in $vmhosts) {

    # Details of the account that needs created on all ESXi hosts
    #
    # Remember that credentials should be sanitized/removed during script storage
    # and only populated during an ad-hoc run of the script, and preferably called
    # using a secrets management method such as the SecretsManagement PowerShell
    # module and/or its plugins for other vaults. For base functionality, I've
    # provided a basic username/password implementation here.
    $username = 'changeme'
    $pswd = 'changeme'

    # Context switch
    #
    # This is needed since each site/region has different ESXi root passwords.
    # This switch will read the name of the parent object of the ESXi host in
    # vSphere, then set the $root_user and $root_pswd variables appropriately
    # based on that.
    switch ((Get-VMHost -Name $vmhost.name).Parent.Name) {
        
        # Cleveland
        CLE_Cluster {
            $root_user = 'probablyroot'
            $root_pswd = 'betterbeagoodone'
        }
    
        # Black Hawk
        BHWK_Cluster1 {
            $root_user = 'probablyroot'
            $root_pswd = 'betterbeagoodtwo'
        }
    
        # GDW Carson
        CSN_VXRail_Cluster1 {
            $root_user = 'probablyroot'
            $root_pswd = 'betterbeagoodthree'
        }
    
        # GDW Elko
        EKO_Cluster1 {
            $root_user = 'probablyroot'
            $root_pswd = 'betterbeagoodfour'
        }
    
        # Data center
        JEI_Cluster1  {
            $root_user = 'probablyroot'
            $root_pswd = 'betterbeagoodfive'
        }
        
        # J Resort
        RSR_Cluster1 {
            $root_user = 'probablyroot'
            $root_pswd = 'betterbeagoodsix'
        }

        # Louisiana
        host {
            $root_user = 'root'
            $root_pswd = 'betterbeagoodseven'
        }
    }

    # Connect to the ESXi host
    Write-Host "Process $($vmhost.name)"
    try {
        Connect-VIServer -Server $vmhost.name -User $root_user -Password $root_pswd -Force

        # Is user present
        if ($null -ne (Get-VMHostAccount -User $username -Server $vmhost.Name).Name) {
            $user_status = "OK"
        }
        # If not, create user
        if ($null -eq (Get-VMHostAccount -User $username -Server $vmhost.Name).Name) {
            try {
                New-VMHostAccount -Id $username -Password $pswd -Server $vmhost.Name
                $user_status = "Changed"
            }
            catch {
                $user_status = "Fail"
            }
        }
    
        # Check for permissions, and grant ReadOnly if missing
        $perm = Get-VIPermission -Principal $userName -Server $vmhost.Name
        $perm_status = "OK"
    
        if (!$perm) {
            $root = Get-Folder -Name root -Server $vmhost.Name
            try {
                New-VIPermission -Entity $root -Principal $userName -Role readonly -Server $vmhost.Name
                $perm_status = "Changed"       
            }
            catch {
                $perm_status = "Fail" 
            }
        }
    
        # Disconnect from ESX host
        Disconnect-VIServer -Server $vmhost.Name -Confirm:$false
        Write-Host "Process ($(vmhost.name) success)"
        [void]$report.Rows.Add($vmhost.name,$user_status,$perm_status)
    }
    catch {
        Write-Host "Process $($vmhost.name) failure"
        [void]$report.Rows.Add($vmhost.name,$user_status,$perm_status)
    }
}
Write-Host "Loop through site's ESX hosts complete"

# Disconnect from vCenter
Disconnect-VIServer -Server $vcenter_server -Force -Confirm:$false

# Report
$report | Format-Table -AutoSize -Wrap
