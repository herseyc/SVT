########################################################
#
#  SVT-VMHAMAP.ps1
#  Map VM Primary Data and Secondary Data Locations
#
#  Hersey Cartwright - http://www.vhersey.com/
#
########################################################

############## Set Variables ############## 
$ovc = "X.X.X.x" #OVC Mgmt IP
$username = "username@domain" #vCenter Username
$pass = "Password-01" #vCenter User Password

#Ignore Self Signed Certificates and set TLS
Try {
Add-Type @"
       using System.Net;
       using System.Security.Cryptography.X509Certificates;
       public class TrustAllCertsPolicy : ICertificatePolicy {
           public bool CheckValidationResult(
               ServicePoint srvPoint, X509Certificate certificate,
               WebRequest request, int certificateProblem) {
               return true;
           }
       }
"@
   [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
   [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} Catch {
}

Clear-Host

# Authenticate - Get SVT Access Token
$uri = "https://" + $ovc + "/api/oauth/token"
$base64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))
$body = @{username="$username";password="$pass";grant_type="password"}
$headers = @{}
$headers.Add("Authorization", "Basic $base64")
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post 
    
$atoken = $response.access_token

if ($atoken -eq $null) {
   Write-Host "Unable to Authenticate"
   exit 1   
}

# Create SVT Auth Header
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")

#Get OmniStack Hosts
$uri = "https://" + $ovc + "/api/hosts?show_optional_fields=false"
$omnistackhosts = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get


# Get OmniStack SVT VMs
$uri = "https://" + $ovc + "/api/virtual_machines?show_optional_fields=true&fields=id%2Cname%2Cha_status%2Cdatastore_name%2Comnistack_cluster_name%2Cstate%2Creplica_set"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

#Write-Host $response.count "SimpliVity Virtual Machines in Federation"
#Write-Host ""

#VMNAME, VMSTATE, VMHA, OSCLUSTER, VMPRIMARY, VMSECONDARY
$vmMAP = @()

foreach ($svtvm in $response.virtual_machines) { # Start SVT VM Loop

  $primary = ""
  $secondary = ""
  
  $haMAP = New-Object -TypeName PSObject
  $haMAP | Add-Member -Type NoteProperty -Name VMNAME -Value $svtvm.name
  $haMAP | Add-Member -Type NoteProperty -Name VMSTATE -Value $svtvm.state
  $haMAP | Add-Member -Type NoteProperty -Name VMHA -Value $svtvm.ha_status
  $haMAP | Add-Member -Type NoteProperty -Name OSCLUSTER -Value $svtvm.omnistack_cluster_name
  $primary = ($omnistackhosts.hosts -match ( $svtvm.replica_set -match "PRIMARY").id ).name
  $haMAP | Add-Member -Type NoteProperty -Name VMPRIMARY -Value $primary
  $secondary = ($omnistackhosts.hosts -match ( $svtvm.replica_set -match "SECONDARY").id ).name
  $haMAP | Add-Member -Type NoteProperty -Name VMSECONDARY -Value $secondary
  
  #Write-Host $svtvm.name "," $svtvm.state "," $svtvm.ha_status "," $svtvm.omnistack_cluster_name "," $svtvm.datastore_name ""  
  #Write-Host "Primary: " ($omnistackhosts.hosts -match ( $svtvm.replica_set -match "PRIMARY").id ).name
  #Write-Host "Secondary: " ($omnistackhosts.hosts -match ( $svtvm.replica_set -match "SECONDARY").id ).name

  $vmMAP += $haMAP  

} # End SVT VM Loop


$vmMAP
