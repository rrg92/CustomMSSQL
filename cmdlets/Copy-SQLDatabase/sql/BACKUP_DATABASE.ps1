param($VALUES)

if($VALUES.PARAMS.BackupTSQL){
	$Log | Log "Was specified a T-SQL Backup command."
	return $VALUES.PARAMS.BackupTSQL;
}

$ServerInfoCommand = . $VALUES.SCRIPT_STORE.SQL.GET_INSTANCE_INFO $VALUES

$Log | Log "Getting source SQL info"
$Log | Log "Source Info Command: $ServerInfoCommand"
$SourceSQLInfo 	= . $SQLInterface.cmdexec -On SOURCE -D master -Q $ServerInfoCommand -AppName "SQL_BACKUPDATABASE_SOURCEINFO"
$SrcVersion		=  GetProductVersionNumeric $SourceSQLInfo.ProductVersion;

$Log | Log "Source Server Version is: $SrcVersion"

$TSQL_Compression = ",COMPRESSION"

if($SrcVersion -lt 10){
	$Log | Log "COMPRESSION unsupported!"
	$TSQL_Compression = ""
}

$TSQL_CopyOnly = ",COPY_ONLY"

if($SrcVersion -le 8){
	$Log | Log "COPY_ONLY unsupported!"
	$TSQL_CopyOnly = ""
}

$BackupFolder 	= (PutFolderSlash $VALUES.PARAMS.BackupFolder);
$UniqueBackupName = $VALUES.PARAMS.UniqueBackupName;

if($UniqueBackupName){
	$ts = (Get-Date).toString("yyyy-MM-dd-HHmmss");
	$BackupFileName = "$($VALUES.BACKUP_FILEPREFIX).$ts.$($VALUES.BACKUP_FILESUFFIX)"
} else {
	$BackupFileName = "$($VALUES.BACKUP_FILEPREFIX).$($VALUES.BACKUP_FILESUFFIX)"
}

$FullDestinationPath = $BackupFolder+$BackupFileName
$Log | Log "Destination backup file will be: $FullDestinationPath"

$BackupCommand = "
	BACKUP DATABASE
		[$SourceDatabase]
	TO	
		DISK = '$FullDestinationPath'
	WITH
		STATS = 10
		$TSQL_CopyOnly 
		$TSQL_Compression
		,INIT
		,FORMAT
		
	SELECT '$FullDestinationPath' as backupfile;
"

return $BackupCommand;