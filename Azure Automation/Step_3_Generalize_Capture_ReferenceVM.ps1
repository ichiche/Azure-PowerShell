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
    [string]$SubscriptionId = '',
    [Parameter(Mandatory)]
    [ValidateSet("WS2016","WS2019","RHEL7","RHEL8")]
    [string]$OSVersion = 'WS2016 or WS2019 or RHEL7 or RHEL8',
    [Parameter(Mandatory=$false)]
    [string]$GalleryRG= 'rg-ggt-sea-pd-sig-01',
    [Parameter(Mandatory=$false)]
    [string]$GalleryName = 'sig_ggt_pd_sea_images'
)

# Script Variable
$connectionName = "AzureRunAsConnection"
$StorageAccountType = "Standard_LRS"
$ReplicaCount = 1
$error.Clear()

switch ($OSVersion) {
    WS2016 { 
        $GalleryImageDefinitionName = "WindowsServer2016"
        $ReferenceVMRG = "rg-ggt-sea-pd-sig-01"
        $ReferenceVMName = "WS2016-RefVM"
    }
    WS2019 { 
        $GalleryImageDefinitionName = "WindowsServer2019"
        $ReferenceVMRG = "rg-ggt-sea-pd-sig-01"
        $ReferenceVMName = "WS2019-RefVM"
    }
    RHEL7 { 
        $GalleryImageDefinitionName = "RedHatEnterprise7"
        $ReferenceVMRG = "rg-ggt-sea-pd-sig-01"
        $ReferenceVMName = "RHEL7-RefVM"
    }
    RHEL8 { 
        $GalleryImageDefinitionName = "RedHatEnterprise8"
        $ReferenceVMRG = "rg-ggt-sea-pd-sig-01"
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
        Write-Output "`n$OSVersion Starting up Reference VM" 
        Start-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Confirm:$false
        
        # Wait for a certain time to ensure Guest OS has completed the start up process
        Start-Sleep -Seconds 180
        Write-Output "`n$OSVersion Reference VM is running now" 
    }

    # Generalize Windows Reference VM
    if ($OSVersion -like "WS*") {
         # Prepare Script
        "C:\Windows\System32\SysPrep\sysprep.exe /generalize /oobe /shutdown /mode:vm /quiet" | Out-File .\Sysprep.ps1 -Force -Confirm:$false

        # Sysprep Reference VM
        Write-Output "`n$OSVersion Performing Sysprep"  
        $InvokeAzVMRunCommand = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath Sysprep.ps1

        # Waiting for Sysprep to shutdown Reference VM
        while ($PowerStatus -ne "PowerState/stopped") {
            Start-Sleep -Seconds 90
            $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
            $PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"} | select -ExpandProperty Code
        }
        Write-Output "`n$OSVersion Sysprep is completed"    

        # Deallocate Reference VM
        Write-Output "`n$OSVersion Deallocating Reference VM" 
        Stop-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Force -Confirm:$false
        Start-Sleep -Seconds 20
        Write-Output "`n$OSVersion Reference VM is deallocated" 
    } else {
        # Recommend to manually SSH to generalize RHEL Reference VM
        Write-Output "`n$OSVersion Run 'sudo waagent -deprovision -force' to generalize Linux VM" 
        "sudo waagent -deprovision -force;sudo shutdown -h now" | Out-File .\GeneralizeLinux.ps1 -Force -Confirm:$false
        #Write-Output "`nRun 'sudo systemctl poweroff --force' to power off Linux VM" 
        #"sudo waagent -deprovision -force" | Out-File .\GeneralizeLinux.ps1 -Force -Confirm:$false
        #"sudo systemctl poweroff --force"| Out-File .\GeneralizeLinux.ps1 -Append -Confirm:$false
        #"sudo shutdown -h now" | Out-File .\GeneralizeLinux.ps1 -Append -Confirm:$false
        $ReturnData = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunShellScript" -ScriptPath GeneralizeLinux.ps1 -AsJob
        #[string]$CommandResult1 = $ReturnData.Value.Message
        [string]$CommandResult1 = $ReturnData.Name
        Write-Output ($OSVersion + " " + $CommandResult1)
        Start-Sleep -Seconds 60

        # Deallocate Reference VM
        $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
        $ProvisioningState = $vm.Statuses | ? {$_.Code -eq "ProvisioningState/updating"} | select -ExpandProperty Code

        if ($ProvisioningState -ne $null) {
            Write-Output "`n$OSVersion ProvisioningState is updating" 
            $PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"} | select -ExpandProperty Code

            if ($PowerStatus -ne "PowerState/deallocated") {
                # Deallocate Reference VM
                Write-Output "`n$OSVersion Deallocating Reference VM" 
                Stop-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Force -Confirm:$false
                Start-Sleep -Seconds 20
                Write-Output "`n$OSVersion Reference VM is deallocated" 
            }
        } else {
            Write-Error ("`n$OSVersion Error Occur while Deprovisioning RHEL Reference VM")
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

        # Create Gallery Image Version sourcing from VM
        Write-Output "`n$OSVersion Creating Gallery Image Version $GalleryImageVersionName" 
        $SetAzVm = Set-AzVm -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Generalized
        $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName
        $SourceImageId = $vm.Id
        New-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinitionName -Name $GalleryImageVersionName -Location $GalleryImageDefinition.Location -TargetRegion $targetRegions -ReplicaCount $ReplicaCount -StorageAccountType $StorageAccountType -SourceImageId $SourceImageId
        
        if ($error.Count -eq 0) {
            Write-Output "`n$OSVersion Gallery Image Version $GalleryImageVersionName is created in $GalleryImageDefinitionName" 
        } else {
            foreach ($item in $error) {
                Write-Error ($item.ToString())
            }

            Write-Error ("`n$OSVersion Error Occur while creating Gallery Image Version")
        }
    }
} catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "`n$OSVersion Connection $connectionName not found"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

