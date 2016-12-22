<#
	$ErrorLogEntries = $SaveToCopies | %{
			
			$Lines = Get-Content $_;
			
			#Five first lines just header informations...
			if($Lines.Length -ge 6){
				$PreviousObject = $null;
				5..($Lines.Length-1) | %{
					
					if($Lines[$_] -match '^\d{4}-\d{2}-\d{2}'){
						$LineParts = ($Lines[$_] -split " ",4);
						$DateString = $LineParts[0]+' '+$LineParts[1]+'0';
						$Props.TimeCreated = [Datetime]::ParseExact($DateString,"yyyy-MM-dd HH:mm:ss.fff",[Globalization.CultureInfo]::InvariantCulture)
						$Props.ProviderName = $LineParts[2];
						$Props.Message = $LineParts[3].trim();
						$PreviousObject = New-Object PsObject -Prop $Props;
						$PreviousObject;
					} else {
						if($PreviousObject){
							$PreviousObject.message += $Lines[$_];
						}
					}
					
					
				}
			}
		}
#>