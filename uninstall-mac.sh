#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -d "$HOME/Library/Services/Share with NetShare.workflow" ]    && rm -rf "$HOME/Library/Services/Share with NetShare.workflow"    && echo "✓  Removed Share Quick Action"
[ -d "$HOME/Library/Services/Receive Files (NetShare).workflow" ] && rm -rf "$HOME/Library/Services/Receive Files (NetShare).workflow" && echo "✓  Removed Receive Quick Action"
[ -f "$SCRIPT_DIR/run-share.sh" ]   && rm -f "$SCRIPT_DIR/run-share.sh"   && echo "✓  Removed share launcher"
[ -f "$SCRIPT_DIR/run-receive.sh" ] && rm -f "$SCRIPT_DIR/run-receive.sh" && echo "✓  Removed receive launcher"
/System/Library/CoreServices/pbs -update 2>/dev/null || true
echo "Done."
