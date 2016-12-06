#Manual File Mapping AVA
#This AVA generate file mapping based on user chooice.


$Log | Log "INSIDE AVA: Manual File Mapping" "VERBOSE"

if($VALUES.PARAMS.ManualFileMapping){
	$Log | Log "Manual file mapping was choosen" -RaiseIdent

	$vols = @();
	$ManualFileMapping | %{
	
		if(!$_.logicalName){
			throw "EMPTY_LOGICAL_NAME"
		}
		
		if(!$_.physicalName){
			throw "EMPTY_PHYSICAL_NAME"
		}

		$Log | Log "Manual file specified: $($_.logicalName) TO $($_.physicalName)"
			
		$vol = NewVolumeObject;
		$vol.name = $_.physicalName;
		$vol.sqlLogicalName = $_.logicalName;
		$vol.volType="SQLFILE"
		$vols += $vol;
	}
	
	$VALUES.DFA_TOEXEC = "MANUAL_MAPPING";

	return $vols;
}
