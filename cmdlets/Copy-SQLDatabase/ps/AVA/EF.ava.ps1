#Existent Files AVA
#This AVA check current database files on destination.
#If it exists, then it will use it as volumes.

$Log | Log "INSIDE AVA: Existent Files" "VERBOSE"

#Try existen files;
if(!$VALUES.PARAMS.NoUseCurrentFilesFolder){
	$Log | Log "Attempting use current database files on destination as volume to new files" -RaiseIdent
	
	try {
	
		if(!$VALUES.DESTINATION_INFO.DatabaseExists){
			throw "DESTINATION_DB_DONTEXISTS"
		}
	
		$CurrentFilesCommand = & $VALUES.SCRIPT_STORE.SQL.GET_CURRENT_FILES $VALUES
		$DestinationFiles = & $SQLInterface.cmdexec -On DESTINATION -Q $CurrentFilesCommand -AppNamePartID "EXISTENT_FILES_AVA"
		
		$vols = @();
		
		if($DestinationFiles){
			$DestinationFiles | %{
				$vol = NewVolumeObject;
				$vol.name = $_.physicalName;
				$vol.sqlLogicalName = $_.logicalName;
				$vol.volType="SQLFILE"
				
				$vols += $vol;
			}
		} else {
			throw "NO_DESTINATION_FILES"
		}
		
		#Empty the restore folder... This prevent a folder passed by user must be appended...
		$VALUES.PARAMS.RestoreFolder = $null;
		$VALUES.DFA_TOEXEC = "REPLACE_EXISTENT";
		$Log | Log "FILES COLLECTED SUCESSFULY!" -DropIdent
		return $vols;
	} catch {
		$Log | Log "$_"
		$Log | Log "Replace Policy is: $CurrentFilesFolderPolicy"
		
		if($CurrentFilesFolderPolicy -eq "MustReplace"){
			throw;
		}
		
		$VALUES.PARAMS.NoUseCurrentFilesFolder = $true;
	}
}