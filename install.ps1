# install.ps1 -- NetShareMenu installer
# Registers context menu entries in HKCU (no admin needed)
# Then self-elevates to add the Windows Firewall rule for ports 8080-8099

$installDir = $PSScriptRoot
$ps         = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$wsScript   = "$env:SystemRoot\System32\wscript.exe"
$psArgs     = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File"
$script     = Join-Path $installDir "net-share.ps1"
$launcher   = Join-Path $installDir "launcher.vbs"
$icon       = "$env:SystemRoot\System32\shell32.dll,-259"

Write-Host "NetShareMenu installer" -ForegroundColor Cyan
Write-Host ""

# ======================================
#  REGISTRY  (HKCU -- no admin needed)
# ======================================

$label       = "Send With NetShare"
$labelRcv    = "Receive a File  (NetShare)"
$shareCmd    = "`"$wsScript`" `"$launcher`" `"%1`""
$shareCmdDir = "`"$ps`" $psArgs `"$script`" -Mode share -Path `"%1`""
$receiveCmd  = "`"$ps`" $psArgs `"$script`" -Mode receive"

# Use .NET Registry API directly -- avoids PS wildcard issues with * key
# and preserves quotes in command strings exactly
function Set-RegKey {
    param([string]$Path, [hashtable]$Values)
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($Path)
    foreach ($kv in $Values.GetEnumerator()) {
        $key.SetValue($kv.Key, $kv.Value)
    }
    $key.Close()
}

# Files (the * key -- literal asterisk, PS registry provider chokes on this)
Set-RegKey "Software\Classes\*\shell\NetShare"         @{ "" = $label; "Icon" = $icon }
Set-RegKey "Software\Classes\*\shell\NetShare\command" @{ "" = $shareCmd }
Write-Host "  [OK] Files context menu" -ForegroundColor Green

# Folders
Set-RegKey "Software\Classes\Directory\shell\NetShare"         @{ "" = $label; "Icon" = $icon }
Set-RegKey "Software\Classes\Directory\shell\NetShare\command" @{ "" = $shareCmdDir }
Write-Host "  [OK] Folder context menu" -ForegroundColor Green

# Desktop / folder background -> Receive
Set-RegKey "Software\Classes\Directory\Background\shell\NetShareReceive"         @{ "" = $labelRcv; "Icon" = $icon }
Set-RegKey "Software\Classes\Directory\Background\shell\NetShareReceive\command" @{ "" = $receiveCmd }
Write-Host "  [OK] Desktop 'Receive a File' context menu" -ForegroundColor Green

# ======================================
#  FIREWALL  (needs admin -- self-elevate)
# ======================================
Write-Host ""
Write-Host "Adding firewall rule for ports 8080-8099..." -ForegroundColor Yellow
Write-Host "(A UAC prompt will appear -- click Yes)" -ForegroundColor Yellow

$fwCmd = @"
netsh advfirewall firewall delete rule name="NetShareMenu" >nul 2>&1
netsh advfirewall firewall add rule name="NetShareMenu" dir=in action=allow protocol=tcp localport=8080-8099 profile=private,domain
"@
$fwTmp = [IO.Path]::GetTempFileName() + ".cmd"
[IO.File]::WriteAllText($fwTmp, $fwCmd)
Start-Process "cmd.exe" -ArgumentList "/c `"$fwTmp`"" -Verb RunAs -Wait
Remove-Item $fwTmp -Force -ErrorAction SilentlyContinue

Write-Host "  [OK] Firewall rule added" -ForegroundColor Green

# ======================================
#  AUTO-INSTALL qrcode (for QR images)
# ======================================
Write-Host ""
Write-Host "Installing qrcode Python package..." -ForegroundColor Yellow
$py = $null
foreach ($pc in @("python","python3")) {
    if (Get-Command $pc -ErrorAction SilentlyContinue) { $py = $pc; break }
}
if ($py) {
    & $py -m pip install "qrcode[pil]" -q
    Write-Host "  [OK] qrcode installed" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] Python not found -- QR codes will be text-only" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done! Right-click any file -> 'Share on Network'" -ForegroundColor Cyan
Write-Host "      Right-click desktop  -> 'Receive a File'" -ForegroundColor Cyan
