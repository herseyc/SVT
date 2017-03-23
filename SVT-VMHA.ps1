########################################################
#
#  SVT-VMHA.ps1
#  Check Storage HA Status of SimpliVity VMs
#
#  Hersey Cartwright - http://www.vhersey.com/
#
########################################################

############## Set Variables ############## 
$ovc = "xxx.xxx.xxx.xxx" #OVC Mgmt IP
$username = "user@domain" #vCenter Username
$pass = "Password-01" #vCenter Password

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

# Get OmniStack SVT VMs
$uri = "https://" + $ovc + "/api/virtual_machines?show_optional_fields=true&fields=id%2Cname%2Cha_status%2Cdatastore_name%2Comnistack_cluster_name%2Cstate"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

Write-Host $response.count "SimpliVity Virtual Machines in Federation"
Write-Host ""

[int]$haok = "0"
foreach ($svtvm in $response.virtual_machines) { # Start SVT VM Loop
  $color = "Green"
  if ( $svtvm.ha_status -ne "SAFE" ) {
     $color = "Red"
     #Increment $haok 
     $haok++
  }
  Write-Host "VM:" $svtvm.name "State:" $svtvm.state "SVT HA Status:" $svtvm.ha_status "SVT Cluster:" $svtvm.omnistack_cluster_name "SVT Datastore:" $svtvm.datastore_name ""  -Foregroundcolor $color

} # End SVT VM Loop

Write-Host ""

# Were any VMs found not HA Safe
if ( [int]$haok -ne "0" ) {
  Write-Host "$haok SimpliVity VMs found with HA State not SAFE" -Foregroundcolor Red
} else {
   Write-Host "All SimpliVity VMs in HA State SAFE" -Foregroundcolor Green
} 

Write-Host ""
