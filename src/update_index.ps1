<#
.SYNOPSIS
Generates hierarchical Obsidian indexes with nested folder support.

.DESCRIPTION
Creates index.md files with:
- YAML front matter
- Folder name headers
- Indented subfolder structures
- Configurable sorting

.PARAMETER TargetFolder
Relative path to folder in your vault (e.g., "Projects" or "Notes/Work")

.PARAMETER SortBy
Sorting method: 'name' (default), 'date', or 'none'

.PARAMETER IncludeSubfolders
Include nested directories with indented hierarchy

.PARAMETER WhatIf
Preview changes without file modification

.EXAMPLE
./update_index.ps1 -TargetFolder "Research" -IncludeSubfolders
./update_index.ps1 -TargetFolder "Notes/ClientA" -SortBy date -WhatIf
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetFolder,
    
    [ValidateSet('name', 'date', 'none')]
    [string]$SortBy = 'name',
    
    [switch]$IncludeSubfolders,
    
    [switch]$WhatIf,

    [string]$VaultPath = "",

    [string]$OutputFile = "_index.md"
)

# ========== PATH VALIDATION AND FILE PROCESSING ==========
$folderPath = Join-Path -Path $VaultPath -ChildPath $TargetFolder
$indexFile = Join-Path -Path $folderPath -ChildPath $OutputFile

if (-not (Test-Path $folderPath)) {
    Write-Error "Target folder not found: $folderPath"
    exit 1
}

$params = @{
    Path = $folderPath
    Filter = "*.md"
    File = $true
}

if ($IncludeSubfolders) { $params.Recurse = $true }

$files = Get-ChildItem @params | 
         Where-Object { $_.Name -ne $OutputFile }

# ========== SORT DEFINITION==========
switch ($SortBy) {
    'name'  { $files = $files | Sort-Object Name }
    'date'  { $files = $files | Sort-Object LastWriteTime -Descending }
    'none'  { <# No sorting #> }
}

# ========== CONTENT GENERATION ==========
$folderName = Split-Path -Path $TargetFolder -Leaf

$frontMatter = @"
---
tags: index
auto-generated: true
updated: "$(Get-Date -Format "yyyy-MM-dd HH:mm")"
sort: $SortBy
---

# Index of $folderName
"@

if ($IncludeSubfolders) {
    $content = $files | Group-Object {
        $relPath = $_.FullName.Substring($folderPath.Length + 1).Replace('\', '/') -replace '\.md$', ''
        if ($relPath -match '/') { 
            ($relPath -split '/' | Select-Object -First 1)
        } else {
            '[root]'
        }
    } | Sort-Object {
        if ($_.Name -eq '[root]') { 0 } else { 1 }
    } | ForEach-Object {
        if ($_.Name -eq '[root]') {
            $_.Group | ForEach-Object {
                "- [[$($_.BaseName)]]"
            }
        } else {
            # Subfolder with indented files
            $subfolder = $_.Name
            "- **$subfolder**"
            $_.Group | ForEach-Object {
                $fileRelPath = $_.FullName.Substring($folderPath.Length + 1).Replace('\', '/') -replace '\.md$', ''
                $fileName = $fileRelPath.Split('/')[-1] 
                "    - [[$fileRelPath|$fileName]]"
            }
        }
    }
} else {
    $content = $files | ForEach-Object {
        "- [[$($_.BaseName)]]"
    }
}

# ========== FILE OUTPUT ==========
$fullContent = $frontMatter + "`n`n" + ($content -join "`n")

if ($WhatIf) {
    Write-Host "[WhatIf] Would update $indexFile`:"
    $fullContent
} else {
    $fullContent | Set-Content -Path $indexFile
    Write-Host "Index updated for '$TargetFolder' (Sorted by: $SortBy, Subfolders: $IncludeSubfolders)"
}