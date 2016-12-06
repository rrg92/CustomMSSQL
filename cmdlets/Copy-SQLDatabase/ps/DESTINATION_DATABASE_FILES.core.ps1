param($VALUES)

$Log | Log "Getting destination database files!"

#File command!
$GetFilesCommand = . $VALUES.SCRIPT_STORE.SQL.GET_DATABASE_FILES

try {
	$VALUES.DESTINATION_INFO.DestinationFiles = . $SQLInterface.cmdexec -On DESTINATION -Q $GetFilesCommand -AppNamePartId "DESTINATION_FILES_INFO"
} catch {
	$Log | Log "ERROR GETTING DESTINATION FILES INFO: $_";
}
