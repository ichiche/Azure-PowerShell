# Global Parameter
$NewImageName = ""
$osDiskName = "" # Enter OS Disk Name of VM
$rgName = "" # Enter Resource Group Name
$location = "" # Enter Azure Resource Location, e.g. "East Asia"
$subscriptionId = "" # Enter Subscription ID

# Login
Connect-AzAccount # Comment this line if using Connect-To-Cloud.ps1

# Main
Set-AzContext -SubscriptionId $subscriptionId
$managedDiskID = "/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.Compute/disks/$osDiskName"
$imageConfig = New-AzImageConfig -Location $location # -HyperVGeneration V2
$imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsState Generalized -OsType Windows -ManagedDiskId $managedDiskID
New-AzImage -ImageName $NewImageName -ResourceGroupName $rgName -Image $imageConfig

# Logout
Disconnect-AzAccount