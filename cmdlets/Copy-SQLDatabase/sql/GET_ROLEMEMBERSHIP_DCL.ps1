param([switch]$PutGO = $false)


$MemberList = $VALUES.DESTINATION_INFO.PERMISSIONS.ROLES_MEMBERS
$i			= $MemberList.count;

$GO = "`r`nGO`r`n"

$Log | Log "Building T-SQL..."

$DCL = "";
while($i--){
	$CurrentMember = $MemberList[$i];
	
	if(!$CurrentMember){
		continue;
	}
	
	$DCL  += "EXEC sp_addrolemember '$($CurrentMember.roleName)','$($CurrentMember.memberName)';`r`n";
	
	if($PutGO){
		$DCL += $GO;
	}
	
	
}

$Log | Log "T-SQL Length: $($DCL.Length) ";

return $DCL;