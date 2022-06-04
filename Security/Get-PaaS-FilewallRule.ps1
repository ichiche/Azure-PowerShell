Import-Module Az
Import-Module Az.MySql
Import-Module Az.RedisCache
Connect-AzAccount

# Linux VM

$vms = Get-AzVM | ? {$_.OSProfile.LinuxConfiguration -ne $null}
$SshKeyResult = @()

foreach ($vm in $vms) {
	Write-Host ("`nProcessing: " + $vm.Name) -ForegroundColor Yellow
	
	$obj = New-Object -TypeName PSobject
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "VMName" -Value $vm.Name
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroupName" -Value $vm.ResourceGroupName
	
	if ($vm.OSProfile.LinuxConfiguration.Ssh.PublicKeys.KeyData -ne $null) {
		[string]$keyData = $vm.OSProfile.LinuxConfiguration.Ssh.PublicKeys.KeyData
	} else {
		[string]$keyData = "n/a"
	}
	
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "SshKey" -Value $keyData
	
	$SshKeyResult += $obj
}

$SshKeyResult | Export-Csv C:\Temp\SshKeyResult.csv -NoTypeInformation -Force -Confirm:$false



# MSSQL

$mssqlservers = Get-AzSqlServer
$MSSqlFirewallRuleResult = @()

foreach ($mssqlserver in $mssqlservers) {
	Write-Host ("`nProcessing: " + $mssqlserver.ServerName) -ForegroundColor Yellow
	
	$filewallRules = $mssqlserver | Get-AzSqlServerFirewallRule

	foreach ($filewallRule in $filewallRules) {
		$obj = New-Object -TypeName PSobject
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerName" -Value $mssqlserver.ServerName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroupName" -Value $mssqlserver.ResourceGroupName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "FirewallRuleName" -Value $filewallRule.FirewallRuleName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartIpAddress" -Value $filewallRule.StartIpAddress
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "EndIpAddress" -Value $filewallRule.EndIpAddress
		$MSSqlFirewallRuleResult += $obj
	}
}

$MSSqlFirewallRuleResult | Export-Csv C:\Temp\MSSqlFirewallRuleResult.csv -NoTypeInformation -Force -Confirm:$false




# MySQL

$mysqlservers = Get-AzMySqlServer
$MysqlFirewallRuleResult = @()

foreach ($mysqlserver in $mysqlservers) {
	Write-Host ("`nProcessing: " + $mysqlserver.FullyQualifiedDomainName) -ForegroundColor Yellow
	
	$currentRGName = $mysqlserver.Id.SubString($mysqlserver.Id.IndexOf("resourceGroups")+15)
	$currentRGName = $currentRGName.SubString(0, $currentRGName.IndexOf("/"))
	$filewallRules = Get-AzMySqlFirewallRule -ResourceGroupName $currentRGName -ServerName $mysqlserver.Name

	foreach ($filewallRule in $filewallRules) {
		$obj = New-Object -TypeName PSobject
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerName" -Value $mysqlserver.FullyQualifiedDomainName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroupName" -Value $currentRGName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "FirewallRuleName" -Value $filewallRule.Name
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartIpAddress" -Value $filewallRule.StartIpAddress
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "EndIpAddress" -Value $filewallRule.EndIpAddress
		$MysqlFirewallRuleResult += $obj
	}
}

$MysqlFirewallRuleResult | Export-Csv C:\Temp\MysqlFirewallRuleResult.csv -NoTypeInformation -Force -Confirm:$false




# Redis Cache

$RedisCaches = Get-AzRedisCache
$RedisCachesFirewallRuleResult = @()

foreach ($RedisCache in $RedisCaches) {
	Write-Host ("`nProcessing: " + $RedisCache.HostName) -ForegroundColor Yellow
	
	$filewallRules = Get-AzRedisCacheFirewallRule -ResourceGroupName $RedisCache.ResourceGroupName -Name $RedisCache.Name

	foreach ($filewallRule in $filewallRules) {
		$obj = New-Object -TypeName PSobject
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "ServerName" -Value $RedisCache.HostName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroupName" -Value $RedisCache.ResourceGroupName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "FirewallRuleName" -Value $filewallRule.RuleName
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartIpAddress" -Value $filewallRule.StartIp
		Add-Member -InputObject $obj -MemberType NoteProperty -Name "EndIpAddress" -Value $filewallRule.EndIp
		$RedisCachesFirewallRuleResult += $obj
	}
}

$RedisCachesFirewallRuleResult | Export-Csv C:\Temp\RedisCachesFirewallRuleResult.csv -NoTypeInformation -Force -Confirm:$false

