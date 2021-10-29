<#
    .DESCRIPTION
        Generalize and Capture Reference VM

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
$error.Clear()

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

# Login
try {
    # Get connection "AzureRunAsConnection"  
    $servicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName
    $ApplicationId = $servicePrincipalConnection.ApplicationId
    $CertificateThumbprint = $servicePrincipalConnection.CertificateThumbprint
    $TenantId = $servicePrincipalConnection.TenantId                

    # Get credential "SendGrid"
    $SendGrid = Get-AutomationPSCredential -Name "SendGrid"
    $SendGridAplKey = $SendGrid.Password
    $SendGridPlainAplKey = $SendGrid.GetNetworkCredential().Password

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

# Start up Reference VM if necessary
$vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
$PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"} | select -ExpandProperty Code

if ($PowerStatus -ne "PowerState/running") {
    Start-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Confirm:$false

    # Wait for a certain time to ensure Guest OS has completed the start up process
    Start-Sleep -Seconds 180
}

# Prepare Script
"C:\Windows\System32\SysPrep\sysprep.exe /generalize /oobe /shutdown /mode:vm /quiet" | Out-File .\Sysprep.ps1 -Force -Confirm:$false

# Generalize Windows Reference VM
if ($OSVersion -like "WS*") {
    # Sysprep Reference VM
    Write-Output "`nPerforming Sysprep"  
    $InvokeAzVMRunCommand = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath Sysprep.ps1

    # Check Power Status of Reference VM
    while ($PowerStatus -ne "PowerState/stopped") {
        Start-Sleep -Seconds 60
        $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
        $PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"} | select -ExpandProperty Code
    }
    Write-Output "`nSysprep is completed"    

    # Deallocate Reference VM
    Write-Output "`nDeallocating Reference VM" 
    Stop-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Force -Confirm:$false
    Start-Sleep -Seconds 10
    Write-Output "`nReference VM is deallocated" 
} else { # Generalize RHEL Reference VM

}

# Create Gallery Image Version only if no error occur before
if ($error.Count -eq 0) {
    # Get Gallery Image Definition 
    $GalleryImageDefinition = Get-AzGalleryImageDefinition -ResourceGroupName $GalleryRG -GalleryName $GalleryName -Name $GalleryImageDefinitionName

    # New Gallery Image Version
    $GalleryImageVersionName = (Get-Date -Format "yyyy.MM.dd").ToString()
    $region_eastus = @{Name = 'East US'}
    $region_eastasia = @{Name = 'East Asia'}
    $region_southeastasia = @{Name = 'Southeast Asia'}
    $targetRegions = @($region_eastus, $region_eastasia, $region_southeastasia)
    $StorageAccountType = "Premium_LRS"
    $ReplicaCount = 1

    # Create Gallery Image Version sourcing from VM
    Write-Output "`nCreating Gallery Image Version" 
    $SetAzVm = Set-AzVm -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Generalized
    $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName
    $SourceImageId = $vm.Id
    New-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinitionName -Name $GalleryImageVersionName -Location $GalleryImageDefinition.Location -TargetRegion $targetRegions -ReplicaCount $ReplicaCount -StorageAccountType $StorageAccountType -SourceImageId $SourceImageId
    Write-Output "`nGallery Image Version is created" 
}