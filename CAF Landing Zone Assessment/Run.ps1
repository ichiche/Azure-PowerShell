# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$Global:ExcelFullPath = "C:\Temp\CAF-Assessment.xlsx" # Export Result to Excel file 

# Run-Script Configuration
$GetDiagnosticSetting = $true
$GetRedisNetworkIsolation = $true

# Script Variable
$Global:Assessment = @()

# Login
$AzLogin = az login | Out-Null
$ConnectAzAccount = Connect-AzAccount | Out-Null

# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    $Global:Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    $Global:Subscriptions = Get-AzSubscription
}

# Get the Latest Location Name and Display Name
$Global:NameReference = Get-AzLocation

# Module
Import-Module ImportExcel

# Main
Write-Host "`nCAF Landing Zone Assessment have been started ..." -ForegroundColor Yellow
Write-Host "`nThis process may take more than 15 minutes ..." -ForegroundColor Yellow
Write-Host "`nPlease wait until it finishes ..." -ForegroundColor Yellow

if ($GetDiagnosticSetting) {
    Write-Host "`nCollecting Diagnostic Setting" -ForegroundColor Cyan
    & .\Get-DiagnosticSetting.ps1
}

if ($GetRedisNetworkIsolation) {
    Write-Host "`nCollecting Azure Cache for Redis Network Configuration" -ForegroundColor Cyan
    & .\Get-Redis-NetworkIsolation.ps1
}

# End
Write-Host "`nCAF Landing Zone Assessment have been completed" -ForegroundColor Yellow
Write-Host ("`nPlease refer to the Assessment Result locate at " + $Global:ExcelFullPath)-ForegroundColor Yellow
Write-Host "`n"



