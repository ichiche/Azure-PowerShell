# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$CsvFullPath = "C:\Temp\Azure-Classic-Resource.csv" # Export Result to CSV file 

# Script Variable
$Global:ClassicList = @()
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

function Rename-ResourceType {
    param (
        [string]$ResourceType
    )

    switch -Wildcard ($ResourceType) {
        "*domainNames*" { $ResourceType = "Cloud Service (classic)"; continue; }
        "*reservedIps*" { $ResourceType = "Reserved IP Address (classic)"; continue; }
        "*virtualMachines*" { $ResourceType = "Virtual Machine (classic)"; continue; }
        "*virtualNetworks*" { $ResourceType = "Virtual Network (classic)"; continue; }
        "*storageAccounts*" { $ResourceType = "Storage Account (classic)"; continue; }
        Default {}
    }

    return $ResourceType
}

# Main
foreach ($Subscription in $Subscriptions) {
    # Set current subscription for Az Module
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow
    $CurrentItem++

    # Get Az Resource List
    $ClassicResources = Get-AzResource | ? { $_.ResourceType -like "*Classic*" }
    
    foreach ($ClassicResource in $ClassicResources) {
        $Location = Rename-Location -Location $ClassicResource.Location
        $ResourceType = Rename-ResourceType -ResourceType $ClassicResource.ResourceType
        
        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $ClassicResource.ResourceGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $ClassicResource.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $ResourceType
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceId" -Value $ClassicResource.ResourceId
    
        # Save to Array
        $Global:ClassicList += $obj
    }
}

# Export Result to CSV file
$Global:ClassicList | sort ResourceType, SubscriptionName, ResourceGroup, ResourceName | Export-Csv -Path $CsvFullPath -NoTypeInformation -Confirm:$false -Force

# Count resource type
Write-Host ("`n--- Summary ---")
Write-Host ("`nCount of Classic Resource: " + $Global:ClassicList.Count) -ForegroundColor Cyan

Write-Host ("`n--- Breakdown ---")
$CountType = $Global:ClassicList | group ResourceType | select Name, Count | sort Count, Name -Descending
foreach ($item in $CountType) {
    Write-Host ("`n" + $item.Name + ": " + $item.Count)
}

# End
Write-Host "`nCompleted" -ForegroundColor Yellow
Write-Host "`n"