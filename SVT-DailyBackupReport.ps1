##################################################################
# Use PowerShell and the SimpliVity REST API  to 
# To Create a Report of Backups Taken in the Last 24 Hours
#
# Usage: SVT-DailyBackupReport.ps1
#
# http://www.vhersey.com/
#
##################################################################
############## BEGIN USER VARIABLES ############## 
$ovc = "<OVCIP>"
$username = "<USERNAME>"
$pass_word = "<PASSWORD>"
############### END USER VARIABLES ###############

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

# Authenticate - Get SVT Access Token
$uri = "https://" + $ovc + "/api/oauth/token"
$base64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))
$body = @{username="$username";password="$pass_word";grant_type="password"}
$headers = @{}
$headers.Add("Authorization", "Basic $base64")
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post 
    
$atoken = $response.access_token

# Create SVT Auth Header
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")

# Get Date Back 24 Hours - Format Correctly for SVT REST API
$yesterday = (get-date).AddHours(-24)
$yesterday = $yesterday.ToUniversalTime()
$createdafter = (get-date $yesterday -format s) + "Z"

# Get OmniStack Clusters in Federation
$uri = "https://" + $ovc + "/api/omnistack_clusters"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

For ($i=0; $i -lt [int]$response.count; $i++) {
   Write-Host "SVT Cluster Name:" $response.omnistack_clusters[$i].name
   
   # Get Backups in OmniStack Cluster
   $uri = "https://" + $ovc + "/api/backups?show_optional_fields=false&omnistack_cluster_id=" + $response.omnistack_clusters[$i].id + "&created_after=" + $createdafter
   $bursp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
   Write-Host "Backups Found: " $bursp.count
   For ($d=0; $d -lt [int]$bursp.count; $d++) {
        $bursp[$d].backups | Select virtual_machine_name, virtual_machine_state, created_at, type, state, omnistack_cluster_name | FT
   }
}


