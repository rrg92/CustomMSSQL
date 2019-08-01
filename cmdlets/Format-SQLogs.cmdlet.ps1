Function Format-SQLogs {
	[CmdLetBinding(SupportsShouldProcess=$True)]
	param(
		#Specify directory where the logs was saved using Get-SQLogs
			$Source

		,#Generate a detailed report in excel
			[switch]$ReportEx
			
		,#Generates internal information for debugging...
		 #A file that can be used import-clixml will be exported. Check command output to determine file.
			[switch]$GenerateInternal = $false
			
		,[switch]$ReturnsInternal
		
		,[switch]$ShowProgress = $false
		
		,[switch]$OpenFolder = $false
		
		,$LogTypes = @("CLUSTERLOG","WINEVENTS")
	)
	
	$ErrorActionPreference = "Stop";
	$IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
	

	#Defining some functions and configurations for script...
		
	$GMV = GetGMV
	$CmdLetBaseFolder = "$($GMV.CMDLETSIDR)\Format-SQLog\libs"
	
	if(![IO.Directory]::Exists($Source)){
		throw "SOURCE_DIRECTORY_NOT_FOUND: $Source"
	}

	#Loading the internal dtabase...
	$Internal = $null;
	$InternalFileName = 'internalinfo.xml';
	if([IO.File]::Exists("$Source\$InternalFileName")){
		$Internal = Import-CliXml "$Source\$InternalFileName";
	}

	if(!$Internal){
		throw 'CANNOT_LOAD_INTERNAL_DATABASE.'
	}

	#Creating the format
	write-host "Creating the output base dir..."
	$OutputBaseDir 	= "$Source\!formatted";
	$NewDir			= New-Item -ItemType Directory -force -Path $OutputBaseDir;

	write-host "Output dir will be $OutputBaseDir";
	
	#This all database containing the collectors.
	$ExternalInfo = @{
		Source = $Source;
		internal = $Internal
		ErrorLines = @();
	}
	
	$LogEntriesCollectors = @{
		WINEVENTS = NewLogCollector "$Source\winevents" {
						
						#The winevents must contain all exported xml log entries!
						gci ("$($this.BaseFolder)\*.xml") | %{
							try {
								write-host "	Importing file $($_.Name)";
								$AllLogEntries += Import-CliXMl $_.FullName
							} catch {
								write-host "	Failed: $_";
							}
						}
						
						return $AllLogEntries;
				}
				
		SQLLOG = NewLogCollector "$Source\sql" {
						
						#The winevents must contain all exported xml log entries!
						$AllLogEntries = @()
						gci $this.BaseFolder | %{
							try {
								write-host "	Reading file $($_.Name)";
								$FileContent = Get-Content $_.FullName;
								
								$FileContent | %{
									$CurrentRow = $_;
									
									if($CurrentRow -match '^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d.\d\d) (.+)'){
										
										if($CurrentDate){
											#Save previous;;;
											$E = New-Object PSObject -Prop $OutputColumns;
											$E.LogName = 'SQLLOG';
											$E.TimeCreated = $CurrentDate
											$E.Id = 0;
											$E.Level = '?';
											$E.ProviderName = ($Buffer[0] -Split '\s+',2)[0]
											$E.MachineName = 'localhost';
											$E.Message = $Buffer -Join "`r`n";
											
											
											
											$AllLogEntries += $E;
										}
										
										$CurrentDate  = Get-Date $matches[1]
										$Buffer		  = @(
												$matches[2]
											)
									} else {
										$Buffer	 += $_;
									}	
									
								}
								
								#$AllLogEntries += Import-CliXMl $_.FullName
							} catch {
								write-host "	Failed: $_";
							}
						}
						
						return $AllLogEntries;
				}
				
		CLUSTERLOG = NewLogCollector "$Source\clusterlog" {
		
						
						#Getting all computers involved!
						$ExternalInfo = $this.ExternalInfo;
						$Computers = $ExternalInfo.internal.ComputersToCollect | %{$_.ComputerName};
						
						
						
						if($Computers){
							write-host "	Source computers was: $Computers"
						} else {
							write-host "	Cannot retrieve computers list of internal database..."
						}
						
						
						$OutputColumns = $ExternalInfo.OutputColumns;
						$OutputColumns.LogName = "CLUSTER";
						
						
						#The winevents must contain all exported xml log entries!
						$this.debuginfo.add("files", @{});
						$AllLogEntries = @();
						gci ("$($this.BaseFolder)\*.log") | %{
							$CurrentFileDebugInfo = @{}
							$this.debuginfo.files.add($_.name,$CurrentFileDebugInfo);
							
							$LogSourceComputer = $null
							$Computers | ?{!$LogSourceComputer} | %{
								#If current computer match the log name, then it is where log was generated...
								if( $_ -match "^$_[._]*.*" ){
									$LogSourceComputer = $_;
								}
							}
							
							if(!$LogSourceComputer){
								write-host "	Cannot determine source computer of the file $($_.Name)";
							}
							
							#Extracting records... Based on https://technet.microsoft.com/en-us/library/cc962179.aspx?f=255&MSPPError=-2147217396
							
							
							$i = 0;
							$CurrentFile = $_.name;
							$PreviousEntry = $null;
							$OutputColumns.MachineName = $LogSourceComputer;
							$LogEntries = Get-Content $_.FullName |  %{
								try {
									$i++;
									$CurrentLine		 = $_;
									$ProcessThreadReg 	= '([0-9a-z]+)\.([0-9a-z]+)'
									$TimestampReg 		= '(\d{4}/\d{2}/\d{2}-\d{2}:\d{2}:\d{2}.\d{3})'
									#$ComponentName		= '(\[[^\]]+\])'
									$LogLevelReg		= '([^\s]+)'
									
									$GeneralFormat 	= "^$ProcessThreadReg::$TimestampReg $LogLevelReg\s+(.+)"
									
									#If line starts with space or tabs... it is part of previous message...
									if($_ -match "^[`t`s].+"){
										if($PreviousEntry){
											$PreviousEntry.message += $_;
										}
										return;
									}
									
									if($_ -match $GeneralFormat){
										$Level = $matches[4];							
										
										if($Level -eq 'INFO'){
											return; #Next object...
										}
										
										$LogTime = $matches[3];
										
										try {
											$TimeCreated = [Datetime]::ParseExact($LogTime,'yyyy/MM/dd-HH:mm:ss.fff',$null, [Globalization.DateTimeStyles]::AdjustToUniversal);
										} catch {
											throw 'CANNOT_CONVERT_DATETIME';
										}
										
										
										$OutputColumns.TimeCreated = $TimeCreated.toLocalTime();
										$OutputColumns.Level = $Level
										$OutputColumns.Message = $matches[5];
										$E = New-Object PSObject -Prop $OutputColumns;
										$PreviousEntry = $E;
										return $E;
									} else {
										throw 'DONT_MATCH_PATTERN'
									}
								} catch {
									$ExternalInfo.ErrorLines += NewErrorLine $CurrentFile $i $CurrentLine $_;
								}
							}
							
							$AllLogEntries += $LogEntries;
							$CurrentFileDebugInfo.add("LogEntries", $LogEntries);
							$CurrentFileDebugInfo.add("ErrorLines", $ExternalInfo.ErrorLines);
							

						}
						
						return $AllLogEntries;
				}
	}
	
	#This is the output table!
	$OutputColumns = @{
		#This is de lognmae.
		#	Logs from cluster will have "CLUSTER" name.
		LogName = ''

		#Data of the log entrie
		TimeCreated = ''

		#Id of the event...
		Id = ''

		#Numeric Level of the entry...
		Level = ''

		#Provider name of the event
		ProviderName = ''

		#Computer where event is generated...
		MachineName = ''

		#The event message...
		Message = ''
	}
	$ExternalInfo.add("OutputColumns", $OutputColumns)
	$OutputColumnsNames = @($OutputColumns.keys|%{$_.toString()})

	if($ReportEx){
		write-host "Generating and extended reporting. Log Types: $LogTypes";

		#This will contains all logging to be exported, from all log files!
		$AllLogEntries = @()
		$AllErrors = @();


		#Translating logs to powershell objects...
		$LogEntriesCollectors.GetEnumerator()  | %{
			$CollectorName = $_.Key;
			$Collector = $_.Value;
			$Collector.ExternalInfo = $ExternalInfo;
			
			if($LogTypes -NotContains $CollectorName){
				return; #Next collector...
			}
			
			if(![IO.Directory]::Exists($Collector.BaseFolder)){
				write-host "	$($Collector.BaseFolder) not exists. Nothing to do.";
				return; #next collector!
			}

			write-host "Calling collector $CollectorName. Base folder: $($Collector.BaseFolder)"
			try {
				$ExternalInfo.ErrorLines = @();
				$Logs += $Collector.getLogEntries();
				
				if($ExternalInfo.ErrorLines){
					$AllErrors += $ExternalInfo.ErrorLines
				}
				
				if($Logs){
					$AllLogEntries += $Logs | select -Property $OutputColumnsNames;
				}
			} catch {
				write-host "	Error on collector: $_"
			}
		}
		
		ImportDependencieModule 'ImportExcel'
		
		if($AllLogEntries){
			
			
			$total = $AllLogEntries.count;
			write-host "Exporting logs... (Total entries: $($total))"
			$Start = Get-Date;
			if($ShowProgress){
				$i = [decimal]0;
				$AllLogEntries | %{$i++; $percent = [int](($i/$total)*100.00); write-progress -Activity 'Exporting logs' -PercentComplete $percent -Status "($i/$total) exported [$percent%]"
					$_} | Export-Excel -WorkSheetName 'Logs' -WorkSheetName 'Logs' -Path "$OutputBaseDir\ReportEx.xlsx"
			} else {
	

				$AllLogEntries | Export-Excel -WorkSheetName 'Logs' -TableName 'Logs' -Path "$OutputBaseDir\ReportEx.xlsx"

				
			}
			
			write-host "Export time: $( (Get-Date)-$Start )";
		}
		
		if($AllErrors){
			write-host "Exporting errors"
			$AllErrors |  Export-Excel -WorkSheetName 'Errors' -Path "$OutputBaseDir\ReportEx.xlsx"
		}
		
	
	}

	$Internal = @{
		AllLogEntries = $AllLogEntries
		Collectors = $LogEntriesCollectors
	}
	
	if($GenerateInternal){
		$InternalOutputPath = $OutputBaseDir+'\internalinfo.xml';
		write-host "Generating internal to $InternalOutputPath";
		$Internal | Export-CliXML $InternalOutputPath;
		
		if($ReturnsInternal){
			return Import-CliXML $InternalOutputPath
		}
	}

	if($OpenFolder){
		explorer.exe $OutputBaseDir
	}
	
		
	<#
		.SYNOPSIS 
			Formats and analyze logs generated by Get-SQLogs cmdlet!
			
		.DESCRIPTION
			This cmdlet allows user formats and generate many data absed on collect information by SQLLogs.

	#>
}	

#This contains a object that represents a log collector!
#Collectors are scripts that understand each log type to be tranlated on powershell objects.
#For each file, the log collector can extract your files informations...
Function NewLogCollector {
	param($BaseFolder, $Script)
	
	$o = New-Object PsObject -Prop @{
				BaseFolder = $BaseFolder
				externalInfo = $null
				debuginfo = @{}
		}
		
	$o | Add-Member -Type ScriptMethod -Name "getLogEntries" -Value $Script;
	
	return $o;
}

#create a error line object..
Function NewErrorLine {
	param($file,$num,$Line, $Error)
	
	return New-Object PsObject -Prop @{file=$file;num=$num;line=$line;error=$Error};
}