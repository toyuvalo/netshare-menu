# NetShare Menu

Right-click any file, folder, or the desktop on Windows to instantly share or receive files over your local network — no cloud, no accounts, no cables.

## What it does

### Share on Network (right-click any file or folder)
Starts a local HTTP server and shows a dark GUI with a **QR code + URL**. Anyone on the same Wi-Fi can scan the code or type the URL to download directly from your PC. The browser page also has a **drag-and-drop upload zone** — so they can send files back to you at the same time. Received files land in `Downloads\received\`.

### Upload to transfer.sh (right-click any file or folder)
Uploads the file(s) to [transfer.sh](https://transfer.sh) and gives you a shareable download link. Multiple files are zipped automatically. The URL is copied to your clipboard the moment the upload finishes.

### Receive a File (right-click desktop or folder background)
Opens a receive-only server so other devices on the network can send files to you without you needing to share anything first. Files land in `Downloads\received\`.

## Install

Right-click `install.ps1` → **Run with PowerShell**

The installer:
- Registers **Share on Network** on right-click for all files and folders (HKCU — no admin needed)
- Registers **Receive a File** on right-click for the desktop and folder backgrounds
- Adds a Windows Firewall inbound rule for ports 8080–8099 (UAC prompt — click Yes)
- Auto-installs the `qrcode` Python package for QR code generation

## Uninstall

Right-click `uninstall.ps1` → **Run with PowerShell**

## Requirements

- Windows 10/11
- Python 3.8+ — [python.org](https://www.python.org/downloads/)
- `curl.exe` — built into Windows 10 (1803+), needed for transfer.sh uploads

## How it works

| Mode | How |
|------|-----|
| Serve on LAN | Python `http.server` on ports 8080–8099, served from the selected file's folder |
| Receive | Same server, pointed at `Downloads\received\`, upload-only browser UI |
| Upload | `curl.exe` upload to `transfer.sh`, result URL shown and copied |

The server page is a dark-themed single-page HTML app served by `server.py` — no dependencies, works in any browser on any device.

## More tools like this

Built by [dvlce.ca](https://dvlce.ca) — see [webdev.dvlce.ca](https://webdev.dvlce.ca) for the full project showcase.

## License

MIT with [Commons Clause](https://commonsclause.com/) — free to use, modify, and share. Commercial resale not permitted.
