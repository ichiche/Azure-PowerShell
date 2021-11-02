<#
    .DESCRIPTION
        Delete Obsolete Image Version

    .NOTES
        AUTHOR: Isaac Cheng, Microsoft Customer Engineer
        EMAIL: chicheng@microsoft.com
        LASTEDIT: Nov 2, 2021
#>

Param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = '5ba60130-b60b-4c4b-8614-06a0c6723d9b',
    [Parameter(Mandatory=$false)]
    [string]$GalleryRG = 'Image',
    [Parameter(Mandatory=$false)]
    [string]$GalleryName = 'SharedImage',
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

    # Define the easiest valid and active date of Image Version 
    $ValidDate = Get-Date
    [int]$RecentMonth = ("-" + $RetainRecentMonth)
    $ValidDate = $ValidDate.AddMonths($RecentMonth)
    Write-Output ("Image Version before " + $ValidDate.ToLongDateString() + " will be deleted")

    # Get Image Version from Shared Image Gallery
    Write-Output "`nRetrieving Image Version" 
    $GalleryImageDefinitions = Get-AzGalleryImageDefinition -ResourceGroupName $GalleryRG -GalleryName $GalleryName -Name $GalleryImageDefinitionName

    foreach ($GalleryImageDefinition in $GalleryImageDefinitions) {
        Write-Output ("`nImage Definition: " + $GalleryImageDefinition.Name)
        # Retrieve Image Versions
        $GalleryImageVersions = Get-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinition.Name
        
        # Find Obsolete Image Version
        foreach ($GalleryImageVersion in $GalleryImageVersions) {
            if ($GalleryImageVersion.PublishingProfile.PublishedDate -lt $ValidDate) {
                Remove-AzGalleryImageVersion -ResourceGroupName $GalleryRG -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageDefinition.Name -Name $GalleryImageVersion.Name
                Write-Output ("Image Version: " + $GalleryImageVersion.Name + " is deleted")
            } else {
                Write-Output ("Image Version: " + $GalleryImageVersion.Name + " is retained")
            }
        }
    }
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