#Generate the DCL command for restore permission!
param([switch]$PutGO = $false)

$PrincipalsList 	= $VALUES.DESTINATION_INFO.PERMISSIONS.PRINCIPALS
$i	= $PrincipalsList.count;

$GO = "`r`nGO`r`n"

$Log | Log "Building T-SQL... Principal count: $i";

$DCL = "";
while($i--){
	
	$CurrentPrincipal = $PrincipalsList[$i];
	$type = $CurrentPrincipal.type_desc
	$principalName = $CurrentPrincipal.principalName
	$mappedName = $CurrentPrincipal.serverPrincipal
	
	if($type -eq "DATABASE_ROLE"){
		$DCL += "IF USER_ID('$principalName') IS NULL EXEC('CREATE ROLE [$principalName]');`r`n";
	}
	else {
		$CreateDCL = "";
		$AlterDCL = "";
		
		if($mappedName){
			$CreateDCL = "CREATE USER [$principalName] FROM LOGIN [$mappedName]";
			$AlterDCL = "ALTER USER [$principalName] WITH LOGIN = [$mappedName]"
		} else {
			$CreateDCL = "CREATE USER [$principalName] WITHOUT LOGIN";
			$AlterDCL = "/*MAPPED LOGIN IS EMPTY*/"
		}

		$DCL += "IF USER_ID('$principalName') IS NULL EXEC('$CreateDCL') ELSE EXEC('$AlterDCL');`r`n";
	}
	
	if($PutGO){
		$DCL += $GO;
	}
}

$Log | Log "T-SQL Length: $($DCL.Length) ";


return $DCL;