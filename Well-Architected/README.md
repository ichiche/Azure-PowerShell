# Instruction

## QuickStart

1. Download all scripts to same local directory
1. Modify **Global Parameter**
1. Open a **Windows PowerShell** with **Version 7 or above**
1. Change current directory to where the script exist
1. Run the script either one of below method
   1. Directly execute **Run.ps1**
   1. Copy the content of **Run.ps1** and paste into **Windows PowerShell**
1. [Optional] Separately Login Azure using Az Module and Azure CLI in **Windows PowerShell** and retrieve the list of certain subscriptions

## Remark

- Refer to To-Do-List.md for upcoming enhancement

## Scope of functionalities

- Get Azure Backup status of **Azure VM**, **SQL Server in Azure VM**, and **Azure Blob Storage**
- Get Capacity, PITR, LTR, Backup Storage, Replication, Redundancy of Azure SQL / Azure SQL Managed Instance
- Collect Diagnostic Setting
   - Support to get Diagnostic Setting of most mainstream services
- Collect Azure Cache for Redis Network Configuration
   - Include Availability Zones
- Get Availability Zone Enabled Service  
- Get Classic Resource

## Availability Zone

Get the Azure Services with **Availability Zones** enabled in the subscription of follow Azure Services:

**Get-AZoneEnabledService.ps1**
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

**Get-AzureSql-SqlMI-Configuration.ps1**
- Azure SQL Database
- Azure SQL Managed Instance

#### App Service

- Zone Redundant is supported to be created by ARM template at this moment
- Zone redundant status is shown on Azure Portal only
- Az Module and Azure CLI are not able to retrieve the Zone redundant status
- https://docs.microsoft.com/en-us/azure/app-service/how-to-zone-redundancy#how-to-deploy-a-zone-redundant-app-service

#### Storage Account

- V1 is recommended to upgrade

#### Regions and Availability Zones in Azure

- https://docs.microsoft.com/en-us/azure/availability-zones/az-overview#services-by-category

## Azure Kubernetes Service (AKS)

- In Summary Page, it indicates by node pool instead of Kubernetes Cluster instance 

## Azure SQL

#### Limitation

- Support to identify a Replica Database, but not support to confirm whether a Database has enabled Geo-Replica
- Support to identify a Database is added to Failover Group, but not support to explicitly indicate Primary and Secondary of Failover Group

## Azure SQL Managed Instance

#### Limitation

- Not support to query the Instance Pool
- Support to identify a Database is added to Failover Group, but not support to explicitly indicate Primary and Secondary of Failover Group

## Redis Cache

**Get-Redis-NetworkIsolation.ps1**
- Verify whether **Availability Zones** is enabled
- Collect the configuration of Network Isolation Method of Redis Cache Instance
- Require Azure CLI

Reference

- https://docs.microsoft.com/en-us/azure/azure-cache-for-redis/cache-network-isolation

## Virtual Machine

#### Limitation

For verifying the status of **Region Disaster Recovery** and **Zone to Zone Disaster Recovery**

- Azure Portal (Supported)
- Az Module (Supported)
   - Require additional permission to perform action 'Microsoft.RecoveryServices/vaults/extendedInformation/write'
- Azure CLI (Not Supported)

## Azure Backup

#### Limitation

- Support to query the existing Azure VM only
   - Not support to detect a deleted VM but backup copy exist in a Recovery Service Vault
- Not Support to list the Azure File Share with/without backup enabled
   - Although RunAs account with read only permission is capable to retrieve Azure File Share Backup Copy by running Get-AzRecoveryServicesBackupProtectionPolicy, it is not able to list Azure File Share of all storage account without access key or using read only access account
- Clarify the backup status SQL Server in Azure VM replied on Resource Type **Microsoft.SqlVirtualMachine/SqlVirtualMachines**
   - Azure VM Agent has to function properly in order to reflect whether SQL Server is installed on Azure VM 
   - Support to query the Databases that enable backup, not support to query the Databases that has not enable backup

## Resource Type Matrix

| Azure Services | Resource Type | Is Hidden Resource | Support Tagging | 
| - | - | - | - | 
| Availability Test | microsoft.insights/webtests | No | Yes |
| API Connection | Microsoft.Web/connections | No | Yes |
| Application Insights | microsoft.insights/components | No | Yes |
| Data collection Rule | microsoft.Insights/dataCollectionRules | No | Yes |
| Azure Workbook | microsoft.insights/workbooks | No | Yes |
| Azure Lab Account | Microsoft.LabServices/labaccounts | No | Yes |
| Data Share | Microsoft.DataShare/accounts | No | Yes |
| Managed Identity | Microsoft.ManagedIdentity/userAssignedIdentities | No | Yes |
| On-premises Data Gateway | Microsoft.Web/connectionGateways | No | Yes |
| App Service Environment | Microsoft.Web/hostingEnvironments | No | Yes |
| Azure DevOps Organization | microsoft.visualstudio/account | No | No | 
| SQL Managed Instance Database | Microsoft.Sql/managedInstances/databases | No | No | 
| SQL Virtual Cluster | Microsoft.Sql/virtualClusters | No | No | 
| Service Endpoint Policy | Microsoft.Network/serviceEndpointPolicies | No | Yes | 