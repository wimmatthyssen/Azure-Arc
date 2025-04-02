<#
.SYNOPSIS

A script used to install OpenSHH on a Windows Server 2019 or 2022.

.DESCRIPTION

A script used to install OpenSHH on a Windows Server 2019 or 2022.
This script will do all of the following:

Check if PowerShell is running as Administrator, otherwise exit the script.
Install OpenSSH Server.
Install OpenSSH Client.
Start and enable the SSH service.   
Allow OpenSSH through the Windows Firewall.

.NOTES

Filename:       Install-OpenSSH-on-a-Windows-Server-2019-2022.ps1
Created:        02/04/2025
Last modified:  02/04/2025
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Windows PowerShell (v5.1 or above)
OS:             Windows Server 2019 and Windows Server 2022
Action:         Update variables if needed to fit your environment.
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

.\Install-OpenSSh-on-a-Windows-Server-2019-2022

.LINK


#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

# Dynamic variables - Please change the values if needed to fit your environment.
$firewallRuleName = "OpenSSH-Server-In"  # Variable for the firewall rule name

Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$foregroundColor3 = "Red"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started.

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 2 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Check if PowerShell is running as Administrator, otherwise exit the script.

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdministrator -eq $false) 
{
    Write-Host ($writeEmptyLine + "# Please run PowerShell as Administrator" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    exit
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Install OpenSSH Server.

try {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop | Out-Null 
    Write-Host ($writeEmptyLine + "# OpenSSH Server installed" + $writeSeperatorSpaces + $global:currenttime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
} catch {
    Write-Host ($writeEmptyLine + "# Failed to install OpenSSH Server: $($_.Exception.Message)" + $writeSeperatorSpaces + $global:currenttime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    exit
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Install OpenSSH Client.

try {
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 -ErrorAction Stop | Out-Null 
    Write-Host ($writeEmptyLine + "# OpenSSH Client installed" + $writeSeperatorSpaces + $global:currenttime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
} catch {
    Write-Host ($writeEmptyLine + "# Failed to install OpenSSH Client: $($_.Exception.Message)" + $writeSeperatorSpaces + $global:currenttime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    exit
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Start and enable the SSH service.

try {
    # Start the SSH service
    Start-Service sshd
    # Set the SSH service to start automatically with Windows
    Set-Service -Name sshd -StartupType Automatic
    Write-Host ($writeEmptyLine + "# SSH service started and set to automatic" + $writeSeperatorSpaces + $global:currenttime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
} catch {
    Write-Host ($writeEmptyLine + "# Failed to start or configure SSH service: $($_.Exception.Message)" + $writeSeperatorSpaces + $global:currenttime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    exit
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Allow OpenSSH through the Windows Firewall.

try {
    # Check if the firewall rule already exists
    $firewallRule = Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue

    if ($null -eq $firewallRule) {
        # Rule does not exist, create it
        New-NetFirewallRule -Name $firewallRuleName -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        Write-Host ($writeEmptyLine + "# Windows Firewall rule created and configured for OpenSSH" + $writeSeperatorSpaces + $global:currenttime)`
        -foregroundcolor $foregroundColor2 $writeEmptyLine
    } else {
        # Rule already exists
        Write-Host ($writeEmptyLine + "# Windows Firewall rule already exists and is configured for OpenSSH" + $writeSeperatorSpaces + $global:currenttime)`
        -foregroundcolor $foregroundColor2 $writeEmptyLine
    }
} catch {
    Write-Host ($writeEmptyLine + "# Failed to configure Windows Firewall for OpenSSH: $($_.Exception.Message)" + $writeSeperatorSpaces + $global:currenttime)`
    -foregroundcolor $foregroundColor3 $writeEmptyLine
    exit
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed.

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
