<#
.SYNOPSIS

A script used to remove an ESU license by using the Azure Arc WS2012 ESU ARM APIs.

.DESCRIPTION

A script used to remove an ESU license by using the Azure Arc WS2012 ESU ARM APIs.
This script will do all of the following:

Remove the breaking change warning messages.
Change the current context to the specified Azure subscription.
Delete the ESU license.

.NOTES

Filename:       Remove-ESU-license-using-Azure-Arc-WS2012-ESU-ARM-APIs.ps1
Created:        18/10/2023
Last modified:  18/10/2023
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v10.4.1)
Action:         Change variables were needed to fit your needs. 
Disclaimer:     This script is provided "as is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "<xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx>" (if not using the default tenant)
Set-AzContext -Subscription "<SubscriptionName>" (if not using the default subscription)
.\Remove-ESU-license-using-Azure-Arc-WS2012-ESU-ARM-APIs -SubscriptionName <"your Azure subscription name here"> -EsuLicenseName <"your ESU license name here">

.LINK

https://wmatthyssen.com/2023/10/20/azure-arc-remove-an-extended-security-license-with-an-azure-powershell-script/
#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    # $subscriptionName -> Name of the Azure Subscription
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $subscriptionName,
    # $esuLicenseName -> Name of the ESU license
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $esuLicenseName
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$region = #<your region here> The used Azure public region. Example: "westeurope"

$rgNameArcManagement = #<your Azure Arc management resource group name here> The name of the Azure resource group in which your Azure Arc managment resources are deployed. Example: "rg-prd-myh-arc-management-01"

Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null 
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Remove the breaking change warning messages

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true | Out-Null
Update-AzConfig -DisplayBreakingChangeWarning $false | Out-Null
$warningPreference = "SilentlyContinue"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 1 minute to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to the specified subscription

$subName = Get-AzSubscription | Where-Object {$_.Name -like $subscriptionName}

Set-AzContext -SubscriptionId $subName.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Specified subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Delete the ESU license

# Construct the URI for the Azure resource to be deleted
$URI = "https://management.azure.com/subscriptions/" + $subName.SubscriptionId + "/resourceGroups/" + $rgNameArcManagement + "/providers/Microsoft.HybridCompute/licenses/" + $esuLicenseName + "?api-version=2023-06-20-preview"

# Get the Azure access token and store it in a variable
$accessToken = (Get-AzAccessToken -ResourceUrl https://management.azure.com).Token

# Prepare headers for the API request
$headers = [ordered]@{"Content-Type"="application/json"; "Authorization"="Bearer $accessToken"} 

# Specify the HTTP method for the request (in this case, DELETE)
$method = "DELETE" 

# Define the JSON body for the request (replace $region with the actual region value in the variables section)
$body = '{"location": $region}'

# Set the security protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 

# Send the HTTP request to the specified URI with the provided method, headers, and body
$response = Invoke-WebRequest -URI $URI -Method $method -Headers $headers -Body $body

Write-Host ($writeEmptyLine + "# ESU license $esuLicenseName deleted" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
