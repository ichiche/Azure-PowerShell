# Global Parameter
$SpecificTenant = "" # "Y" or "N"
$TenantId = "" # Enter Tenant ID if $SpecificTenant is "Y"
$TextFileFullPath = "C:\Temp\DiagramsNet-Format.txt" # Export Result to Text file 

# Script Variable
$Global:vNet = @()
$Global:vNetPeering = @()
[int]$UniqueId = 1
[int]$vNetPeeringCurrentIndex = 0

# Login
Connect-AzAccount

# Get Azure Subscription
if ($SpecificTenant -eq "Y") {
    $Subscriptions = Get-AzSubscription -TenantId $TenantId
} else {
    $Subscriptions = Get-AzSubscription
}

# Get the Latest Location Name and Display Name
$Global:NameReference = Get-AzLocation

# Function to align the Display Name
function Rename-Location {
    param (
        [string]$Location
    )

    foreach ($item in $Global:NameReference) {
        if ($item.Location -eq $Location) {
            $Location = $item.DisplayName
        }
    }

    return $Location
}

# Convert Resource ID to Virtual Network Unique ID
function ConvertTo-UniqueId {
    param (
        [string]$ResourceId
    )
    
    $UniqueId = $Global:vNet | ? {$_.VirtualNetworkId -eq $ResourceId} | select -ExpandProperty UniqueId

    return $UniqueId
}

function Update-vNetArray-Ordering {
    $Global:vNet = $Global:vNet | sort @{e='VirtualNetworkGateway';desc=$true}, VirtualNetworkGatewayType,  @{e='PeeringCount';desc=$true}, VirtualNetwork
}

# Main
Write-Host "`nThe process has been started" -ForegroundColor Yellow
Write-Host "`nThis should take less than 10 minutes to complete" -ForegroundColor Yellow

# Get Virtual Network
foreach ($Subscription in $Subscriptions) {
	$AzContext = Set-AzContext -SubscriptionId $Subscription.Id
    $vns = Get-AzVirtualNetwork
    $vngs = Get-AzResourceGroup | Get-AzVirtualNetworkGateway

    foreach ($vn in $vns) {
        if ($vn.ResourceGroupName -notlike "databricks-rg*") {
            $GatewayInstance = $null
            $GatewayInstance = $vn.Subnets.IpConfigurations.Id | ? {$_ -like "*providers/Microsoft.Network/virtualNetworkGateways/*"} | select -First 1

            if ($GatewayInstance -ne $null) {

                Write-Host ($vn.Name + " is deployed with Virtual Network Gateway`n")
                $IsGateway = "Y"
                $GatewayName = $GatewayInstance.Substring($GatewayInstance.IndexOf("providers/Microsoft.Network/virtualNetworkGateways/") + "providers/Microsoft.Network/virtualNetworkGateways/".Length)
                $GatewayName = $GatewayName.Substring(0, $GatewayName.IndexOf("/ipConfigurations"))
                $GatewayType = $vngs | ? {$_.Name -eq $GatewayName} | select -ExpandProperty GatewayType

                if ($GatewayType -eq $null) {
                    $GatewayType = "NoAccessRight"
                }
            } else {
                $IsGateway = "N"
                $GatewayType = "N/A"
            }

            $Location = Rename-Location -Location $vn.Location

            # Unique ID
            [string]$TempId = $UniqueId.ToString()
            $UniqueId++

            if ($TempId.Length -eq 1) {
                $TempId = "v00" + $TempId 
            } elseif ($TempId.Length -eq 2) {
                $TempId = "v0" + $TempId 
            } else {
                $TempId = "v" + $TempId 
            }

            # Get Peering Count
            $peering = Get-AzVirtualNetworkPeering -ResourceGroupName $vn.ResourceGroupName -VirtualNetworkName $vn.Name 

            # Save to Temp Object
            $obj = New-Object -TypeName PSobject
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value $Subscription.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $Subscription.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $vn.ResourceGroupName
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value $Location
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetwork" -Value $vn.Name
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkId" -Value $vn.Id
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkGateway" -Value $IsGateway
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkGatewayType" -Value $GatewayType
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "UniqueId" -Value $TempId 
            Add-Member -InputObject $obj -MemberType NoteProperty -Name "PeeringCount" -Value $peering.Count

            # Save to Array
            $Global:vNet  += $obj
        }
    }
}

# Ordering
Update-vNetArray-Ordering

Write-Host "Ignore the error message about Set-AzContext and Get-AzVirtualNetworkPeering`n" -ForegroundColor Yellow

# Get Virtual Network Peering for Virtual Network with Virtual Network Gateway deployed
foreach ($vn in $Global:vNet) {
    if ($vn.VirtualNetworkGateway -eq "Y") {
        $AzContext = Set-AzContext -SubscriptionId $vn.SubscriptionId

        # Get Peering Status
        $peerings = Get-AzVirtualNetworkPeering -ResourceGroupName $vn.ResourceGroup -VirtualNetworkName $vn.VirtualNetwork

        if ($peerings -ne $null -and $peerings.Count -gt 0) {
            foreach ($peering in $peerings) {
                    $StartEndpointUniqueId = ConvertTo-UniqueId -ResourceId $vn.VirtualNetworkId
                    $DestinationEndpointUniqueId = ConvertTo-UniqueId -ResourceId $peering.RemoteVirtualNetwork.Id

                    # Check if already added to Peering Array List
                    $IsExist = $false
                    foreach ($item in $Global:vNetPeering) {

                        if ($item.StartEndpointUniqueId -eq $StartEndpointUniqueId -and $item.DestinationEndpointUniqueId -eq $DestinationEndpointUniqueId) {
                            $IsExist = $true
                        }

                        if ($item.StartEndpointUniqueId -eq $DestinationEndpointUniqueId -and $item.DestinationEndpointUniqueId -eq $StartEndpointUniqueId) {
                            $IsExist = $true
                        }
                    }

                    if ($IsExist -eq $false) {
                        $DestinationEndpointSubscriptionId = $peering.RemoteVirtualNetwork.Id.Substring(("/subscriptions/".Length))
                        $DestinationEndpointSubscriptionId = $DestinationEndpointSubscriptionId.Substring(0, $DestinationEndpointSubscriptionId.IndexOf("/resourceGroups/"))

                        if ($peering.RemoteVirtualNetwork.Id -like "*/providers/Microsoft.ClassicNetwork/virtualNetworks*") {
                            $DestinationEndpointVirtualNetworkRG = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
                            $DestinationEndpointVirtualNetworkRG = $DestinationEndpointVirtualNetworkRG.Substring(0, $DestinationEndpointVirtualNetworkRG.IndexOf("/providers/Microsoft.ClassicNetwork/virtualNetworks/"))
                            $DestinationEndpointVirtualNetwork = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/providers/Microsoft.ClassicNetwork/virtualNetworks/") + "/providers/Microsoft.ClassicNetwork/virtualNetworks/".Length)
                        } else {
                            $DestinationEndpointVirtualNetworkRG = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
                            $DestinationEndpointVirtualNetworkRG = $DestinationEndpointVirtualNetworkRG.Substring(0, $DestinationEndpointVirtualNetworkRG.IndexOf("/providers/Microsoft.Network/virtualNetworks/"))
                            $DestinationEndpointVirtualNetwork = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/Microsoft.Network/virtualNetworks/") + "/Microsoft.Network/virtualNetworks/".Length)
                        }

                        # Save to Temp Object
                        $obj = New-Object -TypeName PSobject
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartEndpointUniqueId" -Value $StartEndpointUniqueId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartEndpointVirtualNetwork" -Value $peering.VirtualNetworkName
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointUniqueId" -Value $DestinationEndpointUniqueId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointSubscriptionId" -Value $DestinationEndpointSubscriptionId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointVirtualNetworkRG" -Value $DestinationEndpointVirtualNetworkRG
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointVirtualNetwork" -Value $DestinationEndpointVirtualNetwork
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "PeeringState" -Value $peering.PeeringState

                        # Save to Array
                        $Global:vNetPeering += $obj
                    }
            }
        }
    }
}

# Process Second Layer of the Destination Endpoint Virtual Network with ER / VPN Gateway if exist
if ($Global:vNetPeering.Count -ne 0) {
    foreach ($vNetWithGateway in $Global:vNetPeering) {
        $AzContext = Set-AzContext -SubscriptionId $vNetWithGateway.DestinationEndpointSubscriptionId
        
        # Get Peering Status
        $peerings = Get-AzVirtualNetworkPeering -ResourceGroupName $vNetWithGateway.DestinationEndpointVirtualNetworkRG -VirtualNetworkName $vNetWithGateway.DestinationEndpointVirtualNetwork

        if ($peerings -ne $null -and $peerings.Count -gt 0) {
            foreach ($peering in $peerings) {
                    $StartEndpointUniqueId = $vNetWithGateway.DestinationEndpointUniqueId
                    $DestinationEndpointUniqueId = ConvertTo-UniqueId -ResourceId $peering.RemoteVirtualNetwork.Id

                    # Check if already added to Peering Array List
                    $IsExist = $false
                    foreach ($item in $Global:vNetPeering) {

                        if ($item.StartEndpointUniqueId -eq $StartEndpointUniqueId -and $item.DestinationEndpointUniqueId -eq $DestinationEndpointUniqueId) {
                            $IsExist = $true
                        }

                        if ($item.StartEndpointUniqueId -eq $DestinationEndpointUniqueId -and $item.DestinationEndpointUniqueId -eq $StartEndpointUniqueId) {
                            $IsExist = $true
                        }
                    }

                    if ($IsExist -eq $false) {
                        $DestinationEndpointSubscriptionId = $peering.RemoteVirtualNetwork.Id.Substring(("/subscriptions/".Length))
                        $DestinationEndpointSubscriptionId = $DestinationEndpointSubscriptionId.Substring(0, $DestinationEndpointSubscriptionId.IndexOf("/resourceGroups/"))

                        if ($peering.RemoteVirtualNetwork.Id -like "*/providers/Microsoft.ClassicNetwork/virtualNetworks*") {
                            $DestinationEndpointVirtualNetworkRG = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
                            $DestinationEndpointVirtualNetworkRG = $DestinationEndpointVirtualNetworkRG.Substring(0, $DestinationEndpointVirtualNetworkRG.IndexOf("/providers/Microsoft.ClassicNetwork/virtualNetworks/"))
                            $DestinationEndpointVirtualNetwork = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/providers/Microsoft.ClassicNetwork/virtualNetworks/") + "/providers/Microsoft.ClassicNetwork/virtualNetworks/".Length)
                        } else {
                            $DestinationEndpointVirtualNetworkRG = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
                            $DestinationEndpointVirtualNetworkRG = $DestinationEndpointVirtualNetworkRG.Substring(0, $DestinationEndpointVirtualNetworkRG.IndexOf("/providers/Microsoft.Network/virtualNetworks/"))
                            $DestinationEndpointVirtualNetwork = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/Microsoft.Network/virtualNetworks/") + "/Microsoft.Network/virtualNetworks/".Length)
                        }

                        # Save to Temp Object
                        $obj = New-Object -TypeName PSobject
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartEndpointUniqueId" -Value $StartEndpointUniqueId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartEndpointVirtualNetwork" -Value $peering.VirtualNetworkName
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointUniqueId" -Value $DestinationEndpointUniqueId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointSubscriptionId" -Value $DestinationEndpointSubscriptionId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointVirtualNetworkRG" -Value $DestinationEndpointVirtualNetworkRG
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointVirtualNetwork" -Value $DestinationEndpointVirtualNetwork
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "PeeringState" -Value $peering.PeeringState

                        # Save to Array
                        $Global:vNetPeering += $obj
                    }
            }
        }
    }
} 

# Record the current index of peering list for n-tier peering lookup
$vNetPeeringCurrentIndex = $Global:vNetPeering.Count

# Get Virtual Network Peering for Virtual Network without Virtual Network Gateway deployed
foreach ($vn in $Global:vNet) {
    if ($vn.VirtualNetworkGateway -eq "N" -and $vn.PeeringCount -gt 0) {
        $AzContext = Set-AzContext -SubscriptionId $vn.SubscriptionId

        # Get Peering Status
        $peerings = Get-AzVirtualNetworkPeering -ResourceGroupName $vn.ResourceGroup -VirtualNetworkName $vn.VirtualNetwork

        if ($peerings -ne $null -and $peerings.Count -gt 0) {
            foreach ($peering in $peerings) {
                    $StartEndpointUniqueId = ConvertTo-UniqueId -ResourceId $vn.VirtualNetworkId
                    $DestinationEndpointUniqueId = ConvertTo-UniqueId -ResourceId $peering.RemoteVirtualNetwork.Id

                    # Check if already added to Peering Array List
                    $IsExist = $false
                    foreach ($item in $Global:vNetPeering) {

                        if ($item.StartEndpointUniqueId -eq $StartEndpointUniqueId -and $item.DestinationEndpointUniqueId -eq $DestinationEndpointUniqueId) {
                            $IsExist = $true
                        }

                        if ($item.StartEndpointUniqueId -eq $DestinationEndpointUniqueId -and $item.DestinationEndpointUniqueId -eq $StartEndpointUniqueId) {
                            $IsExist = $true
                        }
                    }

                    if ($IsExist -eq $false) {
                        $DestinationEndpointSubscriptionId = $peering.RemoteVirtualNetwork.Id.Substring(("/subscriptions/".Length))
                        $DestinationEndpointSubscriptionId = $DestinationEndpointSubscriptionId.Substring(0, $DestinationEndpointSubscriptionId.IndexOf("/resourceGroups/"))
                        
                        if ($peering.RemoteVirtualNetwork.Id -like "*/providers/Microsoft.ClassicNetwork/virtualNetworks*") {
                            $DestinationEndpointVirtualNetworkRG = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
                            $DestinationEndpointVirtualNetworkRG = $DestinationEndpointVirtualNetworkRG.Substring(0, $DestinationEndpointVirtualNetworkRG.IndexOf("/providers/Microsoft.ClassicNetwork/virtualNetworks/"))
                            $DestinationEndpointVirtualNetwork = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/providers/Microsoft.ClassicNetwork/virtualNetworks/") + "/providers/Microsoft.ClassicNetwork/virtualNetworks/".Length)
                        } else {
                            $DestinationEndpointVirtualNetworkRG = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
                            $DestinationEndpointVirtualNetworkRG = $DestinationEndpointVirtualNetworkRG.Substring(0, $DestinationEndpointVirtualNetworkRG.IndexOf("/providers/Microsoft.Network/virtualNetworks/"))
                            $DestinationEndpointVirtualNetwork = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/Microsoft.Network/virtualNetworks/") + "/Microsoft.Network/virtualNetworks/".Length)
                        }

                        # Save to Temp Object
                        $obj = New-Object -TypeName PSobject
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartEndpointUniqueId" -Value $StartEndpointUniqueId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartEndpointVirtualNetwork" -Value $peering.VirtualNetworkName
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointUniqueId" -Value $DestinationEndpointUniqueId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointSubscriptionId" -Value $DestinationEndpointSubscriptionId
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointVirtualNetworkRG" -Value $DestinationEndpointVirtualNetworkRG
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointVirtualNetwork" -Value $DestinationEndpointVirtualNetwork
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name "PeeringState" -Value $peering.PeeringState

                        # Save to Array
                        $Global:vNetPeering += $obj
                    }
            }
        }
    }
}

# Process Second Layer of the Destination Endpoint Virtual Network without ER / VPN Gateway
for ($i = $vNetPeeringCurrentIndex; $i -lt $Global:vNetPeering.Count; $i++) {
    $AzContext = Set-AzContext -SubscriptionId $Global:vNetPeering[$i].DestinationEndpointSubscriptionId
    
    # Get Peering Status
    $peerings = Get-AzVirtualNetworkPeering -ResourceGroupName $Global:vNetPeering[$i].DestinationEndpointVirtualNetworkRG -VirtualNetworkName $Global:vNetPeering[$i].DestinationEndpointVirtualNetwork

    if ($peerings -ne $null -and $peerings.Count -gt 0) {
        foreach ($peering in $peerings) {
                $StartEndpointUniqueId = $Global:vNetPeering[$i].DestinationEndpointUniqueId
                $DestinationEndpointUniqueId = ConvertTo-UniqueId -ResourceId $peering.RemoteVirtualNetwork.Id

                # Check if already added to Peering Array List
                $IsExist = $false
                foreach ($item in $Global:vNetPeering) {

                    if ($item.StartEndpointUniqueId -eq $StartEndpointUniqueId -and $item.DestinationEndpointUniqueId -eq $DestinationEndpointUniqueId) {
                        $IsExist = $true
                    }

                    if ($item.StartEndpointUniqueId -eq $DestinationEndpointUniqueId -and $item.DestinationEndpointUniqueId -eq $StartEndpointUniqueId) {
                        $IsExist = $true
                    }
                }

                if ($IsExist -eq $false) {
                    $DestinationEndpointSubscriptionId = $peering.RemoteVirtualNetwork.Id.Substring(("/subscriptions/".Length))
                    $DestinationEndpointSubscriptionId = $DestinationEndpointSubscriptionId.Substring(0, $DestinationEndpointSubscriptionId.IndexOf("/resourceGroups/"))
                    
                    if ($peering.RemoteVirtualNetwork.Id -like "*/providers/Microsoft.ClassicNetwork/virtualNetworks*") {
                        $DestinationEndpointVirtualNetworkRG = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
                        $DestinationEndpointVirtualNetworkRG = $DestinationEndpointVirtualNetworkRG.Substring(0, $DestinationEndpointVirtualNetworkRG.IndexOf("/providers/Microsoft.ClassicNetwork/virtualNetworks/"))
                        $DestinationEndpointVirtualNetwork = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/providers/Microsoft.ClassicNetwork/virtualNetworks/") + "/providers/Microsoft.ClassicNetwork/virtualNetworks/".Length)
                    } else {
                        $DestinationEndpointVirtualNetworkRG = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/resourceGroups/") + "/resourceGroups/".Length)
                        $DestinationEndpointVirtualNetworkRG = $DestinationEndpointVirtualNetworkRG.Substring(0, $DestinationEndpointVirtualNetworkRG.IndexOf("/providers/Microsoft.Network/virtualNetworks/"))
                        $DestinationEndpointVirtualNetwork = $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.IndexOf("/Microsoft.Network/virtualNetworks/") + "/Microsoft.Network/virtualNetworks/".Length)
                    }

                    # Save to Temp Object
                    $obj = New-Object -TypeName PSobject
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartEndpointUniqueId" -Value $StartEndpointUniqueId
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "StartEndpointVirtualNetwork" -Value $peering.VirtualNetworkName
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointUniqueId" -Value $DestinationEndpointUniqueId
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointSubscriptionId" -Value $DestinationEndpointSubscriptionId
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointVirtualNetworkRG" -Value $DestinationEndpointVirtualNetworkRG
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "DestinationEndpointVirtualNetwork" -Value $DestinationEndpointVirtualNetwork
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name "PeeringState" -Value $peering.PeeringState

                    # Save to Array
                    $Global:vNetPeering += $obj
                }
        }
    }
}

# Reserve 
# Record the current index of peering list for n-tier peering lookup
$vNetPeeringCurrentIndex = $Global:vNetPeering.Count

# Supplement the Unique ID for the Virtual Network that has no access permission
foreach ($item in $Global:vNetPeering) {
    if ($item.DestinationEndpointUniqueId -eq $null -or $item.DestinationEndpointUniqueId -eq "") {

        # Add Unique ID
        [string]$TempId = $UniqueId.ToString()
        $UniqueId++

        if ($TempId.Length -eq 1) {
            $TempId = "unknown00" + $TempId 
        } elseif ($TempId.Length -eq 2) {
            $TempId = "unknown0" + $TempId 
        } else {
            $TempId = "unknown" + $TempId 
        }
        
        $item.DestinationEndpointUniqueId = $TempId

        # Add Virtual Network info to vNet Array
        $VirtualNetwork 

        $obj = New-Object -TypeName PSobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionName" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubscriptionId" -Value $item.DestinationEndpointSubscriptionId
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "ResourceGroup" -Value $item.DestinationEndpointVirtualNetworkRG
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "Location" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetwork" -Value $item.DestinationEndpointVirtualNetwork
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkId" -Value $item.DestinationEndpointUniqueId
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkGateway" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "VirtualNetworkGatewayType" -Value "N/A"
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "UniqueId" -Value $TempId 
        Add-Member -InputObject $obj -MemberType NoteProperty -Name "PeeringCount" -Value "N/A"
        $Global:vNet  += $obj
    }
}

# Ordering
Update-vNetArray-Ordering

# Export to Text File for uploading to Diagrams.net
$CsvFileContent = @"
## Supply chain tracking
# label: %name%
# stylename: shapeType
# styles: {"vNetWithVPNGateway": "rounded=1;fillColor=#dae8fc;strokeColor=#6c8ebf;", \
#		   "vNetWithERGateway": "rounded=1;fillColor=#c4bbf0;strokeColor=#9f87e8;", \
#          "vNet":"shape=ellipse;fillColor=#f5f5f5;strokeColor=#5e5e5e;perimeter=ellipsePerimeter;", \
#          "vNetWithNoPeering":"shape=ellipse;fillColor=#f8cecc;strokeColor=#b85450;perimeter=ellipsePerimeter"}
# namespace: csvimport-
# connect: {"from":"supplier", "to":"id", "invert":true, "style":"curved=0;endArrow=none;startArrow=none;strokeColor=#999999;endFill=1;"}
# width: auto
# height: auto
# padding: 40
# ignore: id,shapeType,supplier
# nodespacing: 50
# levelspacing: 50
# edgespacing: 50
# layout: horizontalflow
## CSV starts below this line
id,name,supplier,shapeType
"@

# Create Entity
foreach ($vn in $Global:vNet) {
    $id = $vn.UniqueId
    $name = $vn.VirtualNetwork
    $supplier = ""

    foreach ($item in $Global:vNetPeering) {
        if ($item.DestinationEndpointUniqueId -eq $vn.UniqueId) {
                if ($supplier -ne "") {
                    $supplier += ","
                } else {
                    $supplier += '"'
                }
                $supplier += $item.StartEndpointUniqueId
        }
    }

    if ($supplier -ne "") {
        $supplier += '"'
    }

    if ($vn.VirtualNetworkGatewayType -eq "ExpressRoute") {
        $shapeType = "vNetWithERGateway"
    } elseif ($vn.VirtualNetworkGatewayType -eq "Vpn") {
        $shapeType = "vNetWithVPNGateway"
    } elseif ($vn.PeeringCount -gt 0) {
        $shapeType = "vNet"
    } else {
        $shapeType = "vNetWithNoPeering"
    }

    # Append to File
    $CsvFileContent += "`n"
    $CsvFileContent += $id + "," + $name + "," + $supplier + "," + $shapeType
}

$CsvFileContent | Out-File -FilePath $TextFileFullPath -Confirm:$false -Force

# End
Write-Host "`nCompleted`n" -ForegroundColor Yellow