param($VALUES)

$Log | Log "Generating a SQL command: GET_BACKUP_FIILES" "VERBOSE"

[string]$BACKUPCOMMAND = "";


#If in suggest mode -and file is present, then we must use originalPath... 
if($VALUES.PARAMS.SuggestOnly -and $VALUES.SOURCE_BACKUP.originalFullPath)
{
	$BACKUPCOMMAND = "
		RESTORE FILELISTONLY /*SUGGESTONLY_SOURCE_PATH*/
		FROM 
			DISK = '$($VALUES.SOURCE_BACKUP.originalFullPath)'
	"
}

elseif ($VALUES.PARAMS.SuggestOnly -and $VALUES.PARAMS.SourceServerInstance -and $VALUES.PARAMS.SourceDatabase) #In this case, SQL will not execute backup command and we must return a SQL to query on source instance...
{
	$BACKUPCOMMAND = "
		SELECT /*SUGGESTONLY_SOURCE_SQL_SERVER*/
			 F.file_id as FileID 
			,F.name as logicalName
			,F.physical_name AS physicalName 
			,CASE F.Type
				WHEN 0 THEN 'D'
				WHEN 1 THEN 'L'
				WHEN 2 THEN 'S'
			END as Type
			,F.size as Size
		FROM 
			sys.database_files F
	"
}
elseif($VALUES.SOURCE_BACKUP.fullPath)
{
	$BACKUPCOMMAND = "
		RESTORE FILELISTONLY /*NORMAL_MODE*/
		FROM 
			DISK = '$($VALUES.SOURCE_BACKUP.fullPath)'
	"
}
else {
	throw "INSUFFICIENT_INFORMATION_FOR_GET_BACKUP_FILES"
}




return $BACKUPCOMMAND;