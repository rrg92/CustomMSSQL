param($S,$Q,$D="master",[switch]$MultipleRS = $false)

$ErrorActionPreference="stop";
#Save current location
push-location
#Change current location
set-location (Split-Path -Parent $MyInvocation.MyCommand.Definition )

Function New-RSReader {return New-Object PSObject -Prop @{reader=$null;readCount=0;hadNext=$null}};
Function Get-RS {param($RSReader) return ReaderResultRest($RSReader) };
Function Close-Connection {param($c) $c.Dispose()}

try{

	. ".\readerResult.ps1"
	

#Creating the connection 
	$ConnectionString = @(
		"Server=$($S)"
		"Database=$($D)"
		"Integrated Security=True"
	)

	if(!$Pooling){
		$ConnectionString += "Pooling=false"
	}
	
	try {
		$NewConex = New-Object System.Data.SqlClient.SqlConnection
		$NewConex.ConnectionString = $ConnectionString -Join ";" 
		$NewConex.Open()
		
		$commandTSQL = $NewConex.CreateCommand()
		$commandTSQL.CommandText = $Q
		$commandTSQL.CommandTimeout = 0;
		$result = $commandTSQL.ExecuteReader()
		$r = New-RSReader
		$r.reader = $result;
		$r 
	} finally {
	
		if($NewConex -and !$MultipleRS){
			write-host "Disposing connection!"
			$Newconex.Dispose()
		}
	
	}
	
} finally {
	pop-location
}