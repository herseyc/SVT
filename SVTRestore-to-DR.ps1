
##################################################################
# Use PowerShell and the SimpliVity REST API  to 
# Restore Predefined VMs to DR Datacenter
#
# Usage: SVTRestore-to-DR.ps1
#
# http://www.vhersey.com/
# 
# http://www.simplivity.com/
#
##################################################################

############## BEGIN USER VARIABLES ############## 

#Define VMs to Restore
$vmstorestore = "VM01", "VM02", "VM03"

#Define Recovery Datacenter
$recoverydatacenter = "Raleigh"

############### END USER VARIABLES ###############
$ovc = Read-Host "Enter OVC Management IP Address"

$username = Read-Host "Enter OVC Username"
$pass_word = Read-Host "Enter OVC Password"

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

# Restore Defined VMs in DR Datacenter
foreach ($vm in $vmstorestore) {

   # Get last backup for VM in DR datacenter
   $uri = "https://" + $ovc + "/api/backups?virtual_machine_name=" + $vm + "&omnistack_cluster_name=" + $recoverydatacenter + "&limit=1"
   $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

   $backuptorestore = $response.backups[0].id
   $recoverydatastore = $response.backups[0].datastore_id

   if ( $backuptorestore ) {
          
      $uri = "https://" + $ovc + "/api/backups/" + $backuptorestore + "/restore?restore_original=false"

      $restoredate = Get-Date -format MMddyyyyHHmmss
      $restorename = $vm + "-dr-" + $restoredate

      $body = @{}
      $dsid = $recoverydatastore
      #### Write-Host "Datastore id: " $dsid

      $body.Add("datastore_id", "$dsid")
      $body.Add("virtual_machine_name", "$restorename") 
      $body = $body | ConvertTo-Json
      
      Write-Host "Restoring VM $vm from $backuptorestore ... "
      $response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post -ContentType 'application/vnd.simplivity.v1+json'
   
   } else {
          
      Write-Host "Backup for $vm not found."
      
   }
   
}


