# Scope of functionalities

Retrieve the instance information includes pricing tier, current redundancy method, zone redundancy configuration of follow Azure Services:

- Application Gateway
- Event Hub (Namespace)
- Azure Kubernetes Service (AKS)
- Virtual Network Gateway
- Recovery Services Vault
- Storage Account
- Virtual Machine
- Virtual Machine Scale Set
- Managed Disk
- Api Management
- Azure Firewall

**To be updated**
- Azure Cache for Redis
- Azure SQL Database (Preview)
- Azure SQL Managed Instance (Preview)
- Azure Cosmos DB
- Azure Database for MySQL
- Azure Database for PostgreSQL

# Limitation

## App Service

Zone Redundant is supported to be created by ARM template at this moment. Zone redundant status is shown on Azure Portal only. Az Module and Azure CLI are not able to retrieve the Zone redundant status.

## Virtual Machine

1. It is supported to verify the status of **Region Disaster Recovery** and **Zone to Zone Disaster Recovery** using Azure Portal.

1. Az Module require additional permission to perform action 'Microsoft.RecoveryServices/vaults/extendedInformation/write', reader role is not enough. 

1. Azure CLI does not support.

**Reference**

https://docs.microsoft.com/en-us/azure/app-service/how-to-zone-redundancy#how-to-deploy-a-zone-redundant-app-service

# Regions and Availability Zones in Azure

https://docs.microsoft.com/en-us/azure/availability-zones/az-overview#services-by-category
