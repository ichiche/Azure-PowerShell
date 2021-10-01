# Global Parameter
$ConnectSpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID

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
        $InstanceSize,
        $CurrentRedundancyType,
        $EnabledZoneRedundant,
        $EnabledAvailabilityZone
    )

    # Pre-Configuration
    if ($Location -eq "eastasia") { $Location = "East Asia" }
    if ($Location -eq "southeastasia") { $Location = "Southeast Asia" }
    if ($Location -eq "eastus") { $Location = "East US" }

    # Save to Temp Object
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $SubscriptionName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $SubscriptionId
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $ResourceGroup
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceName" -Value $InstanceName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceType" -Value $InstanceType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceSize" -Value $InstanceSize
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "CurrentRedundancyType" -Value $CurrentRedundancyType
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledZoneRedundant" -Value $EnabledZoneRedundant
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledAvailabilityZone" -Value $EnabledAvailabilityZone

    # Save to Array
    $Global:ResultArray += $obj
}

# Main
foreach ($Subscription in $Subscriptions) {
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow
    $CurrentItem++

    #Region Application Gateway
    $AppGateways = Get-AzApplicationGateway

    foreach ($AppGateway in $AppGateways) {
        [array]$array = $AppGateway.Zones

        if ($array.Count -gt 0) {
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $AppGateway.ResourceGroupName -Location $AppGateway.Location -InstanceName $AppGateway.Name -InstanceType "Application Gateway" -InstanceSize $AppGateway.Sku.Name -CurrentRedundancyType "Zone Redundant" -EnabledZoneRedundant "Y" -EnabledAvailabilityZone $array
        } else {
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $AppGateway.ResourceGroupName -Location $AppGateway.Location -InstanceName $AppGateway.Name -InstanceType "Application Gateway" -InstanceSize $AppGateway.Sku.Name -CurrentRedundancyType "No Redundant" -EnabledZoneRedundant "N" -EnabledAvailabilityZone "N/A"
        }
    }
    #EndRegion Application Gateway

    #Region Recovery Services Vault
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        $BackupStorageRedundancy = Get-AzRecoveryServicesBackupProperty -Vault $RecoveryServicesVault | select -ExpandProperty BackupStorageRedundancy

        if ($BackupStorageRedundancy -eq "ZoneRedundant") {
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $RecoveryServicesVault.ResourceGroupName -Location $RecoveryServicesVault.Location -InstanceName $RecoveryServicesVault.Name -InstanceType "Recovery Service Vault" -InstanceSize "N/A" -CurrentRedundancyType "Zone Redundant" -EnabledZoneRedundant "Y" -EnabledAvailabilityZone "All Zones"
        } else { # GeoRedundant, LocallyRedundant
            Add-Record -SubscriptionName $Subscription.Name -SubscriptionId $Subscription.Id -ResourceGroup $RecoveryServicesVault.ResourceGroupName -Location $RecoveryServicesVault.Location -InstanceName $RecoveryServicesVault.Name -InstanceType "Recovery Service Vault" -InstanceSize "N/A" -CurrentRedundancyType $BackupStorageRedundancy -EnabledZoneRedundant "N" -EnabledAvailabilityZone "N/A"
        }
    }
    #EndRegion Recovery Services Vault
}

# WIP
foreach ($Subscription in $Subscriptions) {
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id 
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow
    $CurrentItem++

    # Event Hub # Event Hub Namespace 
    # Deploy to All Zone by default 
}