@{
	NAME = "EXISTENT BACKUP"
	SCRIPT = {
		param($VALUES)
		
		$ExistentBackupName = $VALUES.PARAMS.ExistentBackupName;
		$UseExistentPolicy = $VALUES.PARAMS.UseExistentPolicy;
		
		
		if(!$ExistentBackupName){
			$Log | Log "ExistentBackupName wasn't passed." "VERBOSE"
			return;
		}
		

		$Log | Log  "Using file $ExistentBackupName"

	
		try{
			$backupfile = (gi $ExistentBackupName) | %{$_.FullName}
			$SBA = (NewSourceBackup)
			$SBA.fullPath = $backupfile;
			$SBA.determined=$true;
		} catch {
			$Log | Log  "Error getting existent files: $_" -RaiseIdent
		} finally {
			if(!$backupFile){
				$Log | Log "No backups found!"
				$Log | Log "Existent Policy is: $UseExistentPolicy"	
				if($UseExistentPolicy -eq "MustUse"){
					throw "NO_EXISTENT_BACKUP_NAME_FOUND"
				}
			}
		}
			
		
		return $SBA;
	}
}

