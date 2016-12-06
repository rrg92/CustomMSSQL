param([switch]$PutGO = $false)


$BackedupPermissionsList 	= $VALUES.DESTINATION_INFO.PERMISSIONS.PERMISSIONS
$i							= $BackedupPermissionsList.count;

$GO = "`r`nGO`r`n"

$Log | Log "Building T-SQL..."

$DCL = "";

while($i--){
	$CurrentPermission = $BackedupPermissionsList[$i];
	
	if(!$CurrentPermission.SecurableClass){
		throw "INVALID_SECURABLE_CLASS";
	}
	
	if(!$CurrentPermission.SecurableName){
		throw "INVALID_SECURABLE_NAME";
	}

	if($CurrentPermission.SecurableClass -eq "DATABASE"){
		$FullSecurableDCL = ""
	} else {
		$FullSecurableDCL = "ON $($CurrentPermission.SecurableClass)::$($CurrentPermission.SecurableName)";

		if($CurrentPermission.SecurableMinorName){
			$FullSecurableDCL += "($($CurrentPermission.SecurableMinorName))";
		}
	}
	
	$DCL += "$($CurrentPermission.PermissionState) $($CurrentPermission.permission_name) $FullSecurableDCL TO [$($CurrentPermission.principalName)];`r`n";
	
	if($PutGO){
		$DCL += $GO;
	}
}

$Log | Log "T-SQL Length: $($DCL.Length)";

return $DCL;