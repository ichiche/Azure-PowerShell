# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$CsvFullPath = "C:\Temp\Azure-AzoneService-Assessment.csv" # Export Result to CSV file 

# Script Variable
$Global:ResultArray = @()
[int]$CurrentItem = 1

# Login
#Connect-AzAccount # Comment this line if using Connect-To-Cloud.ps1

# Function
function Add-Record {
    param (
        $SubscriptionName,
        $SubscriptionId,
        $ResourceGroup,
        $Location,
        $InstanceName,
        $InstanceType,
        $InstanceTypeDetail,
        $InstanceSize,
        $CurrentRedundancyType,
        $EnabledZoneRedundant,
        $EnabledAvailabilityZone,
        $Remark
    )

    # Pre-Configuration
    if ($Location -eq "eastasia") { $Location = "East Asia" }
    if ($Location -eq "southeastasia") { $Location = "Southeast Asia" }
    if ($Location -eq "eastus") { $Location = "East US" }
    if ($Location -eq "centralus") { $Location = "Central US" }
    if ($Location -eq "westus") { $Location = "West US" }
    if ($Location -eq "westus2") { $Location = "West US 2" }
    

    # Save to Temp Object
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $SubscriptionName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $SubscriptionId
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $ResourceGroup
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceName" -Value $InstanceName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceType" -Value $InstanceType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceTypeDetail" -Value $InstanceTypeDetail
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceSize" -Value $InstanceSize
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "CurrentRedundancyType" -Value $CurrentRedundancyType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledZoneRedundant" -Value $EnabledZoneRedundant
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledAvailabilityZone" -Value $EnabledAvailabilityZone
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Remark" -Value $Remark

    # Save to Array
    $Global:ResultArray += $obj
}

# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    #$Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    #$Subscriptions = Get-AzSubscription
}

<#
# Get Site Recovery Replication Protected Items of All Subscriptions
$ReplicationProtectedItems = @()
Write-Host "`nCollecting detail of Site Recovery Replication Protected Items`n" -ForegroundColor Yellow

foreach ($Subscription in $Subscriptions) {
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {

        Write-Host ($RecoveryServicesVault.Name + "`n") -ForegroundColor Yellow
        Set-AzRecoveryServicesAsrVaultContext -Vault $RecoveryServicesVault

        $fabrics = Get-AzRecoveryServicesAsrFabric

        foreach ($fabric in $fabrics) {
            $ProtectionContainers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric

            foreach ($ProtectionContainer in $ProtectionContainers) {
                $ReplicationProtectedItems += Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $ProtectionContainer
            }
        }
    }
}
Write-Host "`nCompleted to collect detail of Site Recovery Replication Protected Items`n" -ForegroundColor Yellow
#>

# Main
foreach ($Subscription in $Subscriptions) {
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow
    $CurrentItem++

    #Region Application Gateway
    $AppGateways = Get-AzApplicationGateway
    $InstanceType = "Application Gateway" 

    foreach ($AppGateway in $AppGateways) {
        [array]$array = $AppGateway.Zones
        
        # Add-Record
        if ($array.Count -gt 0) {
            [string]$EnabledAvailabilityZone = $array -join ","
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $AppGateway.ResourceGroupName -Location $AppGateway.Location -InstanceName $AppGateway.Name -InstanceType $InstanceType -InstanceTypeDetail "" -InstanceSize $AppGateway.Sku.Name -CurrentRedundancyType "Zone Redundant" -EnabledZoneRedundant "Y" -EnabledAvailabilityZone $EnabledAvailabilityZone -Remark ""
        } else {
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $AppGateway.ResourceGroupName -Location $AppGateway.Location -InstanceName $AppGateway.Name -InstanceType $InstanceType -InstanceTypeDetail "" -InstanceSize $AppGateway.Sku.Name -CurrentRedundancyType "No Redundant" -EnabledZoneRedundant "N" -EnabledAvailabilityZone "N/A" -Remark ""
        }
    }
    #EndRegion Application Gateway

    #Region Event Hub
    # 'Event Hub' is actually called AzEventHubNamespace which is Event Hub Namespace
    # Event Hub Entity is called AzEventHub which is part of AzEventHubNamespace
    $EventHubs = Get-AzEventHubNamespace
    $InstanceType = "Event Hub" 
    $InstanceTypeDetail = "Event Hub Namespace" 

    foreach ($EventHub in $EventHubs) {
        # SKU
        $sku = ($EventHub.Sku.Tier + ": " + $EventHub.Sku.Capacity + " Unit")
        
        # Auto-Inflate
        if ($EventHub.IsAutoInflateEnabled -eq $true) {
            $remark = "Auto-Inflate Enabled, Maximum Throughput Units: " + $EventHub.MaximumThroughputUnits
        } else {
            $remark = ""
        }
        
        # Geo-Recovery
        $GeoDR = $null
        
        try {
            $GeoDR = Get-AzEventHubGeoDRConfiguration -ResourceGroupName $EventHub.ResourceGroupName -Namespace $EventHub.Name -ErrorAction SilentlyContinue
        } catch {
            
        }
        
        if ($GeoDR -ne $null) {
            if ($GeoDR.Role -ne "PrimaryNotReplicating") {
                $PartnerNamespace = $GeoDR.PartnerNamespace.Substring($GeoDR.PartnerNamespace.IndexOf("/namespaces/") + ("/namespaces/".Length))
                $remark += ("; Geo-Recovery Partner Namespace: " + $PartnerNamespace)
            }
        }
        
        # Add-Record 
        if ($EventHub.ZoneRedundant -eq $true) {
            if ($GeoDR -ne $null) {
                $CurrentRedundancyType = "Zone Redundant with Geo-Recovery (" + $GeoDR.Role + ")"
            } else {
                $CurrentRedundancyType = "Zone Redundant"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $EventHub.ResourceGroupName -Location $EventHub.Location -InstanceName $EventHub.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant "Y" -EnabledAvailabilityZone "All Zones" -Remark $remark
        } else {
            if ($GeoDR -ne $null) {
                $CurrentRedundancyType = "Geo-Recovery (" + $GeoDR.Role + ")"
            } else {
                $CurrentRedundancyType = "No Redundant"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $EventHub.ResourceGroupName -Location $EventHub.Location -InstanceName $EventHub.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant "N" -EnabledAvailabilityZone "N/A" -Remark $remark
        }
    }
    #EndRegion Event Hub
    
    #Region Azure Kubernetes Service (AKS)
    $AksClusters = Get-AzAksCluster
    $InstanceType = "Kubernetes Service"
    
    foreach ($AksCluster in $AksClusters) {
        foreach ($AgentPool in $AksClusters.AgentPoolProfiles) {
            $ResourceGroupName = $AksCluster.NodeResourceGroup.Substring($AksCluster.NodeResourceGroup.IndexOf("_") + 1)
            $ResourceGroupName = $ResourceGroupName.Substring(0, $ResourceGroupName.IndexOf("_"))
            $InstanceTypeDetail = ($AgentPool.Mode + " Pool")
            $remark = ("Agent Pool Name: " + $AgentPool.Name)
            [array]$array = $AgentPool.AvailabilityZones  
            
            # Add-Record
            if ($array.Count -gt 0) {
                [string]$EnabledAvailabilityZone = $array -join ","
                Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $ResourceGroupName -Location $AksCluster.Location -InstanceName $AksCluster.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $AgentPool.VmSize -CurrentRedundancyType "Zone Redundant" -EnabledZoneRedundant "Y" -EnabledAvailabilityZone $EnabledAvailabilityZone -Remark $remark
            } else {
                Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $ResourceGroupName -Location $AksCluster.Location -InstanceName $AksCluster.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $AgentPool.VmSize -CurrentRedundancyType "No Redundant" -EnabledZoneRedundant "N" -EnabledAvailabilityZone "N/A" -Remark $remark
            }
        }
    }
    #EndRegion Azure Kubernetes Service (AKS)
    
    #Region Virtual Network Gateway
    $vngs = Get-AzResourceGroup | Get-AzVirtualNetworkGateway
    $InstanceType = "Virtual Network Gateway"
    
    foreach ($vng in $vngs) {
        $InstanceTypeDetail = $vng.GatewayType

        # SKU
        $sku = ($vng.Sku.Tier + ": " + $vng.Sku.Capacity + " Unit")
        
        # Primary Public IP Address
        $PrimaryIpConfig = $vng.IpConfigurations | ? {$_.Name -eq "default"}
        $PublicIpResourceId = $PrimaryIpConfig.PublicIpAddress.Id
        $PublicIpRg = $PublicIpResourceId.Substring($PublicIpResourceId.IndexOf("resourceGroups/") + ("resourceGroups/".Length))
        $PublicIpRg = $PublicIpRg.Substring(0, $PublicIpRg.IndexOf("/providers/Microsoft.Network/"))
        $PublicIpName = $PublicIpResourceId.Substring($PublicIpResourceId.IndexOf("/publicIPAddresses/") + ("/publicIPAddresses/".Length))
        $PublicIp = Get-AzPublicIpAddress -ResourceGroupName $PublicIpRg -ResourceName $PublicIpName
        [array]$array = $PublicIp.Zones
        [string]$EnabledAvailabilityZone = ("First: " + $array -join ",")
        $remark = ("First PIP Name: " + $PublicIpName)
        
        # Active-Active Design
        if ($vng.ActiveActive) {
            $SecondIpConfig = $vng.IpConfigurations | ? {$_.Name -eq "activeActive"}
            $SecondIpResourceId = $SecondIpConfig.PublicIpAddress.Id
            $SecondIpRg = $SecondIpResourceId.Substring($SecondIpResourceId.IndexOf("resourceGroups/") + ("resourceGroups/".Length))
            $SecondIpRg = $SecondIpRg.Substring(0, $SecondIpRg.IndexOf("/providers/Microsoft.Network/"))
            $SecondIpName = $SecondIpResourceId.Substring($SecondIpResourceId.IndexOf("/publicIPAddresses/") + ("/publicIPAddresses/".Length))
            $SecondIp = Get-AzPublicIpAddress -ResourceGroupName $SecondIpRg -ResourceName $SecondIpName
            [array]$SecondArray = $SecondIp.Zones
            $EnabledAvailabilityZone += ("; Second: " + $SecondArray -join ",")
            $remark += ("; Second PIP Name: " + $SecondIpName)
        } 
        
        # Add-Record
        if ($array.Count -gt 0) {
            if ($vng.ActiveActive) {
                $CurrentRedundancyType = "Zone Redundant with Active-Active"
            } else {
                $CurrentRedundancyType = "Zone Redundant"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vng.ResourceGroupName -Location $vng.Location -InstanceName $vng.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant "Y" -EnabledAvailabilityZone $EnabledAvailabilityZone -Remark $remark
        } else {
            if ($vng.ActiveActive) {
                $CurrentRedundancyType = "Active-Active"
            } else {
                $CurrentRedundancyType = "No Redundant"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vng.ResourceGroupName -Location $vng.Location -InstanceName $vng.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant "N" -EnabledAvailabilityZone "N/A" -Remark $remark
        }
    }
    #EndRegion Virtual Network Gateway
    
    #Region Recovery Services Vault
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault
    $InstanceType = "Recovery Services Vault"
    
    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        $BackupStorageRedundancy = Get-AzRecoveryServicesBackupProperty -Vault $RecoveryServicesVault | select -ExpandProperty BackupStorageRedundancy
    
        # Add-Record
        if ($BackupStorageRedundancy -eq "ZoneRedundant") {
            $CurrentRedundancyType = "Zone Redundant"
            $EnabledZoneRedundant = "Y" 
            $EnabledAvailabilityZone = "All Zones" 
            
        } else { 
            $CurrentRedundancyType = $BackupStorageRedundancy # GeoRedundant, LocallyRedundant
            $EnabledZoneRedundant = "N" 
            $EnabledAvailabilityZone = "N/A"
        }
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $RecoveryServicesVault.ResourceGroupName -Location $RecoveryServicesVault.Location -InstanceName $RecoveryServicesVault.Name -InstanceType $InstanceType -InstanceTypeDetail "" -InstanceSize "N/A" -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -EnabledAvailabilityZone $EnabledAvailabilityZone -Remark ""
    }
    #EndRegion Recovery Services Vault

    #Region Storage Account
    $StorageAccounts = Get-AzStorageAccount
    $InstanceType = "Storage Account"

    foreach ($StorageAccount in $StorageAccounts) {
        $InstanceTypeDetail = $StorageAccount.Kind
        
        # SKU
        $sku = $StorageAccount.Sku.Name
        
        # Add-Record
        if ($sku -like "*ZRS*") {
            $CurrentRedundancyType = $sku.Substring($sku.IndexOf("_") + 1)
            $EnabledZoneRedundant = "Y" 
            $EnabledAvailabilityZone = "All Zones" 
        } else {
            $CurrentRedundancyType = $sku.Substring($sku.IndexOf("_") + 1)
            $EnabledZoneRedundant = "N" 
            $EnabledAvailabilityZone = "N/A"
        }
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $StorageAccount.ResourceGroupName -Location $StorageAccount.Location -InstanceName $StorageAccount.StorageAccountName -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -EnabledAvailabilityZone $EnabledAvailabilityZone -Remark ""
    }
    #EndRegion Storage Account

    #Region Virtual Machine
    # Region Disaster Recovery / Zone to Zone Disaster Recovery for Azure Virtual Machines is not enabled to be confirmed by using PowerShell due to potential permission problem
    $vms = Get-AzVM
    $InstanceType = "Virtual Machine"

    foreach ($vm in $vms) {
        $InstanceTypeDetail = "Standalone"
        [array]$array = $vm.Zones

        # SKU
        $sku = $vm.HardwareProfile.VmSize

        # Availability Set
        if ($vm.AvailabilitySetReference.Id -ne $null ) {
            $InstanceTypeDetail = "Availability Set"
        }
        
        # Virtual Machine Scale Set
        if ($vm.VirtualMachineScaleSet -ne $null ) {
            $InstanceTypeDetail = "Virtual Machine Scale Set"
        }

        # Add-Record
        if ($array.Count -gt 0) {
            $CurrentRedundancyType = "N/A"
            $EnabledZoneRedundant = "N/A"
            [string]$EnabledAvailabilityZone = $array -join ","
        } else {
            $CurrentRedundancyType = "N/A"
            $EnabledZoneRedundant = "N/A"
            $EnabledAvailabilityZone = "N/A"
        }
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vm.ResourceGroupName -Location $vm.Location -InstanceName $vm.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -EnabledAvailabilityZone $EnabledAvailabilityZone -Remark ""
    }
    #EndRegion Virtual Machine
}

# Export Result to CSV file 
$Global:ResultArray | sort SubscriptionName, InstanceType | Export-Csv -Path $CsvFullPath -NoTypeInformation -Confirm:$false -Force

# End
Write-Host "`nCompleted`n" -ForegroundColor Yellow
