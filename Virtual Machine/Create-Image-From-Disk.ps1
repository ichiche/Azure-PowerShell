#Region Global Parameter
$NewImageName = "" # Enter the Name of new created Azure Image 
$osDiskName = "" # Enter OS Disk Name of VM
$rgName = "" # Enter Resource Group Name
$location = "" # Enter Azure Resource Location, e.g. "East Asia"
$subscriptionId = "" # Enter Subscription ID
#EndRegion Global Parameter

#Region Login
Connect-AzAccount # Comment this line if using Connect-To-Cloud.ps1
#EndRegion Login

#Region Main
Set-AzContext -SubscriptionId $subscriptionId
$managedDiskID = "/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.Compute/disks/$osDiskName"
$imageConfig = New-AzImageConfig -Location $location # -HyperVGeneration V2
$imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsState Generalized -OsType Windows -ManagedDiskId $managedDiskID
New-AzImage -ImageName $NewImageName -ResourceGroupName $rgName -Image $imageConfig
#EndRegion Main

#Region Logout
Disconnect-AzAccount
#EndRegion Logout