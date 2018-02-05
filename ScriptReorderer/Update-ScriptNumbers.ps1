<#
.SYNOPSIS
	Updates SQL upgrade script file numbers for a given range
.DESCRIPTION
	Defaults to reordering entire folder. Optionally re-number a subset starting from a specific start number
.NOTES
#>
function global:Update-ScriptNumbers{
	param(
	[Parameter(Position=1)]	
	[string]$PreviousVersion = "",
	[Parameter(Position=2)]
	[string]$NewVersion = "",
	[Parameter(Position=3)]
	[string]$StartScriptString = 0,
	[Parameter(Position=4)]
	[string]$EndScriptString = "",
	[Parameter(Position=5)]
	[string]$Path = (Get-Item -Path ".\" -Verbose).FullName,
	[Parameter(Position=6)]
	[int]$SeedNo = 0
	)

	if($EndScriptString.length -eq 0)
	{
		$files = ls $Path *.sql | where { $_.Name -gt $StartScriptString } | sort Name 
	}
	else
	{
		$files = ls $Path *.sql | where { $_.Name -gt $StartScriptString -and $_.Name -lt $EndScriptString } | sort Name 
	}

	$versionMatch = Get-Content -Path "$($files[0].FullName)" | %{ [Regex]::Matches($_, "\([\d,|\s,]+\)") } #| %{ $_.Value }
	$versionArray = $versionMatch.Value.split(",()")

	if ($PreviousVersion.Length -eq 0)
	{
		Write-Host "Looking for previous version number in $($files[0].FullName)"	
		$PreviousVersion = "$($versionArray[1]).$($versionArray[2]).$($versionArray[3]).$($versionArray[4])"
		Write-Host "Previous Version found $($PreviousVersion)"
	}

	if ($NewVersion.Length -eq 0)
	{
		Write-Host "Looking for current version number in $($files[0].FullName)"	
		$NewVersion = "$($versionArray[5]).$($versionArray[6]).$($versionArray[7]).$($versionArray[8])"
		Write-Host "Version found $($NewVersion)"
	}

	$files | % { Write-Host $_.Name }
	Read-Host "Press enter to re-number these files with previous version starting at $($PreviousVersion) and new version starting at $($NewVersion). File numbers will start from $($SeedNo)"
	
	# iterate over files, increment the version number in the file contents and also increment the name of each file
	Foreach ($file in $files )
	{
		$paddedNumber = $SeedNo.ToString("0#");
		$newName = $file.Name -replace '^\d+', $paddedNumber

		if($file.Name -eq $newName)
		{
			$SeedNo++	
			continue
		}

		$logName = [io.path]::GetFileNameWithoutExtension($newName) + ".log"
		$newContent = Get-Content -path "$($file.FullName)" | % { $_ -Replace "SPOOL\s[0-9]{2}_[0-9]{8}[\w|\/.]+", ("SPOOL " + $logName) }
		Set-Content -Path "$($file.FullName)" -Value $newContent
		
		$commaSeparatedNewVersionNo = $NewVersion -replace "\.", ","
		$commaSeparatedPreviousVersionNo = $PreviousVersion -replace "\.", ","
		$commaSeparatedOldAndPreviousVersionNos = $commaSeparatedPreviousVersionNo + "," + $commaSeparatedNewVersionNo
		
		$newCheckDbVersionString = "CMS_ESM.DB_MAINTENANCE.CHECK_DBVERSION(" + $commaSeparatedOldAndPreviousVersionNos + ");";
		$newContent = Get-Content -path "$($file.FullName)" | % { $_ -Replace "CMS_ESM.DB_MAINTENANCE.CHECK_DBVERSION\([\d|\s|,]+\);", ("CMS_ESM.DB_MAINTENANCE.CHECK_DBVERSION($($commaSeparatedOldAndPreviousVersionNos));") }
		Set-Content -Path "$($file.FullName)" -Value $newContent
		
		$newUpdateDbVersionString = "CMS_ESM.DB_MAINTENANCE.UPDATE_DBVERSION("+ $commaSeparatedNewVersionNo + ", '" + $newName + "', true);"
		$newContent = Get-Content -path "$($file.FullName)" | % { $_ -Replace "CMS_ESM.DB_MAINTENANCE.UPDATE_DBVERSION\([\w|,|\s|\'|\.]+\);", ($newUpdateDbVersionString) }
		Set-Content -Path "$($file.FullName)" -Value $newContent
		
		$PreviousVersion = $NewVersion
		$arrVersionNo = $NewVersion -split '\.'
		$arrVersionNo[3] = ([int]$arrVersionNo[3] + 1)
		$NewVersion = $arrVersionNo[0] + "." + $arrVersionNo[1] + "." + $arrVersionNo[2] + "." + $arrVersionNo[3]
		
		Write-Host "Renaming $($file.Name) to $($newName)"
		$file | Rename-Item -NewName $newName
		$SeedNo++
	}
}

Set-Alias upsn Update-ScriptNumbers