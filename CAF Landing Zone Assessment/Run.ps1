# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$Global:ExcelFullPath = "C:\Temp\CAF-Assessment.xlsx" # Export Result to Excel file 

# Script Variable
$Global:RunScriptList = @()

# Run-Script Configuration
$GetAzureBackup = $true
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

# Set PowerShell Windows Size
$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.size(120,5000)
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
Write-Host "Enabled RunScript:" -ForegroundColor Green -BackgroundColor Black


if ($GetAzureBackup) {
    Write-Host "Collect Azure Backup Status" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAzureBackup" -Command "& .\Get-AzureBackup-Status.ps1"
} else {
    $DisabledRunScript += "Collect Azure Backup Status"
}

if ($GetDiagnosticSetting) {
    Write-Host "Collect Diagnostic Setting" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetDiagnosticSetting" -Command "& .\Get-DiagnosticSetting.ps1"
} else {
    $DisabledRunScript += "Collect Diagnostic Setting"
} 

if ($GetRedisNetworkIsolation) {
    Write-Host "Collect Azure Cache for Redis Network Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetRedisNetworkIsolation" -Command "& .\Get-Redis-NetworkIsolation.ps1"
} else {
    $DisabledRunScript += "Collect Azure Cache for Redis Network Configuration"
} 

if ($GetClassicResource) {
    Write-Host "Get the list of Classic Resource" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetClassicResource" -Command "& .\Get-Classic-Resource.ps1"
} else {
    $DisabledRunScript += "Get the list of Classic Resource"
} 

if ($DisabledRunScript.Count -ne 0 -and $DisabledRunScript -ne $null) {
    Write-Host "`n"
    Write-Host "Disabled RunScript:" -ForegroundColor DarkRed -BackgroundColor Black

    foreach ($item in $DisabledRunScript) {
        Write-Host $item -ForegroundColor Cyan
    }
}

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
Write-Host "`n`nThe process may take more than 15 minutes ..."
Write-Host "`nPlease wait until it finishes ..."
Start-Sleep -Seconds 5
foreach ($RunScript in $Global:RunScriptList) {
    Invoke-Expression -Command $RunScript.Command
}

# End
Write-Host "`n`nCAF Landing Zone Assessment have been completed"
Start-Sleep -Seconds 2
Write-Host ("`nPlease refer to the Assessment Result locate at " + $Global:ExcelFullPath)
Write-Host "`n`n"