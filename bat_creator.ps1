<#
.DESCRIPTION
    A console-based UI to create a .bat file that calls update_index.ps1 with parameters.
#>

param(
    [string]$RootDirectory = "C:\Users\leo--"
)

Write-Host "================================================================="
Write-Host "   Create .BAT file for update_index.ps1"
Write-Host "================================================================="
Write-Host "Root directory: $RootDirectory`n"

# Function to select folder with search
function Get-FolderFromUser {
    param([string]$RootDir)
    
    while ($true) {
        $searchTerm = Read-Host "`nEnter folder name part to search"
        if (-not $searchTerm) { 
            Write-Warning "Please enter a search term"
            continue
        }

        $allDirs = @(Get-ChildItem -Path $RootDir -Directory -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*$searchTerm*" })
        
        if (-not $allDirs) {
            Write-Warning "No folders found matching '$searchTerm'"
            continue
        }

        Write-Host "`nMatching folders:"
        $i = 0
        $allDirs | ForEach-Object { Write-Host "[$i] $($_.FullName)"; $i++ }

        $choice = Read-Host "`nEnter folder number (or blank to search again)"
        if (-not $choice) { continue }
        if ($choice -match "^\d+$" -and [int]$choice -lt $allDirs.Count) {
            return $allDirs[$choice].FullName
        }
        else {
            Write-Warning "Invalid selection"
        }
    }
}

# Get target folder and calculate relative path
$TargetFolder = Get-FolderFromUser -RootDir $RootDirectory
$relativePath = $TargetFolder.Substring($RootDirectory.Length).TrimStart('\')

Write-Host "`nSelected folder: $TargetFolder"
Write-Host "Relative path: $relativePath`n"

# Get parameters
do {
    $SortBy = Read-Host "Sort by (name/date/none)"
} while ($SortBy -notin @('name', 'date', 'none'))

$IncludeSubfolders = (Read-Host "Include subfolders? (y/n)").Trim() -match '^y'
$WhatIf = (Read-Host "Use -WhatIf? (y/n)").Trim() -match '^y'
$OutputFile = Read-Host "Output filename [_index.md]"
if (-not $OutputFile) { $OutputFile = "_index.md" }

# Build BAT file content
$includeSwitch = if ($IncludeSubfolders) { "-IncludeSubfolders" } else { "" }
$whatIfParam = if ($WhatIf) { "-WhatIf" } else { "" }

$batContent = @"
@echo off
setlocal

set "VaultPath=%~1"
if "%VaultPath%"=="" set "VaultPath=$RootDirectory"

powershell -NoProfile -ExecutionPolicy Bypass -File "update_index.ps1" ^
    -VaultPath "%VaultPath%" ^
    -TargetFolder "$relativePath" ^
    -SortBy $SortBy ^
    $includeSwitch ^
    $whatIfParam ^
    -OutputFile "$OutputFile"

endlocal
"@

# Save BAT file

$lastFolderOfRoot = Split-Path -Path $RootDirectory -Leaf
$lastFolderOfRelative = Split-Path -Path $relativePath -Leaf

$batFileName = "indexGenerator_$lastFolderOfRoot`_$lastFolderOfRelative.bat"

$batContent | Out-File $batFileName -Encoding ASCII

Write-Host "`nCreated batch file: $batFileName"