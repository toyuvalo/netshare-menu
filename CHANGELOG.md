# Changelog

All notable changes to NetShare Menu will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## [1.1.0] — 2026-05-02

### Added
- **QR-gated access.** Each session generates a 144-bit URL-safe token. The QR code embeds it as `?t=<token>`; the first request with a valid token sets a `nst` session cookie so every follow-up click/upload from the scanning device works automatically. Anyone without the token (or cookie) gets a 403. Constant-time comparison via `secrets.compare_digest`.
- `CHANGELOG.md` and `.gitignore` (covering `__pycache__/`).

### Changed
- **Server now binds only to the detected LAN IP**, not `0.0.0.0`. VPN tunnels, guest Wi-Fi adapters, and any other interfaces are no longer exposed. The PowerShell readiness probe now connects to the same bind IP instead of `127.0.0.1`.
- `New-QRImage` passes the URL via `sys.argv` rather than interpolating it into the temporary Python source. Eliminates the entire class of source-injection risk if a URL ever contained shell-relevant characters.

### Security
- Closes two HIGH-severity findings from a session-time codex/agent review:
  - Server bound to all interfaces → bound to detected LAN IP only.
  - QR generator interpolated URL into Python source → URL passed via argv.

## [1.0.0] — 2026-03-22

Initial release. Right-click context menu for "Send With NetShare" (per-file/folder) and "Receive a File" (desktop), QR + dark browser frontend, multipart upload, transfer.sh fallback, HKCU registry, firewall allow-rule for ports 8080-8099. Windows + macOS + Linux.
