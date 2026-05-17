<#
.SYNOPSIS
 
A script used to enable guest management on an Arc-enabled SCVMM VM and harden the Azure Connected Machine agent during onboarding.
 
.DESCRIPTION
 
A script used to enable guest management on an Arc-enabled SCVMM VM and harden the Azure Connected Machine agent during onboarding.
The script will do all of the following:
 
Remove the breaking change warning messages.
Change the current context to the specified subscription.
Store the specified set of tags in a hash table.
Enable guest management on the target VM.
Wait for the Azure Connected Machine agent to register in Azure.
Apply azcmagent hardening configuration inside the guest OS via WinRM.
Apply tags to the resulting Arc machine resource.
 
.NOTES
 
Filename:       Enable-HardenedArcScvmmGuestManagement.ps1
Created:        14/05/2026
Last modified:  14/05/2026
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell
Requires:       PowerShell Az.ScVmm, Az.ConnectedMachine
Action:         Change variables where needed to fit your needs.
Disclaimer:     This script is provided "As Is" with no warranties.
 
.EXAMPLE
 
Connect-AzAccount
.\Enable-HardenedArcScvmmGuestManagement.ps1 -vmName "vmName" -password "yourPassword"

Example .\Enable-HardenedArcScvmmGuestManagement.ps1 -vmName "swpvm023" -password "SuperSecretPassword!123,"
 
.LINK
 
https://wmatthyssen.com/2026/05/18/azure-arc-enabled-scvmm-securing-the-azure-connected-machine-agent-during-onboarding-with-powershell/
#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    # $VMName -> Name of the VM
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $vmName,
    # $password -> Password for the VM admin account (plain text, converted to SecureString inside the script)
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $password
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$environment = "xxx" # Used for tagging purposes, e.g. Dev, Test, Acceptance, Prod - Example: "prd"
$subscriptionName = "sub-yourcompany-xxxxxx-xxx" # Name of the subscription where the Arc machine resource is provisioned - Example: "sub-myhbe-241011-prd-arc-infra"
$resourceGroup = "rg-xxx-xxx-xx-01" # Name of the resource group where the Arc machine resource is provisioned - Example: "rg-srv-prd-we-01"

$username = "domain\admin_account" # Username of the VM admin account, in UPN or DOMAIN\username format - Example: "corp\wmatthyssen-admin"
$domainName = "corp.yourcompany.com" # Domain name used to construct the FQDN for WinRM connection - Example: "corp.wimmatthyssen.com"
$vmFqdn = "$vmName.$domainName" 
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

$tagEnvironmentName = "Env" # Name of the environment tag - Example: "Env"
$tagEnvironmentValue = (Get-Culture).TextInfo.ToTitleCase($environment.ToLower()) # Value of the environment tag, converted to title case - Example: "Prd"
$tagCostCenterName  = "CostCenter" # Name of the cost center tag - Example: "CostCenter"
$tagCostCenterValue = "23" # Value of the cost center tag - Example: "23"
$tagCriticalityName = "Criticality" # Name of the criticality tag - Example: "Criticality"
$tagCriticalityValue = "High" # Value of the criticality tag - Example: "High"
$tagArcSQLName = "ArcSQLServerExtensionDeployment" # Name of the Arc SQL Server extension deployment tag - Example: "ArcSQLServerExtensionDeployment"
$tagArcSQLValue = "Disabled" # Value of the Arc SQL Server extension deployment tag, used to exclude the VM from auto-deployment via Azure Policy - Example: "Disabled"
$tagDatacenterName  = "Datacenter" # Name of the datacenter tag - Example: "Datacenter"
$tagDatacenterValue = "01" # Value of the datacenter tag - Example: "01"
$tagCityName = "City" # Name of the city tag - Example: "City"  
$tagCityValue = "Antwerp" # Value of the city tag - Example: "Antwerp"
$tagCountryName = "CountryOrRegion" # Name of the country/region tag - Example: "CountryOrRegion"
$tagCountryValue = "Belgium" # Value of the country/region tag - Example: "Belgium"
$tagMaintenanceWindowName = "MaintenanceWindow" # Name of the maintenance window tag, used for scheduling updates and reboots via Azure Update Management
$tagMaintenanceWindowValue = "mc-win-t1-monthly-4th-thu-2000-rir" # Value of the maintenance window tag, used for scheduling updates and reboots via Azure Update Management - Example: "mc-win-t1-monthly-4th-thu-2000-rir" (which stands for "Maintenance Calendar - Windows - Tier 1 - Monthly on the 4th Thursday at 20:00 - Reboot If Required")
$tagMaintenanceWindowDefenderName = "MaintenanceWindowDefender" # Name of the maintenance window tag specifically for Microsoft Defender for Endpoint updates, used for scheduling Defender updates via Azure Update Management
$tagMaintenanceWindowDefenderValue = "mc-win-daily-defender-1000-nr" # Value of the maintenance window tag specifically for Microsoft Defender for Endpoint updates, used for scheduling Defender updates via Azure Update Management - Example: "mc-win-daily-defender-1000-nr" (which stands for "Maintenance Calendar - Windows - Daily at 10:00 - No Reboot")

$allowedExtensions = "Microsoft.AdminCenter/AdminCenter," +
                     "Microsoft.Azure.Monitor/AzureMonitorWindowsAgent," +
                     "Microsoft.Azure.AzureDefenderForServers/MDE.Windows," +
                     "Microsoft.SoftwareUpdateManagement/WindowsOsUpdateExtension," +
                     "Microsoft.CPlat.Core/WindowsPatchExtension"

Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null 
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$foregroundColor3 = "Red"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Remove the breaking change warning messages

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true | Out-Null
Update-AzConfig -DisplayBreakingChangeWarning $false | Out-Null
$warningPreference = "SilentlyContinue"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 5 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to the specified subscription

$subName = Get-AzSubscription | Where-Object {$_.Name -like $subscriptionName}

Set-AzContext -SubscriptionId $subName.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Specified subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Store the specified set of tags in a hash table

$tags = @{
    $tagEnvironmentName=$tagEnvironmentValue
    $tagCostCenterName=$tagCostCenterValue
    $tagCriticalityName=$tagCriticalityValue
    $tagArcSQLName=$tagArcSQLValue
    $tagDatacenterName=$tagDatacenterValue
    $tagCityName=$tagCityValue
    $tagCountryName=$tagCountryValue
    $tagMaintenanceWindowName=$tagMaintenanceWindowValue
    $tagMaintenanceWindowDefenderName=$tagMaintenanceWindowDefenderValue
}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Enable guest management on the target VM

try {
    New-AzScVmmVMGuestAgent `
        -VMName $vmName `
        -ResourceGroupName $resourceGroup `
        -SubscriptionId $subName.SubscriptionId `
        -CredentialsUsername $username `
        -CredentialsPassword $securePassword `
        -ErrorAction Stop | Out-Null
} catch {
    Write-Host ($writeEmptyLine + "# Failed to enable guest management on $vmName. Error: $($_.Exception.Message)" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor Red $writeEmptyLine
    exit 1
}

Write-Host ($writeEmptyLine + "# Guest management enabled on $vmName. Now registration is required, which can take some minutes to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Wait for the Azure Connected Machine agent to register in Azure

$timeout  = 300
$interval = 15
$elapsed  = 0

do {
    Start-Sleep -Seconds $interval
    $elapsed += $interval
    $machine = Get-AzConnectedMachine `
        -Name $vmName `
        -ResourceGroupName $resourceGroup `
        -SubscriptionId $subName.SubscriptionId `
        -ErrorAction SilentlyContinue
    Write-Host ($writeEmptyLine + "# Elapsed: $elapsed seconds | Status: $($machine.Status)" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
} until ($machine.Status -eq "Connected" -or $elapsed -ge $timeout)

if ($machine.Status -ne "Connected") {
    Write-Host ($writeEmptyLine + "# Agent did not register within $timeout seconds. Exiting." + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    exit 1
}

Write-Host ($writeEmptyLine + "# Agent registered successfully" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Apply azcmagent hardening configuration inside the guest OS via WinRM

$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Invoke-Command -ComputerName $vmFqdn -Credential $credential -ErrorAction Stop -ScriptBlock {

        $azcmagent = "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe"

        # Restrict extensions to approved list only
        & $azcmagent config set extensions.allowlist $using:allowedExtensions *>$null

        # Disable inbound connection ports
        & $azcmagent config clear incomingconnections.ports *>$null

        # Disable inbound connections
        & $azcmagent config set incomingconnections.enabled false *>$null

    }
} catch {
    Write-Host ($writeEmptyLine + "# WinRM connection to $vmFqdn failed. Azcmagent hardening was NOT applied. Error: $($_.Exception.Message)" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    exit 1
}

Write-Host ($writeEmptyLine + "# Azcmagent configuration applied successfully: extensions.allowlist set | incomingconnections.ports cleared | incomingconnections.enabled set to false" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Apply tags to the resulting Arc machine resource

Update-AzTag -ResourceId $machine.Id -Tag $tags -Operation Merge | Out-Null

Write-Host ($writeEmptyLine + "# Tags applied successfully" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
