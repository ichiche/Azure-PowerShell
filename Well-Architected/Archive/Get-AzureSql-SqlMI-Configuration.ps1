# Script Variable
$Global:SqlSetting = @()
$Global:SqlSettingSummary = @()
$Global:SqlAccessSummary = @()
[int]$CurrentItem = 1
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

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet SQL / SQL Managed Instance Configuration" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    
    # Set current subscription
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    #Region Azure SQL
	$SqlServers = Get-AzSqlServer
	$Databases = $SqlServers | Get-AzSqlDatabase | ? {$_.DatabaseName -ne "Master" -and $_.Edition -ne "DataWarehouse"}
    $pe = Get-AzPrivateEndpoint

	foreach ($Database in $Databases) {
        Write-Host ("SQL Database: " + $Database.DatabaseName)
        $SqlServer = $SqlServers | ? {$_.ResourceGroupName -eq $Database.ResourceGroupName -and $_.ServerName -eq $Database.ServerName}
        $Location = Rename-Location -Location $Database.Location

        # Pricing Tier
        $Edition = $Database.Edition
        if ($Edition -eq "Premium" -or $Edition -eq "Standard" -or $Edition -eq "Basic") {
            $Sku = $Database.CurrentServiceObjectiveName
            $vCore = "N/A"
        } else {
            $Sku = $Database.SkuName
            $vCore = $Database.Capacity
        }

        # Elastic Pool
        if ([string]::IsNullOrEmpty($Database.ElasticPoolName)) { 
            $PoolName = "N/A" 
        } else { 
            $PoolName = $Database.ElasticPoolName 
            $ElasticPool = Get-AzSqlElasticPool -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -ElasticPoolName $PoolName

            if ($ElasticPool.Edition -eq "Premium" -or $ElasticPool.Edition -eq "Standard" -or $ElasticPool.Edition -eq "Basic") {
                $Sku += " " + $ElasticPool.Capacity + " DTU"
            } else {
                $Sku += " " + $ElasticPool.SkuName
                $vCore = $ElasticPool.Capacity
            }
        }

        # Replica
        if ([string]::IsNullOrEmpty($Database.SecondaryType)) {
            $IsReplica = "N"
        } else {
            $IsReplica = $Database.SecondaryType
        }

        # Failover Group
        $FailoverGroups = Get-AzSqlDatabaseFailoverGroup -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName
        $FailoverGroupEnabled = "N"
        $FailoverGroupName = "N/A"
        if (![string]::IsNullOrEmpty($FailoverGroups)) {
            foreach ($FailoverGroup in $FailoverGroups) {
                if ($FailoverGroup.DatabaseNames -contains $Database.DatabaseName) {
                    $FailoverGroupEnabled = "Y"
                    $FailoverGroupName = $FailoverGroup.FailoverGroupName
                }
            }
        }

        # Backup Storage Redundancy
        if ([string]::IsNullOrEmpty($Database.CurrentBackupStorageRedundancy)) {
            $BackupStorageRedundancy = "N/A"
        } else {
            $BackupStorageRedundancy = $Database.CurrentBackupStorageRedundancy
        }

        # Availability Zone 
        $ZoneRedundant = $Database.ZoneRedundant
        if ($ZoneRedundant) {
            $ZoneRedundant = "Y"
        } else {
            $ZoneRedundant = "N"
        }

        # Private Endpoint
        $PrivateLinkResource = $pe | ? {$_.PrivateLinkServiceConnections.PrivateLinkServiceId -eq $SqlServer.ResourceId}
        if ($PrivateLinkResource.Length -gt 0 -and $PrivateLinkResource -ne $null) {
            $EnabledPrivateEndpoint = "Y"
        } else {
            $EnabledPrivateEndpoint = "N"
        }

        # Allow Public Network Access
        # Sql Server provisioned in early stage has no value
        if ($SqlServer.PublicNetworkAccess -eq "Enabled" -or $SqlServer.PublicNetworkAccess -eq $null) {
            $AllowPublicNetworkAccess = "Y"
        } else {
            $AllowPublicNetworkAccess = "N"
        }

        # Allow Azure Service Access
        $rules = Get-AzSqlServerFirewallRule -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName
        if ($rules.FirewallRuleName -contains "AllowAllWindowsAzureIps" -or $rules.FirewallRuleName -eq "AllowAllWindowsAzureIps") {
            $AllowAzureServiceAccess = "Y"
        } else {
            $AllowAzureServiceAccess = "N"
        }

        # Outbound Firewall Rule
        if ($SqlServer.RestrictOutboundNetworkAccess -eq "Enabled") {
            $RestrictOutboundNetworkAccess = "Y"
        } else {
            $RestrictOutboundNetworkAccess = "N"
        }

        # Backup Policy
        $ShortTerm = Get-AzSqlDatabaseBackupShortTermRetentionPolicy  -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -DatabaseName $Database.DatabaseName
        $LongTerm = Get-AzSqlDatabaseBackupLongTermRetentionPolicy -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -DatabaseName $Database.DatabaseName

        # Long Term Retention
        if ($LongTerm.WeeklyRetention -eq "PT0S") {
            $WeeklyRetention = "Not Enabled"
        } else {
            $WeeklyRetention = $LongTerm.WeeklyRetention
        }

        if ($LongTerm.MonthlyRetention -eq "PT0S") {
            $MonthlyRetention = "Not Enabled"
        } else {
            $MonthlyRetention = $LongTerm.MonthlyRetention
        }

        if ($LongTerm.YearlyRetention -eq "PT0S") {
            $YearlyRetention = "Not Enabled"
        } else {
            $YearlyRetention = $LongTerm.YearlyRetention
        }
                
        # Database maximum storage size
        $db_MaximumStorageSize = $database.MaxSizeBytes / 1GB

        # Database used space
        $db_metric_storage = Get-AzMetric -ResourceId $Database.ResourceId -MetricName 'storage' -WarningAction SilentlyContinue
        $db_UsedSpace = $db_metric_storage.Data.Maximum | select -Last 1
        $db_UsedSpace = [math]::Round($db_UsedSpace / 1GB, 2)

        # Database used space percentage
        $db_metric_storage_percent = Get-AzMetric -ResourceId $Database.ResourceId -MetricName 'storage_percent' -WarningAction SilentlyContinue
        $db_UsedSpacePercentage = $db_metric_storage_percent.Data.Maximum | select -Last 1

        # Database allocated space
        #$db_metric_allocated_data_storage = Get-AzMetric -ResourceId $Database.ResourceId -MetricName 'allocated_data_storage' -WarningAction SilentlyContinue
        #$db_AllocatedSpace = $db_metric_allocated_data_storage.Data.Average | select -Last 1
        #$db_AllocatedSpace = [math]::Round($db_AllocatedSpace / 1GB, 2) 
                
        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $Database.ResourceGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerName" -Value $Database.ServerName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DatabaseName" -Value $Database.DatabaseName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "SQL Database"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Edition" -Value $Edition
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Sku" -Value $Sku
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "vCore" -Value $vCore
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ElasticPoolName" -Value $PoolName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "IsReplica" -Value $IsReplica
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "FailoverGroupEnabled" -Value $FailoverGroupEnabled
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "FailoverGroupName" -Value $FailoverGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "BackupStorageRedundancy" -Value $BackupStorageRedundancy
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ZoneRedundant" -Value $ZoneRedundant
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPrivateEndpoint" -Value $EnabledPrivateEndpoint
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllowPublicNetworkAccess" -Value $AllowPublicNetworkAccess
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllowAzureServiceAccess" -Value $AllowAzureServiceAccess
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "RestrictOutboundNetworkAccess" -Value $RestrictOutboundNetworkAccess
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPublicEndpoint" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "PITR(Day)" -Value $ShortTerm.RetentionDays
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "WeeklyRetention" -Value $WeeklyRetention
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "MonthlyRetention" -Value $MonthlyRetention
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "YearlyRetention" -Value $YearlyRetention
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "MaxDBSize(GB)"  -Value $db_MaximumStorageSize
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "UsedSpace(GB)" -Value $db_UsedSpace
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "UsedSpacePercentage" -Value $db_UsedSpacePercentage
        #Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllocatedSpace(GB)" -Value $db_AllocatedSpace
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerReservedSize(GB)" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerUsedSize(GB)" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DBCreationDate" -Value $Database.CreationDate
        $Global:SqlSetting += $obj
	}
    #EndRegion Azure SQL

    #Region Azure SQL Managed Instance
	$SqlServers = Get-AzSqlInstance

    foreach ($SqlServer in $SqlServers) {
        Write-Host ("SQL Managed Instance: " + $SqlServer.ManagedInstanceName)

        # Pricing Tier
        $Edition = $SqlServer.Sku.Tier
        $Sku = $SqlServer.Sku.Name
        $vCore = $SqlServer.VCores
        
        # Failover Group
        $FailoverGroups = Get-AzSqlDatabaseInstanceFailoverGroup -ResourceGroupName $SqlServer.ResourceGroupName -Location $SqlServer.Location
        $FailoverGroupEnabled = "N"
        $FailoverGroupName = "N/A"
        if (![string]::IsNullOrEmpty($FailoverGroups)) {
            foreach ($FailoverGroup in $FailoverGroups) {
                if ($FailoverGroup.PrimaryManagedInstanceName -eq $SqlServer.ManagedInstanceName -or $FailoverGroup.PartnerManagedInstanceName -eq $SqlServer.ManagedInstanceName) {
                    $FailoverGroupEnabled = "Y"
                    $FailoverGroupName = $FailoverGroup.Name
                }
            }
        }

        # Backup Storage Redundancy
        if ([string]::IsNullOrEmpty($SqlServer.BackupStorageRedundancy)) {
            $BackupStorageRedundancy = "N/A"
        } else {
            $BackupStorageRedundancy = $SqlServer.BackupStorageRedundancy
        }

        # Availability Zone 
        $ZoneRedundant = $SqlServer.ZoneRedundant
        if ($ZoneRedundant) {
            $ZoneRedundant = "Y"
        } else {
            $ZoneRedundant = "N"
        }

        # Private Endpoint
        $PrivateLinkResource = $pe | ? {$_.PrivateLinkServiceConnections.PrivateLinkServiceId -eq $SqlServer.ResourceId}
        if ($PrivateLinkResource.Length -gt 0 -and $PrivateLinkResource -ne $null) {
            $EnabledPrivateEndpoint = "Y"
        } else {
            $EnabledPrivateEndpoint = "N"
        }

        # Public Endpoint
        if ($SqlServer.PublicDataEndpointEnabled) {
            $EnabledPublicEndpoint = "Y"
        } else {
            $EnabledPublicEndpoint = "N"
        }

        # SQL Managed Instance Database
        $Databases = Get-AzSqlInstanceDatabase -InstanceResourceId $SqlServer.Id | ? {$_.Name -ne "Master"}

        foreach ($Database in $Databases) {
            Write-Host ("SQL Managed Instance Database: " + $Database.Name)
            $Location = Rename-Location -Location $Database.Location

            # Backup Policy
            $ShortTerm = Get-AzSqlInstanceDatabaseBackupShortTermRetentionPolicy  -ResourceGroupName $Database.ResourceGroupName -InstanceName $Database.ManagedInstanceName -DatabaseName $Database.Name
            $LongTerm = Get-AzSqlInstanceDatabaseBackupLongTermRetentionPolicy -ResourceGroupName $Database.ResourceGroupName -InstanceName $Database.ManagedInstanceName -DatabaseName $Database.Name

            # Long Term Retention
            if ($LongTerm.WeeklyRetention -eq "PT0S") {
                $WeeklyRetention = "Not Enabled"
            } else {
                $WeeklyRetention = $LongTerm.WeeklyRetention
            }

            if ($LongTerm.MonthlyRetention -eq "PT0S") {
                $MonthlyRetention = "Not Enabled"
            } else {
                $MonthlyRetention = $LongTerm.MonthlyRetention
            }

            if ($LongTerm.YearlyRetention -eq "PT0S") {
                $YearlyRetention = "Not Enabled"
            } else {
                $YearlyRetention = $LongTerm.YearlyRetention
            }
            
            # SQL Managed Instance Storage space reserved
            #$MI_Metric_Storage = Get-AzMetric -ResourceId $SqlServer.Id -MetricName 'reserved_storage_mb' -WarningAction SilentlyContinue
            #[int]$MI_ReservedSpace = $MI_Metric_Storage.Data.Average | select -Last 1
            #$MI_ReservedSpace = [math]::Round($MI_ReservedSpace / 1KB, 2)
            $MI_ReservedSpace = $SqlServer.StorageSizeInGB

            # SQL Managed Instance Storage space used
            $MI_Metric_Storage = Get-AzMetric -ResourceId $SqlServer.Id -MetricName 'storage_space_used_mb' -WarningAction SilentlyContinue
            [int]$MI_UsedSpace = $MI_Metric_Storage.Data.Average | select -Last 1
            $MI_UsedSpace = [math]::Round($MI_UsedSpace / 1KB, 2)

            # Save to Temp Object
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $Database.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerName" -Value $Database.ManagedInstanceName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DatabaseName" -Value $Database.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "SQL Managed Instance Database"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Edition" -Value $Edition
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Sku" -Value $Sku
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "vCore" -Value $vCore
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ElasticPoolName" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "IsReplica" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "FailoverGroupEnabled" -Value $FailoverGroupEnabled
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "FailoverGroupName" -Value $FailoverGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "BackupStorageRedundancy" -Value $BackupStorageRedundancy
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ZoneRedundant" -Value $ZoneRedundant
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPrivateEndpoint" -Value $EnabledPrivateEndpoint
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllowPublicNetworkAccess" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllowAzureServiceAccess" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "RestrictOutboundNetworkAccess" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPublicEndpoint" -Value $EnabledPublicEndpoint
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "PITR(Day)" -Value $ShortTerm.RetentionDays
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "WeeklyRetention" -Value $WeeklyRetention
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "MonthlyRetention" -Value $MonthlyRetention
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "YearlyRetention" -Value $YearlyRetention
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "MaxDBSize(GB)"  -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "UsedSpace(GB)" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "UsedSpacePercentage" -Value "N/A"
            #Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllocatedSpace(GB)" -Value "N/A"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerReservedSize(GB)"  -Value $MI_ReservedSpace
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerUsedSize(GB)"  -Value $MI_UsedSpace
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "DBCreationDate" -Value $Database.CreationDate
            $Global:SqlSetting += $obj
        }
    }
    #EndRegion Azure SQL Managed Instance
}

#Region Export
if ($Global:SqlSetting.Count -ne 0) {

    # Backup Status Summary 
    for ($i = 0; $i -lt 4; $i++) {
        switch ($i) {
            0 { 
                $CurrentSettingStatus = $Global:SqlSetting | group ResourceType, "PITR(Day)" | select Name, Count 
                $RetentionType = "Point-in-time restore (PITR)"
            }
            1 { 
                $CurrentSettingStatus = $Global:SqlSetting | group ResourceType, WeeklyRetention | select Name, Count 
                $RetentionType = "Long-term retention (Weekly)"
            }
            2 { 
                $CurrentSettingStatus = $Global:SqlSetting | group ResourceType, MonthlyRetention | select Name, Count 
                $RetentionType = "Long-term retention (Monthly)"
            }
            3 { 
                $CurrentSettingStatus = $Global:SqlSetting | group ResourceType, YearlyRetention | select Name, Count 
                $RetentionType = "Long-term retention (Yearly)"
            }
        }

        foreach ($item in $CurrentSettingStatus) {
            $ResourceType = $item.Name.Substring(0, $item.Name.IndexOf(","))
            $Retention = $item.Name.Substring($item.Name.IndexOf(",") + 1)
            $ResourceTotal = $Global:SqlSetting | group ResourceType | ? {$_.Name -eq $ResourceType} | select -ExpandProperty Count

            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value $ResourceType
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "RetentionType" -Value $RetentionType
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Retention" -Value $Retention
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $ResourceTotal
            $Global:SqlSettingSummary += $obj
        }
    }

    # Access Summary
    # Zone Redundant per SQL Database(s) and SQL Managed Instance Database
    $ZoneRedundantSetting = $Global:SqlSetting | ? {$_.ResourceType -eq "SQL Database"} | select SubscriptionName, ServerName, ZoneRedundant
    $ZoneRedundantSetting += $Global:SqlSetting | ? {$_.ResourceType -eq "SQL Managed Instance Database"} | select -Unique SubscriptionName, ServerName, ZoneRedundant
    
    # Private Endpoint per SQL Server and SQL Managed Instance Database
    $AllSetting = $Global:SqlSetting | select -Unique SubscriptionName, ServerName, EnabledPrivateEndpoint
    
    # Per SQL Server
    $SqlServerSetting = $Global:SqlSetting | ? {$_.ResourceType -eq "SQL Database"} | select -Unique SubscriptionName, ServerName, AllowPublicNetworkAccess, AllowAzureServiceAccess, RestrictOutboundNetworkAccess
    
    # Per SQL Managed Instance Database
    $SqlMISetting = $Global:SqlSetting | ? {$_.ResourceType -eq "SQL Managed Instance Database"} | select -Unique SubscriptionName, ServerName, EnabledPublicEndpoint

    $CurrentSettingStatus = $Global:SqlSetting | group ZoneRedundant | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "ZoneRedundant"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $ZoneRedundantSetting.Count
        $Global:SqlAccessSummary += $obj
    }

    $CurrentSettingStatus = $AllSetting| group EnabledPrivateEndpoint | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "EnabledPrivateEndpoint"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $AllSetting.Count
        $Global:SqlAccessSummary += $obj
    }

    $CurrentSettingStatus = $SqlServerSetting | group AllowPublicNetworkAccess | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "AllowPublicNetworkAccess"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $SqlServerSetting.Count
        $Global:SqlAccessSummary += $obj
    }

    $CurrentSettingStatus = $SqlServerSetting | group AllowAzureServiceAccess | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "AllowAzureServiceAccess"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $SqlServerSetting.Count
        $Global:SqlAccessSummary += $obj
    }

    $CurrentSettingStatus = $SqlServerSetting | group RestrictOutboundNetworkAccess | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "RestrictOutboundNetworkAccess"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $SqlServerSetting.Count
        $Global:SqlAccessSummary += $obj
    }

    $CurrentSettingStatus = $SqlMISetting | group EnabledPublicEndpoint | select Name, Count 
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value "EnabledPublicEndpoint"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $SqlMISetting.Count
        $Global:SqlAccessSummary += $obj
    }

    # Export to Excel File
    $Global:SqlSettingSummary | sort ResourceType, RetentionType | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "Sql_SqlMI_BackupSummary" -TableName "Sql_SqlMI_BackupSummary" -TableStyle Medium16 -AutoSize -Append
    $Global:SqlAccessSummary | sort ResourceType, RetentionType | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "Sql_SqlMI_Summary" -TableName "Sql_SqlMI_Summary" -TableStyle Medium16 -AutoSize -Append
    $Global:SqlSetting | sort ResourceType, SubscriptionName, DatabaseName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "Sql_SqlMI_Detail" -TableName "Sql_SqlMI_Detail" -TableStyle Medium16 -AutoSize -Append
} else {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure SQL"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:SqlSettingSummary += $obj

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure SQL Managed Instance"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:SqlSettingSummary += $obj

    # Export to Excel File
    $Global:SqlSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ResourceNotFound" -TableName "ResourceNotFound" -TableStyle Light11 -AutoSize -Append
}
#EndRegion Export