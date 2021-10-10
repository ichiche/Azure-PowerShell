# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$CsvFullPath = "C:\Temp\Azure-AppService-vNetIntegration.csv" # Export Result to CSV file 

# Script Variable
$Global:ResultArray = @()
[int]$CurrentItem = 1

# Login
az login # For Azure CLI
Start-Sleep -Seconds 10
Connect-AzAccount

# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    $Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    $Subscriptions = Get-AzSubscription
}

# Main
Write-Host "`nThe process has been started" -ForegroundColor Yellow
Write-Host "`nThis may take more than 10 minutes to complete" -ForegroundColor Yellow

foreach ($Subscription in $Subscriptions) {
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    $AzAccountSet = az account set --subscription $Subscription.Id
    Write-Host ("`nProcessing " + $CurrentItem + " out of " + $Subscriptions.Count + " Subscription: " + $AzContext.Name.Substring(0, $AzContext.Name.IndexOf("(")) + "`n") -ForegroundColor Yellow
    $CurrentItem++

    # App Service
    $AppServices = Get-AzWebApp
    Write-Host ("Number of App Service: " + $AppServices.Count)

    foreach ($AppService in $AppServices) {
        # App Service Plan
        $AppServicePlan = $AppService.ServerFarmId.Substring($AppService.ServerFarmId.IndexOf("/serverfarms/") + "/serverfarms/".Length)
        $AppServicePlanRG = $AppService.ServerFarmId.Substring($AppService.ServerFarmId.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
        $AppServicePlanRG = $AppServicePlanRG.Substring(0, $AppServicePlanRG.IndexOf("/"))
        $AppServicePlanInstance = Get-AzAppServicePlan -ResourceGroupName $AppServicePlanRG -Name $AppServicePlan
        $sku = ($AppServicePlanInstance.Sku.Name + ": " + $AppServicePlanInstance.Sku.Capacity + " Unit")

        # Get vNet Integration
        $WebAppvNetIntegration = az webapp vnet-integration list --resource-group $AppService.ResourceGroup --name $AppService.Name
        
        # Save to Temp Object
        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppService" -Value $AppService.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServiceResourceGroup" -Value $AppService.ResourceGroup
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value $AppService.Kind
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $AppService.Location
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServicePlan" -Value $AppServicePlan
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "AppServicePlanResourceGroup" -Value $AppServicePlanRG
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Sku" -Value $sku
    
        if ($WebAppvNetIntegration -eq "[]") {
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "vNetIntegration" -Value "N"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkId" -Value "N/A"
        } else {
            $vNetInfo = $WebAppvNetIntegration | ConvertFrom-Json
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "vNetIntegration" -Value "Y"
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkId" -Value $vNetInfo.vnetResourceId
        }

        # Save to Array
        $Global:ResultArray += $obj
    }
}

# Export Result to CSV file 
$Global:ResultArray | sort @{e='vNetIntegration';desc=$true}, AppService | Export-Csv -Path $CsvFullPath -NoTypeInformation -Confirm:$false -Force

# End
Write-Host "`nCompleted" -ForegroundColor Yellow
Write-Host ("`nCount of App Service: " + $Global:ResultArray.Count) -ForegroundColor Cyan
Write-Host "`n"