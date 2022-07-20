# Global Parameter
$Location = "East Asia"
$FirewallPolicyRG = "FirewallPolicy"
$FirewallPolicyName = "afwpol-core-prd-sea-001"
$FirewallName = "afw-core-prd-sea-001"
$pipName1 = "pip-afw-core-prd-eas-001"
$ForcedTunnelingEnabled = $false
$pipForcedTunneling = "pip-afwmgmt-core-prd-eas-001"
$HubVNetRG = "Network"
$HubVNetName = "vnet-hub-prd-sea-001"
$logIsExist = $true
$logRG = "Log"
$logName = "log-analytics-temp-prd-sea-001"

# Main
$StartTime = Get-Date

#Region Resource Group
Write-Host "`nProvision Resource Group ..." -ForegroundColor Cyan

# Create Resource Group if not exist
$IsExist = Get-AzResourceGroup -Name $FirewallPolicyRG -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($IsExist)) {
    New-AzResourceGroup -Name $FirewallPolicyRG -Location $Location | Out-Null
    Write-Host ($FirewallPolicyRG + " is created") 
} else {
    Write-Host ($FirewallPolicyRG + " already exist") -ForegroundColor Yellow
}
Start-Sleep -Seconds 5
#EndRegion Resource Group

#Region Azure Firewall Policy 
# Policies are billed based on firewall associations. 
# A policy with zero or one firewall association is free of charge. 
# A policy with multiple firewall associations is billed at a fixed rate. 
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Azure Firewall Policy ..." -ForegroundColor Cyan
$fwpol = New-AzFirewallPolicy -ResourceGroupName $FirewallPolicyRG -Name $FirewallPolicyName -SkuTier Standard -Location $Location
$FirewallPolicyId = $fwpol.Id
Start-Sleep -Seconds 10
#EndRegion Azure Firewall Policy 

#Region Azure Firewall Network Rule
# Priority of New-AzFirewallPolicyRuleCollectionGroup and Set-AzFirewallPolicyRuleCollectionGroup for same RCG should be same
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Network Rule of Azure Firewall Policy ..." -ForegroundColor Cyan
$rcgroup = New-AzFirewallPolicyRuleCollectionGroup -Name "RootCollectionGroup" -Priority 200 -FirewallPolicyObject $fwpol
$netrule = New-AzFirewallPolicyNetworkRule -name Allow-Any-Any -Protocol ("Any", "TCP", "UDP", "ICMP") -SourceAddress "10.10.0.0/16" -DestinationAddress "*" -DestinationPort "*"
$netcol = New-AzFirewallPolicyFilterRuleCollection -Name "SharedPlatformRuleCollection" -Priority 300 -Rule $netrule -ActionType "Allow"
Set-AzFirewallPolicyRuleCollectionGroup -Name $rcgroup.Name -Priority 200 -RuleCollection $netcol -FirewallPolicyObject $fwpol 
#EndRegion Azure Firewall Network Rule

#Region Public IP Address
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Public IP Address for Azure Firewall ..." -ForegroundColor Cyan
$pip = New-AzPublicIpAddress -ResourceGroupName $FirewallPolicyRG -Name $pipName1 -AllocationMethod Static -Location $Location -Sku Standard -Zone (1,2,3)
Start-Sleep -Seconds 5

if ($ForcedTunnelingEnabled) {
    Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    Write-Host "`nProvision Public IP Address for Azure Firewall Forced Tunneling ..." -ForegroundColor Cyan
    $mgmtpip = New-AzPublicIpAddress -ResourceGroupName $FirewallPolicyRG -Name $pipForcedTunneling -AllocationMethod Static -Location $Location -Sku Standard -Zone (1,2,3)
    Start-Sleep -Seconds 5
}
#EndRegion Public IP Address

#Region Azure Firewall
Write-Host ("`n[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`nProvision Azure Firewall ..." -ForegroundColor Cyan
$HubVNet = Get-AzVirtualNetwork -ResourceGroup $HubVNetRG -Name $HubVNetName
if ($ForcedTunnelingEnabled) {
    $afw = New-AzFirewall -ResourceGroupName $HubVNetRG -Name $FirewallName -Location $Location -VirtualNetwork $HubVNet -PublicIpAddress $pip -ManagementPublicIpAddress $mgmtpip -FirewallPolicyId $FirewallPolicyId -Zone 1,2,3
} else {
    $afw = New-AzFirewall -ResourceGroupName $HubVNetRG -Name $FirewallName -Location $Location -VirtualNetwork $HubVNet -PublicIpAddress $pip -FirewallPolicyId $FirewallPolicyId -Zone 1,2,3
}
#EndRegion Azure Firewall

#Region Log Analytics Workspace
if ($logIsExist) {
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName
    
} else {
    # Sku pergb2018 is Pay-as-you-go pricing tier
    $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName -Sku pergb2018 -Location $Location
    Start-Sleep -Seconds 15
}

# Enable all metrics and logs for a resource
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
Remove-AzFirewall -ResourceGroupName $HubVNetRG -Name $FirewallName -Force -Confirm:$false
Start-Sleep -Seconds 10
Remove-AzFirewallPolicy -ResourceGroupName $FirewallPolicyRG -Name $FirewallPolicyName -Force -Confirm:$false
Remove-AzPublicIpAddress -ResourceGroupName $FirewallPolicyRG -Name $pipName -Force -Confirm:$false
if ($ForcedTunnelingEnabled) {
    Remove-AzPublicIpAddress -ResourceGroupName $FirewallPolicyRG -Name $pipForcedTunneling -Force -Confirm:$false
}
Remove-AzOperationalInsightsWorkspace -ResourceGroupName $logRG -Name $logName -Force -Confirm:$false
#EndRegion Decommission