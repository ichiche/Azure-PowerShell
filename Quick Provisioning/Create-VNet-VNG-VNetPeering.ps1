# Global Parameter
$Location = "East Asia"
$HubRG = "rg-hub-eas-hub01"
$HubVNetName = "vnet-hub-quickstart-eas-001"
$SpokeRG = "rg-spoke-pd-eas-app01"
$SpokeVNetName = "vnet-spoke-quickstart-eas-001"
$VngName = "vng-quickstart-prd-eas-001"
$GatewayType = "Vpn" # Vpn or ExpressRoute
$pipName = "pip-vng-quickstart-prd-eas-001"

# Main
$StartTime = Get-Date

#Region Resource Group
Write-Host "`nProvision Resource Group ..." -ForegroundColor Cyan
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Create Resource Group if not exist
$IsExist = Get-AzResourceGroup -Name $HubRG -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($IsExist)) {
    New-AzResourceGroup -Name $HubRG -Location $Location | Out-Null
    Write-Host ("Resource Group " + $HubRG + " is created") 
} else {
    Write-Host ("Resource Group " + $HubRG + " already exist") -ForegroundColor Yellow
}

$IsExist = Get-AzResourceGroup -Name $SpokeRG -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($IsExist)) {
    New-AzResourceGroup -Name $SpokeRG -Location $Location | Out-Null
    Write-Host ("Resource Group " + $SpokeRG + " is created") 
} else {
    Write-Host ("Resource Group " + $SpokeRG + " already exist") -ForegroundColor Yellow
}
Start-Sleep -Seconds 2
#EndRegion Resource Group

#Region Virtual Network
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Hub Virtual Network
Write-Host "`Prepare Subnet: GatewaySubnet ..." -ForegroundColor Cyan
$GatewaySubnet = New-AzVirtualNetworkSubnetConfig -Name GatewaySubnet -AddressPrefix "10.80.251.0/24"
Start-Sleep -Milliseconds 200
Write-Host "`nProvision Hub Virtual Network ..." -ForegroundColor Cyan
$HubVirtualNetwork = New-AzVirtualNetwork -ResourceGroupName $HubRG -Name $HubVNetName -Location $Location -AddressPrefix "10.81.0.0/22","10.80.251.0/24" -Subnet $GatewaySubnet

# Spoke Virtual Network
Write-Host "`nPrepare Subnet: ApplicationGatewaySubnet ..." -ForegroundColor Cyan
$SpokeSubnet1 = New-AzVirtualNetworkSubnetConfig -Name ApplicationGatewaySubnet -AddressPrefix "10.81.20.64/26"
Start-Sleep -Milliseconds 200
Write-Host "`nProvision Spoke Virtual Network ..." -ForegroundColor Cyan
$SpokeVirtualNetwork = New-AzVirtualNetwork -ResourceGroupName $SpokeRG -Name $SpokeVNetName -Location $Location -AddressPrefix "10.81.20.0/22" -Subnet $SpokeSubnet1
#EndRegion Virtual Network

#Region Public IP Address
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Public IP Address for Virtual Network Gateway ..." -ForegroundColor Cyan
$pip = New-AzPublicIpAddress -ResourceGroupName $HubRG -Name $pipName -AllocationMethod Static -Location $Location -Sku Standard -Zone (1,2,3)
Start-Sleep -Seconds 30
#EndRegion Public IP Address

#Region Virtual Network Gateway
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
$VngIpConfig = New-AzVirtualNetworkGatewayIpConfig -Name "VngIpConfig" -SubnetId ($HubVirtualNetwork.Subnets | ? {$_.Name -eq "GatewaySubnet"}).Id -PublicIpAddressId $pip.Id
Start-Sleep -Milliseconds 200

# Require to provision in same resource group where Virtual Network with Gateway Subnet exist
# Public IP Address of VNG can be located in different resource group
if ($GatewayType -eq "ExpressRoute") {
    Write-Host "`nProvision ExpressRoute Virtual Network Gateway ..." -ForegroundColor Cyan
    $Vng = New-AzVirtualNetworkGateway -ResourceGroupName $HubRG -Name $VngName -Location $Location -IpConfigurations $VngIpConfig -GatewayType ExpressRoute -GatewaySku ErGw1AZ
    Start-Sleep -Seconds 30
} else {
    Write-Host "`nProvision VPN Virtual Network Gateway ..." -ForegroundColor Cyan
    $Vng = New-AzVirtualNetworkGateway -ResourceGroupName $HubRG -Name $VngName -Location $Location -IpConfigurations $VngIpConfig -GatewayType Vpn -GatewaySku VpnGw1AZ -VpnType "RouteBased"
    Start-Sleep -Seconds 30
}
#EndRegion Virtual Network Gateway

#Region Virtual Network Peering
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Get Virtual Network Instance
$HubVNet = Get-AzVirtualNetwork -ResourceGroup $HubRG -Name $HubVirtualNetwork.Name
$SpokeVNet = Get-AzVirtualNetwork -ResourceGroup $SpokeRG -Name $SpokeVirtualNetwork.Name

# Setup Virtual Network Peering
Write-Host ("`nAdd Peering between " + $HubVNet.Name + " and " + $SpokeVNet.Name) -ForegroundColor Cyan
Add-AzVirtualNetworkPeering -Name ("Peered-to-" + $SpokeVNet.Name) -VirtualNetwork $HubVNet -RemoteVirtualNetworkId $SpokeVNet.Id -AllowGatewayTransit -AllowForwardedTraffic | Out-Null
Start-Sleep -Milliseconds 200
Add-AzVirtualNetworkPeering -Name ("Peered-to-" + $HubVNet.Name) -VirtualNetwork $SpokeVNet -RemoteVirtualNetworkId $HubVNet.Id -UseRemoteGateways -AllowForwardedTraffic | Out-Null
Start-Sleep -Seconds 15

# Verification
$Result = Get-AzVirtualNetworkPeering -ResourceGroupName $HubRG -VirtualNetworkName $HubVNet.Name -Name ("Peered-to-" + $SpokeVNet.Name) 
if ($Result.PeeringState -ne "Connected") {
    Write-Host "Peering state is failed" -ForegroundColor Yellow
} 
Start-Sleep -Seconds 1
#EndRegion Virtual Network Peering

# End
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCompleted"
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor White -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host "`n`n"

#Region Decommission
Remove-AzVirtualNetworkGateway -ResourceGroupName $HubRG -Name $VngName -Force -Confirm:$false
Start-Sleep -Seconds 10
Remove-AzPublicIpAddress -ResourceGroupName $HubRG -Name $pipName -Force -Confirm:$false
Remove-AzResourceGroup -Name $HubRG -Force -Confirm:$false
Remove-AzResourceGroup -Name $SpokeRG -Force -Confirm:$false
#EndRegion Decommission