# Script Variable
$info = @()

# Collect VM and NIC Information
$vms = Get-AzVM -Status
$nics = Get-AzNetworkInterface  | ? {$_.VirtualMachine -ne $null} | sort Name #skip Nics with no VM

# Map VM to NIC
foreach ($nic in $nics) {
    $vm = $vms | ? {$_.Id -eq $nic.VirtualMachine.id}
    $prv =  $nic.IpConfigurations | select -ExpandProperty PrivateIpAddress
    $alloc =  $nic.IpConfigurations | select -ExpandProperty PrivateIpAllocationMethod

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Name" -Value $($vm.Name)
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "IpAddress" -Value $prv
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "NetworkInterface" -Value $nic.Name
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllocationMethod" -Value $alloc
    $info += $obj
}

# Display result to console 
$info | ft Name, IpAddress, NetworkInterface, AllocationMethod -AutoSize

# Set PrivateIpAllocationMethod to Static
Write-Host ("`nProcessing to set Private Ip Allocation to Static`n") -ForegroundColor Yellow
foreach ($nic in $nics) {
    $vm = $vms | ? {$_.Id -eq $nic.VirtualMachine.id}
    $NicIpConfigurations =  $nic.IpConfigurations | select -ExpandProperty PrivateIpAllocationMethod

    for ($i = 0; $i -lt $NicIpConfigurations.Count; $i++) {
        # Multiple IP Address assigned to single NIC
        if ($NicIpConfigurations.Count -gt 1) {
            #Write-Host ($vm.Name + " - " + $nic.Name + " consist of multiple IP Address, IP" + $i + " currently " + $NicIpConfigurations[$i] + " Allocation") 
            $alloc = $NicIpConfigurations[$i]
        } else {
            #Write-Host ($vm.Name + " - " + $nic.Name)
            $alloc = $NicIpConfigurations
        }

        if ($alloc -ne "Static") {
            Write-Host ($vm.Name + " - " + $nic.Name + " changed from Dynamic to Static")
            $item = Get-AzNetworkInterface -ResourceGroupName $nic.ResourceGroupName -Name $nic.Name
            $item.IpConfigurations[$i].PrivateIpAllocationMethod = "Static"
            Set-AzNetworkInterface -NetworkInterface $item
        }
    }
}

# End
Write-Host ("`nCompleted`n") -ForegroundColor Yellow