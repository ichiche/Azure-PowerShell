# Script Variable
$Global:RedisCacheSetting = @()
$Global:RedisCacheSettingSummary = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "SilentlyContinue"

# Module
Import-Module ImportExcel

# Main
Write-Host "`nCollect Azure Cache for Redis Network Configuration has been started" -ForegroundColor Yellow

foreach ($Subscription in $Global:Subscriptions) {
    az account set --subscription $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $Subscription.name + "`n") -ForegroundColor Yellow
    $CurrentItem++
    
    # Get the Redis Cache List of current subscription
    $RedisCaches = az redis list | ConvertFrom-Json

    # Get configuration of each Redis Cache
    foreach ($RedisCache in $RedisCaches) {
        # SKU
        $sku = ($RedisCache.sku.name + ": " + $RedisCache.sku.family + $RedisCache.sku.capacity)

        # Zone
        if ($RedisCache.zones -eq $null) {
            $EnabledZoneRedundant = "N"
            $DeployedZoneRedundant = "N/A"
        } else {
            $EnabledZoneRedundant = "Y"
            $DeployedZoneRedundant = $RedisCache.zones
        }

        # Redis vNet integration (Not compatible with Redis Private Endpoint)
        if ($RedisCache.sku.name -eq "Premium" -and $RedisCache.subnetId -ne $null) {
            $EnabledVNetIntegration = "Y"
        } else {
            $EnabledVNetIntegration = "N"
        }

        # Redis Private Endpoint (Not compatible with Redis vNet integration)
        if ($RedisCache.privateEndpointConnections -ne $null) {
            $EnabledPrivateEndpoint = "Y"
        } else {
            $EnabledPrivateEndpoint = "N"
        }

        if ($RedisCache.publicNetworkAccess -ne "Enabled") {
            $AllowPrivateEndpointOnly = "Y"
        } else {
            $AllowPrivateEndpointOnly = "N"
        }

         # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $RedisCache.resourceGroup
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $RedisCache.name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Size" -Value $sku
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $RedisCache.location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledZoneRedundant" -Value $EnabledZoneRedundant
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DeployedZoneRedundant" -Value $DeployedZoneRedundant
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledVNetIntegration" -Value $EnabledVNetIntegration
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPrivateEndpoint" -Value $EnabledPrivateEndpoint
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllowPrivateEndpointOnly" -Value $AllowPrivateEndpointOnly

        # Save to Array
        $Global:RedisCacheSetting += $obj
    }
}

# Prepare Redis Cache Setting Summary
$SettingStatus = $Global:RedisCacheSetting

for ($i = 0; $i -lt 3; $i++) {

    switch ($i) {
        0 { 
            $CurrentSettingStatus = $SettingStatus | group EnabledZoneRedundant | select Name, Count 
            $NetworkType = "Zone Redundant"
        }
        1 { 
            $CurrentSettingStatus = $SettingStatus | group EnabledVNetIntegration | select Name, Count 
            $NetworkType = "VNet Integration"
        }
        2 { 
            $CurrentSettingStatus = $SettingStatus | group EnabledPrivateEndpoint | select Name, Count 
            $NetworkType = "Private Endpoint"
        }
    }
    
    foreach ($item in $CurrentSettingStatus) {
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Item" -Value $NetworkType
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Enabled" -Value $item.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subtotal" -Value $item.Count
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Total" -Value $Global:RedisCacheSetting.Count
        $Global:RedisCacheSettingSummary += $obj
    }
}

# Export to Excel File
$Global:RedisCacheSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "RedisCacheSummary" -TableName "RedisCacheSummary" -TableStyle Medium16 -AutoSize -Append
$Global:RedisCacheSetting | sort InstanceType, SubscriptionName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "RedisCacheDetail" -TableName "RedisCacheDetail" -TableStyle Medium16 -AutoSize -Append