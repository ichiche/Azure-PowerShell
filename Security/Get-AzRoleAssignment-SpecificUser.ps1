# Global Parameter
$Global:ExcelOutputFolder = "C:\Temp"
$ExcelFileName = "RoleAssignment.xlsx" # Export Result to Excel file 
$SignInName = "chicheng_microsoft.com#EXT#@mtrchk.onmicrosoft.com" # For User Account from other tenant, the "UserAlias_DomainName#EXT#@TargetTenant.onmicrosoft.com"
$Scope = "Subscription"

# Script Variable
if ($Global:ExcelOutputFolder -notlike "*\") {$Global:ExcelOutputFolder += "\"}
$Global:ExcelFullPath = $Global:ExcelOutputFolder + $ExcelFileName
$Global:RoleAssignment = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet Role Assignment of $SignInName at $Scope" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++
    
    if ($Scope -eq "Subscription") {
        $Assignments = Get-AzRoleAssignment -SignInName $SignInName -Scope ("/subscriptions/" + $Subscription.Id)

        foreach ($Assignment in $Assignments) {
            # Save to Temp Object
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "RoleDefinitionName" -Value $Assignment.RoleDefinitionName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DisplayName" -Value $Assignment.DisplayName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SignInName" -Value $Assignment.SignInName

            # Save to Array
            $Global:RoleAssignment += $obj
        }
    }
}

# Export to Excel File
$Global:RoleAssignment | sort SubscriptionName, RoleDefinitionName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "RoleAssignment" -TableName "RoleAssignment" -TableStyle Medium16 -AutoSize -Append

# End
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCompleted"