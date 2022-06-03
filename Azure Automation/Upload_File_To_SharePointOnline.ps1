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


Connect-PnPOnline:
Line |
   2 |  Connect-PnPOnline -Url $SiteURL -Credentials $Cred
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | AADSTS65001: The user or administrator has not consented to use the application with ID '31359c7f-bd7e-475c-86db-fdb8c937548e' named 'PnP Management Shell'. Send an interactive authorization request for this user and resource.
Trace ID: 246ce9c8-fee6-4efd-a68b-a837a9f85500
Correlation ID: 14f0e0fc-0bd6-44ec-beff-2af5f2472622
Timestamp: 2022-05-31 03:43:47Z

# https://www.sharepointdiary.com/2021/08/fix-connect-pnponline-aadsts65001-user-or-administrator-has-not-consented-to-use-the-application.html

Connect-PnPOnline: Cannot find certificate with this thumbprint in the certificate store.
# https://stackoverflow.com/questions/66386136/azure-function-cannot-find-certificate-with-this-thumbprint-in-the-certificate


# Azure Automation Runbook job goes into suspended mode when adding file to Sharepoint
# https://docs.microsoft.com/en-us/answers/questions/431771/azure-automation-runbook-job-goes-into-suspended-m.html
# https://docs.microsoft.com/en-us/answers/questions/214757/connect-sponline-using-pnp-by-azure-app-registrati.html

Granting access via Azure AD App-Only
# https://docs.microsoft.com/en-us/sharepoint/dev/solution-guidance/security-apponly-azuread