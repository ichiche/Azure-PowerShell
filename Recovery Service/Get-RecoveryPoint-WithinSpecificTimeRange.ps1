# Script Variable
$BackupItemVM = @()  
$BackupItemVMRecoveryPoint = @() 
$StartDate = Get-Date -Year 2022 -Month 01 -Day 5 -Hour 23 -Minute 59
$EndDate = Get-Date -Year 2022 -Month 01 -Day 19 -Hour 23 -Minute 59

# Get Recovery Services Vault from current subscription
$RecoveryServicesVaults = Get-AzRecoveryServicesVault

# Get Backup Item of Recovery Services Vault from current subscription
foreach ($RecoveryServicesVault in $RecoveryServicesVaults) {
    Write-Host ("`nRecovery Services Vault: " + $RecoveryServicesVault.Name) -ForegroundColor Yellow
    Write-Host "Retrieving Azure VM Backup Item..."

    # Azure VM
    $Containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -VaultId $RecoveryServicesVault.ID
    foreach ($Container in $Containers) {
        $CurrentBackupItemVM = Get-AzRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM -VaultId $RecoveryServicesVault.ID
        $VMName = $CurrentBackupItemVM.VirtualMachineId.Substring($CurrentBackupItemVM.VirtualMachineId.IndexOf("/Microsoft.Compute/virtualMachines/") + "/Microsoft.Compute/virtualMachines/".Length)
        Write-Host $VMName

        $BackupItemVM += $CurrentBackupItemVM
        $BackupItemVMRecoveryPoint += Get-AzRecoveryServicesBackupRecoveryPoint -Item $CurrentBackupItemVM -StartDate $StartDate.ToUniversalTime() -EndDate $EndDate.ToUniversalTime() -VaultId $RecoveryServicesVault.ID
    }
}

# Output 
$BackupItemVMRecoveryPoint 

# Get Recovery Points within a specific time range for an item
# https://docs.microsoft.com/en-us/powershell/module/az.recoveryservices/get-azrecoveryservicesbackuprecoverypoint?view=azps-7.1.0

<# 
$rp = Get-AzRecoveryServicesBackupRecoveryPoint -Item $BackupItemVM[2] -StartDate $StartDate.ToUniversalTime() -EndDate $EndDate.ToUniversalTime() -VaultId $RecoveryServicesVaults[0].Id
$container = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -Name "V2VM" -VaultId $vault.ID
$backupItem = Get-AzRecoveryServicesBackupItem -ContainerType AzureVM -WorkloadType AzureVM -VaultId $vault.ID
$rp = Get-AzRecoveryServicesBackupRecoveryPoint -Item $backupItem -StartDate $startdate.ToUniversalTime() -EndDate $enddate.ToUniversalTime() -VaultId $vault.ID
#>