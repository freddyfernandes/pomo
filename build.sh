#!/bin/bash
# Builds and opens Pomo. macOS: build/Pomo.app, Windows (via Swift for Windows): build\Pomo.exe
#   ./build.sh            build if needed, then open
#   ./build.sh --pin      also start at login (menu bar countdown)
#   ./build.sh --unpin    undo that
#   ./build.sh --once     only build, do not open
set -euo pipefail
cd "$(dirname "$0")"

# Windows (Git Bash / MSYS): no app bundle or login items, just an exe.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    mkdir -p build
    [ -f build/Pomo.exe ] && [ build/Pomo.exe -nt Pomo.swift ] || swiftc -O Pomo.swift -o build/Pomo.exe
    [ "${1:-}" = "--once" ] && exit 0
    start build/Pomo.exe; exit 0 ;;
esac

# macOS
APP="$(pwd)/build/Pomo.app"
BIN="$APP/Contents/MacOS/Pomo"
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
case "${1:-}" in
  --pin)
    defaults write local.pomo pinMenuBar -bool YES
    open "$APP"; sleep 1
    osascript -e "tell application \"System Events\" to make login item at end with properties {name:\"Pomo\", path:\"$APP\", hidden:false}" 2>/dev/null \
      || echo "Pomo pinned; add it under System Settings > General > Login Items to start at login." ;;
  --unpin)
    defaults write local.pomo pinMenuBar -bool NO
    osascript -e "tell application \"System Events\" to delete login item \"Pomo\"" >/dev/null 2>&1 || true
    open "$APP" ;;
  *) open "$APP" ;;
esac
