################################################################
#
# Checks and sets advanced settings on an ESXi hosts which will 
# be used as compute only nodes in a SimpliVity environment
#
# Usage: check-svtnfs.ps1 -Compute Node <hostname/ip> -CheckOnly 
#
# 04/04/2016 - http://www.vhersey.com/ 
# 
################################################################
param(
 [Parameter(Mandatory=$true, HelpMessage=”Compute Node Hostname or IP”)][string]$ComputeNode,
 [switch]$CheckOnly = $false
)

# Advanced Settings from OmniCube for vSphere Client Administrator Guide
$SVTnettcpipheapmax = 512 #ESXi 5.1 set to 128, 5.5 set to 512, 6.0 set to 1536
$SVTnettcpipheapsize = 32
$SVTnfsmaxvolumes = 256
$SVTsunrpcmaxconnperip = 128

if ($CheckOnly) {
  write-host "Checking Only - No changes will be made to host." -ForeGroundColor Cyan
}

$vmhost = Get-VMHost $ComputeNode

$nettcpipheapmax = ($vmhost | Get-AdvancedSetting -Name Net.TcpipHeapMax).Value
$nettcpipheapsize = ($vmhost | Get-AdvancedSetting -Name Net.TcpipHeapSize).Value
$nfsmaxvolumes = ($vmhost | Get-AdvancedSetting -Name NFS.MaxVolumes).Value
$sunrpcmaxconnperip = ($vmhost | Get-AdvancedSetting -Name SunRPC.MaxConnPerIP).Value

if ($nettcpipheapmax -ne $SVTnettcpipheapmax) {
   write-host "Net.TcpipHeapMax currently set to $nettcpipheapmax - value should be $SVTnettcpipheapmax" -ForeGroundColor Yellow
   if (!$CheckOnly) {
      write-host "Setting Net.TcpipHeapMax to $SVTnettcpipheapmax" -ForeGroundColor Cyan
      $vmhost | Get-AdvancedSetting -Name Net.TcpipHeapMax | Set-AdvancedSetting -Value $SVTnettcpipheapmax -Confirm:$false
   }
} else {
   write-host "Net.TcpipHeapMax already correctly set to $nettcpipheapmax." -ForeGroundColor Green
}

if ($nettcpipheapsize -ne $SVTnettcpipheapsize) {
   write-host "Net.TcpipHeapSize currently set to $nettcpipheapsize - value should be $SVTnettcpipheapsize" -ForeGroundColor Yellow
   if (!$CheckOnly) {
      write-host "Setting Net.TcpipHeapSize to $SVTnettcpipheapsize" -ForeGroundColor Cyan
      $vmhost | Get-AdvancedSetting -Name Net.TcpipHeapSize | Set-AdvancedSetting -Value $SVTnettcpipheapsize -Confirm:$false
   }
} else {
   write-host "Net.TcpipHeapMax already correctly set to $nettcpipheapsize." -ForeGroundColor Green
}

if ($nfsmaxvolumes -ne $SVTnfsmaxvolumes) {
   write-host "NFS.MaxVolumes currently set to $nfsmaxvolumes - value should be $SVTnfsmaxvolumes" -ForeGroundColor Yellow
   if (!$CheckOnly) {
      write-host "Setting NFS.MaxVolumes to $SVTnfsmaxvolumes" -ForeGroundColor Cyan
      $vmhost | Get-AdvancedSetting -Name NFS.MaxVolumes | Set-AdvancedSetting -Value $SVTnfsmaxvolumes -Confirm:$false
   }
} else {
   write-host "NFS.MaxVolumes already correctly set to $nfsmaxvolumes." -ForeGroundColor Green
}

if ($sunrpcmaxconnperip -ne $SVTsunrpcmaxconnperip) {
   write-host "SunRPC.MaxConnPerIP currently set to $sunrpcmaxconnperip - - value should be $SVTsunrpcmaxconnperip" -ForeGroundColor Yellow
   if (!$CheckOnly) {
      write-host "Setting SunRPC.MaxConnPerIP to $SVTsunrpcmaxconnperip" -ForeGroundColor Cyan
      $vmhost | Get-AdvancedSetting -Name SunRPC.MaxConnPerIP | Set-AdvancedSetting -Value $SVTsunrpcmaxconnperip -Confirm:$false
   }
} else {
   write-host "SunRPC.MaxConnPerIP already correctly set to $sunrpcmaxconnperip." -ForeGroundColor Green
}
write-host "Done!" -ForeGroundColor Cyan



