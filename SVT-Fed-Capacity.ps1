########################################################
#
#  SVT-Fed-Capacity.ps1
#  Get SimpliVity OmniStack Cluster and OmniStack Host
#  Capactiy Information (Available, Used, Free)
#
#  Hersey Cartwright - http://www.vhersey.com/
#
########################################################

############## Set Variables ############## 
$ovc = "XXX.XXX.XXX.XXX" #OVC Mgmt IP
$username = "domain\user" #vCenter Username
$pass = "password" #vCenter Password

# Function to Convert to Bytes to TiB, TB, GB, or GiB
function ConvertTo ($inttoconvert) {
  $TiB = "1099511627776" #Convert to TiB
  $TB = "1000000000000" #Convert to TB
  $GB = "1000000000" #Convert to GB
  $GiB = "1073741824" #Convert to GiB
  $conveq = $TiB  # Set this to what you want to convert to.
  $rounding = 2 # Number of place to round to.
  # Conversion calulation
  $converted = [math]::Round($inttoconvert/$conveq, $rounding)
  return $converted
}


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

# Get OmniStack Clusters
$uri = "https://" + $ovc + "/api/omnistack_clusters?fields=id%2C%20name%2C%20members%2C%20free_space%2C%20allocated_capacity%2C%20used_capacity%2C%20used_logical_capacity"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

Write-Host $response.count "OmniStack Clusters in Federation"
Write-Host ""

foreach ($omnistackcluster in $response.omnistack_clusters) { # Start OmniStack Cluster Loop
  Write-Host "Omnitack Cluster:" $omnistackcluster.name
  Write-Host "     Available Capacity:" (ConvertTo($omnistackcluster.allocated_capacity))
  Write-Host "     Used Capacity:" (ConvertTo($omnistackcluster.used_capacity))
  Write-Host "     Free Capacity:" (ConvertTo($omnistackcluster.free_space))
  Write-Host ""
  foreach ($omnistackhost in $omnistackcluster.members) { # Start OmniStack Host Loop
     $uri = "https://" + $ovc + "/api/hosts/" + $omnistackhost 
     $hostresponse = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
     Write-Host "OmniStack Host:" $hostresponse.host.name
     Write-Host "     Available Capacity:" (ConvertTo($hostresponse.host.allocated_capacity))
     Write-Host "     Used Capacity:" (ConvertTo($hostresponse.host.used_capacity))
     Write-Host "     Free Capacity:" (ConvertTo($hostresponse.host.free_space))
  } # End OmniStack Host Loop
} # End OmniStack Cluster Loop

Write-Host ""






