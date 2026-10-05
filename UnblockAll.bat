@echo off
echo Removing the "downloaded from the internet" flag from every file in this folder...
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -File | Unblock-File; Write-Host 'Done. Every file in this folder and its subfolders has been unblocked.'"

echo.
pause
