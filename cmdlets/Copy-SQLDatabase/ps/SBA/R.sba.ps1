return @{
	NAME = "RECENT BACKUP SOURCE"
	SCRIPT = {
		param($VALUES)
		
			$UseRecentBackup = $VALUES.PARAMS.UseRecentBackup;
			$UseExistentPolicy = $VALUES.PARAMS.UseExistentPolicy;
			$RecentFileMask = $VALUES.PARAMS.RecentFileMask;
			$RecentBase = $VALUES.PARAMS.RecentBase;
			$BackupFolder = (PutFolderSlash $VALUES.PARAMS.BackupFolder);
				
			if(!$UseRecentBackup)
			{
				$Log | Log "UseRecentBackup dont was passed." "VERBOSE"
				return;
			}
			
			if(!$RecentFileMask -and !$VALUES.BACKUP_FILEPREFIX){
				throw "NO_FILTERTOSEARCH: You must pass SourceServerInstance and SourceDatabase to use UseRecent parameter, or use RecentFileMask parameter."
			}
			
			$Log | Log "Using a recent existent backup file"	
			[datetime]$RecentBaseDatetime = 0;
				
			if($RecentBase){
				$RecentBaseDatetime = [datetime]$RecentBase;
				$Log | Log "Recently base is: $RecentBaseDatetime"
			}
			
				
			try {
				$BackupName = $VALUES.BACKUP_FILEPREFIX+"*"+$VALUES.BACKUP_FILESUFFIX 
				
				
				if($RecentFileMask){
					$BackupName = $RecentFileMask;
				}
				
				$Log | Log "Looking for $BackupName in $BackupFolder"
				$backupFile = gci ($BackupFolder+$BackupName) | where {$_.LastWriteTime -ge $RecentBaseDatetime} | sort LastWriteTime -desc | select -First 1 | %{$_.FullName}

				$SBA = (NewSourceBackup)
				$SBA.fullPath = $backupfile;
				$SBA.determined=$true;
			} catch {
				$Log | Log "Error getting most recent backup file: $_" -RaiseIdent
			} finally {
				if(!$backupFile){
					$SBA.determined=$false;
					$Log | Log "No backups found!"
					$Log | Log "Existent Policy is: $UseExistentPolicy"	
					
					if($UseExistentPolicy -eq "MustUse"){
						throw "NO_RECENT_BACKUP_FOUND"
					}
				}
			}
		
	
		return $SBA;
	}
}

