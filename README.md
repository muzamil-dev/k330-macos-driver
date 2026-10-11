# Logitech K330 macOS Driver (`k330d`)

A native, zero-bloat macOS background driver and companion utility designed specifically for the **Logitech K330** wireless keyboard (connected via the Logitech Unifying USB Receiver `0x046d:0xc52b`).

---

## Features

- 📸 **Print Screen (PrtScn) Key**:
  - **Press PrtScn**: Takes an instant full-screen screenshot and copies it directly to your clipboard (with camera shutter sound).
  - **Press Shift + PrtScn**: Opens the macOS interactive crosshair selector to capture any screen region directly to your clipboard.
- 📋 **Dedicated Copy Key**:
  - Pressing the **Context Menu key** (between Right Alt and Right Ctrl) instantly performs **Copy (`Command + C`)** in any active app.
- 📥 **Dedicated Paste Key**:
  - Pressing the **Insert key** performs **Paste (`Command + V`)**.
- 🎵 **Multimedia & Application Hotkeys**:
  - **Launch Email**: Opens your default Mail application.
  - **Home**: Opens your default web browser.
  - **Launch Media Player**: Opens Music.app.
  - **Calculator**: Opens macOS Calculator.
  - **Show Desktop**: Toggles Show Desktop / Mission Control.
  - **Switch Applications**: Triggers macOS Application Switcher (`Command + Tab`).
  - **Lock PC**: Locks your Mac screen immediately.
  - **Media Controls**: Volume Up/Down, Mute, Play/Pause, Stop, Fast Forward, Rewind, Next/Previous track.
  - **Browser Controls**: Search, Back, Forward, Refresh, and Bookmarks.
- ⚡ **Zero-Latency Kernel-Level Remapping**:
  - Uses Apple's native `hidutil` targeting only the Logitech receiver ID (`VendorID: 1133, ProductID: 50475`). Built-in Mac keyboards remain 100% untouched.
- 🔄 **Auto-Reconnect & Sleep/Wake Persistence**:
  - Automatically re-applies hardware mappings whenever the Mac wakes from sleep or the USB receiver is replugged.
- 🚀 **Native Swift Background Service**:
  - Managed via `launchd` LaunchAgent (`com.local.k330d`). Runs seamlessly at login with zero CPU overhead.

---

## CLI Management (`k330-driver`)

The driver comes with a command-line tool `k330-driver` (installed in `~/.local/bin`):

```bash
# Check driver service and receiver connection status
k330-driver status

# Start live interactive tester (press keys and see events in real-time)
k330-driver test

# Manually re-apply hardware key mappings
k330-driver apply

# Reset hardware mappings back to system defaults
k330-driver clear

# Install LaunchAgent service (starts at login)
k330-driver install

# Uninstall service and remove all files
k330-driver uninstall
```

---

## Configuration

Settings are saved in `~/.config/k330/config.json`:

```json
{
  "vendorID": 1133,
  "productID": 50475,
  "printScreenToClipboard": true,
  "shiftPrintScreenInteractive": true,
  "mapMenuKeyToCopy": true,
  "mapInsertKeyToPaste": true,
  "swapAltAndWindows": false,
  "playShutterSound": true
}
```

If you ever want to swap Alt and Windows keys (so the physical Alt key next to the spacebar behaves as Command, matching Apple layout), set `"swapAltAndWindows": true` and run `k330-driver apply`.

---

## Architecture

1. **Hardware Layer (`hidutil`)**:
   Maps `0x700000046` (PrintScreen) to `F13` (`0x700000068`), `0x700000065` (Menu Key) to `F14` (`0x700000069`), and `0x700000049` (Insert) to `F15` (`0x70000006A`) at the `AppleUserHIDEventService` layer.
2. **System Layer (`com.apple.symbolichotkeys`)**:
   Hooks `F13` into macOS WindowServer Key 29 (full-screen screenshot to clipboard) and `Shift+F13` into Key 31 (region screenshot to clipboard) for native performance.
3. **Daemon Layer (`k330d`)**:
   Runs as an Aqua LaunchAgent (`~/Library/LaunchAgents/com.local.k330d.plist`). Captures Carbon global hotkeys for F13/F14/F15, posts synthetic `Cmd+C` / `Cmd+V`, plays audio feedback, and monitors `IOHIDManager` for multimedia controls and device reconnection.
