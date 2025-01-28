param(
    [Parameter(Mandatory=$true)]
    [string]$VaultPath,

    [Parameter(Mandatory=$true)]
    [string]$TargetFolder,
    
    [ValidateSet('name', 'date', 'none')]
    [string]$SortBy = 'name',
    
    [switch]$IncludeSubfolders,
    
    [switch]$WhatIf,

    [string]$OutputFile = "_index.md"
)

try {
    $VaultPath = (Resolve-Path $VaultPath).Path.Replace('\', '/').Trim('/')
}
catch {
    Write-Error "Invalid vault path: $VaultPath"
    exit 1
}

$TargetFolder = $TargetFolder.Replace('\', '/').Trim('/')
$folderPath = Join-Path -Path $VaultPath -ChildPath $TargetFolder

if (-not (Test-Path $VaultPath)) {
    Write-Error "Vault path not found: $VaultPath"
    exit 1
}

if (-not (Test-Path $folderPath)) {
    Write-Error "Target folder not found in vault: $TargetFolder"
    exit 1
}

function Get-VaultRelativePath {
    param($FullPath)
    
    $full = $FullPath.Replace('\', '/').Trim('/')
    $vaultRoot = $VaultPath.ToLower().Replace('\', '/').Trim('/')
    
    if (-not $full.ToLower().StartsWith($vaultRoot)) {
        Write-Error "File path '$FullPath' is not within vault root '$VaultPath'"
        exit 1
    }
    
    $targetFolderLeaf = $TargetFolder.Split('/')[-1]
    $folderPathNormalized = $folderPath.Replace('\', '/').Trim('/') + '/'
    $filePathNormalized = $full.Replace('\', '/')
    
    $relativeFromTargetFolder = $filePathNormalized.Substring($folderPathNormalized.Length).Trim('/')
    $linkPath = "$targetFolderLeaf/$relativeFromTargetFolder" -replace '\.md$', ''
    
    return $linkPath
}

$params = @{
    Path        = $folderPath
    Filter      = "*.md"
    File        = $true
    ErrorAction = 'Stop'
}

if ($IncludeSubfolders) { $params.Recurse = $true }

try {
    $files = Get-ChildItem @params | Where-Object { $_.Name -ne $OutputFile }
}
catch {
    Write-Error "Error reading files: $_"
    exit 1
}

switch ($SortBy) {
    'name'  { $files = $files | Sort-Object Name }
    'date'  { $files = $files | Sort-Object LastWriteTime -Descending }
    'none'  { <# No sorting #> }
}

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

try {
    if ($IncludeSubfolders) {
        $content = $files | Group-Object {
            $filePath = $_.FullName.Replace('\', '/')
            $relativeFromTargetFolder = $filePath.Substring($folderPath.Replace('\', '/').Length + 1)
            if ($relativeFromTargetFolder -match '^([^/]+)/') {
                $Matches[1]
            } else {
                '[root]'
            }
        } | Sort-Object { if ($_.Name -eq '[root]') { 0 } else { 1 } } | ForEach-Object {
            if ($_.Name -eq '[root]') {
                $_.Group | ForEach-Object {
                    $linkPath = Get-VaultRelativePath $_.FullName
                    $fileName = $linkPath.Split('/')[-1]
                    "- [[$linkPath|$fileName]]"
                }
            }
            else {
                $subfolder = $_.Name
                "- **$subfolder**"
                $_.Group | ForEach-Object {
                    $linkPath = Get-VaultRelativePath $_.FullName
                    $fileName = $linkPath.Split('/')[-1]
                    "    - [[$linkPath|$fileName]]"
                }
            }
        }
    }
    else {
        $content = $files | ForEach-Object {
            $linkPath = Get-VaultRelativePath $_.FullName
            "- [[$linkPath]]"
        }
    }
}
catch {
    Write-Error "Error generating content: $_"
    exit 1
}

$indexFile = Join-Path -Path $folderPath -ChildPath $OutputFile
$fullContent = $frontMatter + "`n`n" + ($content -join "`n")

if ($WhatIf) {
    Write-Host "[WhatIf] Would update $indexFile`:"
    $fullContent
}
else {
    try {
        $fullContent | Set-Content -Path $indexFile -ErrorAction Stop
        Write-Host "Successfully updated index: $indexFile"
    }
    catch {
        Write-Error "Failed to write index file: $_"
        exit 1
    }
}