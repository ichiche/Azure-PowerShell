# Global Parameter
$importedSubnets = Import-Csv ./AllowedNetwork.csv
$kvs = Import-Csv ./kvs.csv 
$AllowedIpAddressRange = ("8.8.8.8","8.8.4.4")

# Script Variable
$RequiredServiceEndpoint = "Microsoft.KeyVault"
$currentSubscriptionId = ""
$AllowedSubnetId = @()
$kvs = $kvs | Sort-Object SubscriptionId


# Main
$StartTime = Get-Date
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Virtual Network Subnet Detail
foreach ($importedSubnet in $importedSubnets) {
    $AllowedSubnetId += $importedSubnet.SubnetId
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $importedSubnet.ResourceGroupName -Name $importedSubnet.VNetName

    # Get Subnet Config
    $SubnetConfigs = Get-AzVirtualNetworkSubnetConfig -Name $importedSubnet.SubnetName -VirtualNetwork $vnet 
    foreach ($SubnetConfig in $SubnetConfigs) {
        Write-Host ("Subnet: " + $SubnetConfig.Name + " of Virtual Network: " + $vnet.Name)
        
        if ($SubnetConfig.ServiceEndpoints.Service -notcontains $RequiredServiceEndpoint) {
            $NextServiceEndpoint = @()
            $NextServiceEndpoint += $SubnetConfig.ServiceEndpoints.Service
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

    Write-Host ("Proceeding " + $kv.Name)
    Update-AzKeyVaultNetworkRuleSet -ResourceGroupName $kv.ResourceGroup -VaultName $kv.Name -VirtualNetworkResourceId $AllowedSubnetId -IpAddressRange $AllowedIpAddressRange -DefaultAction Deny -Bypass AzureServices -PassThru -Confirm:$false | Out-Null
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
