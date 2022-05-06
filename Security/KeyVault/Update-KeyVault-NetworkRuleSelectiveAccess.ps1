# Global Parameter
$AllowedNetworks = Import-Csv ./AllowedNetwork.csv
$kvs = Import-Csv ./KeyVault.csv
$AllowedIpAddressRange = ("8.8.8.8","8.8.4.4")
$AllowTrustedMicrosoftServices = $false

# Script Variable
$RequiredServiceEndpoint = "Microsoft.KeyVault"
$currentSubscriptionId = ""
$AllowedSubnetId = @()
$AllowedNetworks = $AllowedNetworks | Sort-Object SubscriptionId
$kvs = $kvs | Sort-Object SubscriptionId

# Main
$StartTime = Get-Date
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Virtual Network Subnet Detail
foreach ($AllowedNetwork in $AllowedNetworks) {
    if ($currentSubscriptionId -ne $AllowedNetwork.SubscriptionId) {
        $currentSubscriptionId = $AllowedNetwork.SubscriptionId
        $context = Set-AzContext -SubscriptionId $currentSubscriptionId
        Write-Host ("`nCurrent Subscription: " + $AllowedNetwork.SubscriptionName) -ForegroundColor Cyan
    }

    $vnet = Get-AzVirtualNetwork -ResourceGroupName $AllowedNetwork.ResourceGroup -Name $AllowedNetwork.VNetName

    # Get Subnet Config
    $SubnetConfigs = Get-AzVirtualNetworkSubnetConfig -Name $AllowedNetwork.SubnetName -VirtualNetwork $vnet 
    foreach ($SubnetConfig in $SubnetConfigs) {
        Write-Host ("`nSubnet: " + $SubnetConfig.Name + " of Virtual Network: " + $vnet.Name)
        $AllowedSubnetId += $SubnetConfig.Id
        
        if ($SubnetConfig.ServiceEndpoints.Service -notcontains $RequiredServiceEndpoint) {
            $NextServiceEndpoint = @()

            if ($SubnetConfig.ServiceEndpoints.Service.Count -gt 0) {
                $NextServiceEndpoint += $SubnetConfig.ServiceEndpoints.Service
            }
            $NextServiceEndpoint += $RequiredServiceEndpoint
            Write-Host "Adding $RequiredServiceEndpoint ..."
            Set-AzVirtualNetworkSubnetConfig -Name $SubnetConfig.Name -VirtualNetwork $vnet -AddressPrefix $SubnetConfig.AddressPrefix -ServiceEndpoint $NextServiceEndpoint | Out-Null
        }
    }
    $vnet | Set-AzVirtualNetwork | Out-Null
}

# Allow public access from specific virtual networks and IP addresses
foreach ($kv in $kvs) {
    if ($currentSubscriptionId -ne $kv.SubscriptionId) {
        $currentSubscriptionId = $kv.SubscriptionId
        $context = Set-AzContext -SubscriptionId $currentSubscriptionId
        Write-Host ("`nCurrent Subscription: " + $kv.SubscriptionName) -ForegroundColor Cyan
    }

    Write-Host ("`nProceeding " + $kv.VaultName)
    if ($AllowTrustedMicrosoftServices) {
        Update-AzKeyVaultNetworkRuleSet -ResourceGroupName $kv.ResourceGroup -VaultName $kv.VaultName -VirtualNetworkResourceId $AllowedSubnetId -IpAddressRange $AllowedIpAddressRange -DefaultAction Deny -Bypass AzureServices -PassThru -Confirm:$false | Out-Null
    } else {
        Update-AzKeyVaultNetworkRuleSet -ResourceGroupName $kv.ResourceGroup -VaultName $kv.VaultName -VirtualNetworkResourceId $AllowedSubnetId -IpAddressRange $AllowedIpAddressRange -DefaultAction Deny -Bypass None -PassThru -Confirm:$false | Out-Null
    }
}

# End
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCompleted"
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor Blue -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host "`n`n"