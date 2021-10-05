#az login
$AppServiceList = Import-Csv C:\Temp\Azuresites.csv
$ResultArray = @()


az webapp list

foreach ($item in $AppServiceList) {

    if ($CurrentSubscription -ne $item.Subscription) {
        $CurrentSubscription = $item.Subscription
        az account set --subscription $CurrentSubscription
    }

    $Subscriptions = az account list
    $Subscriptions = $Subscriptions | ConvertFrom-Json
    az account set --subscription $Subscriptions[2].id
    
 

    $obj = New-Object -TypeName PSobject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "App Name" -Value $item.AppService
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "App Service Plan" -Value $item.AppServicePlan
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $item.ResourceGroup
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subscription" -Value $item.Subscription
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Type" -Value $item.Type
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Sku" -Value $item.Sku

    $WebApp = az webapp vnet-integration list --name $item.AppService --resource-group $item.ResourceGroup

    if ($WebApp -eq "[]") {
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "vNet Integration" -Value "No"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetwork" -Value "N/A"
    } else {
        $vNetInfo = $WebApp | ConvertFrom-Json
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "vNet Integration" -Value "Yes"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetwork" -Value $vNetInfo.Name
    }

    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $item.Location
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "Tags" -Value $item.Tags

    $ResultArray += $obj
}

$ResultArray | Export-Csv -Path C:\Temp\AppService-vNetIntegration.csv -NoTypeInformation -Confirm:$false -Force 
