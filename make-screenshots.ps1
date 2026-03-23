# make-screenshots.ps1 -- Generate README screenshots for NetShareMenu
# Builds mock forms identical to the real app and captures ONLY the form bounds.
# No full-screen capture, no user interaction, no OOM.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$here   = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$outDir = Join-Path $here "screenshots"
New-Item -Path $outDir -ItemType Directory -Force | Out-Null

function Capture-Form {
    param($Form, $Path)
    $Form.Show()
    $Form.BringToFront()
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 400
    [System.Windows.Forms.Application]::DoEvents()
    $loc = $Form.Location
    $bmp = New-Object System.Drawing.Bitmap($Form.Width, $Form.Height)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($loc.X, $loc.Y, 0, 0, [System.Drawing.Size]::new($Form.Width, $Form.Height))
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $Form.Close()
    $Form.Dispose()
    [System.Windows.Forms.Application]::DoEvents()
}

# -----------------------------------------------------------------------
#  SHARED COLORS
# -----------------------------------------------------------------------
$bg      = [System.Drawing.Color]::FromArgb(28, 28, 30)
$btnBg   = [System.Drawing.Color]::FromArgb(50, 50, 52)
$teal    = [System.Drawing.Color]::FromArgb(80, 200, 160)
$white   = [System.Drawing.Color]::White
$dimGray = [System.Drawing.Color]::FromArgb(120, 120, 120)
$sepClr  = [System.Drawing.Color]::FromArgb(55, 55, 57)
$green   = [System.Drawing.Color]::FromArgb(80, 210, 120)
$yellow  = [System.Drawing.Color]::FromArgb(255, 215, 80)
$grayDim = [System.Drawing.Color]::FromArgb(130, 130, 130)
$redBg   = [System.Drawing.Color]::FromArgb(44, 22, 22)
$redFg   = [System.Drawing.Color]::FromArgb(255, 80, 80)
$redBdr  = [System.Drawing.Color]::FromArgb(80, 30, 30)
$darkBg2 = [System.Drawing.Color]::FromArgb(40, 40, 42)

# -----------------------------------------------------------------------
#  SCREENSHOT 1: SHARE PICKER
# -----------------------------------------------------------------------
function New-PickerForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "NetShare"; $form.BackColor = $bg; $form.ForeColor = $white
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false
    $form.StartPosition = "CenterScreen"; $form.TopMost = $true

    $y = 14

    $hdr = New-Object System.Windows.Forms.Label
    $hdr.Text = "Share on Network"; $hdr.ForeColor = $teal
    $hdr.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $hdr.Location = New-Object System.Drawing.Point(20, $y); $hdr.Size = New-Object System.Drawing.Size(260, 28)
    $form.Controls.Add($hdr); $y += 36

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "3 item(s) selected"; $sub.ForeColor = $dimGray
    $sub.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $sub.Location = New-Object System.Drawing.Point(20, $y); $sub.Size = New-Object System.Drawing.Size(260, 18)
    $form.Controls.Add($sub); $y += 28

    foreach ($t in @("Serve on LAN  (browser download)", "Upload to transfer.sh  (get link)")) {
        $b = New-Object System.Windows.Forms.Button; $b.Text = $t
        $b.Location = New-Object System.Drawing.Point(20, $y); $b.Size = New-Object System.Drawing.Size(260, 34)
        $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 0
        $b.BackColor = $btnBg; $b.ForeColor = $white; $b.TextAlign = "MiddleLeft"
        $b.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        $form.Controls.Add($b); $y += 38
    }

    $form.ClientSize = New-Object System.Drawing.Size(300, ($y + 12))
    return $form
}

# -----------------------------------------------------------------------
#  SCREENSHOT 2: SERVER WINDOW (serving / receiving)
# -----------------------------------------------------------------------
function New-ServerForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "NetShare"; $form.BackColor = $bg; $form.ForeColor = $white
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false
    $form.StartPosition = "CenterScreen"; $form.TopMost = $true
    $form.Width = 320

    $y = 16

    $hdr = New-Object System.Windows.Forms.Label
    $hdr.Text = "NetShare"; $hdr.ForeColor = $teal
    $hdr.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $hdr.Location = New-Object System.Drawing.Point(20, $y); $hdr.Size = New-Object System.Drawing.Size(260, 30)
    $form.Controls.Add($hdr); $y += 38

    # Mock QR code (white square with grid pattern to simulate QR)
    $qrBox = New-Object System.Windows.Forms.PictureBox
    $qrBox.Location = New-Object System.Drawing.Point(60, $y); $qrBox.Size = New-Object System.Drawing.Size(180, 180)
    $qrBox.BackColor = $white

    $qrBmp = New-Object System.Drawing.Bitmap(180, 180)
    $qrGfx = [System.Drawing.Graphics]::FromImage($qrBmp)
    $qrGfx.Clear($white)
    $black = [System.Drawing.Color]::Black
    $sz = 9
    # Simplified QR-style pattern
    $cells = @(
        @(0,0),@(1,0),@(2,0),@(3,0),@(4,0),@(5,0),@(6,0),
        @(0,1),@(6,1),@(0,2),@(2,2),@(3,2),@(4,2),@(6,2),
        @(0,3),@(2,3),@(4,3),@(6,3),@(0,4),@(2,4),@(3,4),@(4,4),@(6,4),
        @(0,5),@(6,5),@(0,6),@(1,6),@(2,6),@(3,6),@(4,6),@(5,6),@(6,6),
        @(8,0),@(9,0),@(10,0),@(8,2),@(10,2),@(8,3),@(9,3),@(12,0),@(14,0),@(13,1),@(12,2),@(14,2),@(13,3),
        @(0,8),@(1,8),@(3,8),@(5,8),@(0,9),@(2,9),@(4,9),@(0,10),@(1,10),@(2,10),@(4,10),
        @(0,12),@(0,13),@(1,13),@(3,12),@(4,12),@(5,12),@(3,13),@(5,13),@(3,14),@(4,14),@(5,14),
        @(8,8),@(9,8),@(11,8),@(12,8),@(14,8),@(8,9),@(10,9),@(12,9),@(8,10),@(9,10),@(11,10),@(13,10),@(14,10),
        @(8,12),@(10,12),@(11,12),@(13,12),@(9,13),@(11,13),@(14,13),@(8,14),@(10,14),@(12,14),@(13,14)
    )
    $br = New-Object System.Drawing.SolidBrush($black)
    $offset = 18  # center the 15-cell pattern in 180px
    foreach ($c in $cells) {
        $qrGfx.FillRectangle($br, $offset + $c[0]*$sz, $offset + $c[1]*$sz, $sz-1, $sz-1)
    }
    $br.Dispose(); $qrGfx.Dispose()
    $qrBox.Image = $qrBmp
    $qrBox.SizeMode = "Normal"
    $form.Controls.Add($qrBox); $y += 188

    # URL
    $urlLbl = New-Object System.Windows.Forms.Label
    $urlLbl.Text = "http://192.168.1.42:8080"; $urlLbl.ForeColor = $teal
    $urlLbl.Font = New-Object System.Drawing.Font("Consolas", 9)
    $urlLbl.TextAlign = "MiddleCenter"
    $urlLbl.Location = New-Object System.Drawing.Point(14, $y); $urlLbl.Size = New-Object System.Drawing.Size(272, 22)
    $form.Controls.Add($urlLbl); $y += 30

    # Copy + Browser buttons
    $copyBtn = New-Object System.Windows.Forms.Button; $copyBtn.Text = "Copy URL"
    $copyBtn.Location = New-Object System.Drawing.Point(20, $y); $copyBtn.Size = New-Object System.Drawing.Size(120, 30)
    $copyBtn.FlatStyle = "Flat"; $copyBtn.FlatAppearance.BorderColor = $teal; $copyBtn.FlatAppearance.BorderSize = 1
    $copyBtn.BackColor = $bg; $copyBtn.ForeColor = $teal
    $form.Controls.Add($copyBtn)

    $brwBtn = New-Object System.Windows.Forms.Button; $brwBtn.Text = "Open Browser"
    $brwBtn.Location = New-Object System.Drawing.Point(148, $y); $brwBtn.Size = New-Object System.Drawing.Size(132, 30)
    $brwBtn.FlatStyle = "Flat"; $brwBtn.FlatAppearance.BorderSize = 0
    $brwBtn.BackColor = $btnBg; $brwBtn.ForeColor = $white
    $form.Controls.Add($brwBtn); $y += 38

    $sep = New-Object System.Windows.Forms.Panel
    $sep.Location = New-Object System.Drawing.Point(20, $y); $sep.Size = New-Object System.Drawing.Size(260, 1)
    $sep.BackColor = $sepClr; $form.Controls.Add($sep); $y += 10

    $rcvHdr = New-Object System.Windows.Forms.Label
    $rcvHdr.Text = "RECEIVED FILES"; $rcvHdr.ForeColor = $dimGray
    $rcvHdr.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
    $rcvHdr.Location = New-Object System.Drawing.Point(20, $y); $rcvHdr.Size = New-Object System.Drawing.Size(260, 16)
    $form.Controls.Add($rcvHdr); $y += 20

    $rcvList = New-Object System.Windows.Forms.ListBox
    $rcvList.Location = New-Object System.Drawing.Point(20, $y); $rcvList.Size = New-Object System.Drawing.Size(260, 80)
    $rcvList.BackColor = $darkBg2; $rcvList.ForeColor = $green
    $rcvList.Font = New-Object System.Drawing.Font("Consolas", 9); $rcvList.BorderStyle = "None"
    $rcvList.Items.Add("photo_from_iphone.jpg") | Out-Null
    $rcvList.Items.Add("document.pdf") | Out-Null
    $form.Controls.Add($rcvList); $y += 88

    $stopBtn = New-Object System.Windows.Forms.Button; $stopBtn.Text = "Stop Server"
    $stopBtn.Location = New-Object System.Drawing.Point(20, $y); $stopBtn.Size = New-Object System.Drawing.Size(260, 32)
    $stopBtn.FlatStyle = "Flat"; $stopBtn.FlatAppearance.BorderColor = $redBdr; $stopBtn.FlatAppearance.BorderSize = 1
    $stopBtn.BackColor = $redBg; $stopBtn.ForeColor = $redFg
    $form.Controls.Add($stopBtn); $y += 40

    $form.ClientSize = New-Object System.Drawing.Size(300, $y)
    return $form
}

# -----------------------------------------------------------------------
#  SCREENSHOT 3: UPLOAD WINDOW (done state)
# -----------------------------------------------------------------------
function New-UploadDoneForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "NetShare - Upload"; $form.BackColor = $bg; $form.ForeColor = $white
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
    $pb.Minimum = 0; $pb.Maximum = 2; $pb.Value = 2
    $form.Controls.Add($pb); $y += 28

    $status = New-Object System.Windows.Forms.Label
    $status.Text = "Done -- 2 link(s) ready"; $status.ForeColor = $green
    $status.Location = New-Object System.Drawing.Point(20, $y); $status.Size = New-Object System.Drawing.Size(380, 20)
    $form.Controls.Add($status); $y += 30

    $urlBox = New-Object System.Windows.Forms.RichTextBox
    $urlBox.Location = New-Object System.Drawing.Point(20, $y); $urlBox.Size = New-Object System.Drawing.Size(380, 80)
    $urlBox.BackColor = $darkBg2; $urlBox.ForeColor = $teal
    $urlBox.Font = New-Object System.Drawing.Font("Consolas", 9); $urlBox.BorderStyle = "None"
    $urlBox.ReadOnly = $true
    $urlBox.Text = "https://transfer.sh/abc123/photo_beach.jpg`nhttps://transfer.sh/def456/video.mp4"
    $form.Controls.Add($urlBox); $y += 88

    $copyBtn = New-Object System.Windows.Forms.Button; $copyBtn.Text = "Copy URL(s)"
    $copyBtn.Location = New-Object System.Drawing.Point(20, $y); $copyBtn.Size = New-Object System.Drawing.Size(120, 30)
    $copyBtn.FlatStyle = "Flat"; $copyBtn.FlatAppearance.BorderColor = $teal; $copyBtn.FlatAppearance.BorderSize = 1
    $copyBtn.BackColor = $bg; $copyBtn.ForeColor = $teal
    $form.Controls.Add($copyBtn)

    $closeBtn = New-Object System.Windows.Forms.Button; $closeBtn.Text = "Close"
    $closeBtn.Location = New-Object System.Drawing.Point(295, $y); $closeBtn.Size = New-Object System.Drawing.Size(105, 30)
    $closeBtn.FlatStyle = "Flat"; $closeBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,70,70)
    $closeBtn.BackColor = $btnBg; $closeBtn.ForeColor = $white
    $form.Controls.Add($closeBtn)

    return $form
}

# -----------------------------------------------------------------------
#  RUN
# -----------------------------------------------------------------------
Write-Host "Generating screenshots..." -ForegroundColor Yellow

Capture-Form -Form (New-PickerForm)      -Path (Join-Path $outDir "picker.png")
Write-Host "  [1/3] picker.png"     -ForegroundColor Green

Capture-Form -Form (New-ServerForm)      -Path (Join-Path $outDir "server.png")
Write-Host "  [2/3] server.png"     -ForegroundColor Green

Capture-Form -Form (New-UploadDoneForm)  -Path (Join-Path $outDir "upload.png")
Write-Host "  [3/3] upload.png"     -ForegroundColor Green

Write-Host ""
Write-Host "Done. Screenshots saved to: $outDir" -ForegroundColor Green
