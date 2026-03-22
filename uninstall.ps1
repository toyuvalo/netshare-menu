# uninstall.ps1 -- Remove NetShareMenu

Write-Host "Removing NetShareMenu..." -ForegroundColor Yellow

foreach ($path in @(
    "HKCU:\Software\Classes\*\shell\NetShare"
    "HKCU:\Software\Classes\Directory\shell\NetShare"
    "HKCU:\Software\Classes\Directory\Background\shell\NetShareReceive"
)) {
    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "  [OK] Registry entries removed" -ForegroundColor Green

# Remove firewall rule (needs admin)
$fwCmd = 'netsh advfirewall firewall delete rule name="NetShareMenu"'
$fwTmp = [IO.Path]::GetTempFileName() + ".cmd"
[IO.File]::WriteAllText($fwTmp, $fwCmd)
Start-Process "cmd.exe" -ArgumentList "/c `"$fwTmp`"" -Verb RunAs -Wait
Remove-Item $fwTmp -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] Firewall rule removed" -ForegroundColor Green

Write-Host ""
Write-Host "Uninstalled. You can delete this folder manually." -ForegroundColor Cyan
