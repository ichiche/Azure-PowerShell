# Global Parameter
$Location = "East Asia"
$HubRG = "rg-gpsn01-pd-eas-hub01"
$DmzRG = "rg-gpsn01-pd-eas-dmz01"

# Main
$StartTime = Get-Date

#Region Virtual Network
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Hub Virtual Network
Write-Host "`Prepare Subnet: GatewaySubnet ..." -ForegroundColor Cyan
$GatewaySubnet = New-AzVirtualNetworkSubnetConfig -Name GatewaySubnet -AddressPrefix "10.82.251.0/26"
Start-Sleep -Milliseconds 200
Write-Host "`nProvision Hub Virtual Network ..." -ForegroundColor Cyan
$HubVirtualNetwork = New-AzVirtualNetwork -ResourceGroupName $HubRG -Name "vnet-gpsn01-pd-eas-hub-01" -Location $Location -AddressPrefix "10.81.0.0/22","10.82.251.0/26" -Subnet $GatewaySubnet

<#
Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $HubVirtualNetwork -Name "Temp" -AddressPrefix "10.81.0.0/24" | Out-Null
Write-Host ("`nAdd Subnet: " + "Temp") -ForegroundColor Cyan
Start-Sleep -Milliseconds 200
$HubVirtualNetwork | Set-AzVirtualNetwork | Out-Null
#>

# DMZ Virtual Network
Write-Host "`nPrepare Subnet: ApplicationGatewaySubnet ..." -ForegroundColor Cyan
$DmzSubnet1 = New-AzVirtualNetworkSubnetConfig -Name ApplicationGatewaySubnet -AddressPrefix "10.81.20.64/26"
Start-Sleep -Milliseconds 200
Write-Host "`nProvision DMZ Virtual Network ..." -ForegroundColor Cyan
$DmzVirtualNetwork = New-AzVirtualNetwork -ResourceGroupName $DmzRG -Name "vnet-gpsn01-pd-eas-dmz-01" -Location $Location -AddressPrefix "10.81.20.0/22" -Subnet $DmzSubnet1
#EndRegion Virtual Network

#Region Public IP Address
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Public IP Address for ExpressRoute Virtual Network Gateway ..." -ForegroundColor Cyan
$pip = New-AzPublicIpAddress -ResourceGroupName $HubRG -Name "pip-ergw-gpsn01-pd-eas-hub-01" -AllocationMethod Static -Location $Location -Sku Standard -Zone (1,2,3)
Start-Sleep -Seconds 30
#EndRegion Public IP Address

#Region ExpressRoute Virtual Network Gateway
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision ExpressRoute Virtual Network Gateway ..." -ForegroundColor Cyan
$VngIpConfig = New-AzVirtualNetworkGatewayIpConfig -Name "ergw-gpsn01-pd-eas-hub-01" -SubnetId ($HubVirtualNetwork.Subnets | ? {$_.Name -eq "GatewaySubnet"}).Id -PublicIpAddressId $pip.Id
Start-Sleep -Milliseconds 200
$Vng = New-AzVirtualNetworkGateway -ResourceGroupName $HubRG -Name "ergw-gpsn01-pd-eas-hub-01" -Location $Location -IpConfigurations $VngIpConfig -GatewayType ExpressRoute -GatewaySku ErGw1AZ
Start-Sleep -Seconds 30
#EndRegion ExpressRoute Virtual Network Gateway

#Region Virtual Network Peering
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Get Virtual Network Instance
$HubVNet = Get-AzVirtualNetwork -ResourceGroup $HubRG -Name $HubVirtualNetwork.Name
$DmzVNet = Get-AzVirtualNetwork -ResourceGroup $DmzRG -Name $DmzVirtualNetwork.Name

# Setup Virtual Network Peering
Write-Host ("`nAdd Peering between " + $HubVNet.Name + " and " + $DmzVNet.Name) -ForegroundColor Cyan
Add-AzVirtualNetworkPeering -Name ("Peered-to-" + $DmzVNet.Name) -VirtualNetwork $HubVNet -RemoteVirtualNetworkId $DmzVNet.Id -AllowGatewayTransit -AllowForwardedTraffic | Out-Null
Start-Sleep -Milliseconds 200
Add-AzVirtualNetworkPeering -Name ("Peered-to-" + $HubVNet.Name) -VirtualNetwork $DmzVNet -RemoteVirtualNetworkId $HubVNet.Id -UseRemoteGateways -AllowForwardedTraffic | Out-Null
Start-Sleep -Seconds 15

# Verification
$Result = Get-AzVirtualNetworkPeering -ResourceGroupName $HubRG -VirtualNetworkName $HubVNet.Name -Name ("Peered-to-" + $DmzVNet.Name) 
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