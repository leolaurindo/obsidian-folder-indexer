param(
    [string]$JsonPath = "../parameters.json"
)

$paramMappings = @{
    "targetFolder"     = "TargetFolder"
    "sortBy"           = "SortBy"
    "includeSubfolders"= "IncludeSubfolders"
    "whatIf"           = "WhatIf"
    "outputFile"       = "OutputFile"
    "vaultPath"        = "VaultPath"
}

$groups = Get-Content $JsonPath | ConvertFrom-Json

foreach ($group in $groups) {
    $params = @{}
    
    foreach ($jsonKey in $group.PSObject.Properties.Name) {
        # Normalize key name (case-insensitive match)
        $matchedKey = $paramMappings.Keys | Where-Object { $_ -eq $jsonKey } | Select-Object -First 1
        
        if ($matchedKey -and $paramMappings.ContainsKey($matchedKey)) {
            $paramName = $paramMappings[$matchedKey]
            
            if ($paramName -eq "WhatIf") {
                if ($group.$jsonKey) {
                    $params[$paramName] = $true
                } else {
                    $params[$paramName] = $false
                }
            }
            else {
                $params[$paramName] = $group.$jsonKey
            }
        }
    }

    if (-not $params.ContainsKey("TargetFolder")) {
        Write-Warning "Skipping group - missing TargetFolder"
        continue
    }

    .\update_index.ps1 @params
}