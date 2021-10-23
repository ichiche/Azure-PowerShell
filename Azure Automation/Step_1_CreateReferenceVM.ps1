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
$osDiskSizeInGb = 200 # 160
$DataDisk0SizeInGb = 16 # 8
$TimeZone = "China Standard Time"

switch ($OSVersion) {
    WS2016 { 
        $GalleryImageDefinitionName = "WindowsServer2016"
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "WS2016-RefVM"
        $LicenseType = "Windows_Server"
    }
    WS2019 { 
        $GalleryImageDefinitionName = "WindowsServer2019"
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "WS2019-RefVM"
        $LicenseType = "Windows_Server"
    }
    RHEL7 { 
        $GalleryImageDefinitionName = "RHEL7"
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "RHEL7-RefVM"
        $LicenseType = "RHEL_BYOS"
    }
    RHEL8 { 
        $GalleryImageDefinitionName = "RHEL8"
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "RHEL8-RefVM"
        $LicenseType = "RHEL_BYOS"
    }
}

# Login
try {
    # Get connection "AzureRunAsConnection"  
    $servicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName
    $ApplicationId = $servicePrincipalConnection.ApplicationId
    $CertificateThumbprint = $servicePrincipalConnection.CertificateThumbprint
    $TenantId = $servicePrincipalConnection.TenantId                

    # Get credential "TempLocalAdmin"
    $TempLocalAdmin = Get-AutomationPSCredential -Name "TempLocalAdmin"
    $TempAdminAccountName = $TempLocalAdmin.UserName
    $TempAdminAccountPassword = $TempLocalAdmin.Password
    $TempAdminAccountPlainPassword = $TempLocalAdmin.GetNetworkCredential().Password
    $TempAdminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TempAdminAccountName, $TempAdminAccountPassword

    # Connect to Azure  
    Write-Output "`nConnecting to Azure using Az PowerShell Module"    
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

# Delete Reference VM if exist
$vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -ErrorAction SilentlyContinue

if($vm -ne $null) {
    Write-Output "`nDeleting existing Reference VM" 
    $RemoveAzVM = Remove-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Force -Confirm:$false
    Start-Sleep -Seconds 30

    $RefVMResource = Get-AzResource -ResourceGroupName $ReferenceVMRG | ? {$_.Name -like "$ReferenceVMName*"} | Remove-AzResource -Force -Confirm:$false
    Start-Sleep -Seconds 5
    Write-Output "`nExisting Reference VM is deleted" 
}

# Get Image Version from Shared Image Gallery
Write-Output "`nRetrieving Image Version" 
$GalleryImageDefinition = Get-AzGalleryImageDefinition -ResourceGroupName $GalleryRG -GalleryName $GalleryName -Name $GalleryImageDefinitionName
$Location = Rename-Location -Location $GalleryImageDefinition.Location
$GalleryImageVersion = Get-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinitionName

for ($i = 0; $i -lt $GalleryImageVersion.Count; $i++) {
    if ($i -eq 0) { 
        [DateTime]$LastVersionDate = $GalleryImageVersion[$i].PublishingProfile.PublishedDate
        [int]$LastVersionIndex = 0
    }

    if ($LastVersionDate -lt $GalleryImageVersion[$i].PublishingProfile.PublishedDate) {
        $LastVersionDate = $GalleryImageVersion[$i].PublishingProfile.PublishedDate
        $LastVersionIndex = $i
    }
}
Write-Output "`nImage Version is retrieved" 
Write-Output ("`nImage Version: " + $GalleryImageVersion[$LastVersionIndex].Name + " is selected")

# Create Reference VM from Shared Image Gallery
Write-Output "`nCreating Reference VM" 

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
$TempAdminAccountName = "tempadm"
$TempAdminAccountPassword = "lab@2015P@ssw0rd"
$TempAdminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TempAdminAccountName, ($TempAdminAccountPassword | ConvertTo-SecureString -AsPlainText -Force)
$vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $ReferenceVMName -Credential $TempAdminCredential -ProvisionVMAgent -TimeZone $TimeZone

# Network Interface
$NICName = "$ReferenceVMName-Ethernet0"
$vNet = Get-AzVirtualNetwork -Name $RefVM_vNetName -ResourceGroupName $RefVM_vNetRG
$SubnetId = $vNet.Subnets.Id | ? {$_ -like "*$RefVM_vNetSubnetName*"}
$nic = New-AzNetworkInterface -Name $NICName -ResourceGroupName $RefVM_vNetRG -Location $Location -SubnetId $SubnetId -Confirm:$false
$nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
Set-AzNetworkInterface -NetworkInterface $nic
$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id -Primary

# Disable Boot Diagnostics
Set-AzVMBootDiagnostic -VM $vm -Disable

# Deploy VM
New-AzVM -VM $vm -ResourceGroupName $ReferenceVMRG -Location $Location -LicenseType $LicenseType
Start-Sleep -Seconds 5
Write-Output "`nReference VM is created" 

# Wait for a certain time to ensure Guest OS has completed the initial setup process
[int]$minute = 30
while ($minute -ne 0) {
    if ($minute % 10 -eq 0 -or $minute -le 5 ) {
        Write-Output ("`n" + $minute + " minutes remaining before install Windows Update")
    }
    Start-Sleep -Seconds 60
    $minute--
}

# Prepare Script for Windows Update
"Import-Module PSWindowsUpdate" | Out-File .\InstallWindowUpdate.ps1 -Force -Confirm:$false
"Install-WindowsUpdate -AcceptAll -AutoReboot -Silent" | Out-File .\InstallWindowUpdate.ps1 -Append -Confirm:$false

# Run Windows Update and restart computer after patch installation
Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath InstallWindowUpdate.ps1
Start-Sleep -Seconds 5
Write-Output ("`nWindows Update is Installed" + $ResourceGroup.ResourceGroupName)