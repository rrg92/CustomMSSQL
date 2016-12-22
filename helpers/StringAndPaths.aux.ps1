Function Right($str,$qtd = 1){
	return $str.substring($str.length - $qtd, $qtd)
}

Function PutFolderSlash($folder, [switch]$Slash = $false ){
	
	if(!$folder.EndsWith([System.IO.Path]::DirectorySeparatorChar)){
		$folder += [System.IO.Path]::DirectorySeparatorChar
	}
	
	return $folder;
}

Function IsDirectory {
	param($Path)
	
	$attrs = [System.IO.File]::GetAttributes($Path);
	$dirattr = [System.IO.FileAttributes]::Directory
	return (($attrs -band $dirattr) -eq $dirattr) -as [bool]
}


Function RemoveInvalidPathChars {
	param($String, $ReplaceBy = "")
	
	if($String){
		@([IO.Path]::GetInvalidPathChars() + [IO.Path]::GetInvalidFileNameChars()) | sort -unique | %{$_.toString()} | %{
			$String = $String.replace($_,$ReplaceBy);
		}
	}
	
	return $String;
}


#Adiciona uma barra no final do diretório, se não houver!
Function  AddDirSlash {
	param($Dir)
	
	if(!$Dir.EndsWith([System.IO.Path]::DirectorySeparatorChar)){
		$dir += [System.IO.Path]::DirectorySeparatorChar
	}
	
	return $Dir;
}

#Transforms absolute path in relative.
#Thanks to http://stackoverflow.com/questions/703281/getting-path-relative-to-the-current-working-directory/703290#703290
Function GetRelativePath
{
	param($FullPath, $BaseDir = $null, [switch]$Slash = $false)

	$FullURI 	= New-Object URI($FullPath);
	
	#the dir must ends with a bar...
	if(!$BaseDir){
		$BaseDir = [IO.Path]::GetPathRoot($FullPath)
	}
	
	$BaseDir = PutFolderSlash $BaseDir
	
	$BaseURI = New-Object URI($BaseDir);
	
	if($Slash){
		return $BaseURI.MakeRelative($FullURI);
	} else {
		return $BaseURI.MakeRelative($FullURI).replace('/',[System.IO.Path]::DirectorySeparatorChar);
	}
	
	
}


#Transforms and local path to a network admin share letter$ for a server!
#If path is
Function Local2RemoteAdmin {
	param($Path, $RemoteAddress = $Env:ComputerName)

	$URI = New-Object URI($Path);

	if(!$URI.IsUnc){
		if($Path -match '^[a-z]:\\'){
			return $Path -replace '^([a-z]):\\',"\\$RemoteAddress\`$1`$\"
		} else {
			return $Path;
		}
	} else {
		return $Path;
	}
}