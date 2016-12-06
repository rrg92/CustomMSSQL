#Loads available volumes algorithms.
#THe available volvume algorithms are logic that determine avaiable volumes to restore files.
#The algorithm to be used will be determined by parameters and information collected when cmdlets run.


#Loads the available volume algorithm. This are files that return a hashtable. 
#The hashtable format is documented on this cmdlet documentation.
$AvaFileExtension = 'ava.ps1';
$algFilter = (PutFolderSlash $VALUES.AVA_FOLDER)+"*.$AvaFileExtension"
$Log | Log "FILES: $algFilter" "VERBOSE"
gci $algFilter | %{
	$Log | Log "Loading AVAILABLE VOLUME ALGORITHM $($_.FullName) " "VERBOSE"
	$AlgName = $_.Name.replace(".$AvaFileExtension","")
	$Log | Log "ALGORITHM IS: $AlgName" "VERBOSE" -RaiseIdent -ApplyThis -KeepFlow
	$VALUES.SCRIPT_STORE.AVA.add($AlgName,$_.FullName);
}

$AvaCount = $VALUES.SCRIPT_STORE.AVA.Count;

if(!$AvaCount){
	throw "NO_AVA"
}

$Log | Log "AVA Scripts: $AvaCount" "VERBOSE"