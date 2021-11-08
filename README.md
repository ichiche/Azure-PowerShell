# Contributing

```
All scripts in repository are used for DevTest only.
```

# Prerequisites

| Item | Name | Version | Installation | 
| - | - | - | - | 
| 1 | PowerShell | 5.1 <br /> 7.1 | https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows | 
| 2 | Az Module | 6.4.0 | https://www.powershellgallery.com/packages/Az |
| 3 | Az.DataProtection Module | 0.3.0 | https://www.powershellgallery.com/packages/Az.DataProtection |
| 4 | Azure CLI | 2.28.0 | https://docs.microsoft.com/en-us/cli/azure/install-azure-cli |
| 5 | ImportExcel | 7.3.0 | https://www.powershellgallery.com/packages/ImportExcel |

# PowerShell Multi-threading

This project will not implement RunSpaces for PowerShell V5, all scripts with Multi-threading Capability require PowerShell V7 by using **Pipeline parallelization with ForEach-Object -Parallel**.

**Reference**

- https://docs.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-70?view=powershell-7.1
- https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacefactory.createrunspacepool?view=powershellsdk-7.0.0
- https://adamtheautomator.com/powershell-multithreading/
- https://devblogs.microsoft.com/scripting/beginning-use-of-powershell-runspaces-part-1/
- https://gist.github.com/rjmholt/02fe49189540acf0d2650f571f5176db

# Script Modification

- Variable under **# Global Parameter** is expected to modify
- Variable under **# Script Variable** is expected NOT to modify
- Modify **# Login** if you would like to leverage **Connect-To-Cloud.ps1** to login Azure

# Instruction

1. Review **README.md** in **Connection**
1. Fork a repository or download the necessary script to local computer
1. Modify the script if necessary
1. Execute the script from **Windows PowerShell**

# Disable warning messages in Azure PowerShell

```PowerShell
# Disable breaking change warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value "true"
```

**Reference**

- Configuration
  - https://docs.microsoft.com/en-us/powershell/azure/faq?view=azps-6.5.0
- Add to PowerShell profile to execute this command when every PowerShell session start
  - https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.1#the-profile-files

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
| 8 | Get-Classic-VM.ps1 | Classic and Unmanaged Service | Get **Classic Virtual Machine (ASM)** in the subscription |
| 9 | Get-Unmanaged-Disk.ps1 | Classic and Unmanaged Service | Get **Unmanaged Disk** attached to VM |
| 10 | Get-vNet-Integration.ps1 | App Service | Get the information of App Service includes status of **Virtual Network Integration** and associated vNet if exist |
| 11 | Create-vNetPeering-Diagram.ps1 | Virtual Network Diagram | Generate Virtual Network Diagram using **Diagrams.net** |
