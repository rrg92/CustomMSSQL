#Check if a file can be accessed by specific lock type.
#You can test for S, or X.
#Based on http://stackoverflow.com/questions/876473/is-there-a-way-to-check-if-a-file-is-in-use

Function GetFileLockStatus {
	param($FileName,$AccessType = "X",[switch]$KeepOpen=$false)

	$r = New-Object PSObject -Prop @{
								locked=$null
								stream=$null
								lockType=$null
							}
	
	$FileShare = "None";
	switch($AccessType){
		default {
			throw "INVALID_ACCESS_TYPE: $AccessType";
			return;
		}
	}
	
	$r.lockType = $AccessType;
	
	if(!(Test-Path $FileName)){
		throw "INVALID_FILENAME"
		return;
	}

	$opened = $false;
	
    try {
		$fileinfo = [System.IO.FileInfo] $FileName
        $r.stream = $fileInfo.Open("Open","Read","Read")
		$opened = $true;
		$r.locked = $false;
		
		if($AccessType -eq  "X"){
			try {
				$lockingRes = SetFileLocking -Stream $r.stream -X;
				
				if(!$lockingRes){
					throw "CANNOT_X_LOCK"
				}
				
			} catch {
				$KeepOpen = $false;
				throw "ERROR_X_LOCKING: $_";
			}
		}
    } catch  {
       if(!$opened){
			throw New-Object System.Exception("CANNOT_S_LOCK")
	   }
    } finally {
	
		if($opened -and !$KeepOpen){
			 $r.stream.Dispose() | Out-Null
			 $r.stream = $null;
		}
	
	}
	


    return $r
}

#Try lock a file by a specific type.
#The sleep time specifies the time the functions will wait to file unlock.
#The attempt timeout specifies amount of milliseconds the function will try lock the file.
Function LockFile {
	param($File,$AccessType = "S", $SleepTime = 1000, $Timeout = 0)
	
	$StartTime = Get-Date;
	$EffectiveSleepTime = 0;
	$handle = New-Object PSObject -Prop @{lockStatus=$null;timedOut=$false};
	$firstTime = $true;
	
	do {
		
		if($firstTime){ #if first time.
			$firstTime = $false;
		} else {
			Start-Sleep -M $SleepTime;
		}
		
		$handle.lockStatus = GetFileLockStatus -FileName $File -AccessType $AccessType -KeepOpen
		
		if(!$handle.lockStatus.locked){
			return $handle;
		}
		
	} while( ((Get-Date)-$StartTime).totalMilliseconds -le $Timeout -or $Timeout -eq -1 )
	
	$handle.timedOut = $true;

	return $handle;
}

Function UnLockFile {
	param($Handle)


	if($Handle.lockStatus.stream){
		$Handle.lockStatus.stream.Dispose();
		return $true;
	}
		
	return $false;
}

Function SetFileLocking {
	param($stream,[switch]$S = $false,[switch]$X = $false)
	
	if(!$stream){
		throw "INVALID_STREAM";
	}
	
	if($S){
		$stream.UnLock(0,$stream.Length);
		return $true;
	}
	
	if($X){
		$stream.Lock(0,$stream.Length)
		return $true;
	}
	
	return $false;
}

Function ChangeFileLockType {

	param($Handle,$Type)
	
	$Action = "UnLock";

	if($Type = "S"){
		#Try UnLockFile...
		
		if($Handle.lockType -eq "X"){
			try {
				SetFileLocking -Stream $handle.lockStatus.stream -UnLock;
			} catch {
				throw "ERROR_UNLOCKING_FILE: $_";
				return $false;
			}
		}
	}
	
	if($Type = "X"){
		#Try Lock file...
		
		if($Handle.lockType -eq "S"){
			try {
				SetFileLocking -Stream $handle.lockStatus.stream;
			} catch {
				throw "ERROR_LOCKING_FILE: $_";
				return $false;
			}
		}
	}
	
	
	
	$s.lockType = $Type;
	return $true;
}

#Thanks https://msdn.microsoft.com/en-us/library/system.io.packaging.package(v=vs.110).aspx
Function CopyStream($source, $target) {
    [int]$bufSize = 0x1000;
    [byte[]]$buf =  New-Object byte[] $bufSize;
    [int]$bytesRead = 0;

	while ( ($bytesRead = $source.Read($buf, 0, $bufSize)) -gt 0){
        $target.Write($buf, 0, $bytesRead);	
	}
}


#Zip a directory...
Function ZipDirectory {
	param($FolderToZip, $FilePath = $null)


	if(![IO.Directory]::Exists($FolderToZip)){
		throw "DIRECOTRY_NOT_FOUND: $FolderToZip";
	}


	$FolderToPkg = Get-Item $FolderToZip;
	$AllFolderFiles = gci $FolderToPkg.FullName -recurse -include "*" | ? {!$_.PsIscontainer};

	#Creating a package...
	try {
		if($FilePath){
			if(-not $FilePath -match '[\\/]'){
				$FilePath = "$FolderToPkg\$FilePath"
			}
		} else {
			$FilePath =  "$FolderToPkg.zip"
		}

		$Pkg = [System.IO.Packaging.Package]::Open($FilePath, [Io.FileMode]"Create" );
	} catch {
		throw "MAIN_PACKAGE_CREATION_FAILED: $_";
		return $null;
	}

	try {
		#For each files...
		$AllFolderFiles |  %{
			#Gets a relative path, that is, without driver name...
			$RelativePath = '/'+(GetRelativePath $_.FullName -BaseDir ($FolderToPkg.FullName) -Slash);
			
			#Creating the uri that representa path to the file...
			$URI =  New-Object URI($RelativePath,[UriKind]::Relative);

			#Create the part that represents the file...
			$FilePart = $Pkg.CreatePart($URI,[System.Net.Mime.MediaTypeNames+Application]::Octet);

			#copy the source stream to the package stream!
			try {
				$SourceStream = New-Object IO.FileStream($_.FullName,"Open", "Read");

				if(!$SourceStream){
					throw "INVALID_STREAM_FOR: $_.FullName";
				}

				CopyStream -Source $SourceStream -Target ($FilePart.GetStream())
			} finally {
				if($SourceStream){
					$SourceStream.close();
				}
			}
			
		}

		$DeletePkg = $false;
		return $FilePath;
	} catch {
		$DeletePkg = $true;
		throw;
	} finally {
		$Pkg.close();

		if($DeletePkg){
			Remove-Item -Path $FilePath  -ea "SilentlyContinue" -force;
		}
	}
}