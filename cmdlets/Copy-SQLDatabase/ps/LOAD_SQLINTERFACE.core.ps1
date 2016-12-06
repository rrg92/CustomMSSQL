#SQL Interface is a centralized way to connect to a SQL Instance.
#It defines and hanbdles many things that cmdlet dont need worry about.

$VALUES.PRECONNECTIONS = @{
	SOURCE = @{
				ServerInstance=$VALUES.PARAMS.SourceServerInstance 
				Logon=$VALUES.DESTINATION_SQL_LOGON
				Database=$VALUES.PARAMS.SourceDatabase
			}
			
	DESTINATION = @{
				ServerInstance=$VALUES.PARAMS.DestinationServerInstance 
				Logon=$VALUES.DESTINATION_SQL_LOGON
				Database=$VALUES.PARAMS.DestinationDatabase
			}
}


@{	name="CUSTOMMSSQL"
	PreReq=$null
	cmdexec={
		param(
			$S
			,$d
			,$Q
			,$U,$P
			,$i
			,[switch]$IgnoreExceptions = $false, [switch]$NoExecuteOnSuggest = $false
			, $Logon = @{AuthType="Windows"}
			, $AppNamePartID = ""
			, $On = $null
		)	
			if($NoExecuteOnSuggest -and $VALUES.PARAMS.SuggestOnly){
				$Log | Log "NO EXECUTING BECAUSE IS IN SUGGESTONLY MODE" "VERBOSE"
				return;
			}

			#Hard coded for future implementations...
			$AppNamePrefix = "Copy-SQLDatabase"
			
			#Determine if a pre-determined logon info was passed...
			$PreDetermined = $null;
			if($On){
				if($VALUES.PRECONNECTIONS.Contains($On)){
					$PreDetermined = $VALUES.PRECONNECTIONS.$On;
				}
				
				$Logon = $PreDetermined.Logon;
				
				if($Log.canLog("VERBOSE")){
					$PreDeterminedInfo  = Object2HashString (New-Object PsObject -Prop $PreDetermined) -Expand
					$Log | Log "Using pre determined connections: $On = $PreDeterminedInfo" "VERBOSE"; 
				}
			}

			$cmdparams = @{
				ServerInstance=$S
				Database=$d
				Logon=$Logon
				AppName="$($AppNamePrefix):$AppNamePartID"
			}
			
			if($U){
				$Logon.AuthType = "SQL"
				$Logon.User = $U;												
				$Logon.Password = $P;
			}
			
			if($Q){
				$cmdparams.add("Query",$Q)
			}
			
			if($i){
				$cmdparams.add("InputFile",$i)
			}
			
			if($PreDetermined){
				$PreDetermined.GetEnumerator() | %{
					$CurrentProp = $_.Key;
					$CurrentValue = $_.Value;
					if(!$cmdparams.$CurrentProp){
						$cmdparams.$CurrentProp = $CurrentValue;
					}
				}
			}
			
			if($Log.canLog("VERBOSE")){
				$QueryParams = Object2HashString $cmdparams -Expand;
				$Log | Log "The following SQL will execute under following params: $QueryParams" "VERBOSE"; 
			}
			
			try {
				$results = Invoke-NewQuery @cmdparams;	
				return $results;
			} catch {
				$Log | Log $_ 
				if(!$IgnoreExceptions){
					throw "MSSQL_ERROR: Last executed script failed! Check previous erros in log."
				}
			}
	}
}