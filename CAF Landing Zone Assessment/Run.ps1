# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$Global:ExcelOutputFolder = "C:\Temp"
$ExcelFileName = "CAF-Assessment.xlsx" # Export Result to Excel file 

# Script Variable
if ($Global:ExcelOutputFolder -notlike "*\") {$Global:ExcelOutputFolder += "\"}
$Global:ExcelFullPath = $Global:ExcelOutputFolder + $ExcelFileName
$Global:RunScriptList = @()
$Global:DisabledRunScript = @()
$ErrorActionPreference = "Continue"
$error.Clear()

# Run-Script Configuration
$GetAzureBackup = $true
$GetSql_SqlMI_DB = $true
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
$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.size(120,9999)
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

# Create the Export Folder if not exist
if (!(Test-Path $Global:ExcelOutputFolder)) {
    $Global:ExcelOutputFolder
    try {
        New-Item -Path $Global:ExcelOutputFolder -ItemType Directory -Force -Confirm:$false -ErrorAction Stop
    } catch {
        Write-Host "$Global:ExcelOutputFolder does not exist or cannot create"
        throw
    }
}

# Delete Assessment Excel File
if (Test-Path $Global:ExcelFullPath) {
    try {
        Remove-Item $Global:ExcelFullPath -Force -Confirm:$false -ErrorAction Stop
    } catch {
        Write-Host "Excel File with same name exists or cannot delete"
        throw
    }
}

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
    Update-RunScriptList -RunScript "GetAzureBackup" -Command "& .\Get-AzureBackupStatus.ps1"
} else {
    $Global:DisabledRunScript += "Get Azure Backup Status"
}

if ($GetSql_SqlMI_DB) {
    Write-Host "Get Capacity, PITR, LTR, Backup Storage, Replication, Redundancy of SQL / SQL Managed Instance" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetSql_SqlMI_DB" -Command "& .\Get-AzureSql-SqlMI-Configuration.ps1"
} else {
    $Global:DisabledRunScript += "Get Capacity, PITR, LTR, Backup Storage, Replication, Redundancy of SQL / SQL Managed Instance"
} 

if ($GetDiagnosticSetting) {
    Write-Host "Get Diagnostic Setting" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetDiagnosticSetting" -Command "& .\Get-DiagnosticSetting.ps1"
} else {
    $Global:DisabledRunScript += "Get Diagnostic Setting"
} 

if ($GetRedisNetworkIsolation) {
    Write-Host "Get Azure Cache for Redis Network Configuration" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetRedisNetworkIsolation" -Command "& .\Get-Redis-NetworkIsolation.ps1"
} else {
    $Global:DisabledRunScript += "Get Azure Cache for Redis Network Configuration"
} 

if ($GetAZoneEnabledService) {
    Write-Host "Get Availability Zone Enabled Service" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetAZoneEnabledService" -Command "& .\Get-AZoneEnabledService.ps1"
} else {
    $Global:DisabledRunScript += "Get Availability Zone Enabled Service"
} 

if ($GetClassicResource) {
    Write-Host "Get the list of Classic Resource" -ForegroundColor Cyan
    Update-RunScriptList -RunScript "GetClassicResource" -Command "& .\Get-Classic-Resource.ps1"
} else {
    $Global:DisabledRunScript += "Get the list of Classic Resource"
} 

if ($Global:DisabledRunScript.Count -ne 0 -and (![string]::IsNullOrEmpty($Global:DisabledRunScript))) {
    Write-Host "`n"
    Write-Host "Disabled Run-Script:" -ForegroundColor DarkRed -BackgroundColor Black

    foreach ($item in $Global:DisabledRunScript) {
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
$StartTime = Get-Date
foreach ($RunScript in $Global:RunScriptList) {
    Invoke-Expression -Command $RunScript.Command
}

# End
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCAF Landing Zone Assessment have been completed"
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Host ("`nTotal Process Time: " + $Duration.Minutes + " Minutes " + $Duration.Seconds + " Seconds") -ForegroundColor Blue -BackgroundColor Black
Start-Sleep -Seconds 1
Write-Host ("`nPlease refer to the Assessment Result locate at " + $Global:ExcelFullPath)
Write-Host "`n`n"