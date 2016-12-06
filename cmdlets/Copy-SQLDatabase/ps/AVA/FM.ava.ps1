#Forced Mapping AVA
#This AVA just create volumes list based on user input.
#User will provide volumes folders in parameter VolumeToFolder

$Log | Log "INSIDE AVA: Forced Mapping AVA" "VERBOSE"

if($VALUES.PARAMS.ForceVolumeToFolder){
	Log "Using supplied folder paths as volumes..." -RaiseIdent
	
	$vols = @()
	$VALUES.PARAMS.VolumeToFolder | %{
		if(!$_.Path){
			return; #continue
		}
		
		Log "Adding the $($_.Path) to volume list" "VERBOSE";
		
		$vol = NewVolumeObject;
		$vol.name = $_.Path;
		$vol.volType="FOLDER"
		$vols += $vol;
	}
	
	$VALUES.DFA_TOEXEC = "RANDOM_LEAST_USED";
	return $vols;
}