Function New-MSSQLSession
{
	[CmdLetBinding()]
	param($serverInstance = $null,$database = "master",$logon=@{AuthType="Windows";User="";Password=""},$appName="CUSTOM_MSSQL_POWERSHELL", $exString = "", [switch]$Pooling = $false)
	
	$Session = New-Object -Type PsObject @{ServerInstance = $serverInstance
											database = $database
											logon = $logon
											appName = $appName
											exString = $exString
											pooling=$Pooling
										}
	
	
	#This method allow you load all assemblies need for SMO.
	#This method make all checking need for loading the SMO dependencies.
	#Just call it.
	$LoadSMO = [scriptblock]::create({
	
		$assemblylist = @(
			"Microsoft.SqlServer.Management.Common"
			"Microsoft.SqlServer.Smo"
			"Microsoft.SqlServer.Dmf"
			"Microsoft.SqlServer.DmfSqlClrWrapper"
			"Microsoft.SqlServer.Dmf.Adapters"
			"Microsoft.SqlServer.Instapi"
			"Microsoft.SqlServer.SqlWmiManagement"
			"Microsoft.SqlServer.ConnectionInfo"
			"Microsoft.SqlServer.SmoExtended"
			"Microsoft.SqlServer.SqlTDiagM"
			"Microsoft.SqlServer.SString"
			"Microsoft.SqlServer.Management.RegisteredServers"
			"Microsoft.SqlServer.Management.Sdk.Sfc"
			"Microsoft.SqlServer.SqlEnum"
			"Microsoft.SqlServer.RegSvrEnum"
			"Microsoft.SqlServer.WmiEnum"
			"Microsoft.SqlServer.ServiceBrokerEnum"
			"Microsoft.SqlServer.ConnectionInfoExtended"
			"Microsoft.SqlServer.Management.Collector"
			"Microsoft.SqlServer.Management.CollectorEnum"
			"Microsoft.SqlServer.Management.Dac"
			"Microsoft.SqlServer.Management.DacEnum"
			"Microsoft.SqlServer.Management.Utility"
		)
		
		#This contains possible versions of SQL Server folders with SMO libraries.
		$PossibleVersions = 120,110,100
		$BaseFolder = "C:\Program Files\Microsoft SQL Server\{0}\SDK\Assemblies\"
		
		#The script will try select the folder with the major quantity of dll files.
		$LastQtd = 0
		$ElegibleFolder = ""
		$PossibleVersions | %{
			$CurrentFolder = $BaseFolder -f  $_
			$qtdAvailable = @(gci -EA "SilentlyContinue" @($assemblylist|%{"$CurrentFolder\*$_*.dll"})).count
			if($qtdAvailable -gt $LastQtd){
				$ElegibleFolder = $CurrentFolder
			}
		}
		
		$assemblies = gci ($ElegibleFolder+"\*.dll")
		foreach ($asm in $assemblies)
		{
				$fullPath = $asm.FullName
				try{
					[Reflection.Assembly]::LoadFrom($fullPath)  | out-Null
				} catch {
					if($assemblylist -contains $asm){
						throw
					}
				}
		}
	
	})
	
	#This is a internal function to get SqlDataReader results and convert into a powershell hashtable array.
	#A behavior in powershell cause it call the enumerator of some parameters that are passed.
	#With SqlDataReader, if this happens, the result returned are lost...
	#Thus, this function is for internal comunication only.
	$_readerResultSet = [scriptblock]::create({
							param($readerarr)
								$reader = $readerarr[0]
								$totalColumns = $i = $reader.FieldCount
								[array]$resultset = @()

								write-verbose "Starting get results from a SqlDataReader..."
								write-verbose "The field count is: $totalColumns"
								write-verbose "Starting rows looping..."
								while($reader.read() -eq $true)
								{
									$columnsValue = @{}
									
									write-verbose "A row is available!"
									
									0..($totalColumns-1) | % {
													write-verbose "Getting the columns for this row!"
									
													write-verbose "Getting current column name..."
													$column = $reader.GetName($_); 
													
													write-verbose "Getting current column value..."
													$value = $reader.getValue($_);

													
													if($reader.isDbNull($_)) {
														write-verbose "Current value is null"
														$value = $null
													}
													
													if(!$column){
														write-verbose "Current column has no name. Assing a default name for this."
														$column = "(No Column Name $_)"
													}
													
													write-verbose "The column name is: $column"
													write-verbose "The value of columns will not be displayed."
													
													write-verbose "Adding the column/value pair to internal array..."
													$columnsValue.add($column,$value)
											}
											
										
									write-verbose "Addin the columns array to resultset internal object"
									$resultset += (New-Object PSObject -Prop $columnsValue)
								}

								write-verbose "Returning data to the caller."
								return $resultset;
						})
			
	#This method open a connection with the server...
	$newSession = [scriptblock]::create({
						param($serverInstance = $null,$database = "master",$logon=@{AuthType="Windows";User="";Password=""}, $exString="")
						
						write-verbose "Attemping create the new session."
						
						#Check if already some session for this object...
						$currentSession = $this._session
						
						if($currentSession)
						{
							write-verbose "The current session objects already a value."
							throw "SESSION_ALREADY_CREATED"
						}

						if($serverInstance) {
							$this.serverInstance = $ServerInstance
						}
						write-verbose "The server instance will be: $($this.serverInstance)"
						
						if($database){
							$this.database = $database
						}
						write-verbose "The database will be: $($this.database)"
						
						if($logon){
							$this.logon = $logon
						}
						write-verbose "The logon auth type will be: $($this.logon.AuthType)"
						
						
						$authentication = "Integrated Security=True"
						$appName = $this.appName
						
						if($this.logon.AuthType -eq "SQL") {
							write-verbose "The logon user will be: $($this.logon.User)"
							write-verbose "The logon pass will be: $($this.logon.Password)"
						
							$authentication = "User=$($this.logon.User);Password=$($this.logon.Password)"
						}
						
						if(!$appName){
							$appName = "CUSTOM_MSSQL_POWERSHELL"
						}
						
						write-verbose "The app name will be: $appName"
						
						$ConnectionString = @(
							"Server=$($this.ServerInstance)"
							"Database=$($this.database)"
							$authentication
							"APP=$appName"
						)
						
						if(!$this.Pooling){
							$ConnectionString += "Pooling=false"
						}
						
						$connectionString += ($exString -split ";");
						
						#RRG_EDIT: Changed connection string direct to Join form...
						# "Server=$ServerInstance;Database=$Database;Integrated Security=True;App=$App"
						$NewConex = New-Object System.Data.SqlClient.SqlConnection
						$NewConex.ConnectionString = $ConnectionString -Join ";" 
						
						
						
						write-verbose "The final connection string is: $($NewConex.ConnectionString ) "
						
						try {
							write-verbose "Attempting open tthe connection object"
							$NewConex.Open()
							
							write-verbose "Storing connection object on the session property"
							$this._session = $NewConex
						} catch {
							write-verbose "Some error while connect to server..."
							if($NewConex){
								$NewConex.Dispose()
							}
							throw ($_.Exception.GetBaseException())
						}
					})
					
	#This command ends a connections with server
	$endSession = [scriptblock]::create({
						param($Conex)
						
						if($this._session)
						{
							write-verbose "The  connection object will be disposed."
							$this._session.Dispose()
							
							write-verbose "The  session property will be null"
							$this._session = $null	
						} else {
							write-verbose "No connection on session object available to ending."
						}
	
					})
			
	
	#Get Current Session state, based on SQL Server States.
	#possibles are: SLEEPING;RUNNING
	$getState = [scriptblock]::create({
					$currentState = "SLEEPING"
					$con = $this._session
					
					write-verbose "Attempt get the state."
					
					if($con)
					{
						write-verbose "The current connection state is: $($con.State) "
						
						switch($con.State)
						{
							"Broken" {$currentState="DISCONECTTED"}
							"Closed" {$currentState="DISCONECTTED"}
							"Connecting" {$currentState="RUNNING"}
							"Executing" {$currentState="RUNNING"}
							"Fetching" {$currentState="RUNNING"}
							"Open" {$currentState="SLEEPING"}
						}
					} else {
						$currentState = "DISCONECTTED"
					}
					
					return @{state=$currentState}
				})
	
	#This method execute a batch on the session.
	$execute =  [scriptblock]::create({
					param($TSQL,$ServerInstance = $null,$Database = $null,$Logon = $null,$QueryTimeout = $null,$Close = $false, $ExString = "")
		
					try {
						
						if(!$this._Session)
						{
							write-verbose "No session opended for this objects."
							$Close = $true
							
							write-verbose "Creating session objects..."
							$this.newSession($ServerInstance,$Database,$Logon,$ExString)
						}
			
						$sessionState = $this.getState().state
						
						write-verbose "Current session state is: $sessionState"
						if($sessionState -ne "SLEEPING")
						{
							write-verbose "Session is not sleeping! A erro will trhowed"
							throw "SESSION_BUSY[$sessionState]"
						}
						
						write-verbose "Creating the command object..."
						$commandTSQL = $this._session.CreateCommand()
						
						write-verbose "Setting the SQL script to: $TSQL"
						$commandTSQL.CommandText = $TSQL
						
						write-verbose "Setting the query timeout for : $QueryTimeout"
						$commandTSQL.CommandTimeout = $QueryTimeout
						
						try{
							$result = $null;
							write-verbose "Executing the command on the connection..."
							$result = $commandTSQL.ExecuteReader()
						} catch {
							write-verbose "Some error ocurred while execute the command"
							throw ($_.Exception.GetBaseException())
						}
				
						try {
							write-verbose "Attempting get the results"
							$resultset = @($this._readerResultSet((,$result)))
						} catch {
							$bex = $_.Exception.GetBaseException()
							$Error = "EXECUTE_READING_ERROR:"+$bex.Message
							throw New-Object -Type System.Exception -ArgumentList "$Error",$bex
						}
						
					} catch {
						throw
					} finally {
						if($result)
						{
							write-verbose "Disposing SqlDataReader object..."
							$result.Dispose()
						}
						
						if($commandTSQL)
						{
							write-verbose "Disposing Command object..."
							$commandTSQL.Dispose()
						}
						
						if($Close)
						{
							write-verbose "Ending this session!"
							$this.endSession()
						}
					}
					
					return $resultset;
				})
	
	
	#This method provide a form of you call evalute policies stored in this server in anothers servers.
	$evaluatePolicy = [scriptblock]::create({
					param($policies,[string[]]$targetServer,$targetLogon = $null,$evaluationMode="CHECK",$serverInstance = $null,$logon = $null, $close = $false, $AppName = "POWERSHELL-MSSQL-POLICY_BASED_MANAGEMENT")
			
						if(!$this._Session)
						{
							write-verbose "No sessino opended for this object"
							$Close = $true
							
							write-verbose "Creating session objects..."
							$Database = "master"
							$this.newSession($ServerInstance,$Database,$Logon)
						}
			
						$sessionState = $this.getState().state
						
						write-verbose "Current session state is: $sessionState"
						if($sessionState -ne "SLEEPING")
						{
							write-verbose "Session is not sleeping! A erro will trhowed"
							throw "SESSION_BUSY[$sessionState]"
						}
						
						#Loading SMO library for internal PBM access
						$this.LoadSMO()
						
						#Creating the connection
						
						## For evaluation a policy in specific server, we need generate SqlStoreConnection...
						
						
						
						$targetServers = @(
							$targetServer | %{
								$targetConex = New-Object System.Data.SqlClient.SqlConnection
								$AuthenticationString = "Integrated Security=True;";
								
								if($targetLogon.AuthType -eq "SQL") {
									$AuthenticationString = "User=$($targetLogon.User);Password=$($targetLogon.Password);"
								}
								
								$targetConex.ConnectionString = "Server=$_;Database=master;App=$AppName;$AuthenticationString"
								$targetSqlStoreConnection =  New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($targetConex)
								
								return New-Object PSObject -Prop @{name = $_; sqlStoreConnection = $targetSqlStoreConnection}
							}
						)
						
						try {
						#We open connection with the current server, that's it, the current Policy Store.
						
							#Let's create a SqlStoreConnection object.
							$policySqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($this._session)
							$policySqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($this._session)
							
							#Finnaly, lets create the connection with the policystore \o/
							$policyStore = New-Object Microsoft.SqlServer.Management.Dmf.PolicyStore($policySqlStoreConnection)
							
						#All right... Lets get the policies, based on user filter...
						if($policies -is [scriptblock]){
							$filter = $policies
						}
						
						if($policies -is [object[]] -or $policies -is [string] ){
							$policyNames = $policies  -as [string[]]
							$filter = {  $policy = $_; @($policyNames | WHERE {$policy.Name -like $_}).count -gt 0 }
						}
						
						if($Policies -eq $null){
							$filter = {$true}
						}
						
						$filter = [scriptblock]::create($filter);
						
						$elegiblePolicies = @($policyStore.Policies | WHERE $filter)

						#For each server, by time, evaluate the policy by policy...
						$Evaluations = @(
							$targetServers | % {
								$currentServer = $_
							
								$elegiblePolicies  | %{
									$resultObject = $null
									#Creating a event identifier for listen event related with the policy that we call evaluation...
									#This is a unique string that we pass to Register-ObjectEvent cmdlet.
									#We will need do this for get policie evaluation results for this evaluation only.
									$currentPolicy = $_
									try {
										$EventSourceIdentifier = "$($currentServer.ServerInstance)-$($currentPolicy.Name)-"+([Guid]::NewGuid()).Guid
										
										#Registering the event for getting evaluation results....
										Register-ObjectEvent -InputObject $currentPolicy -EventName PolicyEvaluationFinished -SourceIdentifier $EventSourceIdentifier | Out-Null
										
										#Calling the evaluation...
										$evaluateTarget = $currentServer.sqlStoreConnection
										$evresult = $_.evaluate($evaluationMode,$evaluateTarget)
										
										#Waiting on the event... At this moment it must be fired... The Wait must be fast!
										$EventData = Wait-Event -SourceIdentifier $EventSourceIdentifier
										

										#Getting the object containing the evaluation information...
										$EvaluationResultsDetails = $EventData.SourceEventArgs
										$EvaluationResult = $EvaluationResultsDetails.Result
										$EvaluationDetails = $EvaluationResultsDetails.EvaluationHistory.ConnectionEvaluationHistories[1].EvaluationDetails
										
										$resultObject = New-Object PSObject -Prop @{evaluationPolicy = $_.Name
																		evaluationTarget = $currentServer.name
																		evaluationResult = $EvaluationResult
																		evaluationDetails = $EvaluationDetails
																	}
									} finally {
										#Attempting close the target connection
										#Freeing the resources...
										if($EventData) {
											$EventData | Remove-Event 
											if(Get-EventSubscriber -SourceIdentifier  $EventSourceIdentifier)
											{
												Unregister-Event -SourceIdentifier  $EventSourceIdentifier
											}
										}
									}
									
									if($resultObject) {
										return $resultObject
									}
								}
								
							}
						)

					} finally {
						if($policyStore){
							$policyStore = $null
						}
						
						if($policySqlStoreConnection){
							$policySqlStoreConnection = $null
						}
						
						if($close){
							$this.endSession()
						}
					}
					
					return $Evaluations;
				})
	
	
	$Session | Add-member -Type ScriptMethod -Name _readerResultSet -Value 	$_readerResultSet
	$Session | Add-member -Type ScriptMethod -Name newSession -Value 	$newSession
	$Session | Add-member -Type ScriptMethod -Name endSession -Value 	$endSession
	$Session | Add-member -Type ScriptMethod -Name connect -Value 	$newSession
	$Session | Add-member -Type ScriptMethod -Name disconnect -Value 	$endSession
	$Session | Add-member -Type ScriptMethod -Name getState -Value 	$getState
	$Session | Add-member -Type ScriptMethod -Name execute -Value 	$execute
	$Session | Add-member -Type ScriptMethod -Name loadSMO -Value 	$loadSMO
	$Session | Add-member -Type ScriptMethod -Name evaluatePolicy -Value 	$evaluatePolicy
	$Session | Add-member -Type Noteproperty -Name _session -Value 	$null
	$Session | Add-member -Type Noteproperty -Name serverInstance -Value 	$null
	$Session | Add-member -Type Noteproperty -Name database -Value 	$null
	$Session | Add-member -Type Noteproperty -Name logon -Value 	$null
	
	if($serverInstance){
		write-verbose "Starting the creation of a session object!"
		write-verbose "ExString is: $exString"
		$Session.newSession($serverInstance,$database,$logon,$exString)
	}
	
	return $Session 
}

Function Invoke-NewQuery  {
	[CmdLetBinding()]
	param(	
			#This is the Server instance. Can be ip address, ip and port, name\instance, etc.
				$ServerInstance = $null
			
			,#This is the Database name that you want connect to.
				$Database = "master"
				
			,#This is the Query that you want execute.
				$Query = $null
			
			,#This is the login name, if you want to use SQL Login instead of Windows Authentication.
			 #If you want use Windows Authentication, dont specify this parameter.
				$Login=$null
				
			,#This is the password of login.
				$Password = $null
				
			,#This is the application name show in sys.dm_exec_sessions
				$appName = "CustomMSSQL"
			
			,#This options controls if you wont fix the SET OPTIONS that affects the results.
			 #Some options of the session can produce slow query plans if not configured correctly.
			 #Check this technet article to more details: https://technet.microsoft.com/en-us/library/ms175088(v=sql.105).aspx
			 #By default, the cmdlet will execute some "SET" commands before executing the user query, on same connection opened.
			 #If you specify this option, the cmdlet will not execute this set options.
				[Switch]$NoFixSetOptions
				
			,#Specify some additional connection strings parameters that you can use.
				$exString = ""
				
			,#Specify input file with a query. If both Query and InputFile is specified, this takes precedence.
				$InputFile = $null
				
			,#This is another way of specifu credentials to connect to SQL Server.
			 #It is just a hashtable containing some keys defining the logon informations. 
			 #The keys are:
			 #	AuthType: The type of Authentication, The values are: Windows or SQL
			 #	Login: The SQL Login, if AuthType is "SQL"
			 #	Password: The Login Password.
			 #
			 # If you specify "Login" parameter, it will override this option.
				$Logon = @{AuthType="Windows"}
				
				
			,#Alterantive way to specify "ServerInstance". Is useful to use with results of Get-InstanceByProperty cmdlet.
				[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
				$connectionName = $null
				
			,#Specify the minimum version required by server for script run.
			 #The script will try connect to target instance and get version...
			 #If version returned is less thant this parameter, the script is not execubtale.
			 #The min version must be specified in format MAJOR.MINOR.BUILD or a numeric value represting it.
			 #If cmdlet cannot obtain instance version, the exception CANNOT_GET_MINVERSION is throwed!
				$MinVersion = $null
	)
	
begin {
	#Get all servers!
	$AllConnections = @()
	
	if($MinVersion){
		$NumericMinVersion = GetProductVersionNumeric $MinVersion;
	}
	
}

process {
	
	$Conexao = New-Object PSObject -Prop (GetAllCmdLetParams)
	$Conexao | Add-Member -Type Noteproperty -Name Results -Value $null 
	$Conexao | Add-Member -Type Noteproperty -Name Errors -Value @()
	$AllConnections += $Conexao;
}
	
end {
	
	$isMultiple = $false;
	
	if($AllConnections.count -gt 1){
		$isMultiple = $true;
	}
	
	:ConexoesLoop foreach($Conexao in $AllConnections){

		if($Conexao.connectionName -and !$conexao.serverInstance){
			$Conexao.ServerInstance = $Conexao.connectionName;
		}
		
		if($Conexao.Login){
			$Conexao.logon = @{
					AuthType = "SQL"
					User=$Login
					Password=$Password
				}
		}
		
		if(!$Conexao.ServerInstance)
		{
			$ex = New-Object System.Exception("You must provide a server instance");
			if($isMultiple){
				$Conexao.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		}

		$Query = $Conexao.Query;
		if($Conexao.InputFile){
			
			if(Test-Path $Conexao.InputFile)
			{
				$Query = (Get-Content $Conexao.InputFile) -Join "`r`n"
			} else {
				$ex = New-Object System.Exception( "Invalid File: $InputFile");
				
				if($IsMultiple){
					$Conexao.Errors += $ex
					continue :ConexoesLoop;
				} else {
					throw $ex;
				}
			}
		}
		
		if(!$Query)
		{
			$ex = New-Object System.Exception( "Invalid Query");
			
			if($IsMultiple){
				$Conexao.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		}
		

		
		$FIX_SET_OPTIONS = @(
						"SET ANSI_NULLS ON;"
						"SET ANSI_PADDING ON;"
						"SET ANSI_WARNINGS ON;"
						"SET ARITHABORT ON;"
						"SET CONCAT_NULL_YIELDS_NULL ON;"
						"SET NUMERIC_ROUNDABORT OFF;"
						"SET QUOTED_IDENTIFIER ON;"
						) -Join "`r`n"
		
		try {
			$NewQuery = $null;
			$NumericServerVersion = $null; #This will store the target server numeric version.
			
			$NewQuery = New-MSSQLSession -serverInstance $Conexao.ServerInstance -database $Conexao.database -Logon $Conexao.logon -appName $Conexao.appName -exString $Conexao.exString
		
			#Try  get the minimum version if is was specified!
			if($Conexao.MinVersion -ne $null){
				try {
					$QueryResult = $NewQuery.execute("SELECT SERVERPROPERTY('ProductVersion') as ProductVersion");
					$NumericServerVersion =  GetProductVersionNumeric $QueryResult.ProductVersion;
				} catch {
					throw "CANNOT_GET_MINVERSION: $_"
				}
				
				if($NumericServerVersion -lt $NumericMinVersion){
					write-verbose "Ignoring query execution because Minimum Version. Required:$NumericMinVersion Current:$NumericServerVersion"
					$Conexao.Results = $null
					continue :ConexoesLoop;
				}
			}
			
			
			
			if(!$Conexao.NoFixSetOptions){
				try {
					write-verbose ("Fixing the SET OPTIONS: "+$FIX_SET_OPTIONS)
					$NewQuery.execute($FIX_SET_OPTIONS) | Out-Null
				} catch {
					write-verbose ("SET_OPTIONS FIX ERROR: "+($_.Exception.Message))
				} 
			}
			

			
			$resultset = $NewQuery.execute($Query)
			$Conexao.Results = $resultset;
		} catch {
			$ex = $_;
			
			if($IsMultiple){
				$Conexao.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		} finally {
			if($NewQuery){
				$NewQuery.endSession()
			}
		}
	
	}
	
	if($IsMultiple){
		return $AllConnections
	} else {
		return $AllConnections[0].Results;
	}
}

	<#
		.SYNOPSIS 
			Connects to SQL Server instance and execute a query, using .NET System.Data.SqlClient library.
			
		.DESCRIPTION
			This cmdlet is a rewrite of Invoke-SqlCmd and Sqlcmd. This is a more lightweight and customized version.
			It is build on top of "New-MSSQLSession" cmdlet provided by CustomMSSQL for executing queries without session control.
			
			The cmdlet returns the first resultset only as a array of objects.
			Each row returned is a object. Each column of a row is a "Noteproperty" of the object.
			
			If errors happens while executing the query, the cmdlet throws a exception of type SQLException.
			You can use SQLException to get access to all errors thrown.
			
			The cmdlet provide some parameters that have same name in the Invoke-Sqlcmd (from sqlps module).
			This is for compatibility reasons. But it provides more alternatives and options. Check parameters documentation for more information.
		
		.EXAMPLE
			
			$allTables = Invoke-NewQuery -ServerInstance MyServer -Database "MyDatabase" -Query "SELECT name FROM sys.tables"
			
		.NOTES
		
			KNOW ISSUES
				Handle "GO" - This cmdlet don't handle "GO"
				
			WHAT'S NEW
	#>
}