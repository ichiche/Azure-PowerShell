# Global Parameter
$Location = "Southeast Asia"
$AppGatewayRG = "AppGateway"
$AppGatewayName ="agw-core-prd-sea-001"
$pipName = "pip-agw-core-prd-sea-001"
$HubVNetRG = "Network"
$HubVNetwork = "vnet-hub-prd-sea-001"
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

#Region Azure Application Gateway
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Azure Application Gateway ..." -ForegroundColor Cyan
#EndRegion Azure Firewall

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