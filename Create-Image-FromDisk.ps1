# Global Parameter
$NewImageName = "VM-2019-Template-2021-06"
$vmName = "tpl-2021-06-w2k19-std"
$rgName = "ARM-VM-Template"
$location = "East Asia"
$subscriptionId = "" # Enter Subscription Id

# Windows computer name cannot be more than 15 characters long, 
# Be entirely numeric
# Not contain the following characters: ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?.


Connect-AzAccount
Set-AzContext -SubscriptionId $subscriptionId

$osDiskName = "$vmName-OS-Drive"
$managedDiskID = "/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.Compute/disks/$osDiskName"
$imageConfig = New-AzImageConfig -Location $location # -HyperVGeneration V2
$imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsState Generalized -OsType Windows -ManagedDiskId $managedDiskID

$image = New-AzImage -ImageName $NewImageName -ResourceGroupName $rgName -Image $imageConfig

Disconnect-AzAccount