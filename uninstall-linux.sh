#!/usr/bin/env bash
set -euo pipefail
N="$HOME/.local/share/nautilus/scripts"
[ -f "$N/Share with NetShare" ]        && rm -f "$N/Share with NetShare"        && echo "✓  Removed Nautilus Share script"
[ -f "$N/Receive Files (NetShare)" ]   && rm -f "$N/Receive Files (NetShare)"   && echo "✓  Removed Nautilus Receive script"
for D in "$HOME/.local/share/kservices5/ServiceMenus" "$HOME/.local/share/kio/servicemenus"; do
    [ -f "$D/netshare-share.desktop" ]   && rm -f "$D/netshare-share.desktop"   && echo "✓  Removed KDE Share menu ($D)"
    [ -f "$D/netshare-receive.desktop" ] && rm -f "$D/netshare-receive.desktop" && echo "✓  Removed KDE Receive menu ($D)"
done
echo "Done."
