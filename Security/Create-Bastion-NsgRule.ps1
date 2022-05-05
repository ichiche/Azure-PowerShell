# Global Parameter
$NsgName = "nsg-bastion"
$NsgRG = "Network"

# Login
Connect-AzAccount

# Get Azure Subscription
$Subscriptions = Get-AzSubscription | ? {$_.State -eq "Enabled"}

# Main
Set-AzContext -SubscriptionId $Subscription.Id # Specify target subscription

# Get the NSG resource
$nsg = Get-AzNetworkSecurityGroup -Name $NsgName -ResourceGroupName $NsgRG

# Add custom rule
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Inbound -Priority 120 -Access Allow -Name "AllowHttpsInbound" -Protocol TCP -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Inbound -Priority 130 -Access Allow -Name "AllowGatewayManagerInbound" -Protocol TCP -SourceAddressPrefix GatewayManager -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Inbound -Priority 140 -Access Allow -Name "AllowAzureLoadBalancerInbound" -Protocol TCP -SourceAddressPrefix AzureLoadBalancer -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Inbound -Priority 150 -Access Allow -Name "AllowBastionHostCommunication" -Protocol * -SourceAddressPrefix VirtualNetwork -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 8080,5701
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Outbound -Priority 100 -Access Allow -Name "AllowSshRdpOutbound" -Protocol * -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 22,3389
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Outbound -Priority 110 -Access Allow -Name "AllowAzureCloudOutbound" -Protocol TCP -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix AzureCloud -DestinationPortRange 443
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Outbound -Priority 120 -Access Allow -Name "AllowBastionCommunication" -Protocol * -SourceAddressPrefix VirtualNetwork -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 8080,5701
$nsg | Add-AzNetworkSecurityRuleConfig -Direction Outbound -Priority 130 -Access Allow -Name "AllowGetSessionInformation" -Protocol * -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix Internet -DestinationPortRange 80

# Update the NSG
$nsg | Set-AzNetworkSecurityGroup

# End
Write-Host "`nCompleted`n" -ForegroundColor Yellow