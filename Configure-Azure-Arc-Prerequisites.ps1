<#
.SYNOPSIS

A script used to configure prerequisites for Azure Arc.

.DESCRIPTION

A script used to configure prerequisites for Azure Arc.
This script will do all of the following:

Remove the breaking change warning messages.
Change the current context to the specified subscription.
Store a specified set of tags in a hash table.
Create a resource group for Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled Kubernetes, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-based VM operations on your Azure Local, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled VMware vSphere, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled SCVMM, if it not already exists. Add specified tags and a resource lock.
Create a resource group for SQL Server on Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock.
Create a resource group for SQL Managed Instance enabled by Azure Arc, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled PostgreSQL (preview), if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc data controller, if it not already exists. Add specified tags and a resource lock.
Register required Azure resource providers for Azure Arc-enabled servers, if not already registered. Registration may take up to 10 minutes.
Register required Azure resource providers for Azure Arc-enabled Kubernetes, if not already registered. Registration may take up to 10 minutes.
Register required Azure resource providers for Azure Arc-enabled data services, if not already registered. Registration may take up to 10 minutes.

.NOTES

Filename:       Configure-Azure-Arc-Prerequisites.ps1
Created:        03/06/2022
Last modified:  10/03/2025
Author:         Wim Matthyssen
Version:        1.5
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v10.4.1)
Action:         Change variables were needed to fit your needs.
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx" (if not using the default tenant)
.\Configure-Azure-Arc-Prerequisites.ps1 -SubscriptionName <"your Azure subscription name here">

Example: .\Configure-Azure-Arc-Prerequisites.ps1 -SubscriptionName "sub-prd-myh-arc-infra-03"

.LINK

https://wmatthyssen.com/2022/06/03/azure-arc-azure-powershell-prerequisites-configuration-script/
#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    # $subscriptionName -> Name of the Azure Subscription
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $subscriptionName
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

# Naming convention: example - rg-prd-myh-arc-srv-01 (resource type - spoke - company - purpose - arctype - inventory number)

# Dynamic variables - Please change the values to if required.
$spoke = "prd" # Abbreviation for the spoke (e.g., 'prd' for production, 'dev' for development). Change based on your environment.
$companyShortName = "myh" # Abbreviation for your company or organization (e.g., 'myh' for myhcjourney). Replace with your company's short name.
$purpose = "arc" # Specifies the intended use of the resource group or service (e.g., 'arc' for Azure Arc). Update if different.

# Abbreviations for different resource types
$serverAbbreviation = "srv" # Abbreviation for a server. Change as per your naming convention.
$kubernetesAbbreviation = "k8s" # Abbreviation for Kubernetes. Change as per your naming convention.
$azureLocalAbbreviation = "azl" # Abbreviation for Azure Local. Change as per your naming convention.
$vSphereAbbreviation = "vsphere" # Abbreviation for VMware vSphere. Change as per your naming convention.
$scvmmAbbreviation = "scvmm" # Abbreviation for SCVMM. Change as per your naming convention.
$sqlAbbreviation = "sql" # Abbreviation for SQL Server. Change as per your naming convention.
$sqlManagedInstanceAbbreviation = "sqlmi" # Abbreviation for SQL Managed Instance. Change as per your naming convention.
$postgrSqlabbreviation = "psql" # Abbreviation for PostgreSQL Hyperscale. Change as per your naming convention.
$dataControllersAbbreviation = "adc" # Abbreviation for Data Controllers. Change as per your naming convention.

# Other Configuration Variables
$inventoryNumbering = 1 # Inventory number for the resource (e.g., 1, 2, 3, etc. to differentiate resources).
$region = "westeurope" # Azure region (e.g., 'westeurope', 'eastus'). Replace with your current region if needed.

# Resource groups Arc resources
$rgNameArcServers = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $serverAbbreviation + "-" + $inventoryNumbering.ToString("D2")
$rgNameArcKubernetes = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $kubernetesAbbreviation + "-" + $inventoryNumbering.ToString("D2")

# Resource groups Host environments
$rgNameArcAzureLocal = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $azureLocalAbbreviation + "-" + $inventoryNumbering.ToString("D2")
$rgNameArcVSphere = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $vSphereAbbreviation + "-" + $inventoryNumbering.ToString("D2")
$rgNameArcScvmm = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $scvmmAbbreviation + "-" + $inventoryNumbering.ToString("D2")

# Resource groups Data services
$rgNameArcSqlServers = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $sqlAbbreviation + "-" + $inventoryNumbering.ToString("D2")
$rgNameArcSqlManagedInstance = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $sqlManagedInstanceAbbreviation + "-" + $inventoryNumbering.ToString("D2")
$rgNameArcPostgreSql = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $postgrSqlabbreviation + "-" + $inventoryNumbering.ToString("D2") 
$rgnameArcDataControllers = "rg" + "-" + $spoke + "-" + $companyShortName + "-" + $purpose + "-" + $dataControllersAbbreviation + "-" + $inventoryNumbering.ToString("D2")

# Tags
$tagSpokeName = "Env" # The environment tag name you want to use.
$tagSpokeValue = "$($spoke[0].ToString().ToUpper())$($spoke.SubString(1))"
$tagCostCenterName  = "CostCenter" # The costCenter tag name you want to use.
$tagCostCenterValue = "23" # The costCenter tag value you want to use.
$tagCriticalityName  = "Criticality" # The businessCriticality tag name you want to use.
$tagCriticalityValue = "High" # The businessCriticality tag value you want to use.
$tagPurposeName  = "Purpose" # The purpose tag name you want to use.    
$tagPurposeValue = "$($purpose[0].ToString().ToUpper())$($purpose.SubString(1))"

# Other variables
Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null $foregroundColor1 = "Red"
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

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 2 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to the specified subscription

$subName = Get-AzSubscription | Where-Object {$_.Name -like $subscriptionName}

Set-AzContext -SubscriptionId $subName.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Specified subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Store the specified set of tags in a hash table

$tags = @{$tagSpokeName=$tagSpokeValue;$tagCostCenterName=$tagCostCenterValue;$tagCriticalityName=$tagCriticalityValue;$tagPurposeName=$tagPurposeValue}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgNameArcServers -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcServers.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgNameArcServers -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgNameArcServers

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameArcServers -LockNotes "Prevent $rgNameArcServers from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcServers available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled Kubernetes, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgNameArcKubernetes -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcKubernetes.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled Kubernetes resource group
Set-AzResourceGroup -Name $rgNameArcKubernetes -Tag $tags | Out-Null

# Lock the Azure Arc-enabled Kubernetes resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgNameArcKubernetes

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameArcKubernetes -LockNotes "Prevent $rgNameArcKubernetes from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcKubernetes available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-based VM operations on your Azure Local, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgNameArcAzureLocal -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcAzureLocal.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Azure Arc-based VM operations on your Azure Local resource group
Set-AzResourceGroup -Name $rgNameArcAzureLocal -Tag $tags | Out-Null

# Lock the resource group for Azure Arc-based VM operations on your Azure Local with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgNameArcAzureLocal

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameArcAzureLocal -LockNotes "Prevent $rgNameArcAzureLocal from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcAzureLocal available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled VMware vSphere, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgNameArcVSphere -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcVSphere.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled VMware vSphere resource group
Set-AzResourceGroup -Name $rgNameArcVSphere -Tag $tags | Out-Null

# Lock the Azure Azure Arc-enabled VMware vSphere resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgNameArcVSphere 

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameArcVSphere -LockNotes "Prevent $rgNameArcVSphere from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcVSphere available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled SCVMM, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgNameArcScvmm -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcScvmm.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled SCVMM resource group
Set-AzResourceGroup -Name $rgNameArcScvmm -Tag $tags | Out-Null

# Lock the Azure Arc-enabled SCVMM resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgNameArcScvmm

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameArcScvmm -LockNotes "Prevent $rgNameArcScvmm from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcScvmm available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for SQL Server on Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgNameArcSqlServers -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcSqlServers.ToLower() -Location $region -Force | Out-Null
}

# Set tags SQL Server on Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgNameArcSqlServers -Tag $tags | Out-Null

# Lock the SQL Server on Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgNameArcSqlServers

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameArcSqlServers -LockNotes "Prevent $rgNameArcSqlServers from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcSqlServers available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for SQL Managed Instance enabled by Azure Arc, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgNameArcSqlManagedInstance -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcSqlManagedInstance.ToLower() -Location $region -Force | Out-Null
}

# Set tags SQL Managed Instance enabled by Azure Arc resource group
Set-AzResourceGroup -Name $rgNameArcSqlManagedInstance -Tag $tags | Out-Null

# Lock the SQL Managed Instance enabled by Azure Arc resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgNameArcPostgreSql

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameArcSqlManagedInstance -LockNotes "Prevent $rgNameArcSqlManagedInstance from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcSqlManagedInstance available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled PostgreSQL (preview), if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgNameArcPostgreSql -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcPostgreSql.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled PostgreSQL Hyperscale (preview) resource group
Set-AzResourceGroup -Name $rgNameArcPostgreSql -Tag $tags | Out-Null

# Lock the Azure Arc-enabled PostgreSQL Hyperscale (preview) resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgNameArcPostgreSql

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgNameArcPostgreSql -LockNotes "Prevent $rgNameArcPostgreSql from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcPostgreSql available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc data controller, if it not already exists. Add specified tags and a resource lock.

try {
    Get-AzResourceGroup -Name $rgnameArcDataControllers -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgnameArcDataControllers.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled Data controllers resource group
Set-AzResourceGroup -Name $rgnameArcDataControllers -Tag $tags | Out-Null

# Lock the Azure Arc-enabled Data controllers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgnameArcDataControllers

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgnameArcDataControllers -LockNotes "Prevent $rgnameArcDataControllers from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgnameArcDataControllers available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled servers, if not already registered. Registration may take up to 10 minutes

try {
    # Register Microsoft.HybridCompute resource provider
    Register-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute  | Out-Null

    # Register Microsoft.HybridConnectivity resource provider
    Register-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity  | Out-Null

    # Register Microsoft.GuestConfiguration resource provider
    Register-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration  | Out-Null

    Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled servers are currently registering or already registered" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
} catch {
    Write-Host ($writeEmptyLine + "# Error registering resource providers for Azure Arc-enabled servers: $_" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled Kubernetes, if not already registered. Registration may take up to 10 minutes

try {
    # Register Microsoft.Kubernetes resource provider
    Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes | Out-Null

    # Register Microsoft.KubernetesConfiguration resource provider
    Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration | Out-Null

    # Register Microsoft.ExtendedLocation resource provider
    Register-AzResourceProvider -ProviderNamespace Microsoft.ExtendedLocation | Out-Null

    Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled Kubernetes are currently registering or already registered" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
} catch {
    Write-Host ($writeEmptyLine + "# Error registering resource providers for Azure Arc-enabled Kubernetes: $_" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled data services, if not already registered. Registration may take up to 10 minutes

try {
    # Register Microsoft.AzureArcData resource provider
    Register-AzResourceProvider -ProviderNamespace Microsoft.AzureArcData  | Out-Null

    Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled data services are currently registering or already registered" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
} catch {
    Write-Host ($writeEmptyLine + "# Error registering resource providers for Azure Arc-enabled data services: $_" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
