# Get Redis Cache Network Status


az login
az account set --subscription "subscription_id"
$redis = az redis show --resource-group "rg_name" --name "instance_name"
$redis = $redis | ConvertFrom-Json

# 1 Redis VNet integration 
# Confirm the status by below properties 
$redis.sku.Name -eq "Premium"
$redis.subnetId -eq $null

# 2 Redis Private Endpoint
$redis.privateEndpointConnections -eq $null # Check if no endpoint is added
$redis.publicNetworkAccess -eq "Enabled" # Check if allow public access is enabled