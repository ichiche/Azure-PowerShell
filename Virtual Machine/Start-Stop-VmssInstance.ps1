# Global Parameter
$VmssRG = "MC_AKS_aks-core-prd-001_eastus"
$VmssName = "aks-apppool-19256404-vmss"
$SelectedAZone = 1

# Script Variable

# Retrieve the VM Instance in VM Scale Set with Zone and Power State
$vmss = Get-AzVmssVM -ResourceGroupName $VmssRG -VMScaleSetName $VmssName -InstanceView
$vmss | ft Name, InstanceID, Location, Zones, @{n="PowerState";e={$($_.InstanceView.Statuses.DisplayStatus | ? {$_ -notlike "Provisioning*"})}} -AutoSize

# Stop VM in Scale Set that provisioned in specific Availability Zone
$InstanceIds = @()
$list = $vmss | ? {$_.Zones -eq $SelectedAZone}
foreach ($item in $list) { $InstanceIds += "$($item.InstanceID)"} 
Stop-AzVmss -InstanceId $InstanceIds -ResourceGroupName $VmssRG -VMScaleSetName $VmssName -Confirm:$false -Force

# Start VM in Scale Set that is not in running state
$vmss = Get-AzVmssVM -ResourceGroupName $VmssRG -VMScaleSetName $VmssName -InstanceView
$list = $vmss | ? {$_.InstanceView.Statuses.DisplayStatus -notcontains "VM Running"}
$InstanceIds = @()
foreach ($item in $list) { $InstanceIds += "$($item.InstanceID)"} 
Start-AzVmss -InstanceId $InstanceIds -ResourceGroupName $VmssRG -VMScaleSetName $VmssName -Confirm:$false