# Stop VM in Scale Set that runnign in specific Availability Zone
$vmss = Get-AzVmssVM -ResourceGroupName MC_AKS_aks-core-prd-001_eastus -VMScaleSetName aks-apppool-19256404-vmss -InstanceView
$vmss | select Name, InstanceID, Zones, @{n="PowerState";e={$($_.InstanceView.Statuses.DisplayStatus | ? {$_ -notlike "Provisioning*"})}}
$list = $vmss | ? {$_.Zones -eq 1}
$InstanceIds = @()
foreach ($item in $list) { $InstanceIds += "$($item.InstanceID)"} 
$InstanceIds

Stop-AzVmss -InstanceId $InstanceIds -ResourceGroupName MC_AKS_aks-core-prd-001_eastus -VMScaleSetName aks-apppool-19256404-vmss -Confirm:$false -Force

# Start VM in Scale Set that is not in running state

$vmss = Get-AzVmssVM -ResourceGroupName MC_AKS_aks-core-prd-001_eastus -VMScaleSetName aks-apppool-19256404-vmss -InstanceView
$list = $vmss | ? {$_.InstanceView.Statuses.DisplayStatus -notcontains "VM Running"}
$InstanceIds = @()
foreach ($item in $list) { $InstanceIds += "$($item.InstanceID)"} 
$InstanceIds

# Start-AzVmss: A parameter cannot be found that matches parameter name 'Force'.
Start-AzVmss -InstanceId $InstanceIds -ResourceGroupName MC_AKS_aks-core-prd-001_eastus -VMScaleSetName aks-apppool-19256404-vmss -Confirm:$false