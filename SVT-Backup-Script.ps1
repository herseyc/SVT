#Parameters
$ovc = "IPAddressofOVC"
$user = "vCenterUser@domain"
$pass = "vCenterUserPassword"
$datacenter = "SVTDatacenterToStoreBackup" 
$retention = "525600" # Retention Period in Minutes ie: 525600 = 1 year

#List of VMs to Backup
$vmList = Get-Content C:\temp\simplivity.csv

#Backup each VM in list
foreach ($vmName in $vmList)
{
  # Create a Time Stamp to use in the backup name MonthDayYearHourMinute
  $now = Get-Date
  $dtstamp = "$($now.Month)$($now.Day)$($now.Year)$($now.Hour)$($now.Minute)" 
  $backupname = "$vmName-BU-$dtstamp"

  Write-Host "Backing Up VM $vmName"
    
  # SVT-BackupVM.ps1 can be found at https://github.com/herseyc/SVT/blob/master/SVT-BackupVM.ps1
  c:\temp\SVT-BackupVM.ps1 -OVC $ovc -Username $user -Password $pass -VM $vmName -DC $datacenter -Name $backupname -Expire $retention

}
