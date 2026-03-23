#!/usr/bin/env bash
# NetShare — Linux installer
# Registers Share + Receive for GNOME/Nautilus and KDE/Dolphin.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo " ================================"
echo "   NetShare  —  Linux Setup"
echo " ================================"
echo ""

# ── Python ────────────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "✗  Python 3 not found."
    echo "   Ubuntu/Debian:  sudo apt install python3 python3-pip"
    exit 1
fi
PY="$(command -v python3)"
echo "✓  Python $($PY --version 2>&1 | awk '{print $2}')  →  $PY"

# QR code support (optional)
if ! $PY -m pip show qrcode &>/dev/null 2>&1; then
    echo "   Installing qrcode + pillow for QR display..."
    $PY -m pip install "qrcode[pil]" --quiet --break-system-packages 2>/dev/null \
        || $PY -m pip install "qrcode[pil]" --quiet
    echo "✓  qrcode installed"
else
    echo "✓  qrcode already installed"
fi
echo ""

# ── GNOME / Nautilus ──────────────────────────────────────────────────────────
NAUTILUS_SCRIPTS="$HOME/.local/share/nautilus/scripts"
mkdir -p "$NAUTILUS_SCRIPTS"

cat > "$NAUTILUS_SCRIPTS/Share with NetShare" << NSCRIPT
#!/usr/bin/env bash
IFS=\$'\n'
for f in \$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS; do
    [ -z "\$f" ] && continue
    python3 "$SCRIPT_DIR/net-share-gui.py" share "\$f" &
    break  # only share the first selected item
done
NSCRIPT
chmod +x "$NAUTILUS_SCRIPTS/Share with NetShare"

cat > "$NAUTILUS_SCRIPTS/Receive Files (NetShare)" << NSCRIPT
#!/usr/bin/env bash
python3 "$SCRIPT_DIR/net-share-gui.py" receive &
NSCRIPT
chmod +x "$NAUTILUS_SCRIPTS/Receive Files (NetShare)"
echo "✓  GNOME/Nautilus scripts registered"

# ── KDE / Dolphin ─────────────────────────────────────────────────────────────
for DOLPHIN_DIR in "$HOME/.local/share/kservices5/ServiceMenus" "$HOME/.local/share/kio/servicemenus"; do
    mkdir -p "$DOLPHIN_DIR"

    # Share
    cat > "$DOLPHIN_DIR/netshare-share.desktop" << DESKTOP
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;application/octet-stream;
Actions=netshare_share;
X-KDE-Priority=TopLevel

[Desktop Action netshare_share]
Name=Share with NetShare
Icon=network-server
Exec=python3 $SCRIPT_DIR/net-share-gui.py share %f
DESKTOP

    # Receive (on folder background)
    cat > "$DOLPHIN_DIR/netshare-receive.desktop" << DESKTOP
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;
Actions=netshare_receive;

[Desktop Action netshare_receive]
Name=Receive Files (NetShare)
Icon=network-receive
Exec=python3 $SCRIPT_DIR/net-share-gui.py receive
DESKTOP
done
echo "✓  KDE/Dolphin service menus registered (Plasma 5 + 6)"

echo ""
echo " ================================"
echo "   Done!"
echo " ================================"
echo ""
echo "   GNOME: right-click file/folder → Scripts → Share with NetShare"
echo "   KDE:   right-click file/folder → Share with NetShare"
echo ""
echo "   To restart Nautilus:  nautilus -q"
echo "   To rebuild KDE cache: kbuildsycoca6 --noincremental"
echo ""
