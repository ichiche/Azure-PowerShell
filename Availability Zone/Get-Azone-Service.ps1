# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$CsvFullPath = "C:\Temp\Azure-AzoneService-Assessment.csv" # Export Result to CSV file 

# Script Variable
$Global:ResultArray = @()
[int]$CurrentItem = 1

# Login
#Connect-AzAccount # Comment this line if using Connect-To-Cloud.ps1

# Get the Latest Location Name and Display Name
$Global:NameReference = Get-AzLocation

# Function to align the Display Name
function Rename-Location {
    param (
        [string]$Location
    )

    foreach ($item in $Global:NameReference) {
        if ($item.Location -eq $Location) {
            $Location = $item.DisplayName
        }
    }

    return $Location
}

# Function to save the information to Result Array 
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
        $DeployedZoneRedundant,
        $Remark
    )

    $Location = Rename-Location -Location $Location

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
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "DeployedZoneRedundant" -Value $DeployedZoneRedundant
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
            [string]$DeployedZoneRedundant = $array -join ","
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $AppGateway.ResourceGroupName -Location $AppGateway.Location -InstanceName $AppGateway.Name -InstanceType $InstanceType -InstanceTypeDetail "" -InstanceSize $AppGateway.Sku.Name -CurrentRedundancyType "Zone Redundant" -EnabledZoneRedundant "Y" -DeployedZoneRedundant $DeployedZoneRedundant -Remark ""
        } else {
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $AppGateway.ResourceGroupName -Location $AppGateway.Location -InstanceName $AppGateway.Name -InstanceType $InstanceType -InstanceTypeDetail "" -InstanceSize $AppGateway.Sku.Name -CurrentRedundancyType "No Redundant" -EnabledZoneRedundant "N" -DeployedZoneRedundant "N/A" -Remark ""
        }
    }
    #EndRegion Application Gateway

    #Region Event Hub
    # 'Event Hub' is actually called AzEventHubNamespace which is 'Event Hub Namespace'
    # 'Event Hub Entity' is called AzEventHub which is part of 'Event Hub Namespace'
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
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $EventHub.ResourceGroupName -Location $EventHub.Location -InstanceName $EventHub.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant "Y" -DeployedZoneRedundant "All Zones" -Remark $remark
        } else {
            if ($GeoDR -ne $null) {
                $CurrentRedundancyType = "Geo-Recovery (" + $GeoDR.Role + ")"
            } else {
                $CurrentRedundancyType = "No Redundant"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $EventHub.ResourceGroupName -Location $EventHub.Location -InstanceName $EventHub.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant "N" -DeployedZoneRedundant "N/A" -Remark $remark
        }
    }
    #EndRegion Event Hub
    
    #Region Azure Kubernetes Service (AKS)
    $AksClusters = Get-AzAksCluster
    $InstanceType = "Kubernetes Service"
    
    foreach ($AksCluster in $AksClusters) {
        foreach ($AgentPool in $AksClusters.AgentPoolProfiles) {
            $ResourceGroupName = $AksCluster.NodeResourceGroup.Substring($AksCluster.NodeResourceGroup.IndexOf("_") + 1) # Assume NodeResourceGroup is default name
            $ResourceGroupName = $ResourceGroupName.Substring(0, $ResourceGroupName.IndexOf("_"))
            $InstanceTypeDetail = ($AgentPool.Mode + " Pool")
            $remark = ("Agent Pool Name: " + $AgentPool.Name)
            [array]$array = $AgentPool.AvailabilityZones  
            
            # Add-Record
            if ($array.Count -gt 0) {
                [string]$DeployedZoneRedundant = $array -join ","
                Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $ResourceGroupName -Location $AksCluster.Location -InstanceName $AksCluster.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $AgentPool.VmSize -CurrentRedundancyType "Zone Redundant" -EnabledZoneRedundant "Y" -DeployedZoneRedundant $DeployedZoneRedundant -Remark $remark
            } else {
                Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $ResourceGroupName -Location $AksCluster.Location -InstanceName $AksCluster.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $AgentPool.VmSize -CurrentRedundancyType "No Redundant" -EnabledZoneRedundant "N" -DeployedZoneRedundant "N/A" -Remark $remark
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
        #$sku = ($vng.Sku.Tier + ": " + $vng.Sku.Capacity + " Unit")
        $sku = $vng.Sku.Tier
        
        # Primary Public IP Address
        $PrimaryIpConfig = $vng.IpConfigurations | ? {$_.Name -eq "default" -or $_.Name -eq "GatewayIPConfig"}
        $PublicIpResourceId = $PrimaryIpConfig.PublicIpAddress.Id
        $PublicIpRg = $PublicIpResourceId.Substring($PublicIpResourceId.IndexOf("resourceGroups/") + ("resourceGroups/".Length))
        $PublicIpRg = $PublicIpRg.Substring(0, $PublicIpRg.IndexOf("/providers/Microsoft.Network/"))
        $PublicIpName = $PublicIpResourceId.Substring($PublicIpResourceId.IndexOf("/publicIPAddresses/") + ("/publicIPAddresses/".Length))
        $PublicIp = Get-AzPublicIpAddress -ResourceGroupName $PublicIpRg -ResourceName $PublicIpName
        [array]$array = $PublicIp.Zones
        [string]$DeployedZoneRedundant = ("First: " + $array -join ",")
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
            $DeployedZoneRedundant += ("; Second: " + $SecondArray -join ",")
            $remark += ("; Second PIP Name: " + $SecondIpName)
        } 
        
        # Add-Record
        if ($array.Count -gt 0) {
            if ($vng.ActiveActive) {
                $CurrentRedundancyType = "Zone Redundant with Active-Active"
            } else {
                $CurrentRedundancyType = "Zone Redundant"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vng.ResourceGroupName -Location $vng.Location -InstanceName $vng.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant "Y" -DeployedZoneRedundant $DeployedZoneRedundant -Remark $remark
        } else {
            if ($vng.ActiveActive) {
                $CurrentRedundancyType = "Active-Active"
            } else {
                $CurrentRedundancyType = "No Redundant"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vng.ResourceGroupName -Location $vng.Location -InstanceName $vng.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant "N" -DeployedZoneRedundant "N/A" -Remark $remark
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
            $DeployedZoneRedundant = "All Zones" 
            
        } else { 
            $CurrentRedundancyType = $BackupStorageRedundancy # GeoRedundant, LocallyRedundant
            $EnabledZoneRedundant = "N" 
            $DeployedZoneRedundant = "N/A"
        }
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $RecoveryServicesVault.ResourceGroupName -Location $RecoveryServicesVault.Location -InstanceName $RecoveryServicesVault.Name -InstanceType $InstanceType -InstanceTypeDetail "" -InstanceSize "N/A" -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark ""
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
            $DeployedZoneRedundant = "All Zones" 
        } else {
            $CurrentRedundancyType = $sku.Substring($sku.IndexOf("_") + 1)
            $EnabledZoneRedundant = "N" 
            $DeployedZoneRedundant = "N/A"
        }
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $StorageAccount.ResourceGroupName -Location $StorageAccount.Location -InstanceName $StorageAccount.StorageAccountName -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark ""
    }
    #EndRegion Storage Account

    #Region Virtual Machine
    $vms = Get-AzVM
    $InstanceType = "Virtual Machine"

    foreach ($vm in $vms) {
        $InstanceTypeDetail = "Standalone"
        
        # Location
        [array]$array = $vm.Zones
        $RenamedLocation = Rename-Location -Location $vm.Location 

        if ($array.Count -gt 0) {
            $Location = $RenamedLocation + " (Zone: " + ($array -join ",") + ")"
        } else {
            $Location = $RenamedLocation
        }

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

        # Zone
        $CurrentRedundancyType = "N/A"
        $EnabledZoneRedundant = "N/A"
        $DeployedZoneRedundant = "N/A"

        # Add-Record
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vm.ResourceGroupName -Location $Location -InstanceName $vm.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark ""
    }
    #EndRegion Virtual Machine

    #Region Virtual Machine Scale Set (VMSS)
    $VmScaleSets = Get-AzVmss
    $InstanceType = "Virtual Machine Scale Set"

    foreach ($vmss in $VmScaleSets) {
        $InstanceTypeDetail = "Virtual Machine Scale Set"
        [array]$array = $vmss.Zones

        # SKU
        $sku = ($vmss.Sku.Name + ": " + $vmss.Sku.Capacity + " Unit")
    
        # Zone
        if ($array.Count -gt 0) {
            $CurrentRedundancyType = "Zone Redundant"
            $EnabledZoneRedundant = "Y"
            [string]$DeployedZoneRedundant = $array -join ","
        } else {
            $CurrentRedundancyType = "N/A"
            $EnabledZoneRedundant = "N"
            $DeployedZoneRedundant = "N/A"
        }
        
        # Add-Record
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vmss.ResourceGroupName -Location $vmss.Location -InstanceName $vmss.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark ""

        # Instance OS Disk
        $sku = $vmss.VirtualMachineProfile.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
        $InstanceTypeDetail = "OS Disk"
        $CurrentRedundancyType = $sku.Substring($sku.IndexOf("_") + 1)

        if ($CurrentRedundancyType -like "*ZRS*" ) {
            $EnabledZoneRedundant = "Y"
            $DeployedZoneRedundant = "All Zones"
        } else {
            $EnabledZoneRedundant = "N"
            $DeployedZoneRedundant = "N/A"
        }
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vmss.ResourceGroupName -Location $vmss.Location -InstanceName $vmss.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark ""

        # Instance Data Disk
        $DataDisks = $vmss.VirtualMachineProfile.StorageProfile.DataDisks

        foreach ($DataDisk in $DataDisks) {
            $sku = $DataDisk.ManagedDisk.StorageAccountType
            $InstanceTypeDetail = "Data Disk " + $DataDisk.Lun
            $CurrentRedundancyType = $sku.Substring($sku.IndexOf("_") + 1)
    
            if ($CurrentRedundancyType -like "*ZRS*" ) {
                $EnabledZoneRedundant = "Y"
                $DeployedZoneRedundant = "All Zones"
            } else {
                $EnabledZoneRedundant = "N"
                $DeployedZoneRedundant = "N/A"
            }
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $vmss.ResourceGroupName -Location $vmss.Location -InstanceName $vmss.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark ""
        }
    }
    #EndRegion Virtual Machine Scale Set (VMSS)

    #Region Managed Disk
    $disks = Get-AzDisk
    $InstanceType = "Managed Disk"

    foreach ($disk in $disks) {
        # Location
        [array]$array = $disk.Zones
        $RenamedLocation = Rename-Location -Location $disk.Location 

        if ($array.Count -gt 0) {
            $Location = $RenamedLocation + " (Zone: " + ($array -join ",") + ")"
        } else {
            $Location = $RenamedLocation
        }
        
        # SKU
        $sku = $disk.Sku.Name
    
        # Disk Type
        if ($disk.OsType -ne $null) {
            $InstanceTypeDetail = "OS Disk"
        } else {
            $InstanceTypeDetail = "Data Disk"
        }
        
        # Associated Disk
        if ($disk.ManagedBy -eq $null) {
            $remark = "Unassociated"
        } else {
            $remark = ""
        }

        # Zone
        $CurrentRedundancyType = $sku.Substring($sku.IndexOf("_") + 1)
    
        if ($sku -like "*ZRS*" ) {
            $EnabledZoneRedundant = "Y"
            $DeployedZoneRedundant = "All Zones"
        } else {
            $EnabledZoneRedundant = "N"
            $DeployedZoneRedundant = "N/A"
        }

        # Add-Record
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $disk.ResourceGroupName -Location $Location -InstanceName $disk.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark $remark
    }
    #EndRegion Managed Disk

    #Region Api Management
    $apims = Get-AzApiManagement
    $InstanceType = "Api Management"
    $InstanceTypeDetail = ""

    foreach ($apim in $apims) {
        # Primary Location
        [string]$Location = $apim.Location

        # SKU
        $sku = ($Location + " (" + $apim.Sku.ToString() + ": " + $apim.Capacity.ToString() + " Unit" + ")")
        
        # Zone
        [array]$array = $apim.Zone
        if ($array.Count -gt 0) {
            $EnabledZoneRedundant = "Y"
            [string]$DeployedZoneRedundant = ($Location + " (" + ($array -join ",") + ")")
        } else {
            $EnabledZoneRedundant = "N"
            [string]$DeployedZoneRedundant = ""
        }

        # Additional Region
        [array]$AdditionalRegions = $apim.AdditionalRegions

        if ($AdditionalRegions.Count -gt 0) {
            $CurrentRedundancyType = "Multiple Region"

            foreach ($AdditionalRegion in $AdditionalRegions) {
                # Location
                if ($InstanceTypeDetail -eq "") {
                    $InstanceTypeDetail = "Additional Region: " + $AdditionalRegion.Location
                } else {
                    $InstanceTypeDetail += ", " + $AdditionalRegion.Location
                }

                # SKU
                $sku += ("; " + $AdditionalRegion.Location + " (" + $AdditionalRegion.Sku.ToString() + ": " + $AdditionalRegion.Capacity.ToString() + " Unit" + ")")

                # Zone
                [array]$AdditionalRegionZone = $AdditionalRegion.Zone
                if ($AdditionalRegionZone.Count -gt 0) {
                    $EnabledZoneRedundant = "Y"

                    if ($DeployedZoneRedundant -eq "") {
                        $DeployedZoneRedundant += ($AdditionalRegion.Location + " (" + ($AdditionalRegionZone -join ",") + ")")
                    } else {
                        $DeployedZoneRedundant += (", " + $AdditionalRegion.Location + " (" + ($AdditionalRegionZone -join ",") + ")")
                    }
                }
            }
        } else {
            $CurrentRedundancyType = "Single Region"
            if ($EnabledZoneRedundant -eq "N") { $DeployedZoneRedundant = "N/A" }
        }

        # Add-Record
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $apim.ResourceGroupName -Location $Location -InstanceName $apim.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark ""
    }
    #EndRegion Api Management

    #Region Azure Firewall
    $firewalls = Get-AzFirewall
    $InstanceType = "Azure Firewall"
    $remark = ""

    foreach ($firewall in $firewalls) {
        if ($firewall.Sku.Name -eq "AZFW_Hub") {
            $InstanceTypeDetail = "Azure Firewall with Secured Virtual Hub"
        } 
        
        # SKU
        $sku = $firewall.Sku.Tier

        # Zone
        [array]$array = $firewall.Zones

        if ($array.Count -gt 0) {
            $CurrentRedundancyType = "Zone Redundant"
            $EnabledZoneRedundant = "Y"
            [string]$DeployedZoneRedundant = $array -join ","
        } else {
            $CurrentRedundancyType = "No Redundant"
            $EnabledZoneRedundant = "N"
            $DeployedZoneRedundant = "N/A"
        }

        # Add-Record
        Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $firewall.ResourceGroupName -Location $firewall.Location -InstanceName $firewall.Name -InstanceType $InstanceType -InstanceTypeDetail $InstanceTypeDetail -InstanceSize $sku -CurrentRedundancyType $CurrentRedundancyType -EnabledZoneRedundant $EnabledZoneRedundant -DeployedZoneRedundant $DeployedZoneRedundant -Remark $remark
    }
    #EndRegion Azure Firewall
}

# Export Result to CSV file 
$Global:ResultArray | sort SubscriptionName, InstanceType | Export-Csv -Path $CsvFullPath -NoTypeInformation -Confirm:$false -Force

# End
Write-Host "`nCompleted`n" -ForegroundColor Yellow
