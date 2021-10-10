# Contributing
```
All scripts in repository are used for DevTest only.
```

# Prerequisites

| Item | Name | Version | Installation | 
| - | - | - | - | 
| 1 | PowerShell | 5.1 or above | https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows | 
| 2 | Az Module | 6.4.0 | https://www.powershellgallery.com/packages/Az |
| 3 | Azure CLI | 2.28.0 | https://docs.microsoft.com/en-us/cli/azure/install-azure-cli |
| 4 | ImportExcel | 7.3.0 | https://www.powershellgallery.com/packages/ImportExcel |

# Script Modification

- Variable under **# Global Parameter** is expected to modify
- Variable under **# Script Variable** is expected NOT to modify
- Modify **# Login** if you would like to leverage **Connect-To-Cloud.ps1** to login Azure

# Instruction

1. Review **README.md** in **Connection**
1. Fork a repository or download the necessary script to local computer
1. Modify the script if necessary
1. Execute the script from Windows PowerShell

# File List
| Id | File Name | Folder | Description |
| - | - | - | - |
| 1 | Encrypt-Password-Embed.ps1 | SecureString | Specify the password in script file, converting to **SecureString** and output to text file finally |
| 2 | Encrypt-Password-ReadHost.ps1 | SecureString | Enter the password at PowerShell session for Converting to **SecureString** and output to text file finally |
| 3 | Connect-To-Cloud.ps1 | Connection | Login Azure using PowerShell with encrypted credential |
| 4 | Get-Azone-Service.ps1 | CAF Landing Zone Assessment | Get the Azure Services supporting Availability Zones of all subscriptions |
| 5 | Get-NSG-Rule.ps1 | Security | Get Custom Rule and Association of **Network Security Group (NSG)** of all subscriptions |
| 6 | Create-Image-From-Disk.ps1 | Virtual Machine | Create Azure VM Image from **Managed Disk** |
| 7 | Get-ASR-ReplicationProtectedItem.ps1 | Recovery Service | Get Site Recovery Replication Protected Items |
| 8 | Get-Classic-Resource.ps1 | Classic and Unmanaged Service | List **Classic Resource** (ASM) in the subscription |
| 9 | Get-Classic-VM.ps1 | Classic and Unmanaged Service | List **Classic Virtual Machine** (ASM) in the subscription |
| 10 | Get-Unmanaged-Disk.ps1 | Classic and Unmanaged Service | List **Unmanaged Disk** attached to a VM |
