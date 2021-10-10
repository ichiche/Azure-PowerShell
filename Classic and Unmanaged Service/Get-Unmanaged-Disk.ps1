# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$CsvFullPath = "C:\Temp\Azure-Unmanaged-Disk.csv" # Export Result to CSV file 

# Script Variable
$Global:UnmanagedDisks = @()
$CurrentItem = 1

# Login
az login # For Azure CLI
Start-Sleep -Seconds 10
Connect-AzAccount

# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    $Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    $Subscriptions = Get-AzSubscription
}

# Main
foreach ($Subscription in $Subscriptions) {
    # Set current subscription for Az Module
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id

    # Set current subscription for Azure CLI
    az account set --subscription $Subscription.Id

    # Main
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow
    $CurrentItem++
    $CurrentVMItem = 1
    $vms = Get-AzVM

    foreach ($vm in $vms) {
        Write-Host ("`nProcessing Azure VM (" + $CurrentVMItem + " out of " + $vms.Count + ") of Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("("))) -ForegroundColor White
        $CurrentVMItem++

        # OS Disk
        if ($vm.StorageProfile.OsDisk.ManagedDisk -eq $null) {
            # Save to Temp Object
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VM" -Value $vm.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskName" -Value $vm.StorageProfile.OsDisk.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskType" -Value "OS Disk"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VhdUri" -Value $vm.StorageProfile.OsDisk.Vhd.Uri

            # Save to Array
            $Global:UnmanagedDisks += $obj
        }

        # Data Disk
        $VmDisks = az vm unmanaged-disk list -g $vm.ResourceGroupName --vm-name $vm.Name
        $VmDisks = $VmDisks | ConvertFrom-Json
        foreach ($VmDisk in $VmDisks) {
            if ($VmDisk.managedDisk -eq $null) {
                # Save to Temp Object
                $obj = New-Object -TypeName PSobject
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "VM" -Value $vm.Name
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskName" -Value $VmDisk.Name
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskType" -Value "Data Disk"
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "VhdUri" -Value $VmDisk.vhd.uri

                # Save to Array
                $Global:UnmanagedDisks += $obj
            }
        }
    }
}

# Export Result to CSV file
$Global:UnmanagedDisks | sort SubscriptionName, ResourceGroup, VM | Export-Csv -Path $CsvFullPath -NoTypeInformation -Confirm:$false -Force 

# End
Write-Host "`nCompleted" -ForegroundColor Yellow
Write-Host ("`nCount of Unmanaged Disk: " + $Global:UnmanagedDisks.Count) -ForegroundColor Cyan
Write-Host "`n"

# Logout
Disconnect-AzAccount