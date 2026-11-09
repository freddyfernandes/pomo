#!/bin/bash
# Builds Pomo.app in ./build and launches it. Safe: nothing outside this folder except an optional login item.
#   ./build.sh            build if needed, then open the app
#   ./build.sh --pin      also start Pomo at login (menu-bar app, countdown in the menu bar)
#   ./build.sh --unpin    undo that login item
#   ./build.sh --login    remove the login item (keep pinning)
#   ./build.sh --once     just refresh the app in this folder (no relaunch)
set -euo pipefail
cd "$(dirname "$0")"
APP="$(pwd)/build/Pomo.app"
BIN="$APP/Contents/MacOS/Pomo"
case "${1:-}" in
  --pin)   defaults write local.pomo pinMenuBar -bool YES ;;
  --unpin) defaults write local.pomo pinMenuBar -bool NO; osascript -e "tell application \"System Events\" to delete login item \"Pomo\"" >/dev/null 2>&1 || true ;;
  --login) osascript -e "tell application \"System Events\" to delete login item \"Pomo\"" >/dev/null 2>&1 || true ;;
esac
if [ ! -x "$BIN" ] || [ Pomo.swift -nt "$BIN" ]; then
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  swiftc -O -module-cache-path ./.cache Pomo.swift -o "$BIN"
  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.pomo</string>
  <key>CFBundleName</key><string>Pomo</string>
  <key>CFBundleExecutable</key><string>Pomo</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleIconFile</key><string>Pomo</string>
</dict></plist>
PLIST
  cp assets/icon.icns "$APP/Contents/Resources/Pomo.icns"
fi
[ "${1:-}" = "--once" ] && exit 0
if [ "${1:-}" = "--pin" ]; then
  open "$APP"; sleep 1
  # Login item: start Pomo (and its countdown) at every login. Needs no extra permission on a local app.
  osascript -e "tell application \"System Events\" to make login item at end with properties {name:\"Pomo\", path:\"$APP\", hidden:false}" 2>/dev/null \
    || echo "Pomo pinned; add it under System Settings > General > Login Items to start at login."
else
  open "$APP"
fi
