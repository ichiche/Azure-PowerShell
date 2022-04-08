# Set PowerShell Windows Size
if ($host.UI.RawUI.BufferSize.Width -lt $Width) {
    $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.size(120,9999)
    $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.size(120,45)
    Start-Sleep -Milliseconds 500
}

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