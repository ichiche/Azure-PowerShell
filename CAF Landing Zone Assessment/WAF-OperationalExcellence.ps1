# Script Variable
$Global:ResourceGroupWithoutResource = @()
$OperationalExcellenceSummary = @()
$ErrorActionPreference = "Continue"

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

function Clear-UnsupportedResourceType {
    param (
        $AzResources
    )

    if ($AzResources -ne $null) {
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.AlertsManagement/actionRules"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.alertsmanagement/smartdetectoralertrules"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.compute/virtualmachines/extensions"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.devtestlab/schedules"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.MarketplaceApps/classicDevServices"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/actiongroups"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/activityLogAlerts"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/autoscalesettings"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/metricalerts"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/scheduledqueryrules"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.network/networkintentpolicies"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/networkWatchers/connectionMonitors"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.network/networkWatchers/flowLogs"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.network/privatednszones/virtualnetworklinks"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.offazure/ImportSites"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.OffAzure/MasterSites"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.OffAzure/VMwareSites"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Sql/managedInstances/databases"} # Only Instance support Tagging
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Sql/virtualClusters"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.visualstudio/account"}
        $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.web/certificates"}
        $AzResources = $AzResources | ? {$_.ResourceType -notlike "*/webhooks"}

        $FilteredAzResources = @()
        foreach ($item in $AzResources) {
            # Exclude Master Database
            if ($item.ResourceType -eq "Microsoft.Sql/servers/databases") {
                if ($item.ResourceName -notlike "*/master") {
                    $FilteredAzResources += $item
                }
            } else {
                $FilteredAzResources += $item
            }
        }
        
        return $FilteredAzResources
    } else {
        return $null
    }
}

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nAssess WAF Operational Excellence" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    #Region Resource Group without Resource
    $ResourceGroups = Get-AzResourceGroup

    foreach ($item in $ResourceGroups) {
        $TempList = Get-AzResource -ResourceGroupName $item.ResourceGroupName
        $TempList = Clear-UnsupportedResourceType -AzResources $TempList

        if ($TempList -eq $null) {
            Write-Host ($item.ResourceGroupName + " is empty")
        } 
    }

    #EndRegion Resource Group without Resource

    #Region Tagging
    # Get all Azure Resources
    $TempList = Get-AzResource | ? {$_.ResourceGroupName -notlike "databricks-rg*"}

    # Filtering 
    $TempList = Clear-UnsupportedResourceType -AzResources $TempList
    #EndRegion Tagging

    #$TempList = $TempList | sort ResourceType, ResourceGroupName, ResourceName
    #Write-Host ("`nNumber of Resources that support Diagnostic Logging: " + $TempList.Count)
}