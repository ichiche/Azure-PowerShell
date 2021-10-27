# Script Variable
$Global:ReplicationProtectedItems = @()

# Login
Connect-AzAccount

# Get Azure Subscription
$Subscriptions = Get-AzSubscription
$vms = Get-AzVM


##Replace Recovery service vault name
Get-AzureRmRecoveryServicesVault -Name "shui" | Set-AzureRmRecoveryServicesVaultContext

##FriendlyName is your Azure VM name
$namedContainer=Get-AzureRmRecoveryServicesBackupContainer -ContainerType "AzureVM" -Status "Registered" -FriendlyName "shui"

$item = Get-AzureRmRecoveryServicesBackupItem -Container $namedContainer -WorkloadType "AzureVM"
$item.ProtectionPolicyName

# Main
Write-Host "`nCollecting Site Recovery Replication Protected Items`n" -ForegroundColor Yellow

$vmlist = @()
foreach ($Subscription in $Global:Subscriptions) {
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        #Set-AzRecoveryServicesAsrVaultContext -Vault $RecoveryServicesVault 

        $Containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -VaultId $RecoveryServicesVault.ID

        foreach ($Container in $Containers) {
            $BackupItem = Get-AzRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM -VaultId $RecoveryServicesVault.ID
            $vmlist += $BackupItem
        }
    }
}
$vmlist | group VirtualMachineId
$vmlist | group HealthStatus
$vmlist | group ProtectionStatus


foreach ($Subscription in $Subscriptions) {
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        Write-Host ("Processing Recovery Services Vault: " + $RecoveryServicesVault.Name + "`n") -ForegroundColor Yellow
        Set-AzRecoveryServicesAsrVaultContext -Vault $RecoveryServicesVault # Perform action 'Microsoft.RecoveryServices/vaults/extendedInformation/write' 

        $fabrics = Get-AzRecoveryServicesAsrFabric

        foreach ($fabric in $fabrics) {
            $ProtectionContainers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric

            foreach ($ProtectionContainer in $ProtectionContainers) {
                $ReplicationProtectedItems += Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $ProtectionContainer
            }
        }
    }
}


# SQL in Azure VM
$res = Get-AzResource
$res | ? {$_.resourcetype -eq "Microsoft.SqlVirtualMachine/SqlVirtualMachines"} | select Name


# Azure File
$storageAccount = Get-AzStorageAccount
foreach ($storage in $storageAccount) { 
    if($storage.PrimaryEndpoints.File -ne $null){
        $i = $storage.PrimaryEndpoints
        #Get-AzStorageShare -ResourceGroupName $storage.ResourceGroupName 
    }
}
$ctx=(Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccName).Context


#Get storageaccount names
$SAname = Get-AzStorageAccount

#Now iterate over the storageaccounts
    foreach ( $storageaccount in $SAname.StorageAccountName) { 
        write-output $storageaccount $(az storage share list --account-name $storageaccount --output tsv) #.replace("None",""))
    }


$backupVaults = Get-AzDataProtectionBackupVault -ResourceGroupName iSpr_UAT-asr 

$backupVaultInstances = Get-AzDataProtectionBackupInstance -ResourceGroupName iSpr_UAT-asr -VaultName strdrivedocumentmtruatvault
$backupVaultInstances.Property.DataSourceInfo.ResourceType
$backupVaultInstances.Property.DataSourceInfo.ResourceId

# End
Write-Host "`nCompleted to collect Site Recovery Replication Protected Items" -ForegroundColor Yellow; `
Write-Host "`nCheck variable " -NoNewline; `
Write-Host '$Global:ReplicationProtectedItems' -NoNewline -ForegroundColor Cyan; `
Write-Host " to review`n"