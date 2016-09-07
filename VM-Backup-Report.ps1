##################################################################
# Example script to get backups for a specific VM
##################################################################
################# Variables ######################################
#SVT OVC Address (IP Address of FQDN)
$ovc = "x.x.x.x"

# SVT Authentication
$username = "DOMAIN\User"
$pass_word = "Password"

#VM Inventory Name to report backups on
$workingvm = "VMName"
####################################################################
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

## Authenticate to SimpliVity REST API
$uri = "https://" + $ovc + "/api/oauth/token"
$base64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))
$body = @{username="$username";password="$pass_word";grant_type="password"}
$headers = @{}
$headers.Add("Authorization", "Basic $base64")
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post 
   
$atoken = $response.access_token

Write-Host "Authenticated to SimpliVity Federation"
write-Host ""
write-Host "Get VM ID for $workingVM"

## Get the SimpliVity VM ID for the VM
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")
$uri = "https://" + $ovc + "/api/virtual_machines?show_optional_fields=false&name=" + $workingVM
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

$vmid = $response.virtual_machines.id

## Get the backups for the SimpliVity VM ID
Write-Host "SimpliVity Backups avaiable for $workingVM VMID: $vmid"
Write-Host ""
$uri = "https://" + $ovc + "/api/backups?virtual_machine_id=" + $vmid 
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

## List backups for VM
for ($i=1;$i -le $response.backups.count; $i++) 
{ 
  Write-Host "$($response.backups[$i-1].name) created on $($response.backups[$i-1].created_at) - Backup State: $($response.backups[$i-1].state)"
}
