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

# Limitation
App Service with Zone Redundant is supported to be created by ARM template at this moment. Zone redundant status is shown on Azure Portal only. Az Module and Azure CLI are not able to retrieve the Zone redundant status.

**Reference**
https://docs.microsoft.com/en-us/azure/app-service/how-to-zone-redundancy#how-to-deploy-a-zone-redundant-app-service


# Regions and Availability Zones in Azure
https://docs.microsoft.com/en-us/azure/availability-zones/az-overview#services-by-category
