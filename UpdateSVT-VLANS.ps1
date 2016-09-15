#######################################
# PowerCLI to update VLANs on SimpliVity Storage and Federation PortGroups
# For migration for SimpliVity Direct Connect to 10 GbE Switched
#
# Must be connected to vCenter using Connect-VIServer
#
# Script: UpdateSVT-VLANS.ps1
#
# History:
# 09/15/2016 - Hersey http://www.vhersey.com/ - Created
#######################################
###############VARIABLES###############
# vCenter Inventory Name of SimpliVity Hosts
$SVTHosts = "svthost1.vhersey.com", "svthost2.vhersey.com"

# SimpliVity Storage vmKernel Name
$SVTStorageVMK = "SVT_StorageVMK"

# SimpliVity Storage PortGroup Name
$SVTStoragePG = "SVT_StoragePG"

# SimpliVity Federation PortGroup Name
$SVTFedPG = "SVT_FederationPG"

# SimpliVity Storage VLAN
$SVTStorageVLAN = "60"

# SimpliVity Federation VLAN
$SVTFedVLAN = "61"

foreach ($SVTHost in $SVTHosts) {
    $vmhost = Get-VMHost -Name $SVTHost 
    Write-Host "Updating SimpliVity Virtual Networks for Host: $SVTHost"
    $vmhost | Get-VirtualPortGroup -Name $SVTStoragePG | Set-VirtualPortGroup -VlanId $SVTStorageVLAN
    $vmhost | Get-VirtualPortGroup -Name $SVTStorageVMK | Set-VirtualPortGroup -VlanId $SVTStorageVLAN
    $vmhost | Get-VirtualPortGroup -Name $SVTFedPG | Set-VirtualPortGroup -VlanId $SVTFedVLAN 
}

Write-Host "Done"
