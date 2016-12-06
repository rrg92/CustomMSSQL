#No Realocate Files ava
#This AVA dont generate any mapping.
#Its just generate a dummy volume object in order to break loop.

$Log | Log "INSIDE AVA: No Realocate Files" "VERBOSE"

if($VALUES.PARAMS.NoRelocFiles){
	$Log | Log "NoRelocFiles is present!" "VERBOSE" -RaiseIdent
	
	$VALUES.DFA_TOEXEC = "NORELOCFILES";
	
	#Create a dummy volume just for represent this and passed next validations...
	$vol 			= NewVolumeObject;
	$vol.name 		= "DUMMY"
	$vol.freeSpace	= 0;
	$vol.volType 	= "DUMMY";
			
	
	return $vol;
}

