#Load source backup algorithms (sba)
#The SBA scripts contains all logic to generate a source backup to be restored.

#Loads the source backups algoithms. This are files that return a hashtable. The hashtable format is documented on this cmdlet documentation.
$algFilter = (PutFolderSlash $VALUES.SBA_FOLDER)+"*."+($VALUES.SBA_EXTENSION)
$Log | Log "FILES: $algFilter" "VERBOSE"
gci $algFilter | %{
	$Log | Log "Loading SOURCE BACKUP ALGORITHM $($_.FullName) " "VERBOSE"
	$AlgName = $_.Name.replace("."+$VALUES.SBA_EXTENSION,"")
	$Log | Log "ALGORITHM IS: $AlgName" "VERBOSE"
	$VALUES.SCRIPT_STORE.SBA.add($AlgName,(& $_.FullName));
}

$SbaCount = $VALUES.SCRIPT_STORE.SBA.Count;

if(!$SbaCount){
	throw "NO_SBA"
}

$Log | Log "SBA Scripts: $SbaCount" "VERBOSE"