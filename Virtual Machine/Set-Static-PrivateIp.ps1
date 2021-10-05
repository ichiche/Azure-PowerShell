
# Azure RM Module
$info = @()
$vms = Get-AzureRmVM | sort Name
$nics = Get-AzureRmNetworkInterface | ? {$_.VirtualMachine -ne $null} | sort Name  #skip Nics with no VM

foreach($nic in $nics)
{
    $vm = $vms | ? {$_.Id -eq $nic.VirtualMachine.id}
    $prv =  $nic.IpConfigurations | select -ExpandProperty PrivateIpAddress
    $alloc =  $nic.IpConfigurations | select -ExpandProperty PrivateIpAllocationMethod

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Name" -Value $($vm.Name)
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "IpAddress" -Value $prv
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Network Interface" -Value $nic.Name
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value $alloc
    $info += $obj
}

$info = $info | sort Name
$info | Export-Csv C:\Temp\ARMVM.csv -NoTypeInformation -Force -Confirm:$false

# Az Module
$vms = Get-AzVM -Status | sort Name # Contain Network Interface Info
$vms = $vms | ? {$classicVMInfo.Name -contains $_.Name} # Gather information of imported list for Classic VM
$nics = Get-AzNetworkInterface  | ? {$_.VirtualMachine -ne $null} | sort Name #skip Nics with no VM
$info = @()

foreach($nic in $nics)
{
    $vm = $vms | ? {$_.Id -eq $nic.VirtualMachine.id}
    $prv =  $nic.IpConfigurations | select -ExpandProperty PrivateIpAddress
    $alloc =  $nic.IpConfigurations | select -ExpandProperty PrivateIpAllocationMethod

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Name" -Value $($vm.Name)
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "IpAddress" -Value $prv
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Network Interface" -Value $nic.Name
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value $alloc
    $info += $obj
}

$info = $info | sort Name

# Compare
foreach ($item in $classicVMInfo) {
    $currentVM = $info | ? {$_.Name -eq $item.Name}

    if ($currentVM -ne $null) {
        [string]$currentVMIpAddress = $currentVM.IpAddress

        if ($item.IpAddress -ne $currentVMIpAddress) {
            Write-Host ($item.Name + " IP address not match")
        }
    } else {
        Write-Host ($item.Name + " not found")
    }
}


# Set PrivateIpAllocationMethod to Static
foreach($nic in $nics)
{
    $vm = $vms | ? {$_.Id -eq $nic.VirtualMachine.id}
    $alloc =  $nic.IpConfigurations | select -ExpandProperty PrivateIpAllocationMethod

    if ($alloc -ne "Static") {
        $Nic = Get-AzNetworkInterface -ResourceGroupName $nic.ResourceGroupName -Name $nic.Name
        $Nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
        Set-AzNetworkInterface -NetworkInterface $Nic
    }
}

