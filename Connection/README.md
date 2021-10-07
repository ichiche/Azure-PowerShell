# Prerequisites

- This script applies to the account which has not enabled the MFA (Multi-Factor Authentication)

- Run this script at the location where secure-password.txt exist

# Scope Description

PowerShell support following scopes:

- **Global**: The scope that is in effect when PowerShell starts or when you create a new session or runspace. Variables and functions that are present when PowerShell starts have been created in the global scope, such as automatic variables and preference variables. The variables, aliases, and functions in your PowerShell profiles are also created in the global scope. The global scope is the root parent scope in a session.

- **Local**: The current scope. The local scope can be the global scope or any other scope.

- **Script**: The scope that is created while a script file runs. Only the commands in the script run in the script scope. To the commands in a script, the script scope is the local scope.

- **Reference:** https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes?view=powershell-5.1

# Highlight

- **Connect-AzAccount** within each script is an individual connection section that unable to share with other script

- If you would like to reuse the connection section for multiple, open a **Windows PowerShell**, explicitly login once, then copy the content of each script and paste into this **Windows PowerShell**
