<#
.SYNOPSIS
 
A script used to unlink the ESU licenses for Azure Arc connected servers listed in a CSV file.
 
.DESCRIPTION
 
A script used to unlink the ESU licenses for Azure Arc connected servers listed in a CSV file.
The script will do all of the following:
 
Unlink the ESU licenses for each Azure Arc connected server listed in the CSV file.
 
.NOTES
 
Filename:       Unlink-ESU-licenses-from-Arc-enabled-servers-WS2012.ps1
Created:        14/10/2026
Last modified:  14/10/2026
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell
Requires:       PowerShell Az (v14.6.0)
Action:         Change variables were needed to fit your needs.
Disclaimer:     This script is provided "As Is" with no warranties.
 
.EXAMPLE
 
Connect-AzAccount
.\Unlink-ESU-licenses-from-Arc-enabled-servers-WS2012.ps1 
 
Example: .\Unlink-ESU-licenses-from-Arc-enabled-servers-WS2012.ps1 
 
.LINK
 
https://wmatthyssen.com/2026/10/14/azure-arc-windows-server-2012-esus-have-ended-what-to-do-next/
#>
 
## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$csvPath = ".\AzureArc-WS2012-ESU-LinkedServers.csv" # Path to the exported Azure Resource Graph results (CSV)
$apiVersion = "2023-06-20-preview"

Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null 
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Remove the breaking change warning messages

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true | Out-Null
Update-AzConfig -DisplayBreakingChangeWarning $false | Out-Null
$warningPreference = "SilentlyContinue"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 2 minutes to complete" + $writeSeperatorSpaces + $currentTime + $writeEmptyLine)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Unlink ESU licenses for each server in the CSV file

$servers = Import-Csv -Path $csvPath

foreach ($server in $servers) {
    $path = "/subscriptions/$($server.subscriptionId)/resourceGroups/$($server.resourceGroup)" +
            "/providers/Microsoft.HybridCompute/machines/$($server.machineName)" +
            "/licenseProfiles/default?api-version=$apiVersion"

    $payload = @{
        location   = $server.location
        properties = @{
            esuProfile = @{}
        }
    } | ConvertTo-Json -Depth 5

    $result = Invoke-AzRestMethod -Method PUT -Path $path -Payload $payload

    Write-Host "$($server.machineName): HTTP $($result.StatusCode)"
}

Write-Host ($writeEmptyLine + "# Unlinking ESU licenses" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
