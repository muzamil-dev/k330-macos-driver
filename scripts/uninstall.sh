#!/usr/bin/env bash
set -e

AGENT_DIR="$HOME/Library/LaunchAgents"
BIN_DIR="$HOME/.local/bin"

echo "==> Stopping and unloading k330d service..."
launchctl bootout gui/$(id -u)/com.local.k330d 2>/dev/null || true
launchctl unload "$AGENT_DIR"/com.local.k330d.plist 2>/dev/null || true

echo "==> Removing LaunchAgent plist..."
rm -f "$AGENT_DIR"/com.local.k330d.plist

echo "==> Resetting hardware mappings..."
if [ -x "$BIN_DIR/k330d" ]; then
    "$BIN_DIR"/k330d clear || true
fi

echo "==> Removing installed binaries..."
rm -f "$BIN_DIR"/k330d "$BIN_DIR"/k330-driver

echo "✓ Logitech K330 Driver uninstalled successfully."
