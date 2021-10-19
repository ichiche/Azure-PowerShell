#Login-AzAccount
$Subscriptions = Get-AzSubscription
$ResultArray = @()
[int]$CurrentItem = 0

foreach ($Subscription in $Subscriptions) {
    
	Set-AzContext -SubscriptionId $Subscription.Id
    $CurrentItem++
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription`n") -ForegroundColor Yellow

	$SqlServers = Get-AzSqlServer
	$Databases = $SqlServers | Get-AzSqlDatabase | ? {$_.DatabaseName -ne "Master"}

	foreach ($Database in $Databases) {
        if ($Database.ElasticPoolName -eq $null) { $PoolName = "N/A" } else { $PoolName = $Database.ElasticPoolName }

        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subscription" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroupName" -Value $Database.ResourceGroupName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerName" -Value $Database.ServerName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DatabaseName" -Value $Database.DatabaseName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value "SQL Database"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Sku" -Value $Database.SkuName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ElasticPoolName" -Value $PoolName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Database.Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "CreationDate" -Value $Database.CreationDate
        
        # Size
        $db_resource = Get-AzResource -ResourceId $Database.ResourceId

        # Database maximum storage size
        $db_MaximumStorageSize = $database.MaxSizeBytes / 1GB

        # Database used space
        $db_metric_storage = $db_resource | Get-AzMetric -MetricName 'storage'
        $db_UsedSpace = $db_metric_storage.Data.Maximum | select -Last 1
        $db_UsedSpace = [math]::Round($db_UsedSpace / 1GB, 2)

        # Database used space percentage
        $db_metric_storage_percent = $db_resource | Get-AzMetric -MetricName 'storage_percent'
        $db_UsedSpacePercentage = $db_metric_storage_percent.Data.Maximum | select -Last 1

        # Database allocated space
        $db_metric_allocated_data_storage = $db_resource | Get-AzMetric -MetricName 'allocated_data_storage'
        $db_AllocatedSpace = $db_metric_allocated_data_storage.Data.Average | select -Last 1
        $db_AllocatedSpace = [math]::Round($db_AllocatedSpace / 1GB, 2) 

        Add-Member -InputObject $obj -Name "MaximumStorageSize(GB)" -MemberType NoteProperty -Value $db_MaximumStorageSize
        Add-Member -InputObject $obj -Name "UsedSpace(GB)" -MemberType NoteProperty -Value $db_UsedSpace
        Add-Member -InputObject $obj -Name "UsedSpacePercentage" -MemberType NoteProperty -Value $db_UsedSpacePercentage
        Add-Member -InputObject $obj -Name "AllocatedSpace(GB)" -MemberType NoteProperty -Value $db_AllocatedSpace
        
        # Backup Policy
        $ShortTerm = Get-AzSqlDatabaseBackupShortTermRetentionPolicy  -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -DatabaseName $Database.DatabaseName
        $LongTerm = Get-AzSqlDatabaseBackupLongTermRetentionPolicy -ResourceGroupName $Database.ResourceGroupName -ServerName $Database.ServerName -DatabaseName $Database.DatabaseName

        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ShortTerm" -Value $ShortTerm.RetentionDays
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "WeeklyRetention" -Value $LongTerm.WeeklyRetention
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "MonthlyRetention" -Value $LongTerm.MonthlyRetention
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "YearlyRetention" -Value $LongTerm.YearlyRetention

        $TagsList = ""
        for ($i = 0;$i -lt $Database.Tags.Keys.Count;$i++) {
            if ($i -eq 0) {
                $TagsList = $($Database.Tags.Keys[$i]) + ": " + $($Database.Tags.Values[$i])
            } else {
                $TagsList += ", " + $($Database.Tags.Keys[$i]) + ": " + $($Database.Tags.Values[$i])
            }
        }

        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Tags" -Value $TagsList
        $ResultArray += $obj
	}
}

$ResultArray | Export-Csv -Path C:\Temp\AzureSqlDatabase-Size-BackupRetention.csv -NoTypeInformation -Confirm:$false -Force