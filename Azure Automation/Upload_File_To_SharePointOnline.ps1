#Config Variables
$SiteURL = "https://eiutoday.sharepoint.com/sites/HKAutomation"
$SourceFilePath ="C:\Temp\text.txt"
$DestinationPath = "https://eiutoday.sharepoint.com/sites/HKAutomation/Shared%20Documents/Forms/AllItems.aspx" #Server Relative Path of the Library
$FolderName = 'Shared Documents'
$FolderName = "Shared Documents/Inventory"
$username = ""
$password = ""

#Get Credentials to connect
$Cred = Get-Credential -UserName $username
$adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString -AsPlainText -Force)

#Connect to PnP Online
Connect-PnPOnline -Url $SiteURL -Credentials $adminCredential
      
#powershell pnp to upload file to sharepoint online
Add-PnPFile -Path $SourceFilePath -Folder $DestinationPath
Add-PnPFile -Path $SourceFilePath -Folder $FolderName

# Read more: https://www.sharepointdiary.com/2016/06/upload-files-to-sharepoint-online-using-powershell.html#ixzz7UpgEj76T





# Automation Account Runbook

# Script Variable
$connectionName = "AzureRunAsConnection"

# Get connection "AzureRunAsConnection"  
#$servicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName
#$ApplicationId = $servicePrincipalConnection.ApplicationId
#$CertificateThumbprint = $servicePrincipalConnection.CertificateThumbprint
#$TenantId = $servicePrincipalConnection.TenantId       

$SiteURL = "https://eiutoday.sharepoint.com/sites/HKAutomation"
$ClientId = "847e13a1-3a46-4671-bd53-3c4815ab1893"
$Thumbprint = "D872A8D6A244898759D42FE71624E610800304D0"
$TenantId = "064b5fcd-98e3-413a-ac9c-c63bac22a927"
Connect-PnPOnline -Url $SiteURL -ClientId $ClientId -Thumbprint $Thumbprint -Tenant $TenantId 

"Temp" > ".\TestUpload.txt"
$FolderName = "Shared Documents/Inventory"
Add-PnPFile -Path ".\TestUpload.txt" -Folder $FolderName
