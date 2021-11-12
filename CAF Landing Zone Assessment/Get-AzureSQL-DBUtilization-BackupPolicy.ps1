# Script Variable
$Global:BackupStatus = @()
$Global:BackupStatusSummary = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet Database Utilization, Point-in-time restore (PITR), and Long-term retention (LTR) of Azure SQL and Azure SQL Managed Instance" -ForegroundColor Cyan


foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    $AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++

    #Region Azure SQL
	$SqlServers = Get-AzSqlServer
	$Databases = $SqlServers | Get-AzSqlDatabase | ? {$_.DatabaseName -ne "Master" -and $_.Edition -ne "DataWarehouse"}

	foreach ($Database in $Databases) {
        Write-Host ("Resource: " + $Database.DatabaseName)

        # Elastic Pool
        if ($Database.ElasticPoolName -eq $null) { $PoolName = "N/A" } else { $PoolName = $Database.ElasticPoolName }

        # Pricing Tier
        $Edition = $Database.Edition
        if ($Edition -eq "Premium" -or $Edition -eq "Standard" -or $Edition -eq "Basic") {
            $Sku = $Database.CurrentServiceObjectiveName
        } else {
            $Sku = $Database.SkuName
        }

        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subscription" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroupName" -Value $Database.ResourceGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerName" -Value $Database.ServerName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DatabaseName" -Value $Database.DatabaseName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value "SQL Database"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Edition" -Value $Edition
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Sku" -Value $Sku
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ElasticPoolName" -Value $PoolName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Database.Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "CreationDate" -Value $Database.CreationDate
        
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
        $db_metric_allocated_data_storage = Get-AzMetric -ResourceId $Database.ResourceId -MetricName 'allocated_data_storage' -WarningAction SilentlyContinue
        $db_AllocatedSpace = $db_metric_allocated_data_storage.Data.Average | select -Last 1
        $db_AllocatedSpace = [math]::Round($db_AllocatedSpace / 1GB, 2) 

        Add-Member -InputObject $obj -Name "MaximumStorageSize(GB)" -MemberType NoteProperty -Value $db_MaximumStorageSize
        Add-Member -InputObject $obj -Name "UsedSpace(GB)" -MemberType NoteProperty -Value $db_UsedSpace
        Add-Member -InputObject $obj -Name "UsedSpacePercentage" -MemberType NoteProperty -Value $db_UsedSpacePercentage
        Add-Member -InputObject $obj -Name "AllocatedSpace(GB)" -MemberType NoteProperty -Value $db_AllocatedSpace
        Add-Member -InputObject $obj -Name "ServerReserved(GB)" -MemberType NoteProperty -Value "N/A"
        Add-Member -InputObject $obj -Name "ServerUsed(GB)" -MemberType NoteProperty -Value "N/A"
        
        # Backup Policy
        Write-Host ("[Get-AzSqlDatabaseBackupShortTermRetentionPolicy] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
        $ShortTerm = Get-AzSqlDatabaseBackupShortTermRetentionPolicy  -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -DatabaseName $Database.DatabaseName
        Write-Host ("[Get-AzSqlDatabaseBackupLongTermRetentionPolicy] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
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

        Add-Member -InputObject $obj -MemberType NoteProperty -Name "PITR" -Value $ShortTerm.RetentionDays
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "WeeklyRetention" -Value $WeeklyRetention
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "MonthlyRetention" -Value $MonthlyRetention
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "YearlyRetention" -Value $YearlyRetention
        $Global:BackupStatus += $obj
	}
    #EndRegion Azure SQL

    #Region Azure SQL Managed Instance
	$SqlServers = Get-AzSqlInstance
	$Databases = $SqlServers | Get-AzSqlInstanceDatabase | ? {$_.Name -ne "Master"}

    #EndRegion Azure SQL Managed Instance
}

#Region Export
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Export to Excel File
$Global:LBackupStatus | Export-Csv -Path C:\Temp\AzureSqlDatabase-Size-BackupRetention.csv -NoTypeInformation -Confirm:$false -Force
#EndRegion Export