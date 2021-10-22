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
    [string]$RefVM_vNetRG = 'ImageWorkingItem',
    [Parameter(Mandatory=$false)]
    [string]$RefVM_vNetName = 'vNet-ImageVM',
    [Parameter(Mandatory=$false)]
    [string]$RefVM_vNetSubnetName = 'default',
    [Parameter(Mandatory=$false)]
    [string]$GalleryRG = 'Image',
    [Parameter(Mandatory=$false)]
    [string]$GalleryName = 'SharedImage'
)

# Function to align the Display Name
function Rename-Location {
    param (
        [string]$Location
    )

    foreach ($item in $Global:NameReference) {
        if ($item.Location -eq $Location) {
            $Location = $item.DisplayName
        }
    }

    return $Location
}

# Script Variable
$connectionName = "AzureRunAsConnection"
$VMSize = "Standard_D2s_v3"
$DiskType = "StandardSSD_LRS"
$osDiskSizeInGb = 160
$DataDisk0SizeInGb = 8
$TimeZone = "China Standard Time"

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

# Get the Latest Location Name and Display Name
$Global:NameReference = Get-AzLocation

# Delete Existing Reference VM if exist

# Get Latest Image Version from Shared Image Gallery
$GalleryImageDefinition = Get-AzGalleryImageDefinition -ResourceGroupName $GalleryRG -GalleryName $GalleryName -Name $GalleryImageDefinitionName
$Location = Rename-Location -Location $GalleryImageDefinition.Location
$GalleryImageVersion = Get-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinitionName

for ($i = 0; $i -lt $GalleryImageVersion.Count; $i++) {
    if ($i -eq 0) { 
        [DateTime]$LastVersionDate = $GalleryImageVersion[$i].PublishingProfile.PublishedDate
    }

    if ($LastVersionDate -lt $GalleryImageVersion[$i].PublishingProfile.PublishedDate) {
        $LastVersionDate = $GalleryImageVersion[$i].PublishingProfile.PublishedDate
        $LastVersionIndex = $i
    }
}

# Create Reference VM based on the last version of image from Shared Image Gallery
# VM Image
$vm = New-AzVMConfig -VMName $ReferenceVMName -VMSize $VMSize
$vm = Set-AzVMSourceImage -VM $vm -Id $GalleryImageVersion[$LastVersionIndex].Id

# OS Disk
$osDiskName = "$ReferenceVMName-OS-Drive"
$vm = Set-AzVMOSDisk -VM $vm -Name $osDiskName -StorageAccountType $DiskType -DiskSizeInGB $osDiskSizeInGb -CreateOption FromImage -Caching ReadWrite

# Data Disk 0
$DataDisk0Name = "$ReferenceVMName-Data-Drive-0"
Add-AzVMDataDisk -VM $vm -Name $DataDisk0Name -StorageAccountType $DiskType -DiskSizeInGB $DataDisk0SizeInGb -Lun 0 -CreateOption FromImage -Caching ReadWrite

# OS Setting
$LocalSupportName = "tempadm"
$LocalSupportPassword = "lab@2015P@ssw0rd"
$LocalSupportCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocalSupportName, ($LocalSupportPassword | ConvertTo-SecureString -AsPlainText -Force)
$vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $ReferenceVMName -Credential $LocalSupportCredential -ProvisionVMAgent -TimeZone $TimeZone

# Network Interface
$NICName = "$ReferenceVMName-Ethernet0"
$vNet = Get-AzVirtualNetwork -Name $RefVM_vNetName -ResourceGroupName $RefVM_vNetRG
$SubnetId = $vNet.Subnets.Id | ? {$_ -like "*$RefVM_vNetSubnetName*"}
$nic = New-AzNetworkInterface -Name $NICName -ResourceGroupName $RefVM_vNetRG -Location $Location -SubnetId $SubnetId -Confirm:$false
$nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
Set-AzNetworkInterface -NetworkInterface $nic
#$VMIpAddress = $nic.IpConfigurations[0].PrivateIpAddress
$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id -Primary

# Disable Boot Diagnostics
Set-AzVMBootDiagnostic -VM $vm -Disable

# Deploy VM
New-AzVM -VM $vm -ResourceGroupName $ReferenceVMRG -Location $Location -LicenseType Windows_Server

# Prepare Script for Windows Update
'usoclient.exe StartScan' | Out-File .\InstallWindowUpdate.ps1 -Force -Confirm:$false
'usoclient.exe StartDownload' | Out-File .\InstallWindowUpdate.ps1 -Append -Confirm:$false
'usoclient.exe StartInstall' | Out-File .\InstallWindowUpdate.ps1 -Append -Confirm:$false

# Prepare Script for restart computer 
$WindowsUpdateChecking = @'
while ($true) {
    Start-Sleep -Seconds 30
    $TiWorker = Get-Process -Name TiWorker -ErrorAction SilentlyContinue
    $TrustedInstaller = Get-Process -Name TrustedInstaller -ErrorAction SilentlyContinue

    if ($TiWorker -eq $null -and $TrustedInstaller -eq $null) {
        Start-Sleep -Seconds 60

        $TiWorker = Get-Process -Name TiWorker -ErrorAction SilentlyContinue
        $TrustedInstaller = Get-Process -Name TrustedInstaller -ErrorAction SilentlyContinue

        if ($TiWorker -eq $null -and $TrustedInstaller -eq $null) {
            Restart-Computer -ComputerName localhost -ThrottleLimit 0 -Force -Confirm:$false
            break;
        }
    }
}
'@

$WindowsUpdateChecking | Out-File .\RestartVM.ps1 -Force -Confirm:$false

# Run Windows Update and restart computer after patch installation
Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath InstallWindowUpdate.ps1
Start-Sleep -Seconds 5
Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath RestartVM.ps1
Write-Output ("Windows Patching is completed" + $ResourceGroup.ResourceGroupName)