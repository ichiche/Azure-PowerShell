# Instruction

## Run.ps1

#### QuickStart
1. Download all scripts to same local directory
1. Modify **Global Parameter**
1. Open a **Windows PowerShell** and locate to that directory
1. Run the script either one of below method
   1. Directly execute **Run.ps1**
   1. Copy the content of **Run.ps1** and paste into **Windows PowerShell**
1. [Optional] Separately Login Azure using Az Module and Azure CLI in **Windows PowerShell** and retrieve the list of certain subscriptions

#### Remark
- Refer to To-Do-List.md for upcoming enhancement

#### Scope of functionalities
- Collect Diagnostic Setting
   - Support to get Diagnostic Setting of most mainstream services
- Collect Azure Cache for Redis Network Configuration
- Get Classic Resource
- Get Azure Backup status of **Azure VM**, **SQL Server in Azure VM**, and **Azure Blob Storage**

#### Reference
- https://docs.microsoft.com/en-us/azure/azure-cache-for-redis/cache-network-isolation

## Limitation

#### App Service

- Zone Redundant is supported to be created by ARM template at this moment
- Zone redundant status is shown on Azure Portal only
- Az Module and Azure CLI are not able to retrieve the Zone redundant status
- https://docs.microsoft.com/en-us/azure/app-service/how-to-zone-redundancy#how-to-deploy-a-zone-redundant-app-service

#### Virtual Machine

For verifying the status of **Region Disaster Recovery** and **Zone to Zone Disaster Recovery**

- Azure Portal (Supported)
- Az Module (Supported)
   - Require additional permission to perform action 'Microsoft.RecoveryServices/vaults/extendedInformation/write'
- Azure CLI (Not Supported)

#### Azure Backup

- Support to query the existing Azure VM only
   - Not support to detect a deleted VM but backup copy exist in a recovery service vault
- RunAs account with read only permission is capable to retrieve Azure File Share Backup Copy by running Get-AzRecoveryServicesBackupProtectionPolicy, but unable to list Azure File Share of all storage account without access key, thus not able to list the Azure File Share with/without backup enabled

## Get-Azone-Service.ps1

#### Scope of functionalities

Get the Azure Services supporting **Availability Zones** in the subscription includes pricing tier, current redundancy method, zone redundancy configuration of follow Azure Services:

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

#### Regions and Availability Zones in Azure

- https://docs.microsoft.com/en-us/azure/availability-zones/az-overview#services-by-category
