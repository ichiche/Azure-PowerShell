# Script Variable
$Global:DiagnosticSetting = @()
$DiagnosticSettingSummary = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "SilentlyContinue"

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

    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.alertsmanagement/smartDetectorAlertRules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.AlertsManagement/actionRules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Automation/automationAccounts/runbooks"} # Support Automation Accounts only
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.cdn/profiles"} # Support Endpoint only
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/availabilitySets"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/disks"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/images"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/galleries"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/galleries/images"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/galleries/images/versions"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/restorePointCollections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/snapshots"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/virtualMachines/extensions"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Compute/virtualMachineScaleSets"} # Enabling Azure Monitors for VMSS
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ContainerRegistry/registries/replications"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ContainerRegistry/registries/webhooks"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DataCatalog/catalogs"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DevTestLab/schedules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/actiongroups"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/activityLogAlerts"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/autoscalesettings"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/components"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/metricalerts"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/webtests"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/scheduledqueryrules"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "microsoft.insights/workbooks"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Logic/integrationServiceEnvironments"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Logic/integrationServiceEnvironments/managedApis"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ManagedIdentity/userAssignedIdentities"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/connections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/ddosProtectionPlans"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/localNetworkGateways"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/networkIntentPolicies"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/networkWatchers"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/privateDnsZones"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/privateDnsZones/virtualNetworkLinks"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/privateEndpoints"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/routeFilters"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Network/routeTables"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.network/networkWatchers/flowLogs"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.NotificationHubs/namespaces/notificationHubs"} # Support Namespace only
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.OperationsManagement/solutions"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Portal/dashboards"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.SaaS/resources"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Scheduler/jobcollections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Sql/servers"} # Support Database only
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Sql/servers/jobAgents"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.StorageSync/storageSyncServices"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Web/certificates"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Web/connections"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Web/staticSites"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Sendgrid.Email/accounts"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DataProtection/BackupVaults"} # Backup Vault not support, but Recovery Service vault support
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DataMigration/services"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.DataMigration/services/projects"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Migrate/assessmentProjects"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.Migrate/migrateprojects"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.OffAzure/VMwareSites"}
    $AzResources = $AzResources | ? {$_.ResourceType -ne "Microsoft.ResourceGraph/queries"}
    $AzResources = $AzResources | ? {$_.ResourceType -notlike "*Classic*"}

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
}

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet Diagnostic Setting" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    # Get all Azure Resources
    $TempList = Get-AzResource 

    # Filtering 
    $TempList = Clear-UnsupportedResourceType -AzResources $TempList

    # Get Diagnostic Settings 
    foreach ($item in $TempList) {
        Write-Host ("Resource: " + $item.Name)
        $TempDiagnosticSettings = Get-AzDiagnosticSetting -ResourceId $item.Id
        $Location = Rename-Location -Location $item.Location

        if ($TempDiagnosticSettings -eq $null) {
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $item.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $item.ResourceName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $item.ResourceType
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledDiagnostic" -Value "N"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "WorkspaceId" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "StorageAccountId" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServiceBusRuleId" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EventHubAuthorizationRuleId" -Value "N/A"
            $Global:DiagnosticSetting += $obj

        } else {
            foreach ($TempDiagnosticSetting in $TempDiagnosticSettings) {
                $obj = New-Object -TypeName PSobject
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $item.ResourceGroupName
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $item.ResourceName
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $item.ResourceType
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location

                if ($TempDiagnosticSetting -eq $null) {
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledDiagnostic" -Value "N"
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "WorkspaceId" -Value "N/A"
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "StorageAccountId" -Value "N/A"
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServiceBusRuleId" -Value "N/A"
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EventHubAuthorizationRuleId" -Value "N/A"
                } else {
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledDiagnostic" -Value "Y"
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "WorkspaceId" -Value $TempDiagnosticSetting.WorkspaceId
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "StorageAccountId" -Value $TempDiagnosticSetting.StorageAccountId
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServiceBusRuleId" -Value $TempDiagnosticSetting.ServiceBusRuleId
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EventHubAuthorizationRuleId" -Value $TempDiagnosticSetting.EventHubAuthorizationRuleId
                }
                
                # Save to Array
                $Global:DiagnosticSetting += $obj
            }
        }
    }
}

#Region Export
$Global:DiagnosticSetting = $Global:DiagnosticSetting | sort ResourceType, SubscriptionName, ResourceName

# Prepare Diagnostic Setting Summary
$SettingStatus = $Global:DiagnosticSetting | select -Unique ResourceGroup, ResourceName, ResourceType, EnabledDiagnostic
foreach ($item in ($SettingStatus | group EnabledDiagnostic, ResourceType | select Name, Count)) {
    $EnableStatus = $item.Name.Substring(0, 1)
    $ResourceType = $item.Name.Substring(3)
    $ResourceTotal = $SettingStatus | group ResourceType | ? {$_.Name -eq $ResourceType} | select -ExpandProperty Count

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $ResourceType 
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledDiagnostic" -Value $EnableStatus
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $ResourceTotal
    $DiagnosticSettingSummary += $obj
}
$DiagnosticSettingSummary = $DiagnosticSettingSummary | sort "Resource Type"

# Export to Excel File
$DiagnosticSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "DiagnosticSummary" -TableName "DiagnosticSummary" -TableStyle Medium16 -AutoSize -Append
$Global:DiagnosticSetting | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "DiagnosticDetail" -TableName "DiagnosticDetail" -TableStyle Medium16 -AutoSize -Append
#EndRegion Export