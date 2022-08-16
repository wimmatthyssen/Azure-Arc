<#
.SYNOPSIS

A script used to configure prerequisites for Azure Arc.

.DESCRIPTION

A script used to configure prerequisites for Azure Arc.
This script will do all of the following:

Check if the PowerShell window is running as Administrator (which is a requirement), otherwise the Azure PowerShell script will be exited.
Suppress breaking change warning messages.
Change the current context to use an arc production subscription.
Store a specified set of tags in a hash table.
Create a resource group for Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock.
Create a resource group for SQL Server on Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled Kubernetes, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-based VM operations on your Azure Stack HCI, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled VMware vSphere, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled SCVMM, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled PostgreSQL Hyperscale server, if it not already exists. Add specified tags and a resource lock.
Create a resource group for Azure Arc-enabled SQL managed instance, if it not already exists. Add specified tags and a resource lock.
Register required Azure resource providers for Azure Arc-enabled servers, if not already registered. Registration may take up to 10 minutes.
Register required Azure resource providers for Azure Arc-enabled data services, if not already registered. Registration may take up to 10 minutes.
Register required Azure resource providers for Azure Arc-enabled Kubernetes, if not already registered. Registration may take up to 10 minutes.
Save the Log Analytics workspace from the management subscription in a variable.
Add the SQLAssessment solution, if it is not already added (required for the Environment Health feature in SQL Server on Azure Arc-enabled servers). 
Add the ContainerInsights solution, if it is not already added.
It can take up to 4 hours before any data will be available.

.NOTES

Filename:       Configure-AzureArc-Prerequisites.ps1
Created:        03/06/2022
Last modified:  16/08/2022
Author:         Wim Matthyssen
Version:        1.2
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v7.4.0) Module
Action:         Change variables were needed to fit your needs. 
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

Connect-AzAccount
.\Configure-AzureArc-Prerequisites.ps1

.LINK

https://wmatthyssen.com/2022/06/03/azure-arc-azure-powershell-prerequisites-configuration-script/
#>


## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$spoke = "prd"
$purpose = "arc"
$region = #<your region here> The used Azure public region. Example: "westeurope"

$rgArcServersName = #<your resource group name for Azure Arc-enabled servers> The Azure resource group name used for for Azure Arc-enabled servers. Example: "rg-prd-myh-arc-srv-01"
$rgArcSqlServersName = #<your resource group name for SQL Server on Azure Arc-enabled servers> The Azure resource group name used for SQL Server Azure Arc-enabled servers. Example: "rg-prd-myh-arc-sql-01" 
$rgArcKubernetesName = #<your resource group name for Azure Arc-enabled Kubernetes> The Azure resource group name used for Azure Arc-enabled Kubernetes. Example: "rg-prd-myh-arc-k8s-01"
$rgArcHciName = #<your resource group name for Azure Arc-based VM operations on your Azure Stack HCI> The Azure resource group name used for Azure Arc-based VM operations on your Azure Stack HCI. Example: "rg-prd-myh-arc-hci-01"
$rgArcVSphereName = #<your resource group name for Azure Arc-enabled VMware vSphere> The Azure resource group name used for for Azure Arc-enabled VMware vSphere. Example: "rg-prd-myh-arc-vsphere-01"
$rgArcScvmmName = #<your resource group name for Azure Arc-enabled SCVMM> The Azure resource group name used for for Azure Arc-enabled VMware SCVMM. Example: "rg-prd-myh-arc-scvmm-01"
$rgArcPostgreSqlName = #<your resource group name for Azure Arc-enabled PostgreSQL Hyperscale server> The Azure resource group name used for for Azure Arc-enabled PostgreSQL Hyperscale server. Example: "rg-prd-myh-arc-psql-01"
$rgArcSqlManagedInstanceName = #<your resource group name for Azure Arc-enabled SQL managed instance> The Azure resource group name used for for Azure Arc-enabled SQL managed instance. Example: "rg-prd-myh-arc-sqlmi-01"

$logAnalyticsWorkSpaceName = #<your Log Analytics Worspace name here> The name of your existing Log Analytics workspace. Example: "law-hub-myh-01"
$logAnalyticsSolutionSQLAssessment = "SQLAssessment"
$logAnalyticsSolutionContainers = "ContainerInsights"

$tagSpokeName = #<your environment tag name here> The environment tag name you want to use. Example:"Env"
$tagSpokeValue = "$($spoke[0].ToString().ToUpper())$($spoke.SubString(1))"
$tagCostCenterName  = #<your costCenter tag name here> The costCenter tag name you want to use. Example:"CostCenter"
$tagCostCenterValue = #<your costCenter tag value here> The costCenter tag value you want to use. Example: "23"
$tagCriticalityName = #<your businessCriticality tag name here> The businessCriticality tag name you want to use. Example:"Criticality"
$tagCriticalityValue = #<your businessCriticality tag value here> The businessCriticality tag value you want to use. Example: "High"
$tagPurposeName  = #<your purpose tag name here> The purpose tag name you want to use. Example:"Purpose"
$tagPurposeValue = "$($purpose[0].ToString().ToUpper())$($purpose.SubString(1))" 

$global:currenttime= Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime= Get-Date -UFormat "%A %m/%d/%Y %R"}
$foregroundColor1 = "Red"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Check if PowerShell runs as Administrator (when not running from Cloud Shell), otherwise exit the script

if ($PSVersionTable.Platform -eq "Unix") {
    Write-Host ($writeEmptyLine + "# Running in Cloud Shell" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine
    
    ## Start script execution    
    Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 2 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor1 $writeEmptyLine 
} else {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        ## Check if running as Administrator, otherwise exit the script
        if ($isAdministrator -eq $false) {
        Write-Host ($writeEmptyLine + "# Please run PowerShell as Administrator" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor1 $writeEmptyLine
        Start-Sleep -s 3
        exit
        }
        else {

        ## If running as Administrator, start script execution    
        Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 2 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor1 $writeEmptyLine 
        }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Suppress breaking change warning messages

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to use an arc production subscription

$subNamePrd = Get-AzSubscription | Where-Object {$_.Name -like "*arc*"}
$tenant = Get-AzTenant | Where-Object {$_.Name -like "*$companyShortName*"}

Set-AzContext -TenantId $tenant.TenantId -SubscriptionId $subNamePrd.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Arc production subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Store the specified set of tags in a hash table

$tags = @{$tagSpokeName=$tagSpokeValue;$tagCostCenterName=$tagCostCenterValue;$tagCriticalityName=$tagCriticalityValue;$tagPurposeName=$tagPurposeValue}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcServersName -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcServersName.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcServersName -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcServersName

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcServersName -LockNotes "Prevent $rgArcServersName from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcServersName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for SQL Server on Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcSqlServersName -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcSqlServersName.ToLower() -Location $region -Force | Out-Null
}

# Set tags SQL Server on Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcSqlServersName -Tag $tags | Out-Null

# Lock the SQL Server on Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcSqlServersName

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcSqlServersName -LockNotes "Prevent $rgArcSqlServersName from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcSqlServersName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

### ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled Kubernetes, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcKubernetesName -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcKubernetesName.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled Kubernetes resource group
Set-AzResourceGroup -Name $rgArcKubernetesName -Tag $tags | Out-Null

# Lock the Azure Arc-enabled Kubernetes resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcKubernetesName

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcKubernetesName -LockNotes "Prevent $rgArcKubernetesName from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcKubernetesName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

### ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-based VM operations on your Azure Stack HCI, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcHciName -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcHciName.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled Kubernetes resource group
Set-AzResourceGroup -Name $rgArcHciName -Tag $tags | Out-Null

# Lock the resource group for Azure Arc-based VM operations on your Azure Stack HCI with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcHciName

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcHciName -LockNotes "Prevent $rgArcHciName from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcHciName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled VMware vSphere (preview), if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcVSphereName -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcVSphereName.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcVSphereName -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcVSphereName 

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcVSphereName -LockNotes "Prevent $rgArcVSphereName from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcVSphereName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled SCVMM (preview), if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcScvmmName -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcScvmmName.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcScvmmName -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcScvmmName

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcScvmmName -LockNotes "Prevent $rgArcScvmmName from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcScvmmName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group Azure Arc-enabled PostgreSQL Hyperscale (preview), if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcPostgreSqlName -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcPostgreSqlName.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcPostgreSqlName -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcPostgreSqlName

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcPostgreSqlName -LockNotes "Prevent $rgArcPostgreSqlName from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcPostgreSqlName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group Azure Arc-enabled SQL managed instance, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcSqlManagedInstanceName -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcSqlManagedInstanceName.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcSqlManagedInstanceName -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcPostgreSqlName

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcSqlManagedInstanceName -LockNotes "Prevent $rgArcSqlManagedInstanceName from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcSqlManagedInstanceName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled servers, if not already registered. Registration may take up to 10 minutes

# Register Microsoft.HybridCompute resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute  | Out-Null

# Register Microsoft.HybridConnectivity resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity  | Out-Null

# Register Microsoft.GuestConfiguration resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration  | Out-Null

Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled servers are currently registering or already registerd" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled data services, if not already registered. Registration may take up to 10 minutes

# Register Microsoft.AzureArcData resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.AzureArcData  | Out-Null

Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled data services are currently registering or already registerd" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled Kubernetes, if not already registered. Registration may take up to 10 minutes

# Register Microsoft.Kubernetes resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes | Out-Null

# Register Microsoft.KubernetesConfiguration resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration | Out-Null

# Register Microsoft.ExtendedLocation resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.ExtendedLocation | Out-Null

Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled Kubernetes are currently registering or already registerd" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Add all Arc related solutions, if they are not already added. It can take up to 4 hours before any data will be available

# Select management subscription. Adjust to your needs if you are using another subscription for your Log Analytics workspace, otherwise delete this part!
$subNameManagement = Get-AzSubscription | Where-Object {$_.Name -like "*management*"}
$tenant = Get-AzTenant | Where-Object {$_.Name -like "*$companyShortName*"}
Set-AzContext -TenantId $tenant.TenantId -SubscriptionId $subNameManagement.SubscriptionId | Out-Null

# Save Log Analytics workspace in a variable
$workSpace = Get-AzOperationalInsightsWorkspace | Where-Object Name -Match $logAnalyticsWorkSpaceName

# Add SQL Assessment solution (required for the Environment Health feature in SQL Server on Azure Arc-enabled servers)
try {
    Get-AzMonitorLogAnalyticsSolution -Name $logAnalyticsSolutionSQLAssessment -ResourceGroupName $workSpace.ResourceGroupName `
    -SubscriptionId $subNameManagement.SubscriptionId -ErrorAction Stop | Out-Null
} catch {
    New-AzMonitorLogAnalyticsSolution -Type $logAnalyticsSolutionSQLAssessment -ResourceGroupName $workSpace.ResourceGroupName `
    -Location $workspace.Location -WorkspaceResourceId $workspace.ResourceId | Out-Null
}

# Add Container Monitoring solution
try {
    Get-AzMonitorLogAnalyticsSolution -Name $logAnalyticsSolutionContainers -ResourceGroupName $workSpace.ResourceGroupName `
    -SubscriptionId $subNameManagement.SubscriptionId -ErrorAction Stop | Out-Null
} catch {
    New-AzMonitorLogAnalyticsSolution -Type $logAnalyticsSolutionContainers -ResourceGroupName $workSpace.ResourceGroupName `
    -Location $workspace.Location -WorkspaceResourceId $workspace.ResourceId | Out-Null
}

Write-Host ($writeEmptyLine + "# All Arc related solutions added" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed, but keep in mind resource provider registration can take up to 10 minutes" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
