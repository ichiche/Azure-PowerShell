# Script Variable
$ReplicationProtectedItems = @()

$Subscriptions = Get-AzSubscription

Write-Host "`nCollecting detail of Site Recovery Replication Protected Items`n" -ForegroundColor Yellow

# Main
foreach ($Subscription in $Subscriptions) {
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    $RecoveryServicesVaults = Get-AzRecoveryServicesVault

    foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
        Write-Host ($RecoveryServicesVault.Name + "`n") -ForegroundColor Yellow
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

# End
Write-Host "`nCompleted to collect detail of Site Recovery Replication Protected Items`n" -ForegroundColor Yellow

# Write to console
$ReplicationProtectedItems