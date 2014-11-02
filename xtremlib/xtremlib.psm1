﻿<#
xtremlib is a PowerShell Module that acts as a wrapper for interactions with the XtremIO RESTful API
This is currently incomplete, I intend to include most API functionality as well as make content more presentable

#TODO
 -Lots
 -Implement token-based security
 -Implement all basic storage creation/setting commands

Written by : Brandon Kvarda
             @bjkvarda
             

#>

######### GLOBAL VARIABLES #########
$global:XtremUsername =$null
$global:XtremPassword =$null
$global:XtremName =$null

######### SYSTEM COMMANDS ##########


#Returns Various XtremIO Statistics
Function Get-XtremClusterStatus ([string]$xioname,[string]$username,[string]$password)
{

  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

 $result=
  try{
    $header = Get-XtremAuthHeader -username $username -password $password
    $formattedname = Get-XtremClusterName -xioname $xioname -header $header
    $uri = "https://$xioname/api/json/types/clusters/?name=$formattedname"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).content

    $format =`
    @{Expression={$data.name};Label="System Name";width=16;alignment="Center"},
    @{Expression={$data.'sys-psnt-serial-number'};Label="Serial Number";width=14;alignment="Center"}, `
    @{Expression={$data.'sys-health-state'};Label="Health Status";width=13;alignment="Center"},
    @{Expression={$data.'sys-sw-version'};Label="SW Version";width=10;alignment="Center"},
    @{Expression={$data.'num-of-bricks'};Label="Bricks";width=7;alignment="Center"},
    @{Expression={$data.'dedup-ratio-text'};Label="Dedupe Ratio";width=12;alignment="Center"},
    @{Expression={[decimal]::round(($data.'space-in-use')/1048576)};Label="Phys Capacity Used (GB)";width=24;alignment="Center"},
    @{Expression={[decimal]::round(($data.'logical-space-in-use')/1048576)};Label="Log Capacity Used (GB)";width=23;alignment="Center"},
    @{Expression={$data.'num-of-vols'};Label="# of Volumes";width=12;alignment="Center"},
    @{Expression={$data.iops};Label="IOPS";width=10}

    return $data | Format-Table $format
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }          

}

#Returns list of recent system events
Function Get-XtremEvents([string]$xioname,[string]$username,[string]$password){

}


######### VOLUME AND SNAPSHOT COMMANDS #########

#Returns List of Volumes
Function Get-XtremVolumes([string]$xioname,[string]$username,[string]$password){
  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
  
  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password
    $uri = "https://$xioname/api/json/types/volumes"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get)

    return $data.volumes | Select-Object @{Name="Volume Name";Expression={$_.name}} 
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

#Returns Statistics for a Specific Volume or Snapshot
Function Get-XtremVolumeInfo([string]$xioname,[string]$username,[string]$password,[string]$volname){
   
   if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
   
    
  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/volumes/?name=$volname"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).content
    $hosts = @()
    
    $i = 0
    while($i -lt $data.'lun-mapping-list'.Count)
    {
      $hosts = $hosts + $data.'lun-mapping-list'[$i][0][1]
      $i++
    }
    
        $format =`
    @{Expression={$data.name};Label="Volume Name";width=15;alignment="Center"},
    @{Expression={[decimal]::round(($data.'vol-size')/1048576)};Label="Size (GB)";width=10;alignment="Center"}, `
    @{Expression={[decimal]::round(($data.'logical-space-in-use'))/1048576};Label="Logical Capacity Used (GB)";width=24;alignment="Center"},
    @{Expression={$data.index};Label="Volume ID";width=10;alignment="Center"},
    @{Expression={$data.iops};Label="IOPS";width=7;alignment="Center"},
    @{Expression={$data.'ancestor-vol-id' |Select-Object -Index 1 };Label="Parent Volume";width=15;alignment="Center"},
    @{Expression={$data.'creation-time'};Label="Time Created";width=20;alignment="Center"},
    @{Expression={$hosts};Label="Attached Hosts";width=100}
   
    return $data | Format-Table $format
  
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }  
    
}

#Creates a Volume. If no folder specified, defaults to root. 
Function New-XtremVolume([string]$xioname,[string]$username,[string]$password,[string]$volname,[string]$volsize,[string]$folder){
 
 if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

  if(!$folder){
 $folder = "/"
 }
 
 $result=
  try{
   $header = Get-XtremAuthHeader -username $username -password $password 
   $body = @"
   {
      "vol-name":"$volname",
      "vol-size":"$volsize",
      "parent-folder-id":"$folder"
   }
"@
   $uri = "https://$xioname/api/json/types/volumes/"
   $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
   Write-Host ""
   Write-Host -ForegroundColor Green "Successfully create volume ""$volname"" with $volsize of capacity"
   return $true 
   
  }
  catch{
   Get-XtremErrorMsg($result)
   return $false
  }

}

#Modify a Volume 
Function Edit-XtremVolume([string]$xioname,[string]$username,[string]$password,[string]$volname,[string]$volsize){
  
  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
  
  $result=
  try{
   $header = Get-XtremAuthHeader -username $username -password $password 
   $body = @"
   {
      "vol-name":"$volname",
      "vol-size":"$volsize"
   }
"@
   $uri = "https://$xioname/api/json/types/volumes/?name=$volname"
   $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Put -Body $body
   Write-Host ""
   Write-Host -ForegroundColor Green "Successfully modified volume ""$volname"" to have $volsize of capacity" 
   return $true
  }
  catch{
   Get-XtremErrorMsg($result)
   return $false
  }


}

#Deletes a Volume
Function Remove-XtremVolume([string]$xioname,[string]$username,[string]$password,[string]$volname){
 
 if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
 
 $result = try{
  $header = Get-XtremAuthHeader -username $username -password $password
  $uri = "https://$xioname/api/json/types/volumes/?name="+$volname
  $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Delete
  Write-Host ""
  Write-Host -ForegroundColor Green  "Volume ""$volname"" was successfully deleted"
  return $true
  }
  catch{
   Get-XtremErrorMsg -errordata  $result 
   return $false   
  }
 
}

#Returns List of Snapshots
Function Get-XtremSnapshots([string]$xioname,[string]$username,[string]$password){
 
 if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }


 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/snapshots/"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get)
    
    return $data.snapshots | Select-Object @{Name="Snapshot Name";Expression={$_.name}} 
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

#Creates a Snapshot of a Volume
Function New-XtremSnapshot([string]$xioname,[string]$username,[string]$password,[string]$volname,[string]$snapname,[string]$folder){

if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

if(!$folder){
 $folder = "/"
}

$result =
 try{
 $header = Get-XtremAuthHeader -username $username -password $password
 $body = @"
  {
    "ancestor-vol-id":"$volname",
    "snap-vol-name":"$snapname",
    "folder-id":"$folder"
  }
"@
  $uri = "https://$xioname/api/json/types/snapshots/"
  $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
  Write-Host ""
  Write-Host -ForegroundColor Green "Snapshot of volume ""$volname"" with name ""$snapname"" successfully created"
  return $true
  }
  catch{
    Get-XtremErrorMsg -errordata $result
    return $false
  }
}

#Create Snapshots from a Folder <NEED TO TEST>
Function New-XtremSnapFolder([string]$xioname,[string]$username,[string]$password,[string]$foldertosnap,[string]$snapfoldername,[string]$snapsuffix){

  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

if(!$snapfoldername){
 $snapfoldername = "/"
}

$result =
 try{
 $header = Get-XtremAuthHeader -username $username -password $password
 $body = @"
  {
    "source-folder--id":"$foldertosnap",
    "suffix":"$snapsuffix",
    "source-folder-id":"$folder"
  }
"@
  $uri = "https://$xioname/api/json/types/snapshots/"
  $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
  Write-Host ""
  Write-Host -ForegroundColor Green "Snapshots of volumes within folder ""$foldertosnap"" have been created"
  return $true
  }
  catch{
    Get-XtremErrorMsg -errordata $result
    return $false
  }


}

#Create Snapshots of a set of Volumes (This will need to be modified for 3.0+ release)
Function New-XtremSnapSet([string]$xioname,[string]$username,[string]$password,[string]$vollist,[string]$snaplist){

    

}


#Deletes an XtremIO Snapshot (can probably get rid of this, Remove-XtremVolume also works on snaps)
Function Remove-XtremSnapShot([string]$xioname,[string]$username,[string]$password,[string]$snapname){
 
 if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
 
 $result = try{
      $header = Get-XtremAuthHeader -username $username -password $password
      $uri = "https://$xioname/api/json/types/snapshots/?name=$snapname"
      $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Delete
      Write-Host ""
      Write-Host -ForegroundColor Green "Successfully deleted snapshot ""$snapname"""
      Write-Host ""
      return $true
     }
     catch{
      Get-XtremErrorMsg -errordata $result
      return $false
     }
}

######### VOLUME FOLDER COMMANDS #########

#Returns list of XtremIO Initiator Group Folders
Function Get-XtremVolumeFolders([string]$xioname,[string]$username,[string]$password){

  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }


 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/volume-folders/"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).folders
    
    return $data | Select-Object @{Name="Folder Name";Expression={$_.name}} 
    
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }
}

#Returns details of an XtremIO Volume Folder. Defaults to root if foldername not entered 
Function Get-XtremVolumeFolderInfo([string]$xioname,[string]$username,[string]$password,[string]$foldername){
    
    if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

  if(!$foldername){
 $foldername = "/"
}


 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/volume-folders/?name=$foldername"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).content

    $vollist = @()
   

     for($i = 0; $i -lt $data.'direct-list'.Count ;$i++)
     {
       $vollist = $vollist + $data.'direct-list'[$i][1]
       
     }
     
     
     $format =
    @{Expression={$data.'folder-id'[1]};Label="Folder Name";width=15;alignment="Center"},
    @{Expression={$data.'parent-folder-id'[1]};Label="Parent Folder";width=15;alignment="Center"},
    @{Expression={$vollist};Label="Volumes";width=150}
     
    
    return $data |Format-Table $format
    
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }
}

#Create a new Volume Folder. If no parent folder is specified, defaults to root.
Function New-XtremVolumeFolder([string]$xioname,[string]$username,[string]$password,[string]$foldername,[string]$parentfolderpath){

   if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

  
  if(!$parentfolderpath)
  {
   $parentfolderpath = "/"
  }


$result =
 try{
 $header = Get-XtremAuthHeader -username $username -password $password
 $body = @"
  {
    "parent-folder-id":"$parentfolder",
    "caption":"$foldername"
  }
"@
  $uri = "https://$xioname/api/json/types/ig-folders/"
  $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
  Write-Host ""
  Write-Host -ForegroundColor Green "Initiator Group folder ""$foldername"" successfully created"
  return $true
  }
  catch{
    Get-XtremErrorMsg -errordata $result
    return $false
 }
}

#Rename a Volume Folder
Function Edit-XtremVolumeFolder([string]$xioname,[string]$username,[string]$password,[string]$foldername,[string]$newfoldername){

}

#Delete a Volume Folder
Function Remove-XtremVolumeFolder([string]$xioname,[string]$username,[string]$password,[string]$foldername){

}




######### INITIATOR GROUP FOLDER COMMANDS#########

#Returns list of XtremIO Initiator Group Folders
Function Get-XtremIGFolders([string]$xioname,[string]$username,[string]$password){

  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }


 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/ig-folders/"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).folders
    
    return $data | Select-Object @{Name="Folder Name";Expression={$_.name}} 
    
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }
}

#Returns details of an XtremIO Volume Folder. Defaults to root if foldername not entered 
Function Get-XtremIGFolderInfo([string]$xioname,[string]$username,[string]$password,[string]$foldername){
    
    if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }


 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/ig-folders/?name=/$foldername"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).content

     $iglist = @()

     for($i = 0; $i -lt $data.'direct-list'.count;$i++)
     {
       $iglist = $iglist + $data.'direct-list'[$i][1]
       
     }
     
     $format =
    @{Expression={$data.'folder-id'[1]};Label="Folder Name";width=15;alignment="Center"},
    @{Expression={$data.'parent-folder-id'[1]};Label="Parent Folder";width=15;alignment="Center"},
    @{Expression={$iglist};Label="Initiator Groups";width=150}
     
    
    return $data |Format-Table $format
    
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }
}

#Create a new IG Folder. If no parent folder is specified, defaults to root.
Function New-XtremIGFolder([string]$xioname,[string]$username,[string]$password,[string]$foldername,[string]$parentfolderpath){

   if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

  
  if(!$parentfolder)
  {
   $parentfolder = "/"
  }


$result =
 try{
 $header = Get-XtremAuthHeader -username $username -password $password
 $body = @"
  {
    "parent-folder-id":"$parentfolder",
    "caption":"$foldername"
  }
"@
  $uri = "https://$xioname/api/json/types/ig-folders/"
  $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
  Write-Host ""
  Write-Host -ForegroundColor Green "Initiator Group folder ""$foldername"" successfully created"
  return $true
  }
  catch{
    Get-XtremErrorMsg -errordata $result
    return $false
 }
}

#Rename an IG Folder
Function Edit-XtremIGFolder([string]$xioname,[string]$username,[string]$password,[string]$foldername,[string]$newfoldername){

}

#Delete an IG Folder
Function Remove-XtremIGFolder([string]$xioname,[string]$username,[string]$password,[string]$foldername){

}

######### INITIATOR COMMANDS #########

#Returns List of Initiators
Function Get-XtremClusterInitiators([string]$xioname,[string]$username,[string]$password){
   
   if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }


   $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiators/"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).initiators
    


    return $data | Select-Object @{Name="Initiator Name";Expression={$_.name}} 
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }
}

#Returns info for a specific XtremIO Initiator
Function Get-XtremInitiatorInfo([string]$xioname,[string]$username,[string]$password,[string]$initiatorname){
 
 if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
 
 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiators/?name=$initiatorname"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).content
    
    $format =`
    @{Expression={$data.name};Label="Initiator Name";width=15;alignment="Center"},
    @{Expression={$data.'port-address'};Label="Address";width=24;alignment="Center"}, `
    @{Expression={$data.'ig-id'[1]};Label="Initiator Group";width=24;alignment="Center"},
    @{Expression={$data.index};Label="Index";width=10;alignment="Center"}


    return $data |Format-Table $format
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }
}

#Creates initiator and adds to initiator group
Function New-XtremInitiator([string]$xioname,[string]$username,[string]$password,[string]$initiatorname,[string]$address,[string]$igname){
  
  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiators/"
    $body = @"
   {
      "initiator-name":"$initiatorname",
      "port-address":"$address",
      "ig-id":"$igname"
   }
"@

   $request = (Invoke-RestMethod -Uri $uri -Headers $header -Method POST -Body $body)
   Write-Host ""
   Write-Host -ForegroundColor Green "Successfully created initiator ""$initiatorname"" with address ""$address"" in initiator group ""$igname"""
   Write-Host ""
   return $true
   }
   catch{
    Get-XtremErrorMsg -errordata $result
    return $false
   }
}

#Modifies initiator <NEED TO TEST> <THIS IS NOT COMPLETE>
Function Edit-XtremInitiator([string]$xioname,[string]$username,[string]$password,[string]$initiatorname,[string]$newinitiatorname,[string]$newportaddress){

  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiators/?name=$initiatorname"
    $body = @"
   {
      "ig-id":"$newinitiatorname"
   }
"@

   $request = (Invoke-RestMethod -Uri $uri -Headers $header -Method POST -Body $body)
   Write-Host ""
   Write-Host -ForegroundColor Green "Successfully created initiator ""$initiatorname"" with address ""$address"" in initiator group ""$igname"""
   Write-Host ""
   return $true
   }
   catch{
    Get-XtremErrorMsg -errordata $result
    return $false
   } 

}

#Deletes initiator <NEED TO TEST>
Function Remove-XtremInitiator([string]$xioname,[string]$username,[string]$password,[string]$initiatorname){

    if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
 
 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiators/?name=$initiatorname"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Delete)
    return $true
   }
   catch{
    Get-XtremErrorMsg -errordata $result
    return $false
   }

}

######### INITIATOR GROUP COMMANDS #########

#Returns list of XtremIO Initiator Groups
Function Get-XtremInitiatorGroups([string]$xioname,[string]$username,[string]$password){
   
   if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
   
    
  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiator-groups"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get)

    return $data.'initiator-groups' | Select-Object @{Name="Initiator Group/Hostname";Expression={$_.name}} 
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

#Returns info for a specific XtremIO initiator group
Function Get-XtremInitiatorGroupInfo([string]$xioname,[string]$username,[string]$password,[string]$igname){

     if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
   
    
  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiator-groups/?name=$igname"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).content

    $format =`
    @{Expression={$data.name};Label="Initiator Group Name";width=25;alignment="Center"},
    @{Expression={$data.'num-of-initiators'};Label="# of Initiators";width=15;alignment="Center"}, `
    @{Expression={$data.'num-of-vols'};Label="# of Volumes";width=12;alignment="Center"},
    @{Expression={$data.iops};Label="IOPS";width=8;alignment="Center"}

    return $data |Format-Table $format
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

#Creates initiator group <THIS IS NOT COMPLETE>
Function New-XtremInitiatorGroup([string]$xioname,[string]$username,[string]$password,[string]$igname,[array]$initiatorlist,[string]$foldername){

    if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

  if(!$foldername){
    
    $foldername = "/"

  }

  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiator-groups/"
    $body = @"
   {
      "initiator-list":"$initiatorlist",
      "parent-folder-id":"$foldername",
      "ig-id":"$igname"
   }
"@

   $request = (Invoke-RestMethod -Uri $uri -Headers $header -Method POST -Body $body)
   Write-Host ""
   Write-Host -ForegroundColor Green "Successfully created initiator group ""$igname"""
   Write-Host ""
   return $true
   }
   catch{
    Get-XtremErrorMsg -errordata $result
    return $false
   }

}

#Modifies initiator group
Function Edit-XtremInitiatorGroup([string]$xioname,[string]$username,[string]$password,[string]$igname){

}

#Deletes initiator group <NEED TO TEST THIS>
Function Remove-XtremInitiatorGroup([string]$xioname,[string]$username,[string]$password,[string]$igname){

     if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
   
    
  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/initiator-groups/?name=$igname"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Delete)
    
    Write-Host ""
    Write-Host -ForegroundColor Green "Successfully deleted initiator group ""$igname"""
    return $true
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

######### TARGET INFO COMMANDS #########




######### VOLUME MAPPING COMMANDS #########

#Returns list of volume mapping names
Function Get-XtremVolumeMappingList([string]$xioname,[string]$username,[string]$password){

   if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
   
    
  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/lun-maps"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get)

    return $data.'lun-maps' | Select-Object @{Name="Lun Map Name";Expression={$_.name}} 
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

#Returns Volumes mapped by Initiator group/hostname
Function Get-XtremVolumeMappingInfo([string]$xioname,[string]$username,[string]$password,[string]$igname){
  
   if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

   $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $mapuri = "https://$xioname/api/json/types/lun-maps"
    $data = (Invoke-RestMethod -Uri $mapuri -Headers $header -Method Get)
    $maplist = $data.'lun-maps'.name
    $maparray =@()
    Write-Host ""
    Write-Host "Retrieving volume list for host ""$igname"". This request may take a while on arrays with a lot of volumes..."
    Write-Host ""
    $maplist | ForEach-Object -Process {
    $tempdata = (Invoke-RestMethod -Uri "https://$xioname/api/json/types/lun-maps/?name=$_" -Headers $header -Method Get).content

      if($tempdata.'ig-name' -eq $igname){
        $mapobject = New-Object System.Object
        $mapobject | Add-Member -type NoteProperty -name 'Map ID' -Value $tempdata.'mapping-index'
        $mapobject | Add-Member -type NoteProperty -name 'Volume Name' -Value $tempdata.'vol-name'
        $mapobject | Add-Member -type NoteProperty -name 'Host (IG)' -Value $tempdata.'ig-name'
        $maparray += $mapobject

       }
    }
   return $maparray |Format-Table -AutoSize

    }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

#Returns Map ID for a given volume and host/ig name combination. Helpful for removing a mapping.
Function Get-XtremVolumeMapID([string]$xioname,[string]$username,[string]$password,[string]$igname,[string]$volname){

   if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }

   $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $mapuri = "https://$xioname/api/json/types/lun-maps"
    $data = (Invoke-RestMethod -Uri $mapuri -Headers $header -Method Get)
    $maplist = $data.'lun-maps'.name
    $mapid = $null
    Write-Host ""
    Write-Host "Retrieving volume mapping for volume ""$volname"" and host ""$igname"". This request may take a while on arrays with a lot of volumes..."
    Write-Host ""
    $maplist | ForEach-Object -Process {
    $tempdata = (Invoke-RestMethod -Uri "https://$xioname/api/json/types/lun-maps/?name=$_" -Headers $header -Method Get).content

      if($tempdata.'ig-name' -eq $igname -and $tempdata.'vol-name' -eq $volname){
        
        $mapid = $tempdata.'mapping-index'
      
       }
    }
   return $mapid

    }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

#Maps volume to initiator group
Function New-XtremVolumeMapping([string]$xioname,[string]$username,[string]$password,[string]$volname,[string]$igname){
  
  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }


  $result=try{
    $header = Get-XtremAuthHeader -username $username -password $password
    $body = @"
    {
    "vol-id":"$volname",
    "ig-id":"$igname"
    }
"@
    $uri = "https://$xioname/api/json/types/lun-maps/"
    $request = Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
    Write-Host ""
    Write-Host -ForegroundColor Green "Volume ""$volname"" successfully mapped to initiator group ""$igname"""
    return $true
   }
   catch{
    Get-XtremErrorMsg($result)
    return $false
   }  

}

#Removes volume mapping
Function Remove-XtremVolumeMapping([string]$xioname,[string]$username,[string]$password,[string]$igname,[string]$volname){

  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
   
    
  $result=
  try{
    $mapname = (Get-XtremVolumeMapID -xioname $xioname -username $username -password $password -igname $igname -volname $volname) 
    $header = Get-XtremAuthHeader -username $username -password $password 
    $uri = "https://$xioname/api/json/types/lun-maps/$mapname"
    $request = (Invoke-RestMethod -Uri $uri -Headers $header -Method DELETE)

    Write-Host ""
    Write-Host -ForegroundColor Green "Successfully deleted mapping of volume ""$volname"" from host/ig ""$igname"""
    return $true
   }
   catch{
    Get-XtremErrorMsg -errordata $result
    return $false
   }

}


######### REQUEST HELPERS #########


#Generates Header to be used in requests to XtremIO
Function Get-XtremAuthHeader([string]$username,[string]$password){
 
  $basicAuth = ("{0}:{1}" -f $username,$password)
  $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
  $basicAuth = [System.Convert]::ToBase64String($basicAuth)
  $headers = @{Authorization=("Basic {0}" -f $basicAuth)}

  return $headers
 
}

#Returns XtremIO Cluster Name
Function Get-XtremClusterName ([string]$xioname,[object]$header){

  if($global:XtremUsername){
  $username = $global:XtremUsername
  $xioname = $global:XtremName
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:XtremPassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  }
  
  $clustername = (Invoke-RestMethod -Uri https://$xioname/api/json/types/clusters -Headers $header -Method Get).clusters.name
  return $clustername 
 
}




######### ETC #########

Function Get-XtremErrorMsg([AllowNull()][object]$errordata){   
    $ed = $errordata
    
  try{ 
    $ed = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($ed)
    $responseBody = $reader.ReadToEnd(); 
    $errorcontent = $responseBody | ConvertFrom-Json
    $errormsg = $errorcontent.message
    Write-Host ""
    Write-Host -ForegroundColor Red "Error: $errormsg"
    
    }
   catch{
    Write-Host ""
    Write-Host -ForegroundColor Red "Error: XtremIO name not resolveable"
    
   } 
  
}

#Defines global username, password, and hostname/ip for PS session 
function New-XtremSession([string]$xioname,[string]$username,[string]$password) {

    if($xioname){
    $global:XtremName = $xioname
    $global:XtremUsername = $username
    $securepassword = ConvertTo-SecureString $password -AsPlainText -Force
    $global:XtremPassword =$securepassword

    }
    else{
    $global:XtremName = Read-Host -Prompt "Enter XtremIO XMS Hostname or IP Address"
    $global:XtremUsername = Read-Host -Prompt "Enter XtremIO username"
    $global:XtremPassword = Read-Host -Prompt "Enter password" -AsSecureString
    }    
}


#Edits the Global XtremeName (IP/Hostname) variable
function Edit-XtremName([string] $xioname)
{
  if($xioname)
  {
   $global:XtremName = $xioname
   return

  }
  else{
   
   $global:XtremName = Read-Host -Prompt "Enter New XtremIO XMS Hostname or IP Address"

  }

}

#Edits the Global XtremeUserName variable
function Edit-XtremName([string] $username)
{
  if($username)
  {
   $global:XtremUsername = $username
   return

  }
  else{
   
   $global:XtremUsername = Read-Host -Prompt "Enter New XtremIO Username"

  }

}

#Edits the Global password variable
function Edit-XtremPassword()
{
 
   $global:XtremPassword = Read-Host -Prompt "Enter New XtremIO Password" -AsSecureString

  

}
#Clears all globally set parameters
function Remove-XtremSession(){

  $global:XtremUsername =$null
  $global:XtremPassword =$null
  $global:XtremName =$null


}




