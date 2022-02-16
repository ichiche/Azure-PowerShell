# Global Parameter
$importedSubnet = Import-Csv ./AllowedNetwork.csv
$kvs = Import-Csv ./kvs.csv 
$AllowedIpAddressRange = ("8.8.8.8","8.8.4.4")

# Script Variable
$AllowedSubnetId = @()
$kvs = $kvs | Sort-Object SubscriptionId
$currentSubscriptionId = ""

# Main
$StartTime = Get-Date
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Virtual Network Subnet Detail
foreach ($subnet in $importedSubnet ) {
    $AllowedSubnetId += $subnet.SubnetId
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
