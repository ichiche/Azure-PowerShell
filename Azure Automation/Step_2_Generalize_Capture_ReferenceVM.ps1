<#
    .DESCRIPTION
        Create Reference VM

    .NOTES
        AUTHOR: Isaac Cheng, Microsoft Customer Engineer
        EMAIL: chicheng@microsoft.com
        LASTEDIT: Oct 20, 2021
#>

Param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = '',
    [Parameter(Mandatory)]
    [ValidateSet("WS2016","WS2019","RHEL7","RHEL8")]
    [string]$OSVersion = 'WS2016 or WS2019 or RHEL7 or RHEL8',
    [Parameter(Mandatory=$false)]
    [string]$GalleryRG= 'Image',
    [Parameter(Mandatory=$false)]
    [string]$GalleryName = 'SharedImage'
)

# Script Variable
$connectionName = "AzureRunAsConnection"

switch ($OSVersion) {
    WS2016 { 
        $GalleryImageDefinitionName = "WindowsServer2016"
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "WS2016-RefVM"
    }
    WS2019 { 
        $GalleryImageDefinitionName = "WindowsServer2019"
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "WS2019-RefVM"
    }
    RHEL7 { 
        $GalleryImageDefinitionName = "RHEL7"
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "RHEL7-RefVM"
    }
    RHEL8 { 
        $GalleryImageDefinitionName = "RHEL8"
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "RHEL8-RefVM"
    }
}

try {
    # Get the connection "AzureRunAsConnection "  
    $servicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName
    $ApplicationId = $servicePrincipalConnection.ApplicationId
    $CertificateThumbprint = $servicePrincipalConnection.CertificateThumbprint
    $TenantId = $servicePrincipalConnection.TenantId                

    # Connect to Azure   
    Write-Output "Logging in to Azure..."        
    Connect-AzAccount -ApplicationId $ApplicationId -CertificateThumbprint $CertificateThumbprint -Tenant $TenantId -ServicePrincipal
    Set-AzContext -SubscriptionId $SubscriptionId
} catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Prepare Script
"C:\Windows\System32\SysPrep\sysprep.exe /generalize /oobe /shutdown /mode:vm /quiet" | Out-File .\Sysprep.ps1 -Force -Confirm:$false

# Generalize Windows VM
if ($OSVersion -like "WS*") {
    # Sysprep VM
    Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath Sysprep.ps1

    while ($true) {
        Start-Sleep -Seconds 60
        $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
        $PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"}

        if ($PowerStatus.Code -eq "PowerState/stopped") {
            Stop-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Force -Confirm:$false
            break;
        }
    }
} else { # Generalize RHEL VM

}

# Get Latest Image Version from Shared Image Gallery
$Gallery = Get-AzGallery -ResourceGroupName $GalleryRG -Name $GalleryName

# New Gallery Image Version
$GalleryImageVersionName = (Get-Date -Format "yyyy.MM.dd").ToString()
$region_eastus = @{Name = 'East US'}
$region_eastasia = @{Name = 'East Asia'}
$region_southeastasia = @{Name = 'Southeast Asia'}
$targetRegions = @($region_eastus, $region_eastasia, $region_southeastasia)
$StorageAccountType = "Premium_LRS"
$ReplicaCount = 1

# Source from VM
Set-AzVm -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Generalized
$vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName
$SourceImageId = $vm.Id
New-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinitionName -Name $GalleryImageVersionName -Location $Gallery.Location -TargetRegion $targetRegions -ReplicaCount $ReplicaCount -StorageAccountType $StorageAccountType -SourceImageId $SourceImageId

# Source from Managed Disk
$vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName
$OsDiskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
$OsDisk = @{Source = @{Id = "$OsDiskId"}}
$DataDisk0Id = $vm.StorageProfile.DataDisks[0].ManagedDisk.Id
$DataDisk0 = @{Source = @{Id = "$DataDisk0Id" }; Lun = 0; }
$DataDisks = @($DataDisk0)
New-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinitionName -Name $GalleryImageVersionName -Location $Gallery.Location -TargetRegion $targetRegions -ReplicaCount $ReplicaCount -StorageAccountType $StorageAccountType -OSDiskImage $OsDisk -DataDiskImage $DataDisks