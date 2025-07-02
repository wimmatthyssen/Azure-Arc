<#
.SYNOPSIS

A script used to remove the Azure Connected Machine agent from a Windows machine and to clean ups up all related folders, files, registry keys, related agents, and configuration files.

.DESCRIPTION

A script used to remove the Azure Connected Machine agent from a Windows machine and to clean up all related folders, files, registry keys, related agents, and configuration files.
This script will do all of the following:

Check if PowerShell runs as Administrator, otherwise, exit the script.
Stop Azure Arc related processes.
Stop Azure Arc related services.
If the Azure Connected Machine agent is found, uninstall it using MsiExec.
Take ownership and grant the necessary permissions to remove the Microsoft.CPlat.Core.WindowsPatchExtension folder.
Clean up all subfolders in the Plugins folder except the one containing "Microsoft.Azure.AzureDefenderForServers.MDE.Windows".
Clean up all other Azure Arc folders (without packages folder).
Uninstall the Dependency Agent if it is installed.
Clean up the Microsoft Dependency Agent folder.
Remove any leftover registry keys related to Azure Arc.

.NOTES

Filename:       Remove-Azure-Arc-Connected-Machine-agent-Windows.ps1
Created:        30/06/2025
Last modified:  30/06/2025
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     PowerShell 5.1 or higher
Platform:       Windows
Action:         Change variables were needed to fit your needs.
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

.\Remove-Azure-Arc-Connected-Machine-agent-Windows

.LINK

https://wmatthyssen.com/2025/06/30/azure-arc-uninstall-the-connected-machine-agent-and-clean-up-related-resources-on-windows-using-a-powershell-script/
#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$azcmAgentProductName = "*Azure Connected Machine*"

Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$foregroundColor3 = "Red"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Check if PowerShell runs as Administrator, otherwise, exit the script

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Check if running as Administrator, otherwise exit the script
        
if ($isAdministrator -eq $false) {
        Write-Host ($writeEmptyLine + "# Please run PowerShell as Administrator" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor3 $writeEmptyLine
        Start-Sleep -s 3
        exit
} else {  
        Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 2 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor1  
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Stop Azure Arc related processes

# Define processes to stop
$processes = @(
    "HybridWorkerService",
    "agentwrap",
    "change_tracking_service"
    "change_tracking_agent_windows_amd64",
    "UpdateManagementActionExec",
    "AMAExtHealthMonitor",
    "MonAgentCore",
    "MonAgentHost",
    "MonAgentLauncher",
    "MonAgentManager",
    "MicrosoftDependencyAgent",
    "azcmagent"    
)

# Attempt to stop each process
foreach ($proc in $processes) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force
            Write-Host ($writeEmptyLine + "# Stopped process: $($_.Name)" + $writeSeperatorSpaces + $currentTime)`
            -foregroundcolor $foregroundColor2
        } catch {
            Write-Host ($writeEmptyLine + "# Failed to stop process: $($_.Name) - $_" + $writeSeperatorSpaces + $currentTime)`
            -foregroundcolor $foregroundColor3
        }
    }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Stop Azure Arc related services

# Define Azure Arc related services
$arcServices = @(
    "himds",
    "GCArcService",
    "ArcProxy",
    "HybridWorkerService",
    "change_tracking_service",
    "AutoAssessPatchService",
    "ExtensionService"
)

# Stop each service if it's running
foreach ($service in $arcServices) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Write-Host ($writeEmptyLine + "# Stopped service: $service" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor2
    }
    else {
        Write-Host ($writeEmptyLine + "# Service $service not found or already stopped" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor2
    }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## If the Azure Connected Machine agent is found, uninstall it using MsiExec

$arcAgent = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $azcmAgentProductName }

if ($null -eq $arcAgent) {
    Write-Host ($writeEmptyLine + "# No Azure Connected Machine agent found" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    exit
} else {
    $productCode = $arcAgent.IdentifyingNumber
    $arguments = "/x $productCode /qn"
    Start-Process "msiexec.exe" -ArgumentList $arguments -Wait

    Write-Host ($writeEmptyLine + "# Azure Connected Machine agent found and uninstalled" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Take ownership and grant the necessary permissions to remove the Microsoft.CPlat.Core.WindowsPatchExtension folder

$path = "C:\Packages\Plugins\Microsoft.CPlat.Core.WindowsPatchExtension\1.5.75\bin"

takeown /f $path /r /d Y > $null 
icacls $path /grant Administrators:F /t > $null 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Clean up all subfolders in the Plugins folder except the one containing "Microsoft.Azure.AzureDefenderForServers.MDE.Windows"

$arcPluginsFolder = "$env:SystemDrive\Packages\Plugins"

if (Test-Path $arcPluginsFolder) {
    # Get all subfolders in the Packages folder
    $subFolders = Get-ChildItem -Path $arcPluginsFolder -Directory

    foreach ($subFolder in $subFolders) {
        # Check if the subfolder name contains "Microsoft.Azure.AzureDefenderForServers.MDE.Windows"
        if ($subFolder.Name -notlike "*Microsoft.Azure.AzureDefenderForServers.MDE.Windows*") {
            Remove-Item -Path $subFolder.FullName -Recurse -Force
            Write-Host ($writeEmptyLine + "# Removed plugins folder: $($subFolder.FullName)" + $writeSeperatorSpaces + $currentTime)`
            -foregroundcolor $foregroundColor2
        } else {
            Write-Host ($writeEmptyLine + "# Skipped plugins folder: $($subFolder.FullName)" + $writeSeperatorSpaces + $currentTime)`
            -foregroundcolor $foregroundColor2
        }
    }
} else {
    Write-Host ($writeEmptyLine + "# Plugins folder not found" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor3
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Clean up all other Azure Arc folders (without packages folder)

# Define folders to remove
$arcFolders = @(
    "$env:ProgramData\AzureConnectedMachineAgent",
    "$env:ProgramData\GuestConfig",
    "$env:ProgramData\HybridWorker",
    "$env:ProgramFiles\AzureConnectedMachineAgent",
    "$env:SystemDrive\Resources",
    "$env:ProgramData\GuestConfig",
    "$env:ProgramFiles\ChangeAndInventory"
)

# Remove folders if they exist
foreach ($folder in $arcFolders) {
    if (Test-Path $folder) {
    Remove-Item -Path $folder -Recurse -Force
    Write-Host ($writeEmptyLine + "# Removed folder: $folder" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2
    } else {
        Write-Host ($writeEmptyLine + "# Folder $folder not found" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor2
    }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Uninstall the Dependency Agent if it is installed 

$uninstallers = Get-ChildItem -Path "C:\Program Files\Microsoft Dependency Agent" -Filter "Uninstall_*.exe"

if ($uninstallers.Count -gt 0) {
     $uninstaller = $uninstallers[0].FullName
    Start-Process -FilePath $uninstaller -ArgumentList "/S" -Wait
    Write-Host ($writeEmptyLine + "# Dependency agent found and uninstalled" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2
} else {
    Write-Host ($writeEmptyLine + "# No Dependency agent found" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Clean up the Microsoft Dependency Agent folder

# Define folder to remove
$dependencyFolders = @("$env:ProgramFiles\Microsoft Dependency Agent")

# Remove folders if they exist
foreach ($folder in $dependencyFolders) {
    if (Test-Path $folder) {
    Remove-Item -Path $folder -Recurse -Force
    Write-Host ($writeEmptyLine + "# Removed folder: $folder" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2
    } else {
        Write-Host ($writeEmptyLine + "# Folder $folder not found" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor2
    }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Remove any leftover registry keys related to Azure Arc

# Define registry keys to remove
$regKeys = @(
    "HKLM:\SOFTWARE\Microsoft\AzureConnectedMachineAgent",
    "HKLM:\SYSTEM\CurrentControlSet\Services\AzureConnectedMachineAgent",
    "HKLM:\SOFTWARE\Microsoft\AzureMonitorAgent",
    "HKLM:\SYSTEM\CurrentControlSet\Services\azuremonitoragent"
)

foreach ($key in $regKeys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ($writeEmptyLine + "# Removed registry key: $key" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2
    } else {
        Write-Host ($writeEmptyLine + "# Regkey $key not found" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor2
    }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed.

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
