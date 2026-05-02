# net-share.ps1 -- LAN file sharing context menu
# v1.1.0

param(
    [string]$Mode = "share",   # "share" or "receive"
    [string]$Path,
    [string]$ListFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ======================================
#  CONSTANTS
# ======================================
$dropDir   = Join-Path $env:USERPROFILE "Downloads\received"
$serverPy  = Join-Path $PSScriptRoot "server.py"

$pythonCmd = $null
foreach ($pc in @("python", "python3")) {
    if (Get-Command $pc -ErrorAction SilentlyContinue) { $pythonCmd = $pc; break }
}

# ======================================
#  COLORS
# ======================================
$bg       = [System.Drawing.Color]::FromArgb(28, 28, 30)
$btnBg    = [System.Drawing.Color]::FromArgb(50, 50, 52)
$teal     = [System.Drawing.Color]::FromArgb(80, 200, 160)
$white    = [System.Drawing.Color]::White
$dimGray  = [System.Drawing.Color]::FromArgb(120, 120, 120)
$sepClr   = [System.Drawing.Color]::FromArgb(55, 55, 57)
$green    = [System.Drawing.Color]::FromArgb(80, 210, 120)
$redBg    = [System.Drawing.Color]::FromArgb(44, 22, 22)
$redFg    = [System.Drawing.Color]::FromArgb(255, 80, 80)
$redBdr   = [System.Drawing.Color]::FromArgb(80, 30, 30)

# ======================================
#  HELPERS
# ======================================
function Get-LocalIP {
    try {
        $s = New-Object System.Net.Sockets.UdpClient
        $s.Connect("8.8.8.8", 80)
        $ip = ($s.Client.LocalEndPoint.ToString() -split ":")[0]
        $s.Close()
        return $ip
    } catch { return "127.0.0.1" }
}

function Find-FreePort {
    foreach ($p in 8080..8099) {
        try {
            $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $p)
            $l.Start(); $l.Stop()
            return $p
        } catch {}
    }
    return 8080
}

function New-AuthToken {
    # 144 bits of entropy, URL-safe.
    $bytes = New-Object byte[] 18
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return ([Convert]::ToBase64String($bytes)).Replace('+','-').Replace('/','_').Replace('=','')
}

function New-QRImage {
    param([string]$Url, [string]$OutPath)
    if (-not $pythonCmd) { return $false }
    # URL + OutPath passed via argv; never interpolated into Python source.
    $py = @'
import sys, subprocess
try:
    try: import qrcode
    except ImportError:
        subprocess.check_call([sys.executable,'-m','pip','install','qrcode[pil]','-q'],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        import qrcode
    qrcode.make(sys.argv[1]).save(sys.argv[2])
    print('OK')
except Exception as e: print('FAIL:'+str(e))
'@
    $tmp = [IO.Path]::GetTempFileName() + ".py"
    [IO.File]::WriteAllText($tmp, $py)
    & $pythonCmd $tmp $Url $OutPath 2>$null | Out-Null
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    return (Test-Path $OutPath)
}

function Start-PythonServer {
    param([string]$ServeDir, [int]$Port, [string]$BindIp, [string]$Token)
    New-Item $dropDir -ItemType Directory -Force | Out-Null
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName  = $pythonCmd
    $pinfo.Arguments = "`"$serverPy`" `"$ServeDir`" $Port `"$dropDir`" `"$BindIp`" `"$Token`""
    $pinfo.UseShellExecute        = $false
    $pinfo.CreateNoWindow         = $true
    $pinfo.RedirectStandardOutput = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $pinfo
    $proc.Start() | Out-Null
    # Wait for server to be ready (max 6s) -- probe the actual bind IP
    $probeHost = if ($BindIp) { $BindIp } else { '127.0.0.1' }
    $deadline = (Get-Date).AddSeconds(6)
    while ((Get-Date) -lt $deadline) {
        try {
            $c = New-Object System.Net.Sockets.TcpClient
            $c.Connect($probeHost, $Port); $c.Close(); break
        } catch { Start-Sleep -Milliseconds 200 }
    }
    return $proc
}

# ======================================
#  SERVER WINDOW  (Serve on LAN / Receive)
# ======================================
function Show-ServerWindow {
    param([string]$Url, [System.Diagnostics.Process]$ServerProc)

    $qrPath = [IO.Path]::GetTempFileName() + ".png"
    $hasQR  = New-QRImage -Url $Url -OutPath $qrPath

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "NetShare"
    $form.BackColor = $bg; $form.ForeColor = $white
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false
    $form.StartPosition = "CenterScreen"; $form.TopMost = $true
    $form.Width = 320

    $y = 16

    # Header
    $hdr = New-Object System.Windows.Forms.Label
    $hdr.Text = "NetShare"; $hdr.ForeColor = $teal
    $hdr.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $hdr.Location = New-Object System.Drawing.Point(20, $y)
    $hdr.Size = New-Object System.Drawing.Size(260, 30)
    $form.Controls.Add($hdr); $y += 38

    # QR code
    if ($hasQR) {
        $qrBox = New-Object System.Windows.Forms.PictureBox
        $qrBox.Image    = [System.Drawing.Image]::FromFile($qrPath)
        $qrBox.SizeMode = "Zoom"
        $qrBox.Location = New-Object System.Drawing.Point(60, $y)
        $qrBox.Size     = New-Object System.Drawing.Size(180, 180)
        $qrBox.BackColor = $white
        $form.Controls.Add($qrBox); $y += 188
    }

    # URL
    $urlLbl = New-Object System.Windows.Forms.Label
    $urlLbl.Text      = $Url
    $urlLbl.ForeColor = $teal
    $urlLbl.Font      = New-Object System.Drawing.Font("Consolas", 9)
    $urlLbl.TextAlign = "MiddleCenter"
    $urlLbl.Location  = New-Object System.Drawing.Point(14, $y)
    $urlLbl.Size      = New-Object System.Drawing.Size(272, 22)
    $form.Controls.Add($urlLbl); $y += 30

    # Copy + Browser buttons
    $copyBtn = New-Object System.Windows.Forms.Button
    $copyBtn.Text = "Copy URL"
    $copyBtn.Location = New-Object System.Drawing.Point(20, $y)
    $copyBtn.Size = New-Object System.Drawing.Size(120, 30)
    $copyBtn.FlatStyle = "Flat"
    $copyBtn.FlatAppearance.BorderColor = $teal
    $copyBtn.FlatAppearance.BorderSize  = 1
    $copyBtn.BackColor = $bg; $copyBtn.ForeColor = $teal
    $copyBtn.Add_Click({ [System.Windows.Forms.Clipboard]::SetText($Url) })
    $form.Controls.Add($copyBtn)

    $browserBtn = New-Object System.Windows.Forms.Button
    $browserBtn.Text = "Open Browser"
    $browserBtn.Location = New-Object System.Drawing.Point(148, $y)
    $browserBtn.Size = New-Object System.Drawing.Size(132, 30)
    $browserBtn.FlatStyle = "Flat"; $browserBtn.FlatAppearance.BorderSize = 0
    $browserBtn.BackColor = $btnBg; $browserBtn.ForeColor = $white
    $browserBtn.Add_Click({ Start-Process $Url })
    $form.Controls.Add($browserBtn); $y += 38

    # Separator
    $sep = New-Object System.Windows.Forms.Panel
    $sep.Location = New-Object System.Drawing.Point(20, $y)
    $sep.Size = New-Object System.Drawing.Size(260, 1)
    $sep.BackColor = $sepClr
    $form.Controls.Add($sep); $y += 10

    # Received files label
    $rcvHdr = New-Object System.Windows.Forms.Label
    $rcvHdr.Text = "RECEIVED FILES"
    $rcvHdr.ForeColor = $dimGray
    $rcvHdr.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
    $rcvHdr.Location = New-Object System.Drawing.Point(20, $y)
    $rcvHdr.Size = New-Object System.Drawing.Size(260, 16)
    $form.Controls.Add($rcvHdr); $y += 20

    $rcvList = New-Object System.Windows.Forms.ListBox
    $rcvList.Location  = New-Object System.Drawing.Point(20, $y)
    $rcvList.Size      = New-Object System.Drawing.Size(260, 80)
    $rcvList.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 42)
    $rcvList.ForeColor = $green
    $rcvList.Font      = New-Object System.Drawing.Font("Consolas", 9)
    $rcvList.BorderStyle = "None"
    $form.Controls.Add($rcvList); $y += 88

    # Stop button
    $stopBtn = New-Object System.Windows.Forms.Button
    $stopBtn.Text = "Stop Server"
    $stopBtn.Location = New-Object System.Drawing.Point(20, $y)
    $stopBtn.Size = New-Object System.Drawing.Size(260, 32)
    $stopBtn.FlatStyle = "Flat"
    $stopBtn.FlatAppearance.BorderColor = $redBdr
    $stopBtn.FlatAppearance.BorderSize  = 1
    $stopBtn.BackColor = $redBg; $stopBtn.ForeColor = $redFg
    $stopBtn.Add_Click({
        try { $ServerProc.Kill() } catch {}
        $form.Close()
    })
    $form.Controls.Add($stopBtn); $y += 40

    $form.ClientSize = New-Object System.Drawing.Size(300, $y)

    # Poll drop dir for newly received files
    $script:knownRcv = @{}
    if (Test-Path $dropDir) {
        foreach ($f in (Get-ChildItem $dropDir -File)) { $script:knownRcv[$f.Name] = $true }
    }

    $pollTimer = New-Object System.Windows.Forms.Timer
    $pollTimer.Interval = 1000
    $pollTimer.Add_Tick({
        if (Test-Path $dropDir) {
            foreach ($f in (Get-ChildItem $dropDir -File)) {
                if (-not $script:knownRcv.ContainsKey($f.Name)) {
                    $script:knownRcv[$f.Name] = $true
                    $rcvList.Items.Insert(0, $f.Name)
                }
            }
        }
        if ($ServerProc.HasExited) { $pollTimer.Stop() }
    })

    $form.Add_Shown({ $pollTimer.Start() })
    $form.Add_FormClosed({
        $pollTimer.Stop()
        try { $ServerProc.Kill() } catch {}
        if ($hasQR -and (Test-Path $qrPath)) {
            Start-Sleep -Milliseconds 300
            Remove-Item $qrPath -Force -ErrorAction SilentlyContinue
        }
    })

    [System.Windows.Forms.Application]::Run($form)
}

# ======================================
#  UPLOAD WINDOW  (transfer.sh)
# ======================================
function Show-UploadWindow {
    param([string[]]$Files)

    # Zip multiple files
    $uploadPaths = @()
    $tmpZip      = $null
    if ($Files.Count -gt 1) {
        $tmpZip = Join-Path $env:TEMP "netshare_$(Get-Random).zip"
        Compress-Archive -Path $Files -DestinationPath $tmpZip -Force
        $uploadPaths = @($tmpZip)
    } else {
        $uploadPaths = $Files
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "NetShare - Upload"
    $form.BackColor = $bg; $form.ForeColor = $white
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false
    $form.StartPosition = "CenterScreen"; $form.TopMost = $true
    $form.Size = New-Object System.Drawing.Size(440, 280)

    $y = 16

    $hdr = New-Object System.Windows.Forms.Label
    $hdr.Text = "Uploading to transfer.sh"; $hdr.ForeColor = $teal
    $hdr.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $hdr.Location = New-Object System.Drawing.Point(20, $y); $hdr.Size = New-Object System.Drawing.Size(380, 26)
    $form.Controls.Add($hdr); $y += 38

    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point(20, $y); $pb.Size = New-Object System.Drawing.Size(380, 20)
    $pb.Minimum = 0; $pb.Maximum = $uploadPaths.Count; $pb.Value = 0
    $form.Controls.Add($pb); $y += 28

    $statusLbl = New-Object System.Windows.Forms.Label
    $statusLbl.Text = "Starting..."
    $statusLbl.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $statusLbl.Location = New-Object System.Drawing.Point(20, $y); $statusLbl.Size = New-Object System.Drawing.Size(380, 20)
    $form.Controls.Add($statusLbl); $y += 30

    $urlBox = New-Object System.Windows.Forms.RichTextBox
    $urlBox.Location = New-Object System.Drawing.Point(20, $y); $urlBox.Size = New-Object System.Drawing.Size(380, 80)
    $urlBox.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 42); $urlBox.ForeColor = $teal
    $urlBox.Font = New-Object System.Drawing.Font("Consolas", 9); $urlBox.BorderStyle = "None"
    $urlBox.ReadOnly = $true; $urlBox.ScrollBars = "Vertical"
    $form.Controls.Add($urlBox); $y += 88

    $copyAllBtn = New-Object System.Windows.Forms.Button
    $copyAllBtn.Text = "Copy URL(s)"
    $copyAllBtn.Location = New-Object System.Drawing.Point(20, $y); $copyAllBtn.Size = New-Object System.Drawing.Size(120, 30)
    $copyAllBtn.FlatStyle = "Flat"; $copyAllBtn.FlatAppearance.BorderColor = $teal; $copyAllBtn.FlatAppearance.BorderSize = 1
    $copyAllBtn.BackColor = $bg; $copyAllBtn.ForeColor = $teal; $copyAllBtn.Visible = $false
    $form.Controls.Add($copyAllBtn)

    $closeBtn = New-Object System.Windows.Forms.Button
    $closeBtn.Text = "Close"
    $closeBtn.Location = New-Object System.Drawing.Point(295, $y); $closeBtn.Size = New-Object System.Drawing.Size(105, 30)
    $closeBtn.FlatStyle = "Flat"; $closeBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
    $closeBtn.BackColor = $btnBg; $closeBtn.ForeColor = $white; $closeBtn.Visible = $false
    $closeBtn.Add_Click({ $form.Close() })
    $form.Controls.Add($closeBtn)

    # Upload engine
    $script:uploadIdx  = 0
    $script:uploadURLs = @()
    $script:uploadJob  = $null

    function Start-UploadJob {
        param([int]$Idx)
        $file    = Get-Item $uploadPaths[$Idx]
        $fname   = $file.Name
        $statusLbl.Text      = "Uploading: $fname"
        $statusLbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 215, 80)

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName  = "curl.exe"
        $pinfo.Arguments = "-s -T `"$($file.FullName)`" `"https://transfer.sh/$fname`""
        $pinfo.UseShellExecute        = $false
        $pinfo.CreateNoWindow         = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError  = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $pinfo
        $proc.Start() | Out-Null
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $script:uploadJob = @{ Proc = $proc; OutTask = $outTask; Idx = $Idx }
    }

    $uploadTimer = New-Object System.Windows.Forms.Timer
    $uploadTimer.Interval = 300
    $uploadTimer.Add_Tick({
        if ($script:uploadJob -ne $null) {
            $job = $script:uploadJob
            if (-not $job.Proc.HasExited) { return }
            $url = $job.OutTask.Result.Trim()
            if ($url -match "^https?://") {
                $script:uploadURLs += $url
                $urlBox.AppendText($url + "`n")
            } else {
                $script:uploadURLs += "[upload failed]"
                $urlBox.AppendText("[upload failed]`n")
            }
            $pb.Value = $job.Idx + 1
            $script:uploadJob = $null
            $script:uploadIdx++
        }

        if ($script:uploadJob -eq $null -and $script:uploadIdx -lt $uploadPaths.Count) {
            Start-UploadJob -Idx $script:uploadIdx
            return
        }

        if ($script:uploadJob -eq $null -and $script:uploadIdx -ge $uploadPaths.Count) {
            $uploadTimer.Stop()
            $statusLbl.Text      = "Done -- $($script:uploadURLs.Count) link(s) ready"
            $statusLbl.ForeColor = $green
            $allURLs             = $script:uploadURLs -join "`n"
            [System.Windows.Forms.Clipboard]::SetText($allURLs)
            $copyAllBtn.Add_Click({ [System.Windows.Forms.Clipboard]::SetText($allURLs) })
            $copyAllBtn.Visible = $true
            $closeBtn.Visible   = $true
            if ($tmpZip -and (Test-Path $tmpZip)) { Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue }
        }
    })

    $form.Add_Shown({ Start-UploadJob -Idx 0; $uploadTimer.Start() })
    [System.Windows.Forms.Application]::Run($form)
}

# ======================================
#  SHARE PICKER
# ======================================
function Show-SharePicker {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "NetShare"
    $form.BackColor = $bg; $form.ForeColor = $white
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false
    $form.StartPosition = "CenterScreen"; $form.TopMost = $true

    $y = 14

    $hdr = New-Object System.Windows.Forms.Label
    $hdr.Text = "Share on Network"; $hdr.ForeColor = $teal
    $hdr.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $hdr.Location = New-Object System.Drawing.Point(20, $y); $hdr.Size = New-Object System.Drawing.Size(260, 28)
    $form.Controls.Add($hdr); $y += 36

    $cnt = $initialPaths.Count
    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "$cnt item(s) selected"; $sub.ForeColor = $dimGray
    $sub.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $sub.Location = New-Object System.Drawing.Point(20, $y); $sub.Size = New-Object System.Drawing.Size(260, 18)
    $form.Controls.Add($sub); $y += 28

    $script:picked = $null

    foreach ($entry in @(
        @{ Text = "Serve on LAN  (browser download)"; Key = "lan" }
        @{ Text = "Upload to transfer.sh  (get link)"; Key = "upload" }
    )) {
        $k   = $entry.Key
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $entry.Text
        $btn.Location = New-Object System.Drawing.Point(20, $y)
        $btn.Size = New-Object System.Drawing.Size(260, 34)
        $btn.FlatStyle = "Flat"; $btn.FlatAppearance.BorderSize = 0
        $btn.BackColor = $btnBg; $btn.ForeColor = $white
        $btn.TextAlign = "MiddleLeft"
        $btn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        $btn.Tag = $k
        $btn.Add_Click({ $script:picked = $this.Tag; $form.Close() })
        $btn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(65,65,68) })
        $btn.Add_MouseLeave({ $this.BackColor = $btnBg })
        $form.Controls.Add($btn); $y += 38
    }

    $form.ClientSize = New-Object System.Drawing.Size(300, ($y + 12))
    [System.Windows.Forms.Application]::Run($form)
    return $script:picked
}

# ======================================
#  MAIN
# ======================================
if (-not $pythonCmd) {
    $e = New-Object System.Windows.Forms.Form
    $e.TopMost = $true; $e.WindowState = "Minimized"; $e.Show()
    [System.Windows.Forms.MessageBox]::Show($e,
        "Python is required but not found.`n`nInstall Python from python.org",
        "NetShare", "OK", "Error") | Out-Null
    $e.Close(); exit 1
}

if ($Mode -eq "receive") {
    New-Item $dropDir -ItemType Directory -Force | Out-Null
    $port  = Find-FreePort
    $ip    = Get-LocalIP
    $token = New-AuthToken
    $url   = "http://${ip}:${port}/?t=${token}"
    $proc  = Start-PythonServer -ServeDir $dropDir -Port $port -BindIp $ip -Token $token
    Show-ServerWindow -Url $url -ServerProc $proc
    exit 0
}

# Share mode -- load files
$initialPaths = @()
if ($ListFile -and (Test-Path $ListFile)) {
    $initialPaths = @(Get-Content $ListFile -Encoding UTF8 |
        Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() })
    Remove-Item $ListFile -Force -ErrorAction SilentlyContinue
} elseif ($Path) {
    $initialPaths = @($Path)
}
if ($initialPaths.Count -eq 0) { exit 0 }

$picked = Show-SharePicker
if (-not $picked) { exit 0 }

if ($picked -eq "lan") {
    $firstPath = $initialPaths[0]
    if (Test-Path $firstPath -PathType Container) {
        $serveDir = $firstPath
        $url      = $null
    } else {
        $serveDir = [IO.Path]::GetDirectoryName($firstPath)
        # Direct link for single file
        if ($initialPaths.Count -eq 1) {
            $url = $null  # set after we know the port
        }
    }
    $port  = Find-FreePort
    $ip    = Get-LocalIP
    $token = New-AuthToken
    if ($initialPaths.Count -eq 1 -and (Test-Path $firstPath -PathType Leaf)) {
        $fname = [Uri]::EscapeDataString([IO.Path]::GetFileName($firstPath))
        $url   = "http://${ip}:${port}/${fname}?t=${token}"
    } else {
        $url = "http://${ip}:${port}/?t=${token}"
    }
    $proc = Start-PythonServer -ServeDir $serveDir -Port $port -BindIp $ip -Token $token
    Show-ServerWindow -Url $url -ServerProc $proc

} elseif ($picked -eq "upload") {
    Show-UploadWindow -Files $initialPaths
}
