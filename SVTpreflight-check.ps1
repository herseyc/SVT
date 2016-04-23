#############################################################
# SimpliVity Deployment Pre-Flight Check Script
#
# Uses XML export of SimpliVity Pre-Flight to test network,
# vCenter, and DNS configuration prior to running SimpliVity
# Deployment Manager
#
# Run script from same host as Deployment Mananger
# Tests performed:
#   - vCenter IP Address (ping)
#   - vCenter Forward and Reverse DNS
#   - SimpliVity Arbiter and Port (22122)
#   - ESXi IP Address Availability (ping)
#   - ESXi Forward and Reverse DNS
#   - OVC Management IP Address Availability (ping)
#   - IPMI/CIMC IP Address Availability (ping)
#
# 04/23/2016 - Initial Script
#
# http://www.vhersey.com/ - http://www.simplivity.com/
#
#############################################################
# Export Pre-Flight XML from SimpliVity Pre-Flight Tool
# Set path to Pre-Flight XML Export
$strFilePath = "C:\Utilities\PF\PF_ExportXml.xml"

# Import Pre-Flight XML
[xml]$SVTPreFlight = Get-Content $strFilePath 

# Set Deployment Issues Counter
$DeployIssues = 0

# Add VMware PowerCLI Snapin
Add-PSSnapin *vmware*

#Functions used in tests
#Resolve IP
Function ResolveIPtoHost {
    Param([string]$IP,
    [string]$DNS)
    # write-host "Checking" $IP "on" $DNS
    try {
       $ResolvedIP = (Resolve-DnsName $IP -Server $DNS -ErrorAction SilentlyContinue).NameHost
    }
    catch { 
       $ResolvedIP = "Unable to resolve IP" 
    }
    return $ResolvedHN
}

#Resolve Hostname
Function ResolveHosttoIP {
    Param([string]$HOSTNAME,
    [string]$DNS)
    # write-host "Checking" $HOSTNAME "on" $DNS
    try {
       $ResolvedIP = (Resolve-DnsName $HOSTNAME -Server $DNS -DnsOnly -ErrorAction SilentlyContinue).IPAddress
    }
    catch { 
       $ResolvedIP = "Unable to resolve Hostname" 
    }
    return $ResolvedIP
}

#Get vCenter Version
Function vCenterVersion {
     Param([string]$IP)
     Connect-VIServer $IP
     $vCVersion = ($global:DefaultVIServer.ExtensionData.Content.About).FullName
     Disconnect-VIServer -confirm:$false
     return $vCVersion
}

#Ping a host or IP
Function TestPing  {
    Param([string]$IP)
    $Results = Test-Connection $IP -Count 1 -Quiet
    return $Results
}

#Verify connection to Arbiter
Function TestPortConnection {
    Param([string]$IP,
    [string]$PORT)
    try {
       $t = New-Object Net.Sockets.TcpClient $IP, $PORT
       $Results = $t.Connected 
       $t.Close()
    }
    catch {
       $Results = False
    }

    return $Results
}

write-host ""
write-host "Starting SimpliVity Deployment Pre-Flight Checks" -ForeGroundColor Cyan
write-host ""

foreach ($datacenter in $SVTPreFlight.preflight.datacenter) {
     write-host "Datacenter:"  $datacenter.name
         #vCenter Tests
         write-host "Testing vCenter Server"
         foreach ($vcenter in $datacenter.vcenter) {
              write-host "vCenter Hostname: " $vcenter.hostname
              write-host "vCenter IP: " $vcenter.ip
              $vcenteriptest = TestPing $vcenter.ip
              if ( $vcenteriptest ) {
                 write-host "Good: " $vcenter.ip " answers ping." -ForeGroundColor Green
              } else {
                 write-host "WARNING: " $vcenter.ip " not reachable." $vcenter.ip " must be reachable to run deployment." -ForeGroundColor Yellow
                 $DeployIssues += 1
              }
              # vCenter DNS Lookup
              write-host "Testing Forward DNS Lookup for vCenter Hostname:" $vcenter.hostname
              $vcenteripaddress = (Resolve-DnsName $vcenter.hostname -DnsOnly -ErrorAction SilentlyContinue).IPAddress
              if ( $vcenteripaddress -ne $vcenter.ip  ) {
                 write-host "WARNING:" $vcenter.hostname "did not correctly resolve to" $vcenter.ip -ForeGroundColor Yellow
                 $DeployIssues += 1
              } else {
                 write-host "Good:" $vcenter.hostname "resolved to" $vcenter.ip -ForeGroundColor Green
              }
              write-host "Testing Reverse DNS Lookup for vCenter IP Address:" $vcenter.ip
              $vcenterhostname = (Resolve-DnsName $vcenter.ip -DnsOnly -ErrorAction SilentlyContinue).NameHost
              if ( $vcenterhostname -ne $vcenter.hostname ) {
                 write-host "WARNING:" $vcenter.ip "did not correctly resolve to" $vcenter.hostname -ForeGroundColor Yellow
                 $DeployIssues += 1
              } else {
                 write-host "Good:" $vcenter.ip "resolved to" $vcenter.hostname "." -ForeGroundColor Green
              }

              write-host "Testing for connection to SimpliVity Arbiter on" $vcenter.ip
              $arbitertest = TestPortConnection -IP $vcenter.ip -PORT 22122
              if ( $arbitertest ) {
                 write-host "Good: Arbiter is available on" $vcenter.ip  -ForeGroundColor Green
              } else {
                 write-host "WARNING: " $vcenter.ip " Arbiter not reachable. Ensure Arbiter is installed and port 22122 is open." -ForeGroundColor Yellow
                 $DeployIssues += 1
              }
         }

         #Node test
         foreach ($node in $datacenter.node) {
              write-host "Testing Node: " $node.name
              write-host "ESXi Hostname: " $node.esxi.hostname
              write-host "ESXi IP: " $node.esxi.ip
              write-host "OVC IP: " $node.ovc.ip
              write-host "IPMI IP: " $node.ipmi.ip
              write-host "ESXi DNS1: " ($node.esxi.dns1).trim()
              write-host "ESXi DNS2: " ($node.esxi.dns2).trim()

              write-host "Checking Forward DNS Lookup for ESXi Hostname:" $node.esxi.hostname
              
              $ESXiHostIpOne = ResolveHosttoIP -HOSTNAME $node.esxi.hostname -DNS ($node.esxi.dns1).trim()
              $ESXiHostIpTwo = ResolveHosttoIP -HOSTNAME $node.esxi.hostname -DNS ($node.esxi.dns2).trim()
 
              if ( $ESXiHostIpOne -ne $node.esxi.ip ) {
                 write-host "WARNING:" $node.esxi.hostname "did not correctly resolve on" ($node.esxi.dns1).trim() -ForeGroundColor Yellow
                 $DeployIssues += 1
              } else {
                 write-host "Good:" $node.esxi.hostname "resolved to" $ESXiHostIpOne "on" ($node.esxi.dns1).trim() -ForeGroundColor Green
              }
              if ( $ESXiHostIpTwo -ne $node.esxi.ip ) {
                 write-host "WARNING:" $node.esxi.hostname "did not correctly resolve on" ($node.esxi.dns2).trim() -ForeGroundColor Yellow
                 $DeployIssues += 1
              } else {
                 write-host "Good:" $node.esxi.hostname "resolved to" $ESXiHostIpTwo "on" ($node.esxi.dns2).trim() -ForeGroundColor Green
              }

              write-host "Checking Reverse DNS Lookup for ESXi IP Address:" $node.esxi.ip
              $ESXiHostNameOne = (Resolve-DnsName $node.esxi.ip -Server ($node.esxi.dns1).trim() -DnsOnly -ErrorAction SilentlyContinue).NameHost
              $ESXiHostNameTwo = (Resolve-DnsName $node.esxi.ip -Server ($node.esxi.dns2).trim() -DnsOnly -ErrorAction SilentlyContinue).NameHost
              if ( $ESXiHostNameOne -ne $node.esxi.hostname ) {
                 write-host "WARNING:" $node.esxi.ip "did not correctly resolve to" $node.esxi.hostname  "on" ($node.esxi.dns1).trim() -ForeGroundColor Yellow
                 $DeployIssues += 1
              } else {
                 write-host "Good:" $node.esxi.ip "resolved to" $node.esxi.hostname "on" ($node.esxi.dns1).trim() -ForeGroundColor Green
              }  
              if ( $ESXiHostNameTwo -ne $node.esxi.hostname ) {
                 write-host "WARNING:" $node.esxi.ip "did not correctly resolve to" $node.esxi.hostname  "on" ($node.esxi.dns2).trim() -ForeGroundColor Yellow
                 $DeployIssues += 1
              } else {
                 write-host "Good:" $node.esxi.ip "resolved to" $node.esxi.hostname "on" ($node.esxi.dns2).trim() -ForeGroundColor Green
              }  
            
              # Check ESXi Management IP Address - Should not respond.
              write-host "Testing ESXi Management IP Address:" $node.esxi.ip
              $esximgmtiptest = TestPing $node.esxi.ip
              if ( $esximgmtiptest ) {
                 write-host "WARNING: " $node.esxi.ip " currently in use (answers ping). Must be available for deployment." -ForeGroundColor Yellow
                 $DeployIssues += 1
              } else {
                 write-host "Good: " $node.esxi.ip " does not appear to be in use" -ForeGroundColor Green
              }
              write-host "Testing OVC Management IP Address:" $node.ovc.ip
              # Check OVC Management IP Address - Should not respond.   
              $ovcmgmtiptest = TestPing $node.ovc.ip
              if ( $ovcmgmtiptest ) {
                 write-host "WARNING: " $node.ovc.ip " currently in use (answers ping). Must be available for deployment." -ForeGroundColor Yellow
                 $DeployIssues += 1
              } else {
                 write-host "Good: " $node.ovc.ip " does not appear to be in use" -ForeGroundColor Green
              }

              # Check IPMI IP Address - Should respond.
              write-host "Testing IPMI/CIMC IP Address:" $node.ipmi.ip
              $ipmiiptest = TestPing $node.ipmi.ip
              if ( $ipmiiptest ) {
                 write-host "Good: " $node.ipmi.ip " answers ping" -ForeGroundColor Green
              } else {
                 write-host "WARNING: " $node.ipmi.ip " not reachable." $node.ovc.ip " must be configured and reachable to run deployment." -ForeGroundColor Yellow
                 $DeployIssues += 1
              }
         }
}

write-host ""
write-host "SimpliVity Deployment Pre-Flight Checks Completed" -ForeGroundColor Cyan
write-host ""
if ($DeployIssues -ne 0 ) {
    write-host "Found $DeployIssues potential deployment issues.  Please check for WARNINGs in script output." -ForeGroundColor Yellow
} else {
    write-host "All pre-checks look good!" -ForeGroundColor Green
}


