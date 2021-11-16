<#
    .DESCRIPTION
        Verify Patch Installation Status

    .NOTES
        AUTHOR: Isaac Cheng, Microsoft Customer Engineer
        EMAIL: chicheng@microsoft.com
        LASTEDIT: Nov 16, 2021
#>

Param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = '5ba60130-b60b-4c4b-8614-06a0c6723d9b',
    [Parameter(Mandatory=$false)]
    [ValidateSet("WS2016","WS2019","RHEL7","RHEL8")]
    [string]$OSVersion = 'WS2016'
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
    # Get connection "AzureRunAsConnection"  
    $servicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName
    $ApplicationId = $servicePrincipalConnection.ApplicationId
    $CertificateThumbprint = $servicePrincipalConnection.CertificateThumbprint
    $TenantId = $servicePrincipalConnection.TenantId                

    # Connect to Azure  
    Write-Output ("`nConnecting to Azure Subscription ID: " + $SubscriptionId)
    Connect-AzAccount -ApplicationId $ApplicationId -CertificateThumbprint $CertificateThumbprint -Tenant $TenantId -ServicePrincipal
    Set-AzContext -SubscriptionId $SubscriptionId

    # Start up Reference VM if necessary
    $vm = Get-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Status
    $PowerStatus = $vm.Statuses | ? {$_.Code -like "PowerState*"} | select -ExpandProperty Code

    if ($PowerStatus -ne "PowerState/running") {
        Write-Output "`nStarting up Reference VM" 
        Start-AzVM -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -Confirm:$false
        
        # Wait for a certain time to ensure Guest OS has completed the start up process
        Start-Sleep -Seconds 180
    }
    
    # Verification
    if ($OSVersion -like "WS*") {
        # Windows Update
        $WindowsUpdates = Get-WindowsUpdate | ? {$_.IsInstalled -eq $false}
        if ($WindowsUpdates -ne $null) {
            Write-Output "Following Windows Update(s) is not installed yet:`n"
            foreach ($WindowsUpdate in $WindowsUpdates) {
                Write-Output $WindowsUpdate.Title
            }


            Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath InstallWindowUpdate.ps1
            

            # Run Windows Update and restart computer after patch installation
            "Import-Module PSWindowsUpdate" | Out-File .\InstallWindowUpdate.ps1 -Force -Confirm:$false
            "Install-WindowsUpdate -AcceptAll -AutoReboot -Silent" | Out-File .\InstallWindowUpdate.ps1 -Append -Confirm:$false
            Write-Output "`nProcessing to install Windows Update"
            $error.Clear()
            Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath InstallWindowUpdate.ps1
            
            Start-Sleep -Seconds 5

            if ($error.Count -eq 0) {
                Write-Output ("`nHave triggered to install Windows Update using PSWindowsUpdate without error")
            } else {
                Write-Error ("`nError: PSWindowsUpdate encounter issue")
            }
        }
    } else {
        # yum update
        Write-Output ("`nRunning yum update")
        "yum update -y" | Out-File .\yumUpdate.ps1 -Force -Confirm:$false

        $ReturnData = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunShellScript" -ScriptPath yumUpdate.ps1
        [string]$CommandResult1 = $ReturnData.Value.Message

        if ($CommandResult1 -like "*Complete!*") {
            Start-Sleep -Seconds 30
            $ReturnData = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunShellScript" -ScriptPath yumUpdate.ps1
            [string]$CommandResult2 = $ReturnData.Value.Message
            
            if($CommandResult2 -like "*No packages marked for update*") {
                Write-Output "yum update completed successfully"
            } else {
                Write-Error $CommandResult2
            }
        } else {
            Write-Error $CommandResult1
        }
    }
} catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}