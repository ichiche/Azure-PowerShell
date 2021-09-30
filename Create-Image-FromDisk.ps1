#Create ARM VM Image from Managed Disk
#$NewImageName = "VM-2012R2-Template-2021-06"#2012r2
#$vmName = "tpl_2021_06_w2k12r2_std"#2012r2

#$NewImageName = "VM-2016-Template-2021-06"#2016
#$vmName = "tpl_2021_06_w2k16_std"#2016

$NewImageName = "VM-2019-Template-2021-06"#2019
$vmName = "tpl_2021_06_w2k19_std"#2019

$vmName=$vmName.replace("_","").replace("std","").replace("tpl","vm")
#New-AzVM : Windows computer name cannot be more than 15 characters long, 
#be entirely numeric, 
#or contain the following characters: ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?.

$rgName = "ARM-VM-Template"
$location = "East Asia"
$subscriptionId = "1de24949-2bf7-4678-a41c-abb4771ef51e"

Connect-AzAccount
Set-AzContext -SubscriptionId $subscriptionId

$osDiskName = "$vmName-OS-Drive"
$managedDiskID = "/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.Compute/disks/$osDiskName"
$imageConfig = New-AzImageConfig -Location $location #FIXME -HyperVGeneration V2
$imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsState Generalized -OsType Windows -ManagedDiskId $managedDiskID

$image = New-AzImage -ImageName $NewImageName -ResourceGroupName $rgName -Image $imageConfig

Disconnect-AzAccount