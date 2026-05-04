#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== HostSwitcher Setup ==="
echo ""

echo "Building HostSwitcher.app..."
bash "$SCRIPT_DIR/build.sh"
echo ""
echo "Setup complete."
echo ""
echo "Next steps:"
echo "  1. Open the app: open $SCRIPT_DIR/HostSwitcher.app"
echo "  2. Add HostSwitcher to Input Monitoring and Accessibility"
echo "     in System Settings > Privacy & Security."
echo "  3. Restart HostSwitcher after granting permissions."
echo "  4. Use Cmd+Opt+1/2/3 or the menu bar icon to switch hosts."
