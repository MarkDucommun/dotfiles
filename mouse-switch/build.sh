#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/HostSwitcher.app"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

echo "Building HostSwitcher..."
swiftc -O \
  -o "$APP_DIR/Contents/MacOS/HostSwitcher" \
  "$SCRIPT_DIR/HostSwitcher/main.swift" \
  -framework AppKit \
  -framework IOKit \
  -framework Carbon

# Sign with dev identity if available, otherwise ad-hoc
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -n "$IDENTITY" ]; then
  echo "Signing with: $IDENTITY"
  codesign --force --sign "$IDENTITY" "$APP_DIR"
else
  echo "No dev identity found, signing ad-hoc..."
  codesign --force --sign - "$APP_DIR"
fi

echo ""
echo "Built: $APP_DIR"
echo ""
echo "Next steps:"
echo "  1. Open the app:  open $APP_DIR"
echo "  2. Add HostSwitcher to Input Monitoring AND Accessibility"
echo "     (System Settings → Privacy & Security)"
echo "  3. Restart the app after granting permissions"
echo "  4. Use Cmd+Opt+1/2/3 or the menu bar icon to switch hosts"
