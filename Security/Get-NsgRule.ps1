# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$CsvFullPath = "C:\Temp\Azure-NsgCustomRule.csv" # Export Result to CSV file 

# Script Variable
$Global:ResultArray = @()
[int]$CurrentItem = 1

# Login
Connect-AzAccount

# Function
function Add-Record {
    param (
        $nsg,
        $rule,
        [switch]$HasCustomRule
    )

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subscription" -Value $Subscription.Name
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $nsg.ResourceGroupName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "NsgName" -Value $nsg.Name
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $nsg.Location

    # Associated Virtual Network and Subnet
    [array]$arr = $nsg.Subnets
    if ($arr.count -eq 0) {
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Associated VirtualNetwork/Subnet" -Value "N/A"
    } else {
        for ($i = 0;$i -lt $arr.Count;$i++) {
            [string]$st = $arr[$i].Id
            $st = $st.Substring($st.LastIndexOf("/virtualNetworks")+17,($st.LastIndexOf("/subnets") - ($st.LastIndexOf("/virtualNetworks")+17))) + "/" + $st.Substring($st.LastIndexOf("/")+1)
            
            if ($i -eq 0) {
                $vNetSubnetList = $st
            } else {
                $vNetSubnetList += ", " + $st
            }
        }
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Associated VirtualNetwork/Subnet" -Value $vNetSubnetList
    }

    # Associated Network Interface
    [array]$arr = $nsg.NetworkInterfaces
    if ($arr.Count -eq 0) {
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Associated NetworkInterface" -Value "N/A"
    } else {
        [string]$NetworkInterfaceList = ""

        for ($i = 0;$i -lt $arr.Count;$i++) {
            [string]$st = $arr[$i].Id
            $st = $st.Substring($st.LastIndexOf("/")+1)

            if ($i -eq 0) {
                $NetworkInterfaceList = $st
            } else {
                $NetworkInterfaceList += ", " + $st
            }
        }
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Associated NetworkInterface" -Value $NetworkInterfaceList
    }

    # Custom Rule
    if ($HasCustomRule) {
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "HasCustomRule" -Value "Yes"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RuleName" -Value $rule.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Priority" -Value $rule.Priority
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Access" -Value $rule.Access
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Direction" -Value $rule.Direction
        
        [string]$st = $rule.SourcePortRange
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SourcePortRange" -Value $st

        [string]$st = $rule.DestinationPortRange
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationPortRange" -Value $st

        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Protocol" -Value $rule.Protocol

        [string]$st = $rule.SourceAddressPrefix
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SourceAddressPrefix" -Value $st

        [string]$st = $rule.DestinationAddressPrefix
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationAddressPrefix" -Value $st
    } else {
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "HasCustomRule" -Value "No"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RuleName" -Value " "
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Priority" -Value " "
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Access" -Value " "
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Direction" -Value " "
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SourcePortRange" -Value " "
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationPortRange" -Value " "
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Protocol" -Value " "
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SourceAddressPrefix" -Value " "
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationAddressPrefix" -Value " "
    }

    # Tag
    $TagsList = ""
    [array]$TagKey = $nsg.Tag.Keys
    [array]$TagValue = $nsg.Tag.Values

    for ($i = 0;$i -lt $TagKey.Count;$i++) {
        if ($i -eq 0) {
            $TagsList = $TagKey[$i] + ": " + $TagValue[$i]
        } else {
            $TagsList += ", " + $TagKey[$i]  + ": " + $TagValue[$i]
        }
    }
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Tags" -Value $TagsList
    
    # Save to Array
    $Global:ResultArray += $obj
}

# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    $Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    $Subscriptions = Get-AzSubscription
}

# Main
foreach ($Subscription in $Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id -TenantId $Subscription.TenantId
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++
    
    # Network Security Group
    $nsgs = Get-AzNetworkSecurityGroup

    foreach ($nsg in $nsgs) {
        $NsgRules = $nsg | Get-AzNetworkSecurityRuleConfig
        if ($NsgRules.Count -eq 0) {
            Add-Record -nsg $nsg -rule "" -HasCustomRule:$false
        } else {
            $NsgRules = $NsgRules | sort Direction, Priority
            foreach ($NsgRule in $NsgRules) {
                Add-Record -nsg $nsg -rule $NsgRule -HasCustomRule:$true
            }
        }
    }
}

# Export to CSV file
$Global:ResultArray | sort Subscription, ResourceGroup, NsgName | Export-Csv -Path $CsvFullPath -NoTypeInformation -Confirm:$false -Force 

# End
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCompleted"

# Logout
Disconnect-AzAccount