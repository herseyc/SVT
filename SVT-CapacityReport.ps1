##################################################################
# Use PowerShell and the SimpliVity REST API  to 
# Report on Datacenter and Host Capacity
#
# Usage: SVT-CapacityReport.ps1
#
# http://www.vhersey.com/
# 
# http://www.simplivity.com/
#
##################################################################

############## BEGIN USER VARIABLES ############## 
$ovc = "<ovc_ip_address>"
$username = "<username>"
$pass_word = "<password>"

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


# Get OmniStack Clusters in Federation
$uri = "https://" + $ovc + "/api/omnistack_clusters"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get


For ($i=0; $i -lt [int]$response.count; $i++) {
  #Display each Datacenter Capacity Information
  Write-Host ""
  Write-Host "###############################################################"
  Write-Host "Datacenter Name:" $response.omnistack_clusters[$i].name
  Write-Host "Number of OmniStack Hosts in Datacenter:" $response.omnistack_clusters[$i].members.Count
  $totalpcapTB = (([int64]$response.omnistack_clusters[$i].allocated_capacity)/1073741824/1024)
  write-Host "Datacenter Total Physical Capacity (GB):" ([math]::Round((([int64]$response.omnistack_clusters[$i].allocated_capacity)/1073741824), 2))
  write-Host "Datacenter Consumed Physical Capacity (GB):" ([math]::Round((([int64]$response.omnistack_clusters[$i].used_capacity)/1073741824), 2))
  write-Host "Datacenter Free Physical Capacity (GB):" ([math]::Round((([int64]$response.omnistack_clusters[$i].free_space)/1073741824), 2))
  Write-Host "###############################################################"
  Write-Host "OmniStack Hosts in" $response.omnistack_clusters[$i].name "Datacenter"
  Write-Host "--------------------------------------------------------"
  
  #Display each Host in Datacenter
  foreach ($oshost in $response.omnistack_clusters[$i].members) {
     # Get OmniStack Host Information
     $uri = "https://" + $ovc + "/api/hosts/" + $oshost
     $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
     Write-Host "Hostname:" $response.host.name
     Write-Host "Host Total Physical Capacity (GB):" ([math]::Round((([int64]$response.host.allocated_capacity)/1073741824), 2))
     Write-Host "Host Consumed Physical Capacity (GB):" ([math]::Round((([int64]$response.host.used_capacity)/1073741824), 2))
     Write-Host "Host Free Physical Capacity (GB):" ([math]::Round((([int64]$response.host.free_space)/1073741824), 2))
     Write-Host "--------------------------------------------------------"
  }

       
}
