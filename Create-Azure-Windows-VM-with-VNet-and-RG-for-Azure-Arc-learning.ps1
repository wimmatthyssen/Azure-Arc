<#
.SYNOPSIS

A script used to create an Azure Windows VM with a VNet and subnet, specifically for learning and testing with Azure Arc.

.DESCRIPTION

A script used to create an Azure Windows VM with a VNet and subnet, specifically for learning and testing with Azure Arc.
This script will do all of the following:

Suppress Azure PowerShell breaking change warning messages to avoid unnecessary output.
Change the current context to the specified subscription
Store the specified set of tags in a hash table.
Create a resource group for Azure Arc testing purposes, if it not already exists, and apply specified tags.
Create Network Watcher, if it not already exists, and apply specified tags.
Create Subnets, if they not already exist.
Create Virtual Network, if it not already exists, and apply specified tags.
Create the NIC the VM, if it not already exists, and apply specified tags.
Specify the local administrator account.
Get the latest Azure Marketplace VMImage for Windows Server 2022 that match the specified values, and store it in a varialbe for later use.
Create VM 1 if it not already exists, and apply specified tags.
Set tags on all disks in the resource group.

.NOTES

Filename:       Create-Azure-Windows-VM-with-VNet-and-RG-for-Azure-Arc-Learning.ps1
Created:        21/02/2025
Last modified:  21/02/2025
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v10.4.1)
Action:         Change variables were needed to fit your needs.
Disclaimer:     This script is provided "As Is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx" (if not using the default tenant)
.\Create-Azure-Windows-VM-for-Azure-Arc-learning.ps1 -SubscriptionName <"your Azure subscription name here"> -vmSize <"your VM size here">

Example 1: .\Create-Azure-Windows-VM-with-VNet-and-RG-for-Azure-Arc-Learning.ps1 -SubscriptionName "sub-tst-myh-sandbox-01" 
Example 2: .\Create-Azure-Windows-VM-with-VNet-and-RG-for-Azure-Arc-Learning.ps1 -SubscriptionName "sub-tst-myh-sandbox-01" -vmSize "Standard__D2s_v3"

.LINK


#>

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    # $subscriptionName -> Name of the Azure Subscription
    [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $subscriptionName,
    # $vmSize -> Specifies the VM size.
    [parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string] $vmSize = "Standard_B2ms"
)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

# Naming convention: example - rg-tst-arc-01 (resource type - spoke - purpose - inventory number)

# Dynamic variables - Please change the values to if required.
$spoke = "tst" # Abbreviation for the spoke (e.g., 'tst' for test, 'poc' for proof of concept). Change based on your environment.
$purpose = "arc" # Specifies the intended use of the resource group or service (e.g., 'arc' for Azure Arc). Update if different.
$addressPrefix = "10.23.1." # Address prefix for the virtual network subnets. Update if different.

# Other Configuration Variables
$inventoryNumbering = 1 # Inventory number for the resource (e.g., 1, 2, 3, etc. to differentiate resources).
$region = "westeurope" # Azure region (e.g., 'westeurope', 'eastus'). Replace with your current region if needed.
$regionShort = "we" # Short abbreviation for the Azure region (e.g., 'we' for West Europe, 'eus' for East US). Update if different.

# Resource groups Arc resources
$rgNameArcTst = "rg" + "-" + $spoke + "-" + $purpose + "-" + $inventoryNumbering.ToString("D2")

# Networking resources
$networkWatcherName = "nw" + "-" + $spoke + "-" + $regionShort + "-" + $inventoryNumbering.ToString("D2")
$vnetName = "vnet" + "-" + $spoke + "-" + $regionShort + "-" + $inventoryNumbering.ToString("D2")
$subnetNameGateway = "GatewaySubnet"
$subnetNameAzureBastion = "AzureBastionSubnet"
$subnetNameVm = "snet" + "-" + $spoke + "-" + "vm" + "-" + $inventoryNumbering.ToString("D2")
$subnetAddressPrefixGateway = $addressPrefix + "0/26" 
$subnetAddressPrefixAzureBastion = $addressPrefix + "64/26"
$subnetAddressPrefixVm = $addressPrefix + "128/26"
$vnetAddressPrefix = $addressPrefix + "0/24"

# VM resources
$vmName01 = "swt" + $purpose + $inventoryNumbering.ToString("D3")  # Specifies theVM name. Update if different.
$userName = "loc_arc" # Specifies the username for the VM. Update if different.
$password = "ArcF@lcon_7632" # Specifies the password for the VM. Update if different.
$osSKU01 = "2022-Datacenter" # Specifies the OS SKU for the VM. Update if different.
$osDiskNameVM01 = $vmName01 + "-" + "c" # Specifies the OS disk name for the VM. Update if different.
$osDiskSizeInGB = "127" # Specifies the OS disk size in GB. Update if different.
$diskStorageAccountType = "StandardSSD_LRS" # Premium_LRS = Premium SSD; StandardSSD_LRS = Standard SSD; Standard_LRS = Standard HHD
$nicNameVM01 = "nic" + "-" + "01" + "-" +  $vmName01 # Specifies the NIC name for the VM. Update if different.

# Tags
$tagSpokeName = "Env" # The environment tag name you want to use.
$tagSpokeValue = "$($spoke[0].ToString().ToUpper())$($spoke.SubString(1))"
$tagOSVersionName = "OperatingSystem" # The operating system tag name you want to use.

# Other variables
Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$foregroundColor3 = "Red"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Suppress Azure PowerShell breaking change warning messages to avoid unnecessary output.

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true | Out-Null
Update-AzConfig -DisplayBreakingChangeWarning $false | Out-Null
Update-AzConfig -DisplayRegionIdentified $false | Out-Null
$warningPreference = "SilentlyContinue"

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started.

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 4 minutes to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to the specified subscription.

$subName = Get-AzSubscription | Where-Object {$_.Name -like $subscriptionName}

Set-AzContext -SubscriptionId $subName.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Specified subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Store the specified set of tags in a hash table.

$tags = @{$tagSpokeName=$tagSpokeValue}

Write-Host ($writeEmptyLine + "# Specified set of tags available to add" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a resource group for Azure Arc testing purposes, if it not already exists, and apply specified tags.

try {
    Get-AzResourceGroup -Name $rgNameArcTst -ErrorAction Stop | Out-Null
} catch {
    New-AzResourceGroup -Name $rgNameArcTst.ToLower() -Location $region -Force | Out-Null
}

# Set tags Azure Arc-enabled servers resource group
Set-AzResourceGroup -Name $rgNameArcTst -Tag $tags | Out-Null

Write-Host ($writeEmptyLine + "# Resource group $rgNameArcTst available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

##  Create Network Watcher, if it not already exists, and apply specified tags.

try {
    Get-AzNetworkWatcher -Name $networkWatcherName -ResourceGroupName $rgNameArcTst -ErrorAction Stop | Out-Null 
} catch {
    New-AzNetworkWatcher -Name $networkWatcherName -ResourceGroupName $rgNameArcTst -Location $region -Tag $tags | Out-Null
}

Write-Host ($writeEmptyLine + "# Network watcher $rgNameArcTst created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create Subnets, if they not already exist.

$gatewaySubnet = New-AzVirtualNetworkSubnetConfig -Name $subnetNameGateway -AddressPrefix $subnetAddressPrefixGateway 
$azureBastionSubnet = New-AzVirtualNetworkSubnetConfig -Name $subnetNameAzureBastion -AddressPrefix $subnetAddressPrefixAzureBastion
$vmSubnet = New-AzVirtualNetworkSubnetConfig -Name $subnetNameVm -AddressPrefix $subnetAddressPrefixVm

Write-Host ($writeEmptyLine + "# Virtual network subnet configurations $vnetName created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create Virtual Network, if it not already exists, and apply specified tags.

$subnets = $gatewaySubnet,$azureBastionSubnet,$vmSubnet

try {
    Get-AzVirtualNetwork -Name $vnetName -ResourceGroupname $rgNameArcTst -ErrorAction Stop | Out-Null 
} catch {
    New-AzVirtualNetwork -Name $vnetName -ResourceGroupname $rgNameArcTst -Location $region -AddressPrefix $vnetAddressPrefix -Subnet $subnets -Confirm:$false -Force | Out-Null 
}

# Set tags VNet
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupname $rgNameArcTst 
$vnet.Tag = $tags
Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null

Write-Host ($writeEmptyLine + "# VNet $vnetName created and configured" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create the NIC the VM, if it not already exists, and apply specified tags.

# Get the VNet to which to connect the NIC
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupname $rgNameArcTst 

# Get the Subnet ID to which to connect the NIC
$subnetID = (Get-AzVirtualNetworkSubnetConfig -Name $subnetNameVm -VirtualNetwork $vnet).Id

# Create dynamic NIC VM 1
try {
    Get-AzNetworkInterface -ResourceGroupName $rgNameArcTst -Name $nicNameVM01 -ErrorAction Stop | Out-Null 
} catch {
    New-AzNetworkInterface -Name $nicNameVM01.ToLower() -ResourceGroupName $rgNameArcTst  -Location $region -SubnetId $subnetID | Out-Null 
}

# Store NIC VM 1 in a variable 
$nicVM01 = Get-AzNetworkInterface -ResourceGroupName $rgNameArcTst -Name $nicNameVM01

# Set private IP address NIC VM 1 to static
$nicVM01.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
Set-AzNetworkInterface -NetworkInterface $nicVM01 | Out-Null

# Set tags on NIC VM1
$nicVM01.Tag = $tags
Set-AzNetworkInterface -NetworkInterface $nicVM01 | Out-Null

Write-Host ($writeEmptyLine + "# NIC $nicNameVM01 created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Specify the local administrator account.
 
$passwordSec = convertto-securestring $password -asplaintext -force 
$creds = New-Object System.Management.Automation.PSCredential($userName,$passwordSec)

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Get the latest Azure Marketplace VMImage for Windows Server 2022 that is not deprecated

$images01 = Get-AzVMImage -Location $region -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus $osSKU01 |
Where-Object { $_.ReplicationStatus -ne "Deprecated" } |
Sort-Object -Descending -Property PublishedDate

# Check if any valid images are available
if (-not $images01) {
throw "No valid VM images found for the specified OS SKU: $osSKU01. Ensure that non-deprecated images are available."
}

Write-Host ($writeEmptyLine + "# Latest non-deprecated Azure Marketplace VM image selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create VM 1 if it not already exists, and apply specified tags.

Write-Host ($writeEmptyLine + "# Creating VM $vmName01 in resource group $rgNameArcTst" + $writeSeperatorSpaces + $currentTime) -ForegroundColor $foregroundColor2 $writeEmptyLine

try {
    if (-not (Get-AzVM -ResourceGroupName $rgNameArcTst -Name $vmName01 -ErrorAction SilentlyContinue)) {
        # Create a configurable VM object
        $vm01 = New-AzVMConfig -Name $vmName01.ToLower() -VMSize $vmSize

        # Add the NIC
        Add-AzVMNetworkInterface -VM $vm01 -Id $nicVM01.Id | Out-Null    

        # Specify the image
        if (-not $images01) {
            throw "No VM images found for the specified OS SKU: $osSKU01"
        }
        Set-AzVMSourceImage -VM $vm01 -PublisherName $images01[0].PublisherName -Offer $images01[0].Offer -Skus $images01[0].Skus -Version $images01[0].Version | Out-Null 

        # Set OS properties
        Set-AzVMOperatingSystem -VM $vm01 -Windows -ProvisionVMAgent -EnableAutoUpdate -Credential $creds -ComputerName $vmName01 | Out-Null 
        
        # Set OS disk properties
        Set-AzVMOSDisk -VM $vm01 -name $osDiskNameVM01 -CreateOption fromImage -DiskSizeInGB $osDiskSizeInGB -StorageAccountType $diskStorageAccountType -Windows | Out-Null
        
        # Disable boot diagnostics
        $vm01.DiagnosticsProfile = [Microsoft.Azure.Management.Compute.Models.DiagnosticsProfile]@{
            BootDiagnostics = [Microsoft.Azure.Management.Compute.Models.BootDiagnostics]@{
                Enabled = $false
            }
        }

        # Create VM
        New-AzVM -ResourceGroupName $rgNameArcTst -Location $region -VM $vm01 -OSDiskDeleteOption Delete -Confirm:$false | Out-Null
    }
} catch {
    Write-Host "Error creating VM: $_" -ForegroundColor $foregroundColor3
    throw
}

# Set tags on VM1
$vm01 = Get-AzVM -ResourceGroupName $rgNameArcTst -Name $vmName01
Update-AzTag -Tag $tags -ResourceId $vm01.Id -Operation Merge | Out-Null

# Get OS version VM1
$osVersion = $vm01.StorageProfile.ImageReference.Offer + " $($vm01.StorageProfile.ImageReference.Sku)"

# Add OS tag to VM1
$osTag = @{$tagOSVersionName = $osVersion}
Update-AzTag -ResourceId $vm01.Id -Tag $osTag -Operation Merge | Out-Null

Write-Host ($writeEmptyLine + "# VM $vmName01 created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Set tags on all disks in the resource group.

try {
    Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $diskNames | ForEach-Object {New-AzTag -ResourceId $_.Id -Tag $tags} | Out-Null

    Write-Host ($writeEmptyLine + "# Tags set to all disks in the resource group $rgVMSpoke" + $writeSeperatorSpaces + $currentTime)`
    -foregroundcolor $foregroundColor2 $writeEmptyLine
} catch {
    Write-Host "Error tagging disks: $_" -ForegroundColor $foregroundColor3
}

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed.

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------