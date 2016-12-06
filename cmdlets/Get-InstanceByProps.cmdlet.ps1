Function Get-InstancesByProps {
	[CmdletBinding()]
	param(
		[string]$CMSInstance = $null
		,$Expression = $null
		,[switch]$ListProperties = $false
	)

	#Syntax: 
	$ErrorActionPreference = "Stop";
	
	if(!$CMSInstance){
		#Get from repository
		$CMSPropsRepo = (Get-CMSPropsRepository)
		$CMSInstance = $CMSPropsRepo.ServerInstance+":"+$CMSPropsRepo.Database
	}
	
	#Determining instance and database.
	$ConnectionParts = @($CMSInstance -split ":")
	$InstanceName = $ConnectionParts[0]
	
	if($ConnectionParts[1]){
		$DBName = $ConnectionParts[1]
	} else {
		$DBName = ""
	}
	
	if($ListProperties){
		try {
			$TSQL = "SELECT * FROM cmsprops.CMSProperties"
			$props = Invoke-NewQuery -ServerInstance $InstanceName -Database $DBName -Query $TSQL
			return $props;
		} catch {
			throw "DATABASE_ERROR: $_"
		}
	}
	
	if($Expression -is [hashtable]){
		$TmpExpression = @()
		
		$Expression.GetEnumerator() | %{
			$TmpExpression += "$($_.Key) = ''$($_.Value)''"
		}
		
		$CMSPropExpression = $TmpExpression -join " AND "
	}
	
	elseif($Expression -is [string]) {
		$CMSPropExpression = $Expression;
	}
	
	if($CMSPropExpression){
		$FilterExpressionParam = "@FilterExpression = '$CMSPropExpression'"
	} else {
		$FilterExpressionParam = ""
	}

	$TSQL = "EXEC cmsprops.prcGetInstance $FilterExpressionParam"
	
	write-verbose "TSQL: $TSQL"
	
	try {
		$returnedServers = Invoke-NewQuery -ServerInstance $InstanceName -Database $DBName -Query $TSQL
		return $returnedServers;
	} catch {
		throw "DATABASE_ERROR: $_"
	}
}




Function Get-InstancesByPropsBeta {
	[CmdletBinding()]
	param(
		[string]$CMSInstance = $null
		,$Expression = $null
		,[switch]$ListProperties = $false
		,$CMSPropertyTable = $null
		,$ExPropName 	= "CUSTOMMSSQL:CMSPROPSTABLE"
	)

	#Syntax: 
	$ErrorActionPreference = "Stop";
	
	if(!$CMSInstance){
		#Get from repository
		$CMSPropsRepo = (Get-CMSPropsRepository)
		$CMSInstance = $CMSPropsRepo.ServerInstance+":"+$CMSPropsRepo.Database
	}
	
	#Determining instance and database.
	$ConnectionParts = @($CMSInstance -split ":")
	$InstanceName = $ConnectionParts[0]
	
	if($ConnectionParts[1]){
		$DBName = $ConnectionParts[1]
	} else {
		$DBName = ""
	}
	
	#Attempting to determine de table that contains the properties...
	#By default, the table is the table that contains a extended property called CUSTOMMSSQL:CMSPROPSTABLE defined (any value)...
	#The user can override this, specified a table and schema name in param $CMSPropertyTable
	#User also can override the extended property that defines using the $ExPropName param.
	
	
	$TableNameCMSProps = $CMSPropertyTable;
	if(!$TableNameCMSProps){
		$GetPropertyTableSQL = "SELECT TableName = OBJECT_SCHEMA_NAME(EP.major_id)+'.'+OBJECT_NAME(EP.major_id) FROM sys.extended_properties EP WHERE EP.name = '$ExPropName' "
		
		try {
			$ResultSet = Invoke-NewQuery -ServerInstance $InstanceName -Database $DBName -Query $GetPropertyTableSQL;
		} catch {
			throw "ERROR_GETTING_CMSPROPERTY_TABLE: $_";
		}
		
		$TableNameCMSProps = $ResultSet.TableName
	}
	
	if(!$TableNameCMSProps){
		throw "ERROR_CANNOT_DETERMINE_CMSPROPS_TABLE";
	}
	
	
	#Now, we will mount the property...
	$ServerGroupQuery = "";	
}




















