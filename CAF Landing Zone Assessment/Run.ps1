# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$Global:ExcelFullPath = "C:\Temp\CAF-Assessment.xlsx" # Export Result to Excel file 

# Run-Script Configuration
$GetDiagnosticSetting = $true
$GetRedisNetworkIsolation = $true
$GetClassicResource = $true

function Update-RunScriptList {
    param(
        $RunScript,
        $Command
    )

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "RunScript" -Value $RunScript
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Command" -Value $Command
    $Global:RunScriptList += $obj
}

# Script Variable
$Global:Assessment = @()
$Global:RunScriptList = @()

# Login
#$AzLogin = az login | Out-Null
#$ConnectAzAccount = Connect-AzAccount | Out-Null

# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    #$Global:Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    #$Global:Subscriptions = Get-AzSubscription
}

# Get the Latest Location Name and Display Name
$Global:NameReference = Get-AzLocation

# Module
Import-Module ImportExcel

# Banner
Write-Host "`n`n"
& .\ConvertTo-TextASCIIArt.ps1 -Text "CAF Landing Zone" -FontName jazmine -FontColor White
Start-Sleep -Seconds 5

# Determine Run-Script
Write-Host "`n`n"
Write-Host "Enabled RunScript:" -ForegroundColor Green -BackgroundColor Black

if ($GetDiagnosticSetting) {
    Write-Host "Collect Diagnostic Setting" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetDiagnosticSetting" -Command "& .\Get-DiagnosticSetting.ps1"
}  

if ($GetRedisNetworkIsolation) {
    Write-Host "Collect Azure Cache for Redis Network Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetRedisNetworkIsolation" -Command "& .\Get-Redis-NetworkIsolation.ps1"
}

if ($GetClassicResource) {
    Write-Host "Get the list of Classic Resources" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetClassicResource" -Command "& .\Get-Classic-Resource.ps1"
}

Start-Sleep -Seconds 5

# Startup Message
Write-Host "`n`n"
Write-Host ("*" * 60)
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" + " " * 7 + "Microsoft Cloud Adoption Framework for Azure" + " " * 7 + "*")
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" + " " * 58 + "*")
Write-Host ("*" * 60)
Write-Host "`nThe process may take more than 15 minutes ..."
Write-Host "`nPlease wait until it finishes ..."

# Execute Run Script using RunspacePool
foreach ($RunScript in $Global:RunScriptList) {
    Invoke-Expression -Command $RunScript.Command
}

# End
Write-Host "`nCAF Landing Zone Assessment have been completed"
Start-Sleep -Seconds 2
Write-Host ("`nPlease refer to the Assessment Result locate at " + $Global:ExcelFullPath)
Write-Host "`n"