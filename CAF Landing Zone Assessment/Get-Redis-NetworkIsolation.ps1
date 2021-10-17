# Global Parameter
$CsvFullPath = "C:\Temp\Azure-Redis-Configuration.csv" # Export Result to CSV file 

# Script Variable
$Global:RedisCacheSetting = @()
[int]$CurrentItem = 1
$ErrorActionPreference = "SilentlyContinue"

# Login
az login

# Get Azure Subscription
$Subscriptions = az account list | ConvertFrom-Json

# Main
foreach ($Subscription in $Subscriptions) {
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

        # Redis vNet integration 
        if ($RedisCache.sku.name -eq "Premium" -and $RedisCache.subnetId -ne $null) {
            $EnabledVNetIntegration = "Y"
        } else {
            $EnabledVNetIntegration = "N"
        }

        # Redis Private Endpoint
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

# Export Result to CSV file 
$Global:RedisCacheSetting | sort InstanceType, SubscriptionName | Export-Csv -Path $CsvFullPath -NoTypeInformation -Confirm:$false -Force

# End
Write-Host "`nCompleted`n" -ForegroundColor Yellow