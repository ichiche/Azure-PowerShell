# To Do List
```
- Get App Service vNet Peering
- Get Classic Resources includes Cloud Service
- Check resource group that contain no resource
- Set VM Static Private IP
- Get Diagnostic Setting of core component
- Update Azone Script to support more services
- Get vNet Peering Status and Route Table, draw relationship diagram
- Get Service Endpoint Status
- Get Resource Lock 
- Get Service Health Alert configuration
```

# Contributing
```
All scripts in repository are used for DevTest only.
```

# Installation
| Item | Name | Version |
| - | - | - | 
| 1 | PowerShell | 5.1 or above |
| 2 | Az Module | 6.4.0 |
| 3 | Azure CLI | 2.28.0 |

# Script Configuration
- Variable under **# Global Parameter** is expected to modify
- Variable under **# Script Variable** is expected NOT to modify
- Modify **# Login** if you would like to leverage **Connect-To-Cloud.ps1** to login Azure

# File List
| Id | File Name | Folder | Description |
| - | - | - | - |
| 1 | Encrypt-Password-Embed.ps1 | SecureString | Specify the password in script file, converting to **SecureString** and output to text file finally |
| 2 | Encrypt-Password-ReadHost.ps1 | SecureString | Enter the password at PowerShell session for Converting to **SecureString** and output to text file finally |
| 3 | Connect-To-Cloud.ps1 | Connection | Login Azure using PowerShell with encrypted credential |
| 4 | Get-Azone-Service.ps1 | Availability Zone | Get the Azure Services supporting Availability Zones of all subscriptions |
| 5 | Get-NSG-Rule.ps1 | Security | Get Custom Rule and Association of **Network Security Group (NSG)** of all subscriptions |
| 6 | Create-Image-From-Disk.ps1 | Virtual Machine | Create Azure VM Image from **Managed Disk** |
| 7 | Get-Unmanaged-Disk.ps1 | Storage | List **Unmanaged Disk** attached to a VM |
| 8 | Get-ASR-ReplicationProtectedItem.ps1 | Recovery Service | Get Site Recovery Replication Protected Items |

# Azure Services Naming Principle
- Alphanumeric Characters
- Not allow characters: **` ~ ! @ # $ % ^ & * ( ) = + [ ] { } \ | ; : . ' " , < > / ?**
