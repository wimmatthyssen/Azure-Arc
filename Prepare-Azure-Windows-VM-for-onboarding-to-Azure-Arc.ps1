<#
.SYNOPSIS

A script used to prepare an Azure Windows VM for onboarding to Azure Arc, specifically for learning and testing.

.DESCRIPTION

A script used to prepare an Azure Windows VM for onboarding to Azure Arc, specifically for learning and testing.
This script will do all of the following:

Prepare Azure VM for onboarding to Azure Arc.

.NOTES

Filename:       Prepare-Azure-Windows-VM-for-onboarding-to-Azure-Arc.ps1
Created:        21/02/2025
Last modified:  21/02/2025
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v10.4.1)
Action:         Change variables were needed to fit your needs.
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

.\Prepare-Azure-Windows-VM-for-onboarding-to-Azure-Arc

.LINK


#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started.

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 2 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Prepare Azure VM for onboarding to Azure Arc

# Set the environment variable to override the ARC on an Azure VM installation
[System.Environment]::SetEnvironmentVariable("MSFT_ARC_TEST",'true', [System.EnvironmentVariableTarget]::Machine)

# Disable the Azure VM Guest Agent
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose

# Block access to Azure IMDS endpoint
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

Write-Host ($writeEmptyLine + "# Azure VM is now ready for onboarding to Azure Arc" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed.

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------