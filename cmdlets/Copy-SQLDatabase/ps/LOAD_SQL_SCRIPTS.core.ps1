#Loads SQL scripts.
#SQL scripts contains T-SQL commands to query or execute some action in some sql instance.

$sqlScriptsFilter = (PutFolderSlash $VALUES.SQL_SCRIPTS_FOLDERS)+"*"
gci $sqlScriptsFilter | %{
	$Log | Log "Getting SQL Script $($_.FullName)" "VERBOSE"
	$ScriptType = [System.IO.Path]::GetExtension($_.Name)
	$ScriptName = $_.BaseName
	
	$Log | Log "SCRIPT WILL IDENTIFIED BY ($($ScriptType)): $ScriptName" "VERBOSE"
	
	$ScriptContent = $null;
	#If a SQL Script, then assume it contains direct SQL code with
	if($ScriptType -eq ".sql"){
		$Log | Log "SCRIPTS IS A SQL FILE. CONVERTING TO A SCRIPTBLOCK..." "VERBOSE"
		$ScriptText = Get-Content $_.FullName | Out-String
		$ScriptContent = [scriptblock]::create({return $ScriptText}).GetNewClosure();
	} else {
		$ScriptContent = $_.FullName;
	}

	$VALUES.SCRIPT_STORE.SQL.add($ScriptName,$ScriptContent);
}