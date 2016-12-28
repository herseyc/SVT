##################################################################
# Use PowerShell and the SimpliVity REST API  to 
# Backup a VM running on the SimpliVity DVP
#
# Usage: SVT-BackupVM.ps1 -OVC OVCIP -Username USERNAME -Password PASSWORD -VM VMTOBACKUP -DC DATACENTER -Name BACKUPNAME -Expire MINUTESTOEXPIRE
#
# Set Expiration to 0 to set backup retention to never expire
#
# http://www.vhersey.com/
# 
# http://www.simplivity.com/
#
##################################################################
#Get Parameters
param(
 [Parameter(Mandatory=$true, HelpMessage="OVC IP Address")][string]$OVC,
 [Parameter(Mandatory=$true, HelpMessage="OVC Username")][string]$Username,
 [Parameter(Mandatory=$true, HelpMessage="OVC Password")][string]$Password,
 [Parameter(Mandatory=$true, HelpMessage="VM to Backup")][string]$VM,
 [Parameter(Mandatory=$true, HelpMessage="Datacenter")][string]$DC,
 [Parameter(Mandatory=$true, HelpMessage="Backup Name")][string]$Name,
 [Parameter(Mandatory=$true, HelpMessage="Expiration (minutes)")][string]$Expire
)
############## Set Variables ############## 
$ovc = $OVC
$username = $Username
$pass_word = $Password
$vmtobackup = $VM
$backupdatacenter = $DC
$backupname = $Name
$expiration = $Expire

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

if ($atoken -eq $null) {
   Write-Host "Unable to Authenticate"
   exit 1   
}

# Create SVT Auth Header
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")

#Get VM Id of Source VM
$uri = "https://" + $ovc + "/api/virtual_machines?limit=1&show_optional_fields=false&name=" + $vmtobackup
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
$vmid = $response.virtual_machines[0].id

if ($vmid -eq $null) {
   Write-Host "VM ID Not Found"
   exit 1
}


#Backup Virtual Machine
$backupparams = @{}
$backupparams.Add("backup_name", "$backupname")
$backupparams.Add("destination_id", "$backupdatacenter")
$backupparams.Add("retention", "$expiration")

#Convert backupparams to json
$backupjson = $backupparams | ConvertTo-Json

#Add Content-Type for Json to headers
$headers.Add("Content-Type", "application/vnd.simplivity.v1.1+json")

$uri = "https://" + $ovc + "/api/virtual_machines/" + $vmid + "/backup"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $backupjson 

$headers.Remove("Content-Type")

#Make sure backup task completes.
$taskid = $response.task.id
$loop = $true
while ($loop) {
   $uri = "https://" + $ovc + "/api/tasks/" + $taskid
   $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
   $result = $response.task.state
   if ($result -eq "COMPLETED" ) {
      Write-Host "VM $vmtobackup successfully backed up to $backupdatacenter retained for $expiration minutes."
      $loop = $false
      exit 0
   }
   if ($result -eq "FAILED" ) {
      Write-Host "VM $vmtobackup backup failed."
      $loop = $false
      exit 1
   }
   Start-Sleep 10
}

