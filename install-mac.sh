#!/usr/bin/env bash
# NetShare — macOS installer
# Registers two Finder Quick Actions: Share and Receive.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_DIR="$HOME/Library/Services"

echo ""
echo " ================================"
echo "   NetShare  —  macOS Setup"
echo " ================================"
echo ""

# ── Python ────────────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "✗  Python 3 not found. Install from https://python.org"
    exit 1
fi
PY="$(command -v python3)"
echo "✓  Python $($PY --version 2>&1 | awk '{print $2}')  →  $PY"

# QR code support (optional but nice)
if ! $PY -m pip show qrcode &>/dev/null 2>&1; then
    echo "   Installing qrcode + pillow for QR display..."
    $PY -m pip install "qrcode[pil]" --quiet
    echo "✓  qrcode installed"
else
    echo "✓  qrcode already installed"
fi
echo ""

# ── Launchers ─────────────────────────────────────────────────────────────────
cat > "$SCRIPT_DIR/run-share.sh" << RUNSH
#!/usr/bin/env bash
exec python3 "$SCRIPT_DIR/net-share-gui.py" share "\$1"
RUNSH
chmod +x "$SCRIPT_DIR/run-share.sh"

cat > "$SCRIPT_DIR/run-receive.sh" << RUNSH
#!/usr/bin/env bash
exec python3 "$SCRIPT_DIR/net-share-gui.py" receive
RUNSH
chmod +x "$SCRIPT_DIR/run-receive.sh"
echo "✓  Launchers created"
echo ""

# ── Register Quick Actions ────────────────────────────────────────────────────
ESCAPED_DIR="$(printf '%s' "$SCRIPT_DIR" | sed 's/&/\&amp;/g')"

_make_workflow() {
    local NAME="$1"
    local RUNNER="$2"
    local TYPES="$3"
    local WORKFLOW="$SERVICE_DIR/$NAME.workflow"
    mkdir -p "$WORKFLOW/Contents"

    cat > "$WORKFLOW/Contents/Info.plist" << INFOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>$NAME</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSSendFileTypes</key>
			<array>
$TYPES
			</array>
		</dict>
	</array>
</dict>
</plist>
INFOPLIST

    cat > "$WORKFLOW/Contents/document.wflow" << WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key><string>521</string>
	<key>AMApplicationVersion</key><string>2.10</string>
	<key>AMDocumentVersion</key><string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key><string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>for f in "\$@"; do
    "$ESCAPED_DIR/$RUNNER" "\$f" &amp;
done</string>
					<key>shell</key><string>/bin/bash</string>
					<key>source</key><string>pass-as-arguments</string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.automator.runShellScript</string>
				<key>CFBundleVersion</key><string>2.0.3</string>
				<key>Class Name</key><string>RunShellScriptAction</string>
				<key>UUID</key><string>NS-SHARE-$(echo "$NAME" | md5 | cut -c1-8)-0001</string>
				<key>isViewVisible</key><true/>
			</dict>
		</dict>
	</array>
	<key>connectors</key><dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW
    echo "✓  Quick Action → $WORKFLOW"
}

# Share: files and folders
_make_workflow "Share with NetShare" "run-share.sh" "
				<string>public.item</string>
				<string>public.folder</string>"

# Receive: desktop background (no file selected — triggered from background)
mkdir -p "$SERVICE_DIR/Receive Files (NetShare).workflow/Contents"
cat > "$SERVICE_DIR/Receive Files (NetShare).workflow/Contents/Info.plist" << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Receive Files (NetShare)</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
		</dict>
	</array>
</dict>
</plist>
INFOPLIST

cat > "$SERVICE_DIR/Receive Files (NetShare).workflow/Contents/document.wflow" << WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key><string>521</string>
	<key>AMApplicationVersion</key><string>2.10</string>
	<key>AMDocumentVersion</key><string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key><string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>"$ESCAPED_DIR/run-receive.sh" &amp;</string>
					<key>shell</key><string>/bin/bash</string>
					<key>source</key><string>pass-as-arguments</string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.automator.runShellScript</string>
				<key>CFBundleVersion</key><string>2.0.3</string>
				<key>Class Name</key><string>RunShellScriptAction</string>
				<key>UUID</key><string>NS-RECV-00000001-NETSHARE</string>
				<key>isViewVisible</key><true/>
			</dict>
		</dict>
	</array>
	<key>connectors</key><dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW
echo "✓  Quick Action → $SERVICE_DIR/Receive Files (NetShare).workflow"

/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo ""
echo " ================================"
echo "   Done!"
echo " ================================"
echo ""
echo "   Right-click any file or folder → Quick Actions → Share with NetShare"
echo "   Finder menu bar → Services → Receive Files (NetShare)"
echo ""
echo "   If options don't appear:"
echo "   System Settings → Privacy & Security → Extensions → Finder"
echo ""
