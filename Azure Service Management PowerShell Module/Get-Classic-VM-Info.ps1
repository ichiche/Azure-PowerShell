# Script Variable
$asmvmInfo = @()

# Main
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black

# Get Azure Classic VM from current subscription
$asmvm = Get-AzureVM

foreach ($vm in $asmvm) {
	$rgName = Get-AzureRmResource -Name $vm.Name | select -first 1 -ExpandProperty ResourceGroupName
	$DiskInfo = $vm | Get-AzureDataDisk | select DiskLabel, DiskName, Lun, MediaLink
	$vmInCloudService = Get-AzureVM -ServiceName $vm.ServiceName

	# Clarify either Cluster or Standalone
	if ($vmInCloudService.Count -eq 1) { $ClusterStatus = "Standalone" } else { $ClusterStatus = "Cluster" }

	# Get Number of Data Disks
	if ($DiskInfo.DiskLabel.Count -eq 1) {
		$obj = New-Object -TypeName PSobject
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "VMName" -Value $vm.Name
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroupName" -Value $rgName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "CloudServiceName" -Value $vm.ServiceName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "ClusterStatus" -Value $ClusterStatus
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "PowerStatus" -Value $vm.Status
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskLabel" -Value $DiskInfo.DiskLabel
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskName" -Value $DiskInfo.DiskName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "Lun" -Value $DiskInfo.Lun
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "MediaLink" -Value $DiskInfo.MediaLink.AbsoluteUri
		$asmvmInfo += $obj	
	} else {
		foreach ($DiskItem in $DiskInfo) {
			$obj = New-Object -TypeName PSobject
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "VMName" -Value $vm.Name
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroupName" -Value $rgName
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "CloudServiceName" -Value $vm.ServiceName
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "ClusterStatus" -Value $ClusterStatus
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "PowerStatus" -Value $vm.Status
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskLabel" -Value $DiskItem.DiskLabel
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "DiskName" -Value $DiskItem.DiskName
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "Lun" -Value $DiskItem.Lun
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "MediaLink" -Value $DiskItem.MediaLink
			$asmvmInfo += $obj	
		}
	}
}

# Export to CSV file 
$asmvmInfo | Export-Csv -NoTypeInformation C:\Temp\ClassicVM-FullList.csv -Force

# End
Write-Host ("`n")
Write-Host ("[LOG] " + (Get-Date -Format "yyyy-MM-dd hh:mm")) -ForegroundColor White -BackgroundColor Black
Write-Host "`n`nCompleted"