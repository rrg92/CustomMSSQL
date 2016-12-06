param($VALUES)

$Log |  Log "Getting all permissions for apply after restore."

$ExportFile	= $VALUES.Params.ExportPermissionsFile;

Function ExportToFile {
	param($tsql)
	
	if(!$ExportFile){
		return;
	}
	
	try {
		$tsql >> $ExportFile
	} catch {
		$Log |  Log "Exporting to file failed: $_" "PROGRESS"
	}
}

$PermissionsList = @{
	PRINCIPALS=@()
	DBO=@()
	ROLES_MEMBERS=@()
	PERMISSIONS=@()
}

$VALUES.DESTINATION_INFO.ADD("PERMISSIONS",$PermissionsList);

$BackupPrincipalsCommand 	= & $VALUES.SCRIPT_STORE.SQL.GET_PRINCIPALS
$BackupDboCommand 			= & $VALUES.SCRIPT_STORE.SQL.GET_DBO
$BackupRoleMembersCommand 	= & $VALUES.SCRIPT_STORE.SQL.GET_ROLEMEMBERSHIP
$BackupPermissionsCommand	= & $VALUES.SCRIPT_STORE.SQL.GET_PERMISSIONS

try {
	$Log |  Log "Getting current principals..."
	$PermissionsList.PRINCIPALS = & $VALUES.SQLInterface.cmdexec -On DESTINATION -Q $BackupPrincipalsCommand -AppNamePartID "BKP_PRINCIPALS"
	if(!$PermissionsList.PRINCIPALS){
		$PermissionsList.PRINCIPALS = @();
	}
	$Log |  Log "total principals: $($PermissionsList.PRINCIPALS.count)"
	$VALUES.SUGGEST_REPORT.add("PERMS_PRINCIPALS_COUNT",$PermissionsList.PRINCIPALS.count)
		
	$Log | Log "Getting current database owner..."
	$PermissionsList.DBO = & $VALUES.SQLInterface.cmdexec -On DESTINATION -Q $BackupDboCommand -AppNamePartID "BKP_OWNER"
	$Log | Log "Current Owner: $($PermissionsList.DBO.Owner)"
	$VALUES.SUGGEST_REPORT.add("PERMS_DBO",$PermissionsList.DBO.Owner)
	
	$Log | Log "Getting roles memberships..."
	$PermissionsList.ROLES_MEMBERS = & $VALUES.SQLInterface.cmdexec -On DESTINATION -Q $BackupRoleMembersCommand -AppNamePartID "BKP_ROLES"
	if(!$PermissionsList.ROLES_MEMBERS){
		$PermissionsList.ROLES_MEMBERS = @();
	}
	$Log | Log "total memberships: $($PermissionsList.ROLES_MEMBERS.count)"
	$VALUES.SUGGEST_REPORT.add("PERMS_ROLE_MEMBERS_COUNT",$PermissionsList.ROLES_MEMBERS.count)
	
	$Log | Log "Getting permissions..."
	$PermissionsList.PERMISSIONS = & $VALUES.SQLInterface.cmdexec -On DESTINATION -Q $BackupPermissionsCommand -AppNamePartID "BKP_PERMS"
	if(!$PermissionsList.ROLES_MEMBERS){
		$PermissionsList.ROLES_MEMBERS = @();
	}
	$Log | Log "total permissions: $($PermissionsList.PERMISSIONS.count)"
	$VALUES.SUGGEST_REPORT.add("PERMS_PERMISSIONS_COUNT",$PermissionsList.PERMISSIONS.count)
} catch {
	$Log | Log $_
	$Log | Log	"Error when getting permissions. Check previous errors."
}


if($ExportFile){
	try {
		$Log | Log "Attempting initialize file for export permissons: $ExportFile"
		"-- Export permissions, started on "+((Get-Date).toString("yyyyMMdd HH:mm:ss")) > $ExportFile
	} catch {
		$Log | Log "FAILED: $_";
		$ExportFile = $null;
	}
	
	
	$Log | Log "Exporting DCL principals..."
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_PRINCIPAL_DCL -PutGo
			ExportToFile $tsql
		} catch {
			$Log | Log "Error: $_";
		}
	
	$Log | Log "Exporting DCL role membership..."
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_ROLEMEMBERSHIP_DCL -PutGo
			ExportToFile $tsql
		} catch {
			$Log | Log "Error: $_";
		}
	
	$Log | Log "Exporting DCL permissions..."
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_PERMISSIONS_DCL -PutGO
			ExportToFile $tsql
		} catch {
			$Log | Log "Error: $_";
		}
	
	if($PermissionsList.DBO){
		$Log | Log "Exporting DCL owner..."
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_OWNER_DCL $PermissionsList.DBO.Owner;
			ExportToFile $tsql;
		} catch {
			$Log | Log "Error: $_";
		}
	}		
			
}	



