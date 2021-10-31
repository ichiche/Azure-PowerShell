# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$Global:ExcelFullPath = "C:\Temp\CAF-Assessment.xlsx" # Export Result to Excel file 

# Script Variable
$Global:RunScriptList = @()
$DisabledRunScript = @()

# Run-Script Configuration
$GetAzureBackup = $true
$GetDiagnosticSetting = $true
$GetRedisNetworkIsolation = $true
$GetAZoneEnabledService = $true
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

# Set PowerShell Windows Size
$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.size(120,8000)
$host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.size(120,45)
Start-Sleep -Milliseconds 500

# Banner
[int]$FontNumber = Get-Random -Minimum 0 -Maximum 5
$FontType = @()
$FontType += "standard"
$FontType += "bell"
$FontType += "big"
$FontType += "utopia"
$FontType += "jazmine"
Write-Host "`n`n"
& .\ConvertTo-TextASCIIArt.ps1 -Text "CAF Landing Zone" -FontName $FontType[$FontNumber] -FontColor White
Start-Sleep -Seconds 2

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

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Determine Run-Script
Write-Host "`n`n"
Write-Host "Enabled Run-Script:" -ForegroundColor Green -BackgroundColor Black

if ($GetAzureBackup) {
    Write-Host "Get Azure Backup Status" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAzureBackup" -Command "& .\Get-AzureBackup-Status.ps1"
} else {
    $DisabledRunScript += "Get Azure Backup Status"
}

if ($GetDiagnosticSetting) {
    Write-Host "Get Diagnostic Setting" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetDiagnosticSetting" -Command "& .\Get-DiagnosticSetting.ps1"
} else {
    $DisabledRunScript += "Get Diagnostic Setting"
} 

if ($GetRedisNetworkIsolation) {
    Write-Host "Get Azure Cache for Redis Network Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetRedisNetworkIsolation" -Command "& .\Get-Redis-NetworkIsolation.ps1"
} else {
    $DisabledRunScript += "Get Azure Cache for Redis Network Configuration"
} 

if ($GetAZoneEnabledService) {
    Write-Host "Get Availability Zone Enabled Service" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAZoneEnabledService" -Command "& .\Get-AZoneEnabledService.ps1"
} else {
    $DisabledRunScript += "Get Availability Zone Enabled Service"
} 

if ($GetClassicResource) {
    Write-Host "Get the list of Classic Resource" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetClassicResource" -Command "& .\Get-Classic-Resource.ps1"
} else {
    $DisabledRunScript += "Get the list of Classic Resource"
} 

if ($DisabledRunScript.Count -ne 0 -and (![string]::IsNullOrEmpty($DisabledRunScript))) {
    Write-Host "`n"
    Write-Host "Disabled Run-Script:" -ForegroundColor DarkRed -BackgroundColor Black

    foreach ($item in $DisabledRunScript) {
        Write-Host $item -ForegroundColor Cyan
    }
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

# Execute Run Script using RunspacePool
Write-Host "`n`nThe process may take more than 30 minutes ..."
Write-Host "`nPlease wait until it finishes ..."
Start-Sleep -Seconds 5
foreach ($RunScript in $Global:RunScriptList) {
    Invoke-Expression -Command $RunScript.Command
}

# End
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCAF Landing Zone Assessment have been completed"
Start-Sleep -Seconds 2
Write-Host ("`nPlease refer to the Assessment Result locate at " + $Global:ExcelFullPath)
Write-Host "`n`n"