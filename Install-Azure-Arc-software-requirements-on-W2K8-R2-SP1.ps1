<#
.SYNOPSIS

A script used to install all the software requirements required to onboard a Windows Server 2008 R2 SP1 server into Azure Arc.

.DESCRIPTION

A script used to install all the software requirements required to onboard a Windows Server 2008 R2 SP1 server into Azure Arc.
This script will do all of the following:

Check if PowerShell is running as an administrator; otherwise, exit the script.
Remove the breaking change warning messages.
Create C:\Temp folder if it does not exist.
Create WindowsManagementFramework folder in C:\Temp if it does not exist.
Download the WMF 5.1 zip file.
Extract and cleanup the Win7AndW2K8R2-KB3191566-x64.zip zip file.
Install MSU Win7AndW2K8R2-KB3191566-x64.msu.
Reboot the server after 3 seconds.

.NOTES

Filename:       Install-Azure-Arc-software-requirements-on-W2K8-R2-SP1.ps1
Created:        15/11/2023
Last modified:  15/11/2023
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     2.0
Action:         Change variables were needed to fit your needs. 
Disclaimer:     This script is provided "as is" with no warranties.

.EXAMPLE

.\Install-Azure-Arc-software-requirements-on-W2K8-R2-SP1.ps1

.LINK


#>

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$tempFolderName = "Temp"
$tempFolderPath = "C:\" + $tempFolderName +"\"
$itemType = "Directory"
$wmfFolderName = "WindowsManagementFramework"
$tempWmfFolderPath = $tempFolderPath + $wmfFolderName +"\"
$wmfUrl = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip"
$wmfZip = $tempWmfFolderPath + "Win7AndW2K8R2-KB3191566-x64.zip"

$global:currenttime= Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime= Get-Date -UFormat "%A %m/%d/%Y %R"}
$foregroundColor1 = "Red"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Check if PowerShell is running as an administrator; otherwise, exit the script

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdministrator -eq $false) 
{
    Write-Host ($writeEmptyLine + "# Please run PowerShell as Administrator" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine
    exit
}
 
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Remove the breaking change warning messages

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true | Out-Null
$warningPreference = "SilentlyContinue"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 3 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create C:\Temp folder if it does not exist

If(!(test-path $tempFolderPath))
{
New-Item -Path "C:\" -Name $tempFolderName -ItemType $itemType -Force | Out-Null
}

Write-Host ($writeEmptyLine + "# $tempFolderName folder available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create WindowsManagementFramework folder in C:\Temp if it does not exist
 
If(!(test-path $tempWmfFolderPath))
{
New-Item -Path $tempFolderPath -Name $wmfFolderName -ItemType $itemType | Out-Null
}
  
Write-Host ($writeEmptyLine + "# $wmfFolderName folder available in the $tempFolderName folder" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Download the WMF 5.1 zip file

# Create a new WebClient object
$webClient = New-Object System.Net.WebClient

# Download the zip file
$webClient.DownloadFile($wmfUrl, $wmfZip)

# Dispose of the WebClient object to release resources
$webClient.Dispose()

Write-Host ($writeEmptyLine + "# Win7AndW2K8R2-KB3191566-x64.zip available in the $wmfFolderName folder" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Extract and cleanup the Win7AndW2K8R2-KB3191566-x64.zip zip file

# Create a Shell Application object
$shell = New-Object -ComObject Shell.Application

# Create a folder object for the destination folder
$destinationFolder = $shell.Namespace($tempWmfFolderPath)

# Create a folder object for the zip file
$zipFile = $shell.Namespace($wmfZip)

# Copy the contents of the zip file to the destination folder
$destinationFolder.CopyHere($zipFile.Items())

Write-Host ($writeEmptyLine + "# Win7AndW2K8R2-KB3191566-x64.msu available in extracted folder" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Install MSU Win7AndW2K8R2-KB3191566-x64.msu

# Specify the path to the MSU file
$msuFilePath = $tempWmfFolderPath + "Win7AndW2K8R2-KB3191566-x64.msu"

# Use wusa.exe to install the MSU file
Start-Process -FilePath "wusa.exe" -ArgumentList "$msuFilePath /quiet /norestart" -Wait

Write-Host ($writeEmptyLine + "# Win7AndW2K8R2-KB3191566-x64.msu installed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Reboot the server after 3 seconds

# Get the hostname
$hostname = [System.Net.Dns]::GetHostName()

Write-Host ($writeEmptyLine + "# Script completed, server $hostname will now restart" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine

# Restart the server without a confirmation prompt
Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 3" -Wait

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



