# Contributing
All scripts in repository are used for DevTest only.

# Azure Services Naming Principle
- Alphanumeric Characters
- Not allow characters: ` ~ ! @ # $ % ^ & * ( ) = + [ ] { } \ | ; : . ' " , < > / ?

# Prior to Run the Script

- Variable under **# Global Parameter** is expected to modify
- Variable under **# Script Variable** is expected NOT to modify
- Decide to use either **Connect-To-Cloud.ps1** or manually run command **Connect-AzAccount** to login

# File List

| Id | File Name | Description |
| - | - | - |
| 1 | Get-NSG-Rule.ps1 | Get NSG Custom Rule and Association of all Azure Subscriptions |
| 2 | Get-Azone-Service.ps1 | Get the replication method of Azure Services supporting Availability Zones of all Azure Subscriptions |
| 3 | Create-Image-FromDisk.ps1 | Create Azure VM Image from Managed Disk |

