# Global Parameter
$subscriptionId = "" # Subscription Id of OS Disk and will provision Azure Image under same Subscription
$osDiskRGName = "" # Resource Group Name of OS Disk
$osDiskName = "" # OS Disk Name of VM
$NewImageRGName = ""
$NewImageName = ""
$location = "" # Azure Resource Location of both OS Disk and Azure Image

# Login
Connect-AzAccount

# Main
Set-AzContext -SubscriptionId $subscriptionId
$managedDiskID = "/subscriptions/$subscriptionId/resourceGroups/$osDiskRGName/providers/Microsoft.Compute/disks/$osDiskName"
$imageConfig = New-AzImageConfig -Location $location # -HyperVGeneration V2
$imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsState Generalized -OsType Windows -ManagedDiskId $managedDiskID
New-AzImage -ImageName $NewImageName -ResourceGroupName $NewImageRGName -Image $imageConfig

# Logout
Disconnect-AzAccount