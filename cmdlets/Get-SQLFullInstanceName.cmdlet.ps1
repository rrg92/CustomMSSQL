Function Get-SQLFullInstanceName {
	[CmdLetBinding()]
	param(
		
		#Specify a instance. The default is defualt instance "MSSSQLSERVER"
			$InstanceName = $null
		
		
		,#Force script to query information about all instances.
			[switch]$All
			
		,#Forces scripts to get version number of each instance found in registry
		 #This not connect to sql server, intead, its query registru with this information.	
			[switch]$GetVersion = $false
			
		,#Computer where registry will be queried.
		 #By default, uses currently computer. The users executing must have appropriate permisisons.
			$ComputerName = $null
		
	)

	$ErrorActionPreference = "Stop";


	try {
		$Registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName);
	} catch {
		throw "FAILED_OPEN_REGISTRY: Computer: $ComputerName"
	}
	
	try {
	 
		if(!$InstanceName) {
			$InstanceName = "MSSQLSERVER"
		}
		 
		if($All){
			$InstanceName = $null
		}
		
		$InstanceNamesKeyPath = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
		$InstanceNamesKey = $Registry.OpenSubKey($InstanceNamesKeyPath);
		
		 
		if($InstanceNamesKey){
			$FullNamesInfo = @();
			
			#instances to query!
			$InstancesNamesToQuery = @();
			
			if($InstanceName){
				$InstancesNamesToQuery = $InstanceName;
			} else {
				write-verbose "Getting all instance names on subkey $($InstanceNamesKey.Name)"
				$InstancesNamesToQuery = $InstanceNamesKey.GetValueNames();
			}
			
			write-verbose "Instance names to query: $InstancesNamesToQuery"
			
			#Getting info...
			$InstancesNamesToQuery | %{
				$QueriedFullName  = $InstanceNamesKey.GetValue($_);
				
				if($QueriedFullName){
					$FullNamesInfo += New-Object PSObject -Prop @{InstanceName=$_;FullName=$QueriedFullName;Version=$null;Errors=@{};IsLegacy=$False};
				}
			}
		} else {
			write-verbose "Key $InstanceNamesKeyPath not found..."
		}

		#Query for SQL Server 2000 instances...
		$InstanceNamesKeyPath2000 = 'SOFTWARE\Microsoft\Microsoft SQL Server'
		$InstanceNamesKey2000 = $Registry.OpenSubKey($InstanceNamesKeyPath2000);
		
		if($InstanceNamesKey2000){
			#instances to query!
			$InstancesNamesToQuery = @();
			
			if($InstanceName){
				$InstancesNamesToQuery = $InstanceName;
			} else {
				write-verbose "Getting all instance names on subkey $($InstanceNamesKey2000.Name), Value InstalledInstances"
				$InstalledInstances = $InstanceNamesKey2000.GetValue("InstalledInstances");
				
				if($InstalledInstances){
					$InstancesNamesToQuery = $InstalledInstances -split " ";
				}
			}
			
			write-verbose "Instance names to query: $InstancesNamesToQuery"
			
			#Getting info...
			$InstancesNamesToQuery | %{
				$FullNamesInfo += New-Object PSObject -Prop @{InstanceName=$_;FullName=$null;Version=$null;Errors=@{};IsLegacy=$True};
			}
		}else {
			write-verbose "Key $InstanceNamesKeyPath2000 not found..."
		}
		
		
		
		if($GetVersion){
			$VersionPathKeyTemplate = 'SOFTWARE\Microsoft\Microsoft SQL Server\{0}\MSSQLServer\CurrentVersion'
		
			#For each instance...
			$FullNamesInfo | ?{!$_.IsLegacy} | %{
				$CurrentVersionKeyPath = $VersionPathKeyTemplate -f $_.FullName;
				
				#Opens the key!
				$CurrentVersionKey = $Registry.OpenSubKey($CurrentVersionKeyPath);
				
				if(!$CurrentVersionKey){
					$_.Errors.add("VERSION", "NotFoundKey: $CurrentVersionKeyPath" );
					return; #Next instance...
				}
				
				#Get the value!
				$Version = $CurrentVersionKey.GetValue("CurrentVersion");
				
				if(!$Version){
					$_.Errors.add("VERSION", "NotFoundValue:CurrentVersion" );
					return; #Next instance...
				}
				
				$_.Version = $Version;
			}
		}

		return $FullNamesInfo;
	} catch {
		throw ;
	} finally {
		$Registry.Close(); #Gurantees the registry connection will close always...
	}
	

	<#
		.SYNOPSIS 
			Query registru to get information about SQL Server instance.
			
		.DESCRIPTION
			This cmdlets check SQL Server registry keys to query information about SQL Server version information and instance names (Version based)
	#>
}