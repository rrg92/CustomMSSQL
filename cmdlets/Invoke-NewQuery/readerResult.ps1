Function ReaderResultRest {
	param($RsReader)
		$reader = $RsReader.reader
		$totalColumns = $i = $reader.FieldCount
		[array]$resultset = @()
		
		if($RSReader.readCount -ge 1){
			write-verbose "Getting next result!"
			$RsReader.hadNext = $reader.NextResult()
		}
		
		$RSReader.readCount++;

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
}