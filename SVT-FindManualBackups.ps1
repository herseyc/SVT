##################################################################
# Use PowerShell and the SimpliVity REST API  to 
# locate Manual SVT Backups
#
# Usage: SVT-FindManualBackups.ps1
#
# http://www.vhersey.com/
# 
# http://www.simplivity.com/
#
##################################################################

############## BEGIN USER VARIABLES ############## 
$ovc = "<OVCIP>"
$username = "<Username>"
$pass_word = "<Password>"

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

# SVT Access Token
$atoken = $response.access_token

# Create SVT Auth Header
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")

# Get Manual SVT Backups in Federation
$uri = "https://" + $ovc + "/api/backups?type=MANUAL&limit=1000&fields=name%2Ctype%2Cvirtual_machine_name%2Ccreated_at%2Comnistack_cluster_name%2Cid"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

# Comma separate - VM Name, Backup Name, OmniStack Cluster Name (Datacenter), Backup Created At
for ($i=1;$i -le $response.backups.count; $i++) 
{ 

  Write-Host "$($response.backups[$i-1].virtual_machine_name),$($response.backups[$i-1].name),$($response.backups[$i-1].omnistack_cluster_name),$($response.backups[$i-1].created_at)"
  
}



