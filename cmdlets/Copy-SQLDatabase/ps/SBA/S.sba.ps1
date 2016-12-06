<#
	This is SQL Source Backup Algorithm (SBA)
	This script is responsible for generating a backup directly from a SQL Server instance.
	ITs returns the backup file.
#>

@{
	NAME = "SQL SERVER SOURCE"
	SCRIPT = {
		param($VALUES)
		
			#Creates the object that represent SBA.
			$SBA = (NewSourceBackup);
			
			#If in suggest mode, return immeditally.
			if($VALUES.PARAMS.SuggestOnly){
				$SBA.determined=$true
				return $SBA;
			}
			
			$SourceServerInstance = $VALUES.PARAMS.SourceServerInstance;
			$SourceDatabase = $VALUES.PARAMS.SourceDatabase;
			$SourceReadOnly = $VALUES.PARAMS.SourceReadOnly;
			$SourceLogonInfo = $VALUES.SOURCE_SQL_LOGON
			
		
			$Log | Log "Generating a new database backup of $SourceDatabase in $SourceServerInstance"
			
			if($SourceReadOnly){
				$Log | Log "Source Database will be put in READ_ONLY before backup." -RaiseIdent -ApplyThis
				$ReadOnlyCommand =  . $VALUES.SCRIPT_STORE.SQL.PUT_DATABASE_READONLY $VALUES
				$Log | Log "ReadOnly command: $ReadOnlyCommand"
				$results = & $VALUES.SQLINTERFACE.cmdexec -On SOURCE -d master -Q $ReadOnlyCommand -NoExecuteOnSuggest -AppNamePartID "SBA_S_READONLY"
				$Log.dropIdent();
			}
				
			
			$BackupCommand =  . $VALUES.SCRIPT_STORE.SQL.BACKUP_DATABASE $VALUES
				
			$Log | Log "Backup command: $BackupCommand"
			
			$results = & $VALUES.SQLINTERFACE.cmdexec -On SOURCE -d master -Q $BackupCommand -NoExecuteOnSuggest -AppNamePartID "SBA_S_BACKUP"
			
			
			if($results){
				$SBA.fullPath = $results.backupfile;
				$SBA.determined=$true;
			}

			return $SBA;
	}
}

