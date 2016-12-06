#Discover Volumes AVA
#This ava attempting discover available LUNS in destination instance to restore.

$Log | Log "INSIDE AVA: DISCOVER VOLUMES" "VERBOSE"
$Log | Log "Getting volumes available in remote server $($DestinatonInfo.ComputerName)" -RaiseIdent

$vols = @();
$AvailableVolumes = Get-WMiObject Win32_Volume -ComputerName $DestinatonInfo.ComputerName;

$AvailableVolumes | where {$_.DriveType -eq 3 -and !$_.SystemVolume -and !$_.BootVolume} | %{
	$vol = NewVolumeObject;
	$vol.name = $_.name;
	$vol.freeSpace=$_.freeSpace;
	$vol.realFreeSpace=$_.freeSpace;
	$vol.volType = "LUN"
	$vols += $vol;
	
	$Log | Log "VOLUME FOUND: $($vol.name)"
	if($VolumesForData){
		$Log | Log "Checking if this volume can hold data files..." -RaiseIdent -ApplyThis -KeepFlow
		$TmpVolumesAllowed = $VolumesForData | where {$vol.name -like $_}
		if($TmpVolumesAllowed){
			$Log | Log "YES!" -RaiseIdent -ApplyThis -KeepFlow
			$vol.filesAllowed += "D"
		}
	}
	
	if($VolumesForLog){
		$Log | Log "Checking if this volume can hold log files..." -RaiseIdent -ApplyThis -KeepFlow
		$TmpVolumesAllowed = $VolumesForLog | where {$vol.name -like $_};
		if($TmpVolumesAllowed){
			$Log | Log "YES!" -RaiseIdent -ApplyThis -KeepFlow
			$vol.filesAllowed += "L"
		}
	}
}

return $vols;