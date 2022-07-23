# Global Parameter
$Location = "East Asia"
$AppGatewayRG = "AppGateway"
$AppGatewayName ="agw-core-prd-eas-001"
$skuName = "Standard_v2"
$skuTier = "Standard_v2"
$pipName = "pip-agw-core-prd-eas-001"
$HubVNetRG = "Network"
$HubVNetName = "vnet-hub-prd-eas-001"
$AppGatewaySubnetName = "snet-appgateway-001"
$logIsExist = $true
$logRG = "Log"
$logName = "log-analytics-temp-prd-sea-001"

# Main
$StartTime = Get-Date
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

#Region Resource Group
Write-Host "`nProvision Resource Group ..." -ForegroundColor Cyan

# Create Resource Group if not exist
$IsExist = Get-AzResourceGroup -Name $AppGatewayRG -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($IsExist)) {
    New-AzResourceGroup -Name $AppGatewayRG -Location $Location | Out-Null
    Write-Host ("Resource Group " + $AppGatewayRG + " is created") 
} else {
    Write-Host ("Resource Group " + $AppGatewayRG + " already exist") -ForegroundColor Yellow
}
Start-Sleep -Seconds 5
#EndRegion Resource Group

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

# Backend Http Setting
# If Redirection Rule is specified, Backend Http Setting is not required using Azure Portal, but still require using Az Module
$BackendHttpSetting = New-AzApplicationGatewayBackendHttpSetting -Name "DefaultBackendHttpSetting" -Port 80 -Protocol Http -CookieBasedAffinity Enabled -RequestTimeout 30

# Http Listener
$HttpListener = New-AzApplicationGatewayHttpListener -Name "DefaultHttpListener" -Protocol Http -FrontendIPConfiguration $FrontendIpConfig -FrontendPort $FrontendPort

# Request Routing Rule
$RoutingRule = New-AzApplicationGatewayRequestRoutingRule -Name "DefaultRoutingRule"-RuleType Basic -HttpListener $HttpListener -BackendAddressPool $BackendAddressPool -BackendHttpSettings $BackendHttpSetting 

# Application Gateway Sku
$sku = New-AzApplicationGatewaySku -Name $skuName -Tier $skuTier

# Application Gateway Auto Scale
$autoscaleConfig = New-AzApplicationGatewayAutoscaleConfiguration -MinCapacity 1 -MaxCapacity 3

# Provision Application Gateway
$agw = New-AzApplicationGateway -ResourceGroupName $AppGatewayRG -Name $AppGatewayName `
    -Location $Location `
    -AutoscaleConfiguration $autoscaleConfig `
    -GatewayIpConfigurations $IpConfiguration `
    -FrontendIpConfigurations $FrontendIpConfig `
    -FrontendPorts $FrontendPort `
    -BackendAddressPools $BackendAddressPool `
    -BackendHttpSettingsCollection $BackendHttpSetting `
    -HttpListeners $HttpListener `
    -RequestRoutingRules $RoutingRule `
    -Sku $sku `
    -Zone "1","2","3"
#EndRegion Application Gateway

#Region Log Analytics Workspace
if ($logIsExist) {
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName
    
} else {
    # Sku pergb2018 is Pay-as-you-go pricing tier
    $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName -Sku pergb2018 -Location $Location
    Start-Sleep -Seconds 15
}

# Enable all metrics and logs for a resource
$DiagnosticSetting = Set-AzDiagnosticSetting -Name "DiagnosticEnabled" -ResourceId $agw.Id -WorkspaceId $workspace.ResourceId -Enabled $true
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
Remove-AzApplicationGateway -ResourceGroupName $AppGatewayRG -Name $AppGatewayName -Force -Confirm:$false
Start-Sleep -Seconds 15
Remove-AzPublicIpAddress -ResourceGroupName $AppGatewayRG -Name $pipName -Force -Confirm:$false
Remove-AzResourceGroup -Name $AppGatewayRG -Force -Confirm:$false
Remove-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName -Force -Confirm:$false
#EndRegion Decommission