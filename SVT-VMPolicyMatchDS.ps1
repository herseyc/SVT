##################################################################
# Use PowerShell and the SimpliVity REST API  to 
# Compare VM SVT Backup Policy to Default Datastore SVT Backup Policy
#
# Usage: SVT-VMPolicyMatchDS.ps1
#
# http://www.vhersey.com/
#
##################################################################

############## BEGIN USER VARIABLES ############## 
$ovc = "<ovc-ip>"
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
   Write-Host "SVT Datacenter Name:" $response.omnistack_clusters[$i].name
   #Write-Host "Datacenter ID:" $response.omnistack_clusters[$i].id

   # Get Datastores in OmniStack Cluster
   $uri = "https://" + $ovc + "/api/datastores?show_optional_fields=false&omnistack_cluster_id=" + $response.omnistack_clusters[$i].id
   $dsrsp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
   Write-Host "Datastores Found: " $dsrsp.count
   For ($d=0; $d -lt [int]$dsrsp.count; $d++) {
       Write-Host "SVT Datastore:" $dsrsp.datastores[$d].name
       #Write-Host "SVT Datastore:" $dsrsp.datastores[$d].id
       #Write-Host "SVT Datastore Default Backup Policy ID:" $dsrsp.datastores[$d].policy_id
       Write-Host "SVT Datastore Default Backup Policy Name:" $dsrsp.datastores[$d].policy_name
       
       #Get VMs on Datastore
       $uri = "https://" + $ovc + "/api/virtual_machines?show_optional_fields=false&state=ALIVE&datastore_id=" + $dsrsp.datastores[$d].id
       $vmrsp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
       For ($v=0; $v -lt [int]$vmrsp.count; $v++) {
           #Write-Host "VM:" $vmrsp.virtual_machines[$v].name
           #Write-Host "VM SVT Backup Policy ID:" $vmrsp.virtual_machines[$v].policy_id
           if ( $vmrsp.virtual_machines[$v].policy_id -eq $dsrsp.datastores[$d].policy_id ) {
              Write-Host $vmrsp.virtual_machines[$v].name -ForeGroundColor Green
           } else {
              Write-Host $vmrsp.virtual_machines[$v].name "VM SVT Backup Policy Set To:" $vmrsp.virtual_machines[$v].policy_name -ForeGroundColor Red
           }
           
       }
   }  
}

