# Global Parameter
$Location = "Southeast Asia"
$AppGatewayRG = "AppGateway"
$AppGatewayName ="agw-core-prd-sea-001"
$pipName = "pip-agw-core-prd-sea-001"
$HubVNetRG = "Network"
$HubVNetName = "vnet-hub-prd-sea-001"
$AppGatewaySubnetName = "AppGateway"
$logRG = "Log"
$logName = "log-analytics-temp-prd-sea-001"

# Main
$StartTime = Get-Date

#Region Public IP Address
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Public IP Address for Azure Application Gateway ..." -ForegroundColor Cyan
$pip = New-AzPublicIpAddress -ResourceGroupName $AppGatewayRG -Name $pipName -AllocationMethod Static -Location $Location -Sku Standard -Zone (1,2,3)
Start-Sleep -Seconds 10
#EndRegion Public IP Address

#Region Application Gateway
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Azure Application Gateway ..." -ForegroundColor Cyan

$HubVNet = Get-AzVirtualNetwork -ResourceGroup $HubVNetRG -Name $HubVNetName
$AppGatewaySubnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $HubVNet -Name $AppGatewaySubnetName

# Frontend 
$IpConfiguration  = New-AzApplicationGatewayIPConfiguration -Name "DefaultIpConfiguration" -Subnet $AppGatewaySubnet
$FrontendIpConfig  = New-AzApplicationGatewayFrontendIPConfig -Name "DefaultFrontendIpConfig" -PublicIPAddress $pip
$FrontendPort  = New-AzApplicationGatewayFrontendPort -Name "DefaultFrontendPort" -Port 80

# Backend Pool without target
# At least 1 Backend Pool is needed 
$BackendAddressPool = New-AzApplicationGatewayBackendAddressPool -Name "DefaultBackendAddressPool"

# Http Listener
$HttpListener = New-AzApplicationGatewayHttpListener -Name "DefaultHttpListener" -Protocol Http -FrontendIPConfiguration $FrontendIpConfig -FrontendPort $FrontendPort

# Redirection Rule
# Redirect to Google DNS
# No Backend Http Setting is required 
$RedirectConfiguration = New-AzApplicationGatewayRedirectConfiguration -Name "DefaultRedirectConfiguration" -RedirectType Permanent -TargetUrl "http://8.8.8.8"
$RoutingRule = New-AzApplicationGatewayRequestRoutingRule -Name "DefaultRoutingRule"-RuleType Basic -HttpListener $HttpListener -RedirectConfiguration $RedirectConfiguration

# Application Gateway Sku
$sku = New-AzApplicationGatewaySku `
  -Name Standard_v2 `
  -Tier Standard_v2 `
  -Capacity 2

  $autoscaleConfig = New-AzApplicationGatewayAutoscaleConfiguration -MinCapacity 3
  $gw = New-AzApplicationGateway -Name $appgwName -ResourceGroupName $rgname ..  -AutoscaleConfiguration $autoscaleConfig

New-AzApplicationGateway `
  -Name myAppGateway `
  -ResourceGroupName myResourceGroupAG `
  -Location eastus `
  -BackendAddressPools $backendPool `
  -BackendHttpSettingsCollection $poolSettings `
  -FrontendIpConfigurations $fipconfig `
  -GatewayIpConfigurations $gipconfig `
  -FrontendPorts $frontendport `
  -HttpListeners $defaultlistener `
  -RequestRoutingRules $frontendRule `
  -Sku $sku

#EndRegion Application Gateway

#Region Log Analytics Workspace
# Standard Tier: Pricing tier doesn't match the subscription's billing model
$workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName -Sku pergb2018 -Location $Location
#$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName
Start-Sleep -Seconds 15
$DiagnosticSetting = Set-AzDiagnosticSetting -Name "log-analytics-prd-sea-001" -ResourceId $afw.Id -WorkspaceId $workspace.ResourceId -Enabled $true
#EndRegion Log Analytics Workspace

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCompleted"
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor White -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host "`n`n"

#Region Decommission
Remove-AzPublicIpAddress -ResourceGroupName $AppGatewayRG -Name $pipName -Force -Confirm:$false
Remove-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName -Force -Confirm:$false