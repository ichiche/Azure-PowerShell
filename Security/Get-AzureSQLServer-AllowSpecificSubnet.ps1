# Retrieve the list of Azure SQL Server that allow specific Virtual Network Subnet. 
# Global Parameter
$TargetVNetName = ""
$TargetVNetSubnetName = ""
$TenantId = "" 
$SubscriptionName = ""

# Script Variable
$Global:SqlServerList = @()
$VirtualNetworkRuleList = @()
[int]$CurrentItem = 1

# Login
Connect-AzAccount -TenantId $TenantId 

# Get Azure Subscription
$Subscriptions = Get-AzSubscription -TenantId $TenantId | ? {$_.Name -like "*$SubscriptionName*"}

# Main
Write-Host "`nThe process has been started" -ForegroundColor Yellow

foreach ($Subscription in $Subscriptions) {
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow
    $CurrentItem++

    $SqlServers = Get-AzSqlServer
    if ($SqlServers.Count -ne 0 -and $SqlServers -ne $null) {
        Write-Host ("`nProcessing " + $SqlServers.Count + " Azure SQL Server(s)")
    
        foreach ($SqlServer in $SqlServers) {
            $VirtualNetworkRuleList += Get-AzSqlServerVirtualNetworkRule -ResourceGroupName $SqlServer.ResourceGroupName -ServerName $SqlServer.ServerName | ? {$_.VirtualNetworkSubnetId.ToString() -like "*$TargetVNetName*" -and $_.VirtualNetworkSubnetId.ToString() -like "*$TargetVNetSubnetName*"}
        }
    }
}

$servers = $VirtualNetworkRuleList | select -unique ServerName

# End
Write-Host "`nCompleted" -ForegroundColor Yellow
Write-Host "`nList of Azure SQL Server that allow $TargetVNetSubnetName :" -ForegroundColor Cyan
foreach ($server in $servers) {
    Write-Host $server.ServerName
}
Write-Host ("`nCount of Azure SQL Server that allow $TargetVNetSubnetName : " + $servers.Count) -ForegroundColor Cyan
Write-Host "`n"