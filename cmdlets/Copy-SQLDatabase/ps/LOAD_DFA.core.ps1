#This script load all DFA scripts.
#DFA are distribution file algorihtms.
#The DFA scripts control how cmdlet will map files in source backup to volumes in destination instance.

$algFilter = (PutFolderSlash $VALUES.DFA_FOLDER)+"*."+($VALUES.DFA_EXTENSION)
$Log | Log "FILES: $algFilter" "VERBOSE"
gci $algFilter | %{
	$Log | Log "Loading file distributor algorigthm  $($_.FullName) " "VERBOSE"
	$AlgName = $_.Name.replace("."+$VALUES.DFA_EXTENSION,"")
	$Log | Log "ALGORITHM IS: $AlgName" "VERBOSE" -RaiseIdent -ApplyThis -KeepFlow
	$VALUES.DFA.add($AlgName,$_.FullName);
}
#Set defaults DFA...
$VALUES.DFA_TOEXEC = "BIGGERS_FIRST";

$DfaCount = $VALUES.DFA.Count;

if(!$DfaCount){
	throw "NO_DFA"
}

$Log | Log "DFA Scripts: $DfaCount" "VERBOSE"