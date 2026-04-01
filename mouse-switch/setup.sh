#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KARABINER_DIR="$HOME/.config/karabiner/assets/complex_modifications"

echo "=== MX Master 3 Host Switch Setup ==="

# 1. Make script executable
chmod +x "$SCRIPT_DIR/switch_mouse.py"

# 2. Symlink Karabiner rule
echo ""
if [ -d "$KARABINER_DIR" ]; then
  ln -sf "$SCRIPT_DIR/mx_master_host_switch.json" "$KARABINER_DIR/mx_master_host_switch.json"
  echo "Karabiner rule symlinked."
  echo "  → Open Karabiner-Elements → Complex Modifications → Add Rule → enable it."
else
  echo "Warning: Karabiner config directory not found at $KARABINER_DIR"
  echo "  Install Karabiner-Elements first, then re-run this script."
fi

# 3. Detect mouse
echo ""
echo "Detecting Logitech devices..."
python3 "$SCRIPT_DIR/switch_mouse.py" --detect

echo ""
echo "Setup complete."
echo ""
echo "Next steps:"
echo "  1. Confirm your MX Master 3's PID is in BT_PIDS at the top of switch_mouse.py"
echo "  2. Test:  python3 $SCRIPT_DIR/switch_mouse.py 2"
echo "  3. Grant Input Monitoring to Ghostty if prompted (System Settings → Privacy & Security)"
echo "  4. Enable the Karabiner rule in Karabiner-Elements → Complex Modifications"
