#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
BIN_DIR="$HOME/.local/bin"
AGENT_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs"

mkdir -p "$BIN_DIR" "$AGENT_DIR" "$LOG_DIR"

echo "==> Building Logitech K330 macOS Driver..."
swiftc \
    "$DIR"/src/*.swift \
    -framework Foundation \
    -framework CoreGraphics \
    -framework Carbon \
    -framework IOKit \
    -framework AppKit \
    -O \
    -o "$DIR"/build/k330d

echo "==> Installing binary to $BIN_DIR/k330d..."
mkdir -p "$DIR/build"
cp -f "$DIR"/build/k330d "$BIN_DIR"/k330d
ln -sf "$BIN_DIR"/k330d "$BIN_DIR"/k330-driver

echo "==> Installing LaunchAgent..."
cp -f "$DIR"/launchd/com.local.k330d.plist "$AGENT_DIR"/com.local.k330d.plist

# Unload if currently loaded
launchctl bootout gui/$(id -u)/com.local.k330d 2>/dev/null || true
launchctl unload "$AGENT_DIR"/com.local.k330d.plist 2>/dev/null || true

# Load service
echo "==> Starting k330d background service..."
launchctl bootstrap gui/$(id -u) "$AGENT_DIR"/com.local.k330d.plist 2>/dev/null || \
launchctl load "$AGENT_DIR"/com.local.k330d.plist

# Apply immediate mappings
echo "==> Applying immediate hardware mappings..."
"$BIN_DIR"/k330d apply

echo ""
echo "✓ Logitech K330 Driver successfully installed and running!"
echo "  Run 'k330-driver status' to view status."
echo "  Run 'k330-driver test' to test keys interactively."
