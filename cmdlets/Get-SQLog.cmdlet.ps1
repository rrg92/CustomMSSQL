Function Get-SQLog {
	[CmdLetBinding(SupportsShouldProcess=$True)]
	param(
		#Specify directory to save all colected files!
			$SaveTo
			
		,#Specify a instance name
			$SQLInstance = $null
			
		,#Specify a machine name!
			$MachineName = $null
		
		,#Logging file or directory...
			$LogTo = @("#")
		
		,#Logging level
			$LogLevel = "DETAILED"
			
		,#Sets the a start datetime filter.
		 #For SQL Error logs, all files with creation date equal or greater than this date will.
		 #Also, the first file before this date will be getted!
			[datetime]$FilterStartTime = ((Get-Date).addHours(-24))
			
		,#Sets a end datetime filter.
		 #For SQL Server error logs, all files with creation time less or equal this date will be getted.
		 #Also, the first file after this date will be getted.
			[datetime]$FilterEndTime = (Get-Date)
			
		,#Open directory in explorer.executed
			[switch]$OpenFolder = $false
			
		,#Zips the contents!
			[switch]$Zips = $false
			
		,#Calls to generate advanced reporting...
			[switch]$ReportEx = $false			

		,#Returns internal object, to be used in debugging purposes...
			[switch]$ReturnsInternal = $false
	)
	
	$ErrorActionPreference = "Stop";
	$IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
	

	#Defining some functions and configurations for script...
		
	$GMV = GetGMV
	$CmdLetBaseFolder = "$($GMV.CMDLETSIDR)\Get-SQLog\libs"
	
	#Loads the functions auxiliary...
	
	gci ($CmdLetBaseFolder+'\*.ps1') | %{
		write-verbose "Importing lib $($_.Name)";
		. $_.fullName;
	}
	
	
	$Log = (GetLogObject)
	$Log.LogTo = @($LogTo);
	$Log.LogLevel = $LogLevel;
	
			
	$Log | Invoke-Log "Script started!"
	
	
	#Preparing directorires...
	$SaveTo += '\'+(Get-Date).toString("yyyyMMdd_HHmmss");
	
	if(![IO.Directory]::Exists($SaveTo)){
		$Newdir = New-Item -Itemtype Directory -Path $SaveTo -force;
	}
	
	#Preparando o diretorio para receber os dados!
	$SaveToWinEvt = $SaveTo+'\winevents'
	if(![IO.Directory]::Exists($SaveToWinEvt)){
		$Newdir = New-Item -Itemtype Directory -Path $SaveToWinEvt -force;
	}

	$SaveToClusterLog = $SaveTo+'\clusterlog'
	if(![IO.Directory]::Exists($SaveToClusterLog)){
		$Newdir = New-Item -Itemtype Directory -Path $SaveToClusterLog -force;
	}
	
	#Preparando o diretorio para receber os dados!
	$SaveToSQLErrorLog = $SaveTo+'\sql'
	if(![IO.Directory]::Exists($SaveToSQLErrorLog)){
		$Newdir = New-Item -Itemtype Directory -Path $SaveToSQLErrorLog -force;
	}
	
	
	$Log.LogTo += ($SaveTo+'\log.txt');
	$Log | Invoke-Log "Base export directory is: $SaveTo. StartTime: $FilterStartTime. EndTime: $FilterEndTime"
	
	
	$ListComputersToCollect = @{};
	$ListSQLToCollect = @{};
	

	#Determines error log direcotry of SQL Server Instance! 
	Function GetErrorLogFiles {
		param($InstanceInfo)
		
		$Methods = @{
			QUERY_ERRORLOG = {
				$QueryToRun = "EXEC xp_readerrorlog 0,1,N'Logging SQL Server messages in file'"
				$LogMessages = ExecuteOnSQL -S $InstanceInfo.Address -Q $QueryToRun -LogObject $Log
				
				if($LogMessages){
					$LogText = @($LogMessages)[0].Text;
					
					#Extract the directory part..
					if($LogText -match "Logging SQL Server messages in file.+'([^']+)'"){
						return $matches[1];
					} else{
						$Log | Invoke-Log "	Reg exp cannot found directory on message $LogText" "VERBOSE";
						return $null;
					}	
				} else {
					$Log | Invoke-Log "	No results returned from xp_Readerrorlog..." "VERBOSE"
					return $null;
				}
				
			}
			
		}
		
		$ErrorLogLocation = $null;
		$Methods.GetEnumerator() | ?{!$ErrorLogLocation} | %{
			
			$Log | Invoke-Log "	Using method $($_.Key)" "DETAILED"
			try {
				$ErrorLogLocation = & $_.Value;
				if($ErrorLogLocation){
					if($ErrorLogLocation.trim().Length -eq 0){
						$ErrorLogLocation = $null;
					}
				}

			} catch {
				$Log | Invoke-Log "		Failed: $_" "DETAILED"
			}
		}
		
		
		if(!$ErrorLogLocation){
			throw 'CANNOT_DETERMINE_ERRORLOG_LOCATION'
		}
		
		
		If($Env:ComputerName -eq $InstanceInfo.CurrentComputer){
			$AllErrorLogFiles = gci ($ErrorLogLocation+'*')
		} else {
			$RemotePath = Local2RemoteAdmin $ErrorLogLocation $InstanceInfo.CurrentComputer;
			$Log | Invoke-Log "		Current computer is different of remote sql current... Path will be: $RemotePath" "DETAILED";
			$AllErrorLogFiles = gci ($RemotePath+'*');
		}
		


		if(!$AllErrorLogFiles){
			throw 'CANNOT_LIST_ERROR_LOG_FILES'
		}
		
		
		return $AllErrorLogFiles;
	}
	
	


	#If users specify a SQL Server instance, try get the computer name and SQLNodes, if available as cluster...
	if($SQLInstance){
		$SQLInstance | %{
			$Log | Invoke-Log "Connecting to instance $_ to get information about it..." "PROGRESS"
			
			$queryToRun = @(
				"IF SERVERPROPERTY('IsClustered') = 1 AND OBJECT_ID('sys.dm_os_cluster_nodes') IS NOT NULL"
				"	EXEC('select ComputerName = NodeName FROM sys.dm_os_cluster_nodes') "
				"ELSE"
				"	EXEC('SELECT ComputerName = ISNULL(SERVERPROPERTY(''ComputerNamePhysicalNetBIOS''),SERVERPROPERTY(''MachineName''))')"
			) -Join "`r`n"
			
			$Log | Invoke-Log "Getting cluster and nodes info... Query: $QueryToRun" "VERBOSE"
			$ComputerInfo = ExecuteOnSQL -S $_ -Q $queryToRun -LogObject $Log

			$queryToRun		= @"
				SELECT 
					CurrentComputer = ISNULL(SERVERPROPERTY('ComputerNamePhysicalNetBIOS'),SERVERPROPERTY('MachineName'))
					,ServerName = @@SERVERNAME
					,IsClustered = SERVERPROPERTY('IsClustered')
"@
			
			$Log | Invoke-Log "Getting another info about it... Query: $QueryToRun" "VERBOSE"
			$InfoResult 	= ExecuteOnSQL -S $_ -Q $queryToRun -LogObject $Log
			
			#Collect info about this instance...
			$InstanceInfo = NewInstanceInfo $_;
			$InstanceInfo.ServerName = $InfoResult.ServerName;
			$InstanceInfo.CurrentComputer = $InfoResult.CurrentComputer;
			$InstanceInfo.PossibleComputers = $ComputerInfo | %{$_.ComputerName};

			#Putting on computers list...
			$ComputerInfo | %{
				if($ListComputersToCollect.Contains($_.ComputerName)){
					$ComputerInfo =	$ListComputersToCollect[$_.ComputerName];
				} else {
					$ComputerInfo = NewComputerInfo $_.ComputerName;
					$ListComputersToCollect.add($_.ComputerName,$ComputerInfo)
				}

				if($InfoResult.IsClustered){
					$ComputerInfo.CollectClusterLog = $true;
				}
			}
	
			#Putting on SQLInstance list...
			
			if(!$ListSQLToCollect.Contains($InstanceInfo.ServerName)){
				$ListSQLToCollect.add($InstanceInfo.ServerName,$InstanceInfo);
			}
		}
	}
	
	
	
	#Coletando os logs do event viewer!
	$LogFilters = @{
		LogName = "System","Application"
		Level = 1,2,3
		startTime=$FilterStartTime
		endTime=$FilterEndTime
	}
	
	#Getting computers names to collect...
	$Order = 2;
	$ComputersToCollect = $ListComputersToCollect.GetEnumerator() | %{
		$Current = $_.Value;
		
		#Determine order... We must guaranteee the currently computer is collected first.
		#This is because with this, we guarantee that with a single command we collect all cluster log nodes...
		#If it fails, then we will attempt collect on each node...
		if($Env:ComputerName -eq $Current.ComputerName){
			$Current.CollectOrder = 1;
			$Current.IsCurrent = $true;
		} else {
			$Current.CollectOrder = $Order++;
		}
	
		#Returns current object to pipeline...
		$Current;
	};


	$ComputersToCollect | sort CollectOrder | %{
		$CurrentComputer = $_
		try {
			$Log | Invoke-Log "Connecting on $($CurrentComputer.ComputerName) to collect windows logs..." "PROGRESS"
			
			$Log | Invoke-Log "	Getting windows events..." "PROGRESS";
			$error.clear()
			$LogEvents  =  Get-WinEvent  -FilterHashtable $LogFilters -ComputerName $CurrentComputer.ComputerName -ErrorAction "SilentlyContinue" | SELECT LogName,TimeCreated,Id,Level,LevelDisplayName,ProviderId,ProviderName,MachineName,Message;
		
			if($error){
				$Log | Invoke-Log "	Errors was found in previous executions. The script will continue. Error was: " "PROGRESS"
				$error | %{
					$Log | Invoke-Log "		$_" "PROGRESS"
				}
			}
			
			$LogBaseName = (RemoveInvalidPathChars $CurrentComputer.ComputerName);
			$Destination = "$SaveToWinEvt\$LogBaseName.xml";
			
			$Log | Invoke-Log "	Exporting $($LogEvents.count) events to $Destination" "PROGRESS";
			$LogEvents | Export-CliXml $Destination;

			#Attempts collect errorlog of cluster...
			if($CurrentComputer.CollectClusterLog){
				try{
					$LogBaseName = (RemoveInvalidPathChars $CurrentComputer.ComputerName);
					$Destination = $SaveToClusterLog
					
					
					#Calculates timespan...
					$FilterTimeSpan = [int]((Get-Date)-$FilterStartTime).totalMinutes;


					$Log | Invoke-Log "	Destination: $Destination. TimeSpan: $FilterTimeSpan minutes" "DETAILED";


					#Just make some cluster log collection if current computer where scripts runs is part of a cluster...
					if($Env:ComputerName -eq $CurrentComputer.ComputerName){
						$Log | Invoke-Log "	Script will attempt collect cluster log of all nodes from current node..." "PROGRESS";
						
						#Attempts collect all cluster nodes log...
						try {
							import-module FailoverClusters -force;
							$CurrentNodes = Get-ClusterNode | %{$_.Name};
				
							$Log | Invoke-Log "	 Calling Get-ClusterLog..." "DETAILED";
							$AllLogs = Get-ClusterLog -Destination $Destination -Span $FilterTimeSpan

							$CurrentComputer.debug.add("CLUSTERLOG_ALLLOGS", $AllLogs);

							#Marks all nodes as collected! Note that will use previous hashtable with all objects... this is more fast to find...
							$CurrentNodes | %{ $ListComputersToCollect[$_].ClusterLogCollected = $true  };
						} catch {
							$CurrentComputer.errors += $_;
							$Log | Invoke-Log "	Failed to collect cluster log for all nodes on this node: $_" "PROGRESS";
						}
					} else {
						if($CurrentComputer.ClusterLogCollected){
							$Log | Invoke-Log "	 Cluster log for this computer already collected..." "DETAILED";
						} else {
							$Log | Invoke-Log "	 Script will attempt collect cluster log remotelly..." "DETAILED";

							#The logic is simple: Generate cluster log and return a path to it.
							#Then, uses Local2RemoteAdmin to generate a remote version of file.
							#This is because when copying inside remote command, access denfied is generated.
							#This, probally, is because some issue with credential delegations (its need another login to conenct remotelly...)

							$ScriptToCollect = {
								param($Params)
				
								$ErrorActionPreference="Stop";
								$ResultInfo = New-Object PSObject -Prop @{error=$null;logpath=$null}

								try {	
									import-module FailoverClusters;
									$Log = Get-ClusterLog -Span $Params.TimeSpan -Node $Env:ComputerName;
									$ResultInfo.logpath = $Log.FullName;
								} catch {
									$ResultInfo.error = $_;
								}
							
								return $ResultInfo;
							}

							$ScriptParams = @{TimeSpan=$FilterTimeSpan};
						
							try {	
								$Log | Invoke-Log "	Invoking remote script..." "DETAILED";
								$Result = Invoke-Command -ComputerName $CurrentComputer.ComputerName -ScriptBlock $ScriptToCollect -ArgumentList $ScriptParams
							} catch {
								throw "INVOKE_COMMAND_ERROR:_";
							}
							
							if($Result.error){
								$CurrentComputers.Errors += $Result.error;
								$Ex = New-Object Exception("REMOTE_SCRIPT_ERROR: $($Result.error)",  $Result.error);
								throw $ex;
							}
							
							
							if(!$Result.logpath){
								throw 'INVALID_CLUSTERLOG_REMOTENODE_PATH';
							}

							#At this point we have the remote path, just copy it...
							try {	
								$DestinationFromRemote = $SaveToClusterLog+'\'+$LogBaseName+'_cluster.log';
								$RemotePath = Local2RemoteAdmin $Result.logpath $CurrentComputer.ComputerName;
								$Log | Invoke-Log "	Copying from $RemotePath ($($Result.logpath)) to $DestinationFromRemote" "DETAILED";
								copy $RemotePath $DestinationFromRemote -force;
							} catch {
								throw "REMOTE_COPY_FAILED:  Original: $($Result.logpath) RemotePath: $RemotePath Error: $_"
							}

							$Log | Invoke-Log "	Collected sucessfully. Marking as collected!" "DETAILED";
							$CurrentComputer.ClusterLogCollected = $true;
						}
					}
					
				}catch{
					$CurrentComputer.Errors += $_;
					$Log | Invoke-Log "	Failed to collect cluster log on $($CurrentComputer.ComputerName): $_";
				} 
			}
		} catch {
			$CurrentComputer.Errors += $_;
			$Log | Invoke-Log "	Failed to collect on computer: $_";
			return; #Next computer...
		}
	}
	
	
	#Collect sql server error log files just for collection purposes!
	$SQLToCollect = $ListSQLToCollect.GetEnumerator() | %{$_.Value};
	$SQLToCollect | %{
		$CurrentInstance = $_;
		
		$Log | Invoke-Log "Collecting error logs of $($CurrentInstance.Address)..." "PROGRESS"
		
			
		try {
			$AllErrorLogFiles = GetErrorLogFiles $CurrentInstance;
			$_.ErrorLogFiles = $AllErrorLogFiles;
			
			#Filters!
			#	Get all files  StarTtime >= CreationTime <= EndTime
			
			$LogFiles = @($AllErrorLogFiles | ? { $_.CreationTime -ge $FilterStartTime -and $_.CreationTime -le $FilterEndTime  });
			#First file before startime...
			$LogFiles += $AllErrorLogFiles  | ? { $_.CreationTime -lt $FilterStartTime } | sort CreationTime -Desc | select -first 1 
			#First file after endtime...
			$LogFiles += $AllErrorLogFiles  | ? { $_.CreationTime -gt $FilterEndTime } | sort CreationTime | select -first 1
			
			$LogBaseName = (RemoveInvalidPathChars $CurrentInstance.ServerName);

			$LogFiles | ?{$_} | %{
				$CurrentLog = $_.FullName;
				$Destination = $SaveToSQLErrorLog+'\'+$LogBaseName +'_'+ $_.Name;
				try {
					$Log | Invoke-Log "	Copying log $($_.fullName) to $Destination" "PROGRESS"
					copy $_.FullName $Destination -force;
				} catch {
					$Log | Invoke-Log "Cannot copy $CurrentLog. Error: $_" "PROGRESS"
				}
				
			}
		} catch {
			$CurrentInstance.Errors += $_;
			$Log | Invoke-Log "Cannot collect error log: $_" "PROGRESS";
			return ; #goto next instance...
		}
		
	}

	$InternalFile = "$SaveTo\internalinfo.xml";
	$Log | Invoke-Log "Saving internal to $InternalFile" "PROGRESS";
	@{
		Params 				= (GetAllCmdLetParams)
		SQLToCollect		= $SQLToCollect
		ComputersToCollect	= $ComputersToCollect
		CurrentComputer		= $Env:ComputerName
		CurrentUser			= [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
	} | Export-CliXML $InternalFile;
	

	if($Zips){
		try{
			ZipDirectory $SaveTo;
		} catch {
			$Log | Invoke-Log "Zipping directory $SaveTo failed: $_" "PROGRESS";
		}
	}
	
	if($OpenFolder){
		explorer.exe $SaveTo;
	}


	
	$Log | Invoke-Log "Script executed successfuly!!!" "PROGRESS";

	if($ReturnsInternal){
		return (Import-CliXML $InternalFile); 
	}

	return;
		
	<#
		.SYNOPSIS 
			Collects useful loggin information on machines that have SQL Server installed!
			
		.DESCRIPTION
			This cmdlet allow you collect a lot of logs files from sql error log, event viewer, from multiple machines!
			Just specify a machine or sql instance and script will collect a useful logs.
			For example, if machine is clustered, all logs from all nodes is collected!

	#>
}	

