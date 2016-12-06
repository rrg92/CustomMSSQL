#This script load all cores scripts.
#Core scripts are scripts that implement some core functionality of cmdlet.
#They are useful to organize scripts.

$CoreFolder = (PutFolderSlash $VALUES.CORESCRIPTS_FOLDER)+"*.core.ps1"

gci $CoreFolder | %{
	$Log | Log "Loading core script $($_.FullName) " "VERBOSE"
	$CoreScriptName = $_.Name.replace(".core.ps1","")
	$Log | Log "CORE SCRIPT IS: $CoreScriptName" "VERBOSE" -RaiseIdent -ApplyThis -KeepFlow
	$VALUES.SCRIPT_STORE.CORE.add($CoreScriptName,$_.FullName);
}

$Log | Log "Cores Scripts: $($VALUES.SCRIPT_STORE.CORE.Count)" "VERBOSE"