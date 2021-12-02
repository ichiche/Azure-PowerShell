<#
    .DESCRIPTION
        Verify Patch Installation Status

    .NOTES
        AUTHOR: Isaac Cheng, Microsoft Customer Engineer
        EMAIL: chicheng@microsoft.com
        LASTEDIT: Dec 2, 2021
#>

Param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = '5ba60130-b60b-4c4b-8614-06a0c6723d9b',
    [Parameter(Mandatory)]
    [ValidateSet("WS2016","WS2019","RHEL7","RHEL8")]
    [string]$OSVersion = 'WS2016 or WS2019 or RHEL7 or RHEL8'
)

# Script Variable
$connectionName = "AzureRunAsConnection"

switch ($OSVersion) {
    WS2016 { 
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "WS2016-RefVM"
    }
    WS2019 { 
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "WS2019-RefVM"
    }
    RHEL7 { 
        $ReferenceVMRG = "ImageWorkingItem"
        $ReferenceVMName = "RHEL7-RefVM"
    }
    RHEL8 { 
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
    
    # Verification
    if ($OSVersion -like "WS*") {
        # Prepare Script for Windows Update
        '$WindowsUpdates = Get-WindowsUpdate | ? {$_.IsInstalled -eq $false}' | Out-File .\CheckWindowUpdate.ps1 -Force -Confirm:$false
        'if ($WindowsUpdates -ne $null) { Write-Output "Following Windows Update is not installed yet:`n";' | Out-File .\CheckWindowUpdate.ps1 -Append -Confirm:$false
            'foreach ($WindowsUpdate in $WindowsUpdates) {Write-Output $WindowsUpdate.Title}' | Out-File .\CheckWindowUpdate.ps1 -Append -Confirm:$false
        '} else {Write-Output "Already installed the latest Windows Update";}' | Out-File .\CheckWindowUpdate.ps1 -Append -Confirm:$false
        
        # Get Windows Update Installation Status
        Write-Output "`nGet Windows Update Installation Status" 
        $ReturnData = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath CheckWindowUpdate.ps1
        Write-Output "`n" 
        foreach ($Data in $ReturnData) {
            Write-Output $Data.Value.Message
            if ($Data.Value.Message -like "*not installed yet*") {
                $IsWindowsUpdateInstalled = $false
            } elseif ($Data.Value.Message -like "*Already installed*") {
                $IsWindowsUpdateInstalled = $true
                Write-Output "`nWindows Update Completed" 
            }
        }

        # If latest Windows Update is not installed, run Windows Update and restart computer after patch installation
        if (!$IsWindowsUpdateInstalled ) {
            "Import-Module PSWindowsUpdate" | Out-File .\InstallWindowUpdate.ps1 -Force -Confirm:$false
            "Install-WindowsUpdate -AcceptAll -AutoReboot -Silent" | Out-File .\InstallWindowUpdate.ps1 -Append -Confirm:$false
            Write-Output "`nProcessing to install Windows Update"
            $error.Clear()
            Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunPowerShellScript" -ScriptPath InstallWindowUpdate.ps1
            Start-Sleep -Seconds 5
    
            if ($error.Count -eq 0) {
                Write-Output ("`nHave triggered to install Windows Update using PSWindowsUpdate without error")
            } else {
                Write-Error ("`nError Occur while running PSWindowsUpdate")

                foreach ($item in $error) {
                    Write-Error ($item.ToString())
                }
            }
        }
    } else {
        # Prepare Script for yum update
        Write-Output ("`nRunning yum update")
        "yum update -y" | Out-File .\yumUpdate.ps1 -Force -Confirm:$false

        $ReturnData = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunShellScript" -ScriptPath yumUpdate.ps1
        [string]$CommandResult1 = $ReturnData.Value.Message

        if ($CommandResult1 -like "*No packages marked for update*" -or $CommandResult1 -like "*Nothing to do*") {
            Write-Output "yum update completed successfully"
        } else {
            Write-Output "Re-run yum update"
            Start-Sleep -Seconds 90
            $ReturnData = Invoke-AzVMRunCommand -ResourceGroupName $ReferenceVMRG -Name $ReferenceVMName -CommandId "RunShellScript" -ScriptPath yumUpdate.ps1
            [string]$CommandResult2 = $ReturnData.Value.Message
            if ($CommandResult2 -like "*Complete!*") {
                Write-Output "Re-run yum update completed successfully"
            } else {
                Write-Error $CommandResult2
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