Function ExecuteOnSQL {
	param($S,$d,$Q,$U,$P,$i,[switch]$IgnoreExceptions = $false, $LogObject = $null)
			
			$cmdparams = @{
				ServerInstance=$S
				Database=$d
			}
			if($U){
				$cmdparams.add("Login",$U)
				$cmdparams.add("Password",$P)
			}
												
			if($Q){
				$cmdparams.add("Query",$Q)
			}
			
			if($i){
				$cmdparams.add("InputFile",$i)
			}

		try {
			$results = Invoke-NewQuery @cmdparams;	
			return $results;
		} catch {
			if($LogObject){
				$LogObject | Invoke-Log $_ "PROGRESS";
			}
			 
			if(!$IgnoreExceptions){
				throw "MSSQL_ERROR: Last executed script failed! Check previous erros in log."
			}
		}
}

#Creates a custom o object with instance info...
Function NewInstanceInfo {
	param($InstanceAddress)
	
	return New-Object PSObject -Prop @{
			#The Instance identifier.
			Address = $InstanceAddress
			
			#The server name of the instance! @@SERVERNAME
			ServerName = $null
			
			#The currently computer where instance is running (physical node!)
			CurrentComputer = $null
			
			#All possible computers where instance can run!
			PossibleComputers = @()

			#Objects that represents original path to the error log file!
			ErrorLogFiles = @()

			#Indicates that instance is clustered!
			IsClustered = $false

			#Exceptions and errors encountered in process...
			Errors = @()

			#A flag to control that cluster log for nodes of this instance already collected...
			
		}

}

#Creates a custom o object that represent computer informations...
Function NewComputerinfo {
	param($ComputerName)
	
	return New-Object PSObject -Prop @{
			#The Instance identifier.
			ComputerName = $ComputerName
			
			#The server name of the instance! @@SERVERNAME
			CollectClusterLog = $false

			#this indicates that cluster node for this onde already collected.
			ClusterLogCollected = $false

			#indicates that this is currently computer!
			IsCurrent = $false;

			#Controls the order of this computer on collectio process...
			CollectOrder = 0

			#Exceptions and errors encountered in process...
			Errors = @()

			#debug data...
			debug = @{};
		}

}


