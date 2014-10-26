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



######### GET/INFORMATIONAL COMMANDS ##########


#Returns Various XtremIO Statistics
Function Get-XtremClusterStatus ([string]$xioname,[string]$username,[string]$password)
{
 $result=
  try{
    $header = Get-XtremAuthHeader -username $username -password $password
    $formattedname = Get-XtremClusterName -xioname $xioname -header $header
    $uri = "https://$formattedname/api/json/types/clusters/?name=$formattedname"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get).content

    $format =`
    @{Expression={$data.name};Label="System Name";width=11;alignment="Center"},
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

#Returns List of Volumes
Function Get-XtremVolumes([string]$xioname,[string]$username,[string]$password){
  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password
    $formattedname = Get-XtremClusterName -xioname $xioname -header $header
    $uri = "https://$formattedname/api/json/types/volumes"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get)

    return $data.volumes | Select-Object @{Name="Volume Name";Expression={$_.name}} 
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}

#Returns Statistics for a Specific Volume or Snapshot
Function Get-XtremVolumeInfo([string]$xioname,[string]$username,[string]$password,[string]$volname){
    
  $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $formattedname = Get-XtremClusterName -xioname $xioname -header $header
    $uri = "https://$formattedname/api/json/types/volumes/?name=$volname"
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

#Returns List of Snapshots
Function Get-XtremSnapshots([string]$xioname,[string]$username,[string]$password){
 
 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $formattedname = Get-XtremClusterName -xioname $xioname -header $header
    $uri = "https://$formattedname/api/json/types/snapshots/"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get)
    
    return $data.snapshots | Select-Object @{Name="Snapshot Name";Expression={$_.name}} 
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }

}



#Returns List of Initiators
Function Get-XtremClusterInitiators([string]$xioname,[string]$username,[string]$password){
 $result=
  try{  
    $header = Get-XtremAuthHeader -username $username -password $password 
    $formattedname = Get-XtremClusterName -xioname $xioname -header $header
    $uri = "https://$formattedname/api/json/types/initiator-groups"
    $data = (Invoke-RestMethod -Uri $uri -Headers $header -Method Get)

    return $data.'initiator-groups' | Select-Object @{Name="Initiator Group/Hostname";Expression={$_.name}} 
   }
   catch{
    Get-XtremErrorMsg -errordata $result
   }
}


######### ACTION COMMANDS #########

#Creates a Volume
Function Create-XtremVolume([string]$xioname,[string]$username,[string]$password,[string]$volname,[string]$volsize){
 $result=
  try{
   $header = Get-XtremAuthHeader -username $username -password $password 
   $formattedname = Get-XtremClusterName -xioname $xioname -header $header
   $body = @"
   {
      "vol-name":"$volname",
       "vol-size":"$volsize"
   }
"@
   $uri = "https://$formattedname/api/json/types/volumes/"
   Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
   Write-Host ""
   Write-Host -ForegroundColor Green "Successfully create volume ""$volname"" with $volsize of capacity" 
  }
  catch{
   Get-XtremErrorMsg($result)
  }

}

#Deletes a Volume
Function Remove-XtremVolume([string]$xioname,[string]$username,[string]$password,[string]$volname){
 $result = try{
  $header = Get-XtremAuthHeader -username $username -password $password
  $formattedname = Get-XtremClusterName -xioname $xioname -header $header
  $uri = "https://$formattedname/api/json/types/volumes/?name="+$volname
  Invoke-RestMethod -Uri $uri -Headers $header -Method Delete
  Write-Host ""
  Write-Host -ForegroundColor Green  "Volume ""$volname"" was successfully deleted"
  }
  catch{
   Get-XtremErrorMsg -errordata  $result    
  }
 
}

#Creates a Snapshot of a Volume
Function Create-XtremSnap([string]$xioname,[string]$username,[string]$password,[string]$volname,[string]$snapname){
$result =
 try{
 $header = Get-XtremAuthHeader -username $username -password $password
 $formattedname = Get-XtremClusterName -xioname $xioname -header $header
 $body = @"
  {
    "ancestor-vol-id":"$volname",
    "snap-vol-name":"$snapname"
  }
"@
  $uri = "https://$formattedname/api/json/types/snapshots/"
  Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
  }
  catch{
    Get-XtremErrorMsg -errordata $result
  }
}



#Deletes an XtremIO Snapshot
Function Remove-XtremSnap([string]$xioname,[string]$username,[string]$password,[string]$snapname){
 $result = try{
      $header = Get-XtremAuthHeader -username $username -password $password
      $formattedname = Get-XtremClusterName -xioname $xioname -header $header
      $uri = "https://$formattedname/api/json/types/snapshots/?name=$snapname"
      Invoke-RestMethod -Uri $uri -Headers $header -Method Delete
     }
     catch{
      Get-XtremErrorMsg -errordata $result
     }
}


#Maps volume to initiator group
Function Map-XtremVolume([string]$xioname,[string]$username,[string]$password,[string]$volname,[string]$initgroup){
$result=try{
    $header = Get-XtremAuthHeader -username $username -password $password
    $formattedname = Get-XtremClusterName -xioname $xioname -header $header
    $body = @"
    {
    "vol-id":"$volname",
    "ig-id":"$initgroup"
    }
"@
    $uri = "https://$formattedname/api/json/types/lun-maps/"
    Invoke-RestMethod -Uri $uri -Headers $header -Method Post -Body $body
    Write-Host ""
    Write-Host -ForegroundColor Green "Volume ""$volname"" successfully mapped to initiator group ""$initgroup"""
   }
   catch{
    Get-XtremErrorMsg($result)
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
    Write-Host -ForegroundColor Red "Error: Xtremio name not resolveable"

   }
    
  
}

Function Get-XtremCommands(){



}

