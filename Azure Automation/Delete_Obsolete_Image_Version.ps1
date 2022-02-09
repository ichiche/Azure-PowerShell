<#
    .DESCRIPTION
        Delete Obsolete Image Version

    .NOTES
        AUTHOR: Isaac Cheng, Microsoft Customer Engineer
        EMAIL: chicheng@microsoft.com
        LASTEDIT: Dec 9, 2021
#>

Param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = '',
    [Parameter(Mandatory=$false)]
    [string]$GalleryRG = 'Image',
    [Parameter(Mandatory=$false)]
    [string]$GalleryName = 'SharedImage',
    [Parameter(Mandatory=$false)]
    [string]$GalleryImageDefinitionName = 'RedHatEnterprise7,RedHatEnterprise8',
    [Parameter(Mandatory=$true)]
    [string]$RetainRecentMonth = '6'
)

# Script Variable
$connectionName = "AzureRunAsConnection"

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
    $error.Clear()

    # Define the easiest valid and active date of Image Version 
    $ValidDate = Get-Date -Hour 0 -Minute 1 -Second 0
    [int]$RecentMonth = ("-" + $RetainRecentMonth)
    $ValidDate = $ValidDate.AddMonths($RecentMonth)
    Write-Output ("Prepare to remove Image Version provisioned before " + $ValidDate.ToLongDateString() + " " + $ValidDate.ToShortTimeString())

    # Get Image Version from Shared Image Gallery
    Write-Output "`nRetrieving Image Version" 
    $AllGalleryImageDefinitions = Get-AzGalleryImageDefinition -ResourceGroupName $GalleryRG -GalleryName $GalleryName
    [array]$GalleryImageDefinitionName = $GalleryImageDefinitionName.Split(",")
    $GalleryImageDefinitions = $AllGalleryImageDefinitions | ? {$GalleryImageDefinitionName -contains $_.Name}

    foreach ($GalleryImageDefinition in $GalleryImageDefinitions) {
        # Retrieve Image Versions
        Write-Output ("`nImage Definition: " + $GalleryImageDefinition.Name)
        $GalleryImageVersions = Get-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinition.Name
        
        # Find Obsolete Image Version
        foreach ($GalleryImageVersion in $GalleryImageVersions) {
            if ($GalleryImageVersion.PublishingProfile.PublishedDate -lt $ValidDate) {
                Remove-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinition.Name -Name $GalleryImageVersion.Name -Force -Confirm:$false
                Write-Output ("Image Version: " + $GalleryImageVersion.Name + " is deleted")
            } else {
                Write-Output ("Image Version: " + $GalleryImageVersion.Name + " is retained")
            }
        }
    }

    # End
    if ($error.Count -eq 0) {
        Write-Output ("Obsolete Image Versions are deleted successfully")
    } else {
        Write-Error ("Error Occur while deleting Obsolete Image Version")
    }
} catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}