# Script Variable
$Global:RedisCacheSetting = @()
$Global:RedisCacheSettingSummary = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "Continue"

# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"

# Module
Import-Module ImportExcel

# Main
Write-Host ("`n" + "=" * 100)
Write-Host "`nGet Azure Cache for Redis Network Configuration" -ForegroundColor Cyan

foreach ($Subscription in $Global:Subscriptions) {
    Write-Host ("`n")
    Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
    az account set --subscription $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Global:Subscriptions.Count + " Subscription: " + $Subscription.name) -ForegroundColor Yellow
    $CurrentItem++
    
    # Get the Redis Cache List of current subscription
    $RedisCaches = az redis list | ConvertFrom-Json

    # Get configuration of each Redis Cache
    foreach ($RedisCache in $RedisCaches) {
        # SKU
        $sku = ($RedisCache.sku.name + ": " + $RedisCache.sku.family + $RedisCache.sku.capacity)

        # Zone
        if ($RedisCache.zones -eq $null) {
            $EnabledAZone = "N"
            $DeployedZone = "N/A"
        } else {
            $EnabledAZone = "Y"
            $DeployedZone = $RedisCache.zones
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

        if ($RedisCache.publicNetworkAccess -eq "Enabled") {
            $AllowPublicNetworkAccess = "Y"
        } else {
            $AllowPublicNetworkAccess = "N"
        }

         # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $RedisCache.resourceGroup
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceName" -Value $RedisCache.name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Size" -Value $sku
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $RedisCache.location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledAZone" -Value $EnabledAZone
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DeployedZone" -Value $DeployedZone
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledVNetIntegration" -Value $EnabledVNetIntegration
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "EnabledPrivateEndpoint" -Value $EnabledPrivateEndpoint
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AllowPublicNetworkAccess" -Value $AllowPublicNetworkAccess

        # Save to Array
        $Global:RedisCacheSetting += $obj
    }
}

#Region Export
if ($Global:RedisCacheSetting.Count -ne 0) {
    # Prepare Redis Cache Setting Summary
    $SettingStatus = $Global:RedisCacheSetting

    for ($i = 0; $i -lt 4; $i++) {
        switch ($i) {
            0 { 
                $CurrentSettingStatus = $SettingStatus | group EnabledAZone | select Name, Count 
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
            3 { 
                $CurrentSettingStatus = $SettingStatus | group AllowPublicNetworkAccess | select Name, Count 
                $NetworkType = "Allow Internet Access"
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
    $Global:RedisCacheSetting | sort SubscriptionName | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "RedisCacheDetail" -TableName "RedisCacheDetail" -TableStyle Medium16 -AutoSize -Append
} else {
    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceType" -Value "Azure Cache for Redis"
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Status" -Value "Resource is not found"
    $Global:RedisCacheSettingSummary += $obj
   
    # Export to Excel File
    $Global:RedisCacheSettingSummary | Export-Excel -Path $Global:ExcelFullPath -WorksheetName "ResourceNotFound" -TableName "ResourceNotFound" -TableStyle Light11 -AutoSize -Append
}
#EndRegion Export