<#
    .DESCRIPTION
        Generalize and Capture Reference VM

    .NOTES
        AUTHOR: Isaac Cheng, Microsoft Customer Engineer
        EMAIL: chicheng@microsoft.com
        LASTEDIT: Dec 3, 2021
#>

Param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = '5ba60130-b60b-4c4b-8614-06a0c6723d9b',
    [Parameter(Mandatory=$false)]
    [ValidateSet("WS2016","WS2019","RHEL7","RHEL8")]
    [string]$OSVersion = 'WS2016',
    [Parameter(Mandatory=$false)]
    [string]$GalleryRG = 'Image',
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

try {
    # Get connection "AzureRunAsConnection"  
    $servicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName
    $ApplicationId = $servicePrincipalConnection.ApplicationId
    $CertificateThumbprint = $servicePrincipalConnection.CertificateThumbprint
    $TenantId = $servicePrincipalConnection.TenantId                

    # Get credential "SendGrid"
    #$SendGrid = Get-AutomationPSCredential -Name "SendGrid"
    #$SendGridAplKey = $SendGrid.Password
    #$SendGridPlainAplKey = $SendGrid.GetNetworkCredential().Password

    # Connect to Azure  
    Write-Output ("`nConnecting to Azure Subscription ID: " + $SubscriptionId)  
    Connect-AzAccount -ApplicationId $ApplicationId -CertificateThumbprint $CertificateThumbprint -Tenant $TenantId -ServicePrincipal
    Set-AzContext -SubscriptionId $SubscriptionId
    Write-Output ("`nOS Version: $OSVersion")
    $error.Clear()

    # Start up Reference VM if necessary
    $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
    $PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"} | select -ExpandProperty Code

    if ($PowerStatus -ne "PowerState/running") {
        Write-Output "`nStarting up Reference VM" 
        Start-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Confirm:$false
        
        # Wait for a certain time to ensure Guest OS has completed the start up process
        Start-Sleep -Seconds 180
        Write-Output "`nReference VM is running now" 
    }

    # Generalize Windows Reference VM
    if ($OSVersion -like "WS*") {
         # Prepare Script
        "C:\Windows\System32\SysPrep\sysprep.exe /generalize /oobe /shutdown /mode:vm /quiet" | Out-File .\Sysprep.ps1 -Force -Confirm:$false

        # Sysprep Reference VM
        Write-Output "`nPerforming Sysprep"  
        $InvokeAzVMRunCommand = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath Sysprep.ps1

        # Waiting for Sysprep to shutdown Reference VM
        while ($PowerStatus -ne "PowerState/stopped") {
            Start-Sleep -Seconds 90
            $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
            $PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"} | select -ExpandProperty Code
        }
        Write-Output "`nSysprep is completed"    

        # Deallocate Reference VM
        Write-Output "`nDeallocating Reference VM" 
        Stop-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Force -Confirm:$false
        Start-Sleep -Seconds 20
        Write-Output "`nReference VM is deallocated" 
    } else {
        # Recommend to manually SSH to generalize RHEL Reference VM
        Write-Output "`nRun 'sudo waagent -deprovision -force' to generalize Linux VM" 
        "sudo waagent -deprovision -force;sudo shutdown -h now" | Out-File .\GeneralizeLinux.ps1 -Force -Confirm:$false
        #Write-Output "`nRun 'sudo systemctl poweroff --force' to power off Linux VM" 
        #"sudo waagent -deprovision -force" | Out-File .\GeneralizeLinux.ps1 -Force -Confirm:$false
        #"sudo systemctl poweroff --force"| Out-File .\GeneralizeLinux.ps1 -Append -Confirm:$false
        #"sudo shutdown -h now" | Out-File .\GeneralizeLinux.ps1 -Append -Confirm:$false
        $ReturnData = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunShellScript" -ScriptPath GeneralizeLinux.ps1 -AsJob
        #[string]$CommandResult1 = $ReturnData.Value.Message
        [string]$CommandResult1 = $ReturnData.Name
        Write-Output $CommandResult1
        Start-Sleep -Seconds 60

        # Deallocate Reference VM
        $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
        $ProvisioningState = $vm.Statuses | ? {$_.Code -eq "ProvisioningState/updating"} | select -ExpandProperty Code

        if ($ProvisioningState -ne $null) {
            Write-Output "`nProvisioningState is updating" 
            $PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"} | select -ExpandProperty Code

            if ($PowerStatus -ne "PowerState/deallocated") {
                # Deallocate Reference VM
                Write-Output "`nDeallocating Reference VM" 
                Stop-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Force -Confirm:$false
                Start-Sleep -Seconds 20
                Write-Output "`nReference VM is deallocated" 
            }
        } else {
            Write-Error ("`nError Occur while Deprovisioning RHEL Reference VM")
        }
    }

    # Create Gallery Image Version only if no error occur before
    if ($error.Count -eq 0) {
        # Get Gallery Image Definition 
        $GalleryImageDefinition = Get-AzGalleryImageDefinition -ResourceGroupName $GalleryRG -GalleryName $GalleryName -Name $GalleryImageDefinitionName

        # New Gallery Image Version
        $GalleryImageVersionName = (Get-Date -Format "yyyy.MM.dd").ToString()
        $region_southeastasia = @{Name = 'Southeast Asia'}
        $region_eastus2 = @{Name = 'East US 2'}
        $region_uksouth = @{Name = 'UK South'}
        $targetRegions = @($region_southeastasia, $region_eastus2, $region_uksouth)
        <#
        $region_eastus = @{Name = 'East US'}
        $region_eastasia = @{Name = 'East Asia'}
        $region_southeastasia = @{Name = 'Southeast Asia'}
        $targetRegions = @($region_eastus, $region_eastasia, $region_southeastasia)
        #>
        $StorageAccountType = "Premium_LRS"
        $ReplicaCount = 1

        # Create Gallery Image Version sourcing from VM
        Write-Output "`nCreating Gallery Image Version $GalleryImageVersionName" 
        $SetAzVm = Set-AzVm -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Generalized
        $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName
        $SourceImageId = $vm.Id
        New-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinitionName -Name $GalleryImageVersionName -Location $GalleryImageDefinition.Location -TargetRegion $targetRegions -ReplicaCount $ReplicaCount -StorageAccountType $StorageAccountType -SourceImageId $SourceImageId
        
        if ($error.Count -eq 0) {
            Write-Output "`nGallery Image Version $GalleryImageVersionName is created in $GalleryImageDefinitionName" 
        } else {
            Write-Error ("`nError Occur while creating Gallery Image Version")

            foreach ($item in $error) {
                Write-Error ($item.ToString())
            }
        }
    } 
} catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}