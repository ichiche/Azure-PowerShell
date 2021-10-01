# Global Parameter
$ConnectSpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID
$CsvFullPath = "C:\Temp\Azure-NsgCustomRule-Association.csv" # Export Result to CSV file 

# Script Variable
$Global:ResultArray = @()
[int]$CurrentItem = 0

# Login
Connect-AzAccount # Comment this line if using Connect-To-Cloud.ps1

# Function
function Add-Record {
    param (
        $nsg,
        $Rules,
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
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RuleName" -Value $Rules.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Priority" -Value $Rules.Priority
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Access" -Value $Rules.Access
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Direction" -Value $Rules.Direction
        
        [string]$st = $Rules.SourcePortRange
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SourcePortRange" -Value $st

        [string]$st = $Rules.DestinationPortRange
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationPortRange" -Value $st

        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Protocol" -Value $Rules.Protocol

        [string]$st = $Rules.SourceAddressPrefix
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SourceAddressPrefix" -Value $st

        [string]$st = $Rules.DestinationAddressPrefix
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
    
    # Store to Array
    $Global:ResultArray += $obj
}

# Get Azure Subscription
if ($ConnectSpecificTenant -eq "Y") {
    $Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    $Subscriptions = Get-AzSubscription
}

# Main
foreach ($Subscription in $Subscriptions) {
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id 
    $CurrentItem++
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow

    $nsgs = Get-AzNetworkSecurityGroup

    foreach ($nsg in $nsgs) {

        $nsgRules = $nsg | Get-AzNetworkSecurityRuleConfig
        if ($nsgRules.Count -eq 0) {
            Add-Record -nsg $nsg -Rules "" -HasCustomRule:$false
        } else {
            $nsgRules = $nsgRules | sort Direction, Priority
            foreach ($nsgRule in $nsgRules) {
                Add-Record -nsg $nsg -Rules $nsgRule -HasCustomRule:$true
            }
        }
    }
}

# Export Result to CSV file
$Global:ResultArray | Export-Csv -Path $CsvFullPath -NoTypeInformation -Confirm:$false -Force 

# Logout
Disconnect-AzAccount