# This script apply to the account which has not enabled the MFA (Multi-Factor Authentication)
# Run this script at the location where secure-password.txt exist

# Global Parameter 
$username = "" # Enter UPN of Azure Account
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"

# Script Variable
$password = Get-Content .\secure-password.txt
$adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString)

# Main
Write-Host "`nConnecting to Azure using Az PowerShell Module" -ForegroundColor Gray

if ($SpecificTenant -eq "Y") {
    Connect-AzAccount -Credential $adminCredential -Tenant $TenantId | Out-Null
} else {
    Connect-AzAccount -Credential $adminCredential | Out-Null
}

Write-Host "`nConnected`n" -ForegroundColor Gray