# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$CsvFullPath = "C:\Temp\Azure-Classic-VM.csv" # Export Result to CSV file 

# Script Variable
$Global:ClassicVMList = @()
[int]$CurrentItem = 1

# Login
Connect-AzAccount

# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    $Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    $Subscriptions = Get-AzSubscription
}

# Get the Latest Location Name and Display Name
$Global:NameReference = Get-AzLocation

# Function to align the Display Name
function Rename-Location {
    param (
        [string]$Location
    )

    foreach ($item in $Global:NameReference) {
        if ($item.Location -eq $Location) {
            $Location = $item.DisplayName
        }
    }

    return $Location
}

# Main
foreach ($Subscription in $Subscriptions) {
    # Set current subscription for Az Module
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow
    $CurrentItem++

    # Get Az Resource List
    $ClassicVMs = Get-AzResource | ? {$_.ResourceId -like "*Microsoft.ClassicCompute*" -and $_.ResourceType -eq "Microsoft.ClassicCompute/virtualMachines"}
    
    foreach ($ClassicVM in $ClassicVMs) {
        $Location = Rename-Location -Location $ClassicVM.Location

        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $ClassicVM.ResourceGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "InstanceName" -Value $ClassicVM.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
    
        # Save to Array
        $Global:ClassicVMList   += $obj
    }
}

# Export to CSV file
$Global:ClassicVMList | sort SubscriptionName, ResourceGroup, InstanceName | Export-Csv -Path $CsvFullPath -NoTypeInformation -Force -Confirm:$false 

# End
Write-Host "`nCompleted" -ForegroundColor Yellow
Write-Host ("`nCount of Classic VM: " + $Global:ClassicVMList.Count) -ForegroundColor Cyan
Write-Host "`n"