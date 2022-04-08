```
# Target
- Azone
    - Support more services
        - Azure Cosmos DB
        - Azure Database for MySQL
        - Azure Database for PostgreSQL
- Well-Architected Framework Operational Excellence
    - Check resource group that contain no resource
    - Tagging
    - Service Health Alert configuration, verify if the location where user has deployed the services that is configured the service alert (Region based)
    - Resource Health Alert
- Well-Architected Framework Security
    - Resource Lock of subscription and resource group level
    - Microsoft Defender for XXX
    - Get-AzDdosProtectionPlan > Get Azure DDoS Standard enabled in all VNET, highlight subnet with Firewall, Gateway, AppGW
- Network
    - Get Storage Account, Key Vault, Container Registry, PaaS Database, SQL managed instance (Public Endpoint) Network Rule
    - Check Private Endpoint Status for above resources 
- Azure Database for MySQL
    - Get Backup retention and redundancy option
- Cosmos DB
    - Get Backup Info (periodic mode backup policy includes Backup Interval, Retention, Copies of data retained, storage redundancy) and (continuous backup mode)
- Get Service Endpoint Status of all VNet Subnet (TBC)
- Get Management Group hierarchy (TBC)
```
