#SQL VOLUMES ava 
#This AVA discover volumes using T-SQL at destination.

if($VALUES.PARAMS.GetVolumesInSQL.IsPresent){
	$Log | Log "Getting volumes using SQL DMVs... On destination instance" -RaiseIdent
	
	try {
		$GetVolumesCommand = . $VALUES.SCRIPT_STORE.SQL.GET_VOLUMES $VALUES
		$results = . $SQLInterface.cmdexec -On DESTINATION -d "master" -Q $GetVolumesCommand -AppNamePartID "SQL_VOLUMES_AVA"
		$vols = @();
		$results | %{
			$vol = NewVolumeObject;
			$vol.name = $_.volume_mount_point;
			$vol.freeSpace=$_.available_bytes;
			$vol.realFreeSpace=$_.available_bytes;
			$vol.volType = "LUN"
			$vols += $vol;
		}
	} catch {
		$Log | Log $_
		$Log | Log "ERROR!. Traditional method will be used."
		$vols = $null;
	}

	return $vols;
}

