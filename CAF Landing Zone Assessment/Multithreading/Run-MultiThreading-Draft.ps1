# TBC
# Interactive Login for each session
# Export Result
# Information Sharing between session

# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$Global:ExcelFullPath = "C:\Temp\CAF-Assessment.xlsx" # Export Result to Excel file 

# Run-Script Configuration
$GetDiagnosticSetting = $true
$GetRedisNetworkIsolation = $true

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
Write-Host "`nThe process may take more than 15 minutes ..." -ForegroundColor Yellow
Write-Host "`nPlease wait until it finishes ..." -ForegroundColor Yellow

# Create Runspace Pools for Run-Script
$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Global:RunScriptList.Count)
$RunspacePool.Open()
$RunspacePoolJobs = @()

# Execute Run Script using RunspacePool
foreach ($RunScript in $Global:RunScriptList) {
    $ScriptBlock = {
        param(
            [string]$RunScriptName,
            [string]$RunScriptDirectory
        )

        Set-Location -Path $RunScriptDirectory
        Invoke-Expression -Command $RunScriptName
        #$RunScriptName | Out-File C:\Temp\Test.txt -Force -Confirm:$false
        #$RunScriptDirectory| Out-File C:\Temp\Test.txt -Append -Confirm:$false
    }
    
    $ps1 = [PowerShell]::Create()
    $ps1.RunspacePool = $RunspacePool
    $ps1.AddScript($ScriptBlock).AddArgument($RunScript.Command).AddArgument((Get-Location).Path)
    [IAsyncResult]$IAsyncResult1 = $ps1.BeginInvoke()
    $RunspacePoolJobs += $IAsyncResult1
}

# Wait for Completion
while ($RunspacePoolJobs.IsCompleted -contains $false) {
	Start-Sleep 30
}

# Export

# End
Write-Host "`nCAF Landing Zone Assessment have been completed" -ForegroundColor Yellow
Write-Host ("`nPlease refer to the Assessment Result locate at " + $Global:ExcelFullPath) -ForegroundColor Yellow
Write-Host "`n"