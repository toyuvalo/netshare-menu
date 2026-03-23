# NetShare Menu

Right-click any file, folder, or the desktop on Windows to instantly share or receive files over your local network — no cloud, no accounts, no cables. Works with every device that has a browser: iPhone, Android, Mac, Linux.

## Screenshots

Pick how to share:

![Picker](screenshots/picker.png)

Scan the QR from any device on the same network. Files received appear in the list as they arrive:

![Server window](screenshots/server.png)

Or upload to transfer.sh for an internet-accessible link:

![Upload done](screenshots/upload.png)

## What it does

### Send With NetShare (right-click any file or folder)
Choose between two modes:
- **Serve on LAN** — starts a local HTTP server and shows a QR code + URL. Anyone on the same Wi-Fi scans or types the URL to download. The browser page also has a drag-and-drop upload zone so they can send files back to you at the same time. Received files land in `Downloads\received\`.
- **Upload to transfer.sh** — uploads to [transfer.sh](https://transfer.sh) and copies the shareable download link to your clipboard. Multiple files are zipped automatically. Links expire in 14 days.

### Receive a File (right-click desktop or folder background)
Opens a receive-only server so other devices can send files to you without you needing to share anything first. Files land in `Downloads\received\`.

## Install

Right-click `install.ps1` → **Run with PowerShell**, or:

```powershell
git clone https://github.com/toyuvalo/netshare-menu
cd netshare-menu
powershell -ExecutionPolicy Bypass -File install.ps1
```

The installer:
- Registers **Send With NetShare** on right-click for all files and folders (HKCU — no admin needed)
- Registers **Receive a File** on right-click for the desktop and folder backgrounds
- Adds a Windows Firewall inbound rule for ports 8080–8099 (UAC prompt — click Yes)
- Auto-installs the `qrcode` Python package for QR code generation

## Requirements

- Windows 10/11
- Python 3.8+ — [python.org](https://www.python.org/downloads/)
- `curl.exe` — built into Windows 10 (1803+), needed for transfer.sh uploads

## How it works

| Mode | How |
|------|-----|
| Serve on LAN | Python `http.server` on ports 8080–8099, served from the selected file's folder |
| Receive | Same server, pointed at `Downloads\received\`, upload-only browser UI |
| Upload | `curl.exe` upload to `transfer.sh`, result URL shown and copied to clipboard |

The server page is a dark-themed single-page HTML app served by `server.py` — no dependencies, works in any browser on any device.

## Uninstall

Right-click `uninstall.ps1` → **Run with PowerShell**, or:

```powershell
powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\NetShareMenu\uninstall.ps1"
```

## Related

- [doc-convert-menu](https://github.com/toyuvalo/doc-convert-menu) — right-click image/PDF/document conversion
- [ffmpeg-context-menu](https://github.com/toyuvalo/ffmpeg-context-menu) — right-click audio/video conversion

## License

MIT with [Commons Clause](https://commonsclause.com/) — free to use, modify, and share. Commercial resale not permitted.
