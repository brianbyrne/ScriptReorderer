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
	[string]$StartScriptString = "",
	[Parameter(Position=4)]
	[string]$EndScriptString = "",
	[Parameter(Position=5)]
	[string]$Path = (Get-Item -Path ".\" -Verbose).FullName,
	[Parameter(Position=6)]
	[int]$SeedNo = 0
	)

	if 	($EndScriptString.length -eq 0)
	{
		$files = ls $Path *.sql | where { $_.Name -gt $StartScriptString } | sort Name 
	}
	else
	{
		$files = ls $Path *.sql | where { $_.Name -gt $StartScriptString -and $_.Name -lt $EndScriptString } | sort Name 
	}

	if ($PreviousVersion.Length -eq 0)
	{
		$PreviousVersion = Read-Host "Please enter a previous number, i.e. the previous version before $($files[0])"
	}

	#Operate on SQL files
	$files | % { Write-Host $_.Name }
	Read-Host "Press enter to re-number these files with previous version starting at $($PreviousVersion) and new version starting at $($NewVersion). File numbers will start from $($SeedNo)"
	
	#for each file rename and update contents
	Foreach ($file in $files )
	{
		$paddedNumber = $SeedNo.ToString("0#");
		$newName = $file.Name -replace '^\d+', $paddedNumber
		
		$logName = [io.path]::GetFileNameWithoutExtension($newName) + ".log"
		$newContent = Get-Content -path "$($file.FullName)" | % { $_ -Replace "SPOOL\s[0-9]{2}_[0-9]{8}[\w|\/.]+", ("SPOOL " + $logName) }
		Set-Content -Path "$($file.FullName)" -Value $newContent
		
		$commaSeparatedNewVersionNo = $NewVersion -replace "\.", ","
		$commaSeparatedPreviousVersionNo = $PreviousVersion -replace "\.", ","
		$commaSeparatedOldAndPreviousVersionNos = $PreviousVersion + "," + $NewVersion
		
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