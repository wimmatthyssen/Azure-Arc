<#
.SYNOPSIS

A script used to configure prerequisites for Azure Arc.

.DESCRIPTION

A script used to configure prerequisites for Azure Arc.
This script will do all of the following:

Check if the PowerShell window is running as Administrator (which is a requirement), otherwise the Azure PowerShell script will be exited.
Suppress breaking change warning messages.
Install Azure Arc related PowerShell modules.
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
Last modified:  03/06/2022
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure Cloud Shell or Azure PowerShell
Requires:       PowerShell Az (v7.4.0) Module
Action:         Change variables were needed to fit your needs. 
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

Connect-AzAccount
.\Configure-AzureArc-Prerequisites.ps1

.LINK


#>


## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$spoke = "prd"
$purpose = "arc"
$region = #<your region here> The used Azure public region. Example: "westeurope"

$rgArcServers = #<your resource group name for Azure Arc-enabled servers> The Azure resource group used for for Azure Arc-enabled servers. Example: "rg-prd-myh-arc-srv-01"
$rgArcSqlServers = #<your resource group name for SQL Server on Azure Arc-enabled servers> The Azure resource group used for SQL Server Azure Arc-enabled servers. Example: "rg-prd-myh-arc-sql-01" 
$rgArcKubernetes = #<your resource group name for Azure Arc-enabled Kubernetes> The Azure resource group used for Azure Arc-enabled Kubernetes. Example: "rg-prd-myh-arc-k8s-01"
$rgArcHci = #<your resource group name for Azure Arc-based VM operations on your Azure Stack HCI> The Azure resource group used for Azure Arc-based VM operations on your Azure Stack HCI. Example: "rg-prd-myh-arc-hci-01"
$rgArcVSphere = #<your resource group name for Azure Arc-enabled VMware vSphere> The Azure resource group used for for Azure Arc-enabled VMware vSphere. Example: "rg-prd-myh-arc-vsphere-01"
$rgArcScvmm = #<your resource group name for Azure Arc-enabled SCVMM> The Azure resource group used for for Azure Arc-enabled VMware SCVMM. Example: "rg-prd-myh-arc-scvmm-01"
$rgArcPostgreSql = #<your resource group name for Azure Arc-enabled PostgreSQL Hyperscale server> The Azure resource group used for for Azure Arc-enabled PostgreSQL Hyperscale server. Example: "rg-prd-myh-arc-psql-01"
$rgArcSqlManagedInstance = #<your resource group name for Azure Arc-enabled SQL managed instance> The Azure resource group used for for Azure Arc-enabled SQL managed instance. Example: "rg-prd-myh-arc-sqlmi-01"

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
    Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 10 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
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
        Write-Host ($writeEmptyLine + "# Script started. Without any errors, it will need around 10 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
        -foregroundcolor $foregroundColor1 $writeEmptyLine 
        }
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Suppress breaking change warning messages

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Install Azure Arc related PowerShell modules

#Install Az.ConnectedMachine module, which is required to manage VM extensions on your hybrid servers managed by Azure Arc-enabled servers
Install-Module -Name $powerShellModuleArcServers -Force

#Install AzureConnectedMachineDsc module, which is required to install the Connected Machine agent using Windows PowerShell DSC
Install-Module -Name $powerShellModuleArcServersDsc -Force

Write-Host ($writeEmptyLine + "# All Azure Arc related PowerShell modules are installed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Store the specified set of tags in a hash table

$tags = @{$tagSpokeName=$tagSpokeValue;$tagCostCenterName=$tagCostCenterValue;$tagCriticalityName=$tagCriticalityValue;$tagPurposeName=$tagPurposeValue}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Store the specified set of tags in a hash table

$tags = @{$tagSpokeName=$tagSpokeValue;$tagCostCenterName=$tagCostCenterValue;$tagCriticalityName=$tagCriticalityValue;$tagPurposeName=$tagPurposeValue}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcServers -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcServers.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcServers -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcServers

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcServers -LockNotes "Prevent $rgArcServers from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcServers available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for SQL Server on Azure Arc-enabled servers, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcSqlServers -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcSqlServers.ToLower() -Location $region -Force | Out-Null
}

# Set tags SQL Server on Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcSqlServers -Tag $tags | Out-Null

# Lock the SQL Server on Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcSqlServers

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcSqlServers -LockNotes "Prevent $rgArcSqlServers from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcSqlServers available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

### ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled Kubernetes, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcKubernetes -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcKubernetes.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled Kubernetes resource group
Set-AzResourceGroup -Name $rgArcKubernetes -Tag $tags | Out-Null

# Lock the Azure Arc-enabled Kubernetes resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcKubernetes

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcKubernetes -LockNotes "Prevent $rgArcKubernetes from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcKubernetes available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

### ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-based VM operations on your Azure Stack HCI, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcHci -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcHci.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled Kubernetes resource group
Set-AzResourceGroup -Name $rgArcHci -Tag $tags | Out-Null

# Lock the resource group for Azure Arc-based VM operations on your Azure Stack HCI with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcHci

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcHci -LockNotes "Prevent $rgArcHci from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcHci available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled VMware vSphere (preview), if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcVSphere -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcVSphere.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcVSphere -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcVSphere 

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcVSphere -LockNotes "Prevent $rgArcVSphere from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcVSphere available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc-enabled SCVMM (preview), if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcScvmm -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcScvmm.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcScvmm -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcScvmm

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcScvmm -LockNotes "Prevent $rgArcScvmm from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcScvmm available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group Azure Arc-enabled PostgreSQL Hyperscale (preview), if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcPostgreSql -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcPostgreSql.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcPostgreSql -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcPostgreSql

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcPostgreSql -LockNotes "Prevent $rgArcPostgreSql from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcPostgreSql available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group Azure Arc-enabled SQL managed instance, if it not already exists. Add specified tags and a resource lock

try {
    Get-AzResourceGroup -Name $rgArcSqlManagedInstance -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgArcSqlManagedInstance.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgArcSqlManagedInstance -Tag $tags | Out-Null

# Lock the Azure Arc-enabled servers resource group with a CanNotDelete lock
$lock = Get-AzResourceLock -ResourceGroupName $rgArcPostgreSql

if ($null -eq $lock){
    New-AzResourceLock -LockName DoNotDeleteLock -LockLevel CanNotDelete -ResourceGroupName $rgArcSqlManagedInstance -LockNotes "Prevent $rgArcSqlManagedInstance from deletion" -Force | Out-Null
    } 

Write-Host ($writeEmptyLine + "# Resource group $rgArcSqlManagedInstance available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled servers, if not already registered. Registration may take up to 10 minutes

# Register Microsoft.HybridCompute resource provider

Get-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute | Where-Object {$_.RegistrationState -eq "NotRegistered"} | Register-AzResourceProvider | Out-Null

# Register Microsoft.HybridConnectivity resource provider

Get-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity | Where-Object {$_.RegistrationState -eq "NotRegistered"} | Register-AzResourceProvider | Out-Null

# Register Microsoft.GuestConfiguration resource provider

Get-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration | Where-Object {$_.RegistrationState -eq "NotRegistered"} | Register-AzResourceProvider | Out-Null

Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled servers are currently registering or already registerd" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled data services, if not already registered. Registration may take up to 10 minutes

# Register Microsoft.AzureArcData resource provider

Get-AzResourceProvider -ProviderNamespace Microsoft.AzureArcData | Where-Object {$_.RegistrationState -eq "NotRegistered"} | Register-AzResourceProvider | Out-Null

Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled data services are currently registering or already registerd" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Register required Azure resource providers for Azure Arc-enabled Kubernetes, if not already registered. Registration may take up to 10 minutes

# Register Microsoft.Kubernetes resource provider

Get-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes | Where-Object {$_.RegistrationState -eq "NotRegistered"} | Register-AzResourceProvider | Out-Null

# Register Microsoft.KubernetesConfiguration resource provider

Get-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration | Where-Object {$_.RegistrationState -eq "NotRegistered"} | Register-AzResourceProvider | Out-Null

# Register Microsoft.ExtendedLocation resource provider

Get-AzResourceProvider -ProviderNamespace Microsoft.ExtendedLocation | Where-Object {$_.RegistrationState -eq "NotRegistered"} | Register-AzResourceProvider | Out-Null

Write-Host ($writeEmptyLine + "# All required resource providers for Azure Arc-enabled Kubernetes are currently registering or already registerd" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Add all Arc related solutions, if they are not already added. It can take up to 4 hours before any data will be available

# Select management subscription. Adjust to your needs if you are using another subscription for your Log Analytics workspace, otherwise delete this part!
$companyShortName = #<your company short name here> The company short name you want to use. Example:"myh"
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

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
