@echo off
setlocal

set "VaultPath=%~1"
if "%VaultPath%"=="" set "VaultPath=C:\Users\leo--\demo_vault"

powershell -NoProfile -ExecutionPolicy Bypass -File "update-index.ps1" ^
    -VaultPath "%VaultPath%" ^
    -TargetFolder "folder\subfolder" ^
    -SortBy name ^
    -IncludeSubfolders ^
     ^
    -OutputFile "_index.md"

endlocal
