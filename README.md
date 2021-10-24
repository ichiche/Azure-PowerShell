# Contributing

```
All scripts in repository are used for DevTest only.
```

# Prerequisites

| Item | Name | Version | Installation | 
| - | - | - | - | 
| 1 | PowerShell | 5.1 or 7.0 (LTS) | https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows | 
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
1. Execute the script from **Windows PowerShell**

# CAF Landing Zone Assessment

Refer to README.md in corresponding folder for instruction

# General Script List

| Id | File Name | Folder | Description |
| - | - | - | - |
| 1 | Encrypt-Password-Embed.ps1 | Connection | Specify the password in script file, converting to **SecureString** and export to text file |
| 2 | Encrypt-Password-ReadHost.ps1 | Connection | Enter the password at PowerShell session for Converting to **SecureString** and export to text file |
| 3 | Connect-To-Cloud.ps1 | Connection | Login Azure with pre-encrypted credential using PowerShell  |
| 4 | Get-NsgRule.ps1 | Security | Get Custom Rule and Association of **Network Security Group (NSG)** in the subscription |
| 5 | Create-Image-From-Disk.ps1 | Virtual Machine | Create Azure VM Image from **Managed Disk** |
| 6 | Set-Static-Private-IpAddress.ps1 | Set the allocation type Private IP of Virtual Machine in the subscription to Static |
| 7 | Get-ASR-ReplicationProtectedItem.ps1 | Recovery Service | Get the Site Recovery Replication Protected Items of a Recovery Service Vault |
| 8 | Get-Classic-Resource.ps1 | Classic and Unmanaged Service | Get **Classic Resource (ASM)** in the subscription |
| 9 | Get-Classic-VM.ps1 | Classic and Unmanaged Service | Get **Classic Virtual Machine (ASM)** in the subscription |
| 10 | Get-Unmanaged-Disk.ps1 | Classic and Unmanaged Service | Get **Unmanaged Disk** attached to VM |
| 11 | Get-vNet-Integration.ps1 | App Service | Get the information of App Service includes status of **Virtual Network Integration** and associated vNet if exist |
| 12 | Create-vNetPeering-Diagram.ps1 | Virtual Network Diagram | Generate Virtual Network Diagram using **Diagrams.net** |


