param($VALUES)

Log "	Getting all permissions for apply after restore."

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
	Log "		Getting current principals..."
	$PermissionsList.PRINCIPALS = & $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $BackupPrincipalsCommand
	Log "			total principals: $(@($PermissionsList.PRINCIPALS).count)"
		
	Log "		Getting current database owner..."
	$PermissionsList.DBO = & $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $BackupDboCommand
	Log "			Current Owner: $($PermissionsList.DBO.Owner)"
	
	Log "		Getting roles memberships..."
	$PermissionsList.ROLES_MEMBERS = & $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $BackupRoleMembersCommand
	Log "			total memberships: $(@($PermissionsList.ROLES_MEMBERS).count)"
	
	Log "		Getting permissions..."
	$PermissionsList.PERMISSIONS = & $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $BackupPermissionsCommand
	Log "			total permissions: $($PermissionsList.PERMISSIONS.count)"
} catch {
	Log $_
	Log	"Error when getting permissions. Check previous errors."
}