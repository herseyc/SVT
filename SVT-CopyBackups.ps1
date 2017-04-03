##################################################################################
#
#  SVT-CopyBackups.ps1
#  Copy SimpliVity Backups from one OmniStack Cluster to another
#
#  http://www.vhersey.com/
#
##################################################################################
$ovc = "xxx.xxx.xxx.xxx" # OVC Management IP Address
$username = "user@domain" #vCenter Username
$pass = "Password-01" #vCenter Password

# OmniStack Cluster to Copy Backups From
$srcOSCluster = "ProductionCluster"
# OmniStack Cluater to Copy Backups to
$dstOSCluster = "DRCluster"
#Number of backups to copy
$numberBackups = "1000"
#Starting backup 
$backupStartingOffset = "0"

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

Write-Host "Authenticating to $ovc"
# Authenticate - Get SVT Access Token
$uri = "https://" + $ovc + "/api/oauth/token"
$base64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))
$body = @{username="$username";password="$pass";grant_type="password"}
$headers = @{}
$headers.Add("Authorization", "Basic $base64") 
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post 
    
$atoken = $response.access_token

if ($atoken -eq $null) {
   Write-Host "Unable to Authenticate" -Foregroundcolor Red
   exit 1   
}

# Create SVT Auth Header
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")


#Get OmniStack Cluster ID for Src and Dst OSClusters
$uri = "https://" + $ovc + "/api/omnistack_clusters?show_optional_fields=false&fields=name%2Cid"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

$srcOSClusterId = ($response.omnistack_clusters | Where {$_.Name -eq $srcOSCluster}).id
$dstOSClusterId = ($response.omnistack_clusters | Where {$_.Name -eq $dstOSCluster}).id

$dstCopyParams = @{}
$dstCopyParams.Add("destination_id", "$dstOSClusterId")
$dstCopyParams = $dstCopyParams | ConvertTo-Json

$jsonHeaders = $headers
$jsonHeaders.Add("Content-Type", "application/vnd.simplivity.v1.1+json")
$jsonHeaders.Add("Accept", "application/json")

#Get backups for $srcOSClusterId - $numberBackups starting at $backupStartingOffset
$uri = "https://" + $ovc + "/api/backups?omnistack_cluster_id=" + $srcOSClusterId + "&fields=id%2Ctype%2Cname%2Cexpiration_time%2Cvirtual_machine_name&limit=" + $numberBackups + "&offset=" + $backupStartingOffset
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

foreach ( $srcBackup in $response.backups ) { #Start Backup Loop
   
   # Check dstOSClusterID for existing VM Backup with same Name
   $dstVmName = $srcBackup.virtual_machine_name
   $dstBackupName = $srcBackup.name
   $uri = "https://" + $ovc + "/api/backups?omnistack_cluster_id=" + $dstOSClusterId + "&name=" + $dstBackupName + "&virtual_machine_name=" + $dstVmName
   $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
   $dstBackupFound = $response.count
   
   if ( $dstBackupFound ) {
   
      Write-Host "Backup $dstBackupName for $dstVmName Already Found in $dstOSCluster" -ForegroundColor Yellow

   } else {
   
      $srcCopyBackupId = $srcBackup.id
      $srcBackupExpire = $srcBackup.expiration_time
      #Calculate Retention Minutes
      if ($srcBackupExpire -ne "NA") {
         Write-Host "Source Backup Expiration: $srcBackupExpire"
         $rightnow = Get-Date
         $srcBackupUTC = Get-Date -Date $srcBackupExpire
         $timediff = [DateTime]$srcBackupUTC - [DateTime]$rightnow
         $dstBackupRetentionMins = [math]::Round($timediff.TotalMinutes, 0)
      }
      Write-Host "Copying $dstBackupName for $dstVmName Backup ID $srcCopyBackupId to $dstOSCluster"
      $uri = "https://" + $ovc + "/api/backups/" + $srcCopyBackupId + "/copy"
      $response = Invoke-RestMethod -Uri $uri -Headers $jsonHeaders -Method Post -Body $dstCopyParams
      $taskid = $response.task.id

      $loop = $true
      while ($loop) { #Start Status Loop
         Write-Host "Waiting to Backup Copy to Complete"
         $uri = "https://" + $ovc + "/api/tasks/" + $taskid
         $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
         $result = $response.task.state
         if ($result -eq "COMPLETED" ) {
            Write-Host "Backup $dstBackupName for $dstVmName copied to $dstOSCluster - Completed Successfully" -ForegroundColor Green
            $newBackupId = $response.task.affected_objects.object_id
            Write-Host "New Backup Id is: $newBackupId" -ForegroundColor Cyan

            #Set Expiration On Backup in $dstOSCluster (if it has one)
            if ($srcBackupExpire -ne "NA") {
                Write-Host "Setting Retention Time on Copied Backup to $dstBackupRetentionMins Minutes from $rightnow" -ForegroundColor Cyan
                $retentionParams = "{ ""backup_id"" : [""$newBackupId""], ""retention"" : $dstBackupRetentionMins }"
                $uri = "https://" + $ovc + "/api/backups/set_retention"
                $response = Invoke-RestMethod -Uri $uri -Headers $jsonHeaders -Method Post -Body $retentionParams
            }

            $loop = $false
         }
         if ($result -eq "FAILED" ) {
            Write-Host "Backup ID $copyBackupId copied to $$dstOSCluster - FAILED" -Foregroundcolor Red
            $loop = $false
         }
         Start-Sleep 10
      } # End Status Loop
   }
} # End Backup Loop

