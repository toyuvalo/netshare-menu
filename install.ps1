# install.ps1 -- NetShareMenu installer
# Registers context menu entries in HKCU (no admin needed)
# Then self-elevates to add the Windows Firewall rule for ports 8080-8099

$installDir = $PSScriptRoot
$ps         = "powershell.exe"
$psArgs     = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File"
$script     = Join-Path $installDir "net-share.ps1"
$launcher   = Join-Path $installDir "launcher.vbs"

Write-Host "NetShareMenu installer" -ForegroundColor Cyan
Write-Host ""

# ======================================
#  REGISTRY  (HKCU -- no admin needed)
# ======================================

function Set-MenuEntry {
    param([string]$RegPath, [string]$Label, [string]$Command, [string]$Icon = "")
    $shell = "$RegPath\shell\NetShare"
    $cmd   = "$shell\command"
    New-Item   -Path $shell -Force | Out-Null
    Set-ItemProperty -Path $shell -Name "(Default)" -Value $Label
    Set-ItemProperty -Path $shell -Name "Icon"      -Value "imageres.dll,-1015"
    if ($Icon) { Set-ItemProperty -Path $shell -Name "Icon" -Value $Icon }
    New-Item   -Path $cmd   -Force | Out-Null
    Set-ItemProperty -Path $cmd -Name "(Default)" -Value $Command
}

function Set-ReceiveEntry {
    param([string]$RegPath)
    $shell = "$RegPath\shell\NetShareReceive"
    $cmd   = "$shell\command"
    New-Item   -Path $shell -Force | Out-Null
    Set-ItemProperty -Path $shell -Name "(Default)" -Value "Receive a File"
    Set-ItemProperty -Path $shell -Name "Icon"      -Value "imageres.dll,-1015"
    New-Item   -Path $cmd   -Force | Out-Null
    Set-ItemProperty -Path $cmd -Name "(Default)" -Value (
        "$ps $psArgs `"$script`" -Mode receive")
}

$shareCmd = "wscript.exe `"$launcher`" `"%1`""
$shareCmdDir = "$ps $psArgs `"$script`" -Mode share -Path `"%1`""

# Files (all types)
Set-MenuEntry "HKCU:\Software\Classes\*" "Share on Network" $shareCmd
Write-Host "  [OK] Files context menu" -ForegroundColor Green

# Folders
Set-MenuEntry "HKCU:\Software\Classes\Directory" "Share on Network" $shareCmdDir
Write-Host "  [OK] Folder context menu" -ForegroundColor Green

# Desktop / folder background -> Receive
Set-ReceiveEntry "HKCU:\Software\Classes\Directory\Background"
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
