# Script Variable
$Global:ReplicationProtectedItems = @()

# Login
Connect-AzAccount

# Get Azure Subscription
$Subscriptions = Get-AzSubscription

# Main
Write-Host "`nCollecting Site Recovery Replication Protected Items`n" -ForegroundColor Yellow

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

# End
Write-Host "`nCompleted to collect Site Recovery Replication Protected Items" -ForegroundColor Yellow; `
Write-Host "`nCheck variable " -NoNewline; `
Write-Host '$Global:ReplicationProtectedItems' -NoNewline -ForegroundColor Cyan; `
Write-Host " to review`n"