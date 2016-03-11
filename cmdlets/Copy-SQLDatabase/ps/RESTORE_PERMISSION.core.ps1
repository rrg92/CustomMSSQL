param($VALUES)

Log "	Restoring permissions"

$PermissionsList = $VALUES.DESTINATION_INFO.PERMISSIONS

if(!$PermissionsList){
	Log "	No backed up permissions found. Skipping."
	return;
}

Function GetPrincipalCommand {
	param($principalName,$mappedName,$type) 
	
	if($type -eq "DATABASE_ROLE"){
		return "IF USER_ID('$principalName') IS NULL EXEC('CREATE ROLE [$principalName]')";
	}
	
	else {
		return "IF USER_ID('$principalName') IS NULL EXEC('CREATE USER [$principalName] FROM LOGIN [$mappedName]') ELSE EXEC('ALTER USER [$principalName] WITH LOGIN = [$mappedName]')";
	}
}

Function GetRoleMembershipCommand {
	param($RoleName,$MemberName)
	
	return "EXEC sp_addrolemember '$RoleName','$MemberName';"
}

Function GetPermissionsCommand {
	param($Principal,$PermissionName,$State,$SecurableClass,$majorName,$minorName)
	
	
	if(!$SecurableClass){
		throw "INVALID_SECURABLE_CLASS: $SecurableClass";
	}
	
	if(!$majorName){
		throw "INVALID_SECURABLE_NAME: $majorName";
	}
	
	$FullSecurableDCL = "ON $($SecurableClass)::$majorName";
	
	if($minorName){
		$FullSecurableDCL += "($minorName)";
	}
	
	if($SecurableClass -eq "DATABASE"){
		$FullSecurableDCL = ""
	}
	
	
	
	$dcl = "$State $PermissionName $FullSecurableDCL TO [$Principal]";
	
	return $dcl;
}


try {

	Log "	Creating principals"
	
	$PermissionsList.PRINCIPALS| where {$_} | %{
		try {
			$tsql = (GetPrincipalCommand $_.principalName $_.serverPrincipal $_.type_desc)
			Log "		Creating the principal ($($_.type_desc)) $($_.principalName) mapped to $($_.serverPrincipal)"
			Log "		Create principal command: $tsql"
			& $SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $tsql -NoExecuteOnSuggest
			Log "			SUCCESS!"
		} catch {
			Log "	Error when creating principal: $_";
		}
	}
	
	Log "	Creating role memberships"
	
	$PermissionsList.ROLES_MEMBERS | where {$_}  | %{
		try {
			$tsql = GetRoleMembershipCommand $_.roleName $_.memberName
			Log "		Adding principal $($_.memberName) to $($_.roleName)"
			Log "		Role membership command: $tsql"
			& $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $tsql -NoExecuteOnSuggest
			Log "			SUCCESS!"
		} catch {
			Log "	Error when adding role membership: $_";
		}
	}
	
	Log "	Creating permissions"
	
	$PermissionsList.PERMISSIONS | where {$_} | %{
		try {
			$tsql = GetPermissionsCommand $_.principalName $_.permission_name $_.PermissionState $_.SecurableClass $_.SecurableName $_.SecurableMinorName
			Log "		Permission DCL: $tsql"
			& $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $tsql -NoExecuteOnSuggest
			Log "			SUCCESS!"
		} catch {
			Log "	Error when assigning permission: $_";
		}
	}
	
	if($PermissionsList.DBO){
	
	Log "	Changing the owner"
	
		$OwnerPrincipal = $PermissionsList.DBO.Owner;
		try {
			$tsql = "ALTER AUTHORIZATION ON DATABASE::[$($VALUES.PARAMS.DestinationDatabase)] TO [$OwnerPrincipal]";
			Log "		Changing the database owner to $OwnerPrincipal"
			& $SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $tsql -NoExecuteOnSuggest
			Log "			SUCCESS!"
		} catch {
			Log "	Error when changing the owner: $_";
		}
	}
} catch {
	Log $_
	Log	"Error when restoring permissions. Check previous errors."
}