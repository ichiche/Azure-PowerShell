# Contributing
All scripts in repository are used for DevTest only.

# Installation
| Item | Name | Version |
| - | - | - | 
| 1 | Az Module | 6.4.0 |
| 2 | Azure CLI | 2.28.0 |

# Script Configuration

- Variable under **# Global Parameter** is expected to modify
- Variable under **# Script Variable** is expected NOT to modify
- Decide to use either **Connect-To-Cloud.ps1** or manually run command **Connect-AzAccount** to login


# Script 

| Id | File Name | Folder | Description |
| - | - | - | - |
| 1 | Encrypt-Password-Embed.ps1 | SecureString | Specify the password in script file, converting to **SecureString** and output to text file finally |
| 2 | Encrypt-Password-ReadHost.ps1 | SecureString | Enter the password at PowerShell session for Converting to **SecureString** and output to text file finally |
| 3 | Connect-To-Cloud.ps1 | Connection | Login Azure using PowerShell with encrypted credential |
| 4 | Get-Azone-Service.ps1 | Availability Zone | Get the Azure Services supporting Availability Zones of all subscriptions |
| 5 | Get-NSG-Rule.ps1 | Network | Get Custom Rule and Association of NSG of all subscriptions |
| 6 | Create-Image-From-Disk.ps1 | Azure VM | Create Azure VM Image from Managed Disk |
| 7 | ps1 | Recovery Service | Get Site Recovery Replication Protected Items |

# Azure Services Naming Principle
- Alphanumeric Characters
- Not allow characters: **` ~ ! @ # $ % ^ & * ( ) = + [ ] { } \ | ; : . ' " , < > / ?**

