param($VALUES)

$Log | Log "Restoring permissions"

$PermissionsList 	= $VALUES.DESTINATION_INFO.PERMISSIONS


if(!$PermissionsList){
	$Log | Log "No backed up permissions found. Skipping."
	return;
}


try {

	$Log | Log "Creating principals"
	
	try {
		$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_PRINCIPAL_DCL;
		if($tsql){
			& $SQLInterface.cmdexec -On DESTINATION -Q $tsql -NoExecuteOnSuggest -AppNamePartID "RST_PRINCIPALS"
			$Log | Log "SUCCESS!"
		} else {
			$Log | Log "NO COMMAND!"
		}

	} catch {
		$Log | Log "Error when creating principal: $_";
	}
	
	
	$Log | Log "Creating role memberships"
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_ROLEMEMBERSHIP_DCL
			if($tsql){
				& $VALUES.SQLInterface.cmdexec -On DESTINATION -Q $tsql -NoExecuteOnSuggest -AppNamePartID "RST_ROLES"
				$Log | Log "SUCCESS!"
			} else {
				$Log | Log "NO COMMAND!"
			}
		} catch {
			$Log | Log "Error when adding role membership: $_";
		}
	
	$Log | Log "Creating permissions"
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_PERMISSIONS_DCL
			if($tsql){
				& $VALUES.SQLInterface.cmdexec -On DESTINATION -Q $tsql -NoExecuteOnSuggest -AppNamePartID "RST_PERMS"
				$Log | Log "SUCCESS!"
			} else {
				$Log | Log "NO COMMAND!"
			}
		} catch {
			$Log | Log "Error when assigning permission: $_";
		}
	
	if($PermissionsList.DBO){
	
	$Log | Log "Changing the owner"
	
		$OwnerPrincipal = $PermissionsList.DBO.Owner;
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_OWNER_DCL $OwnerPrincipal;
			$Log | Log "Changing the database owner to $OwnerPrincipal"
			& $SQLInterface.cmdexec -On DESTINATION -Q $tsql -NoExecuteOnSuggest -AppNamePartID "RST_OWNER"
			$Log | Log "SUCCESS!"
		} catch {
			$Log | Log "Error when changing the owner: $_";
		}
	}
} catch {
	$Log | Log $_
	$Log | Log	"Error when restoring permissions. Check previous errors."
}