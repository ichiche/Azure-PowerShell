# Global Parameter
$TenantId = "2bd50c63-c7a7-4718-897e-9c1600a37b66" # Riwhisper
$Subscriptions = Get-AzSubscription -TenantId $TenantId -SubscriptionId "5ba60130-b60b-4c4b-8614-06a0c6723d9b"


$TenantId = "97f55d35-1929-4acf-9c11-d7aaf05b6756" # MTR
$Subscriptions = Get-AzSubscription -TenantId $TenantId | ? {$_.Name -like "DEA*"}

$Subscriptions = Get-AzSubscription

[int]$CurrentItem = 0
foreach ($Subscription in $Subscriptions) {
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id 
    $CurrentItem++
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0,$AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow

    $AppGateways = Get-AzApplicationGateway

    foreach ($AppGateway in $AppGateways) {
        [array]$array = $AppGateway.Zones

        if ($array.Count -eq 0) {
            Write-Host ($AppGateway.Name + " not enabled Zone Redundant")
        } else {
            Write-Host ($AppGateway.Name + " enabled Zone Redundant in Zone $array")
        }
    }
}   
