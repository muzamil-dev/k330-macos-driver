import Foundation

let args = CommandLine.arguments
let command = args.count > 1 ? args[1].lowercased() : "run"
var config = DriverConfig.load()

func printUsage() {
    print("""
    Logitech K330 macOS Driver Manager

    Usage:
      k330-driver <command>

    Commands:
      run          Run the driver daemon in foreground (used by LaunchAgent)
      apply        Apply hardware key mappings (PrintScreen, Copy key, etc.)
      clear        Reset hardware key mappings to default
      status       Show current driver & receiver connection status
      test         Start live key tester to verify keys in real-time
      install      Build & install background driver service (LaunchAgent)
      uninstall    Remove driver service and restore default macOS settings
      help         Show this help message

    Features:
      • Print Screen (PrtScn)  -> Instant full-screen screenshot to clipboard
      • Shift + PrtScn         -> Interactive area screenshot to clipboard
      • Context Menu Key       -> Copy (Cmd + C)
      • Insert Key             -> Paste (Cmd + V)
      • Top Multimedia Keys    -> Native macOS app & playback controls
    """)
}

switch command {
case "run", "daemon":
    print("[k330d] Starting Logitech K330 driver daemon (PID: \(ProcessInfo.processInfo.processIdentifier))...")
    
    // Apply hardware mappings
    _ = HIDHardware.applyMappings(config: config)
    
    // Configure system symbolic hotkeys for WindowServer screenshot integration
    _ = HIDHardware.configureSystemSymbolicHotkeys()
    
    // Start listeners
    HotKeyManager.shared.start(config: config)
    ConsumerListener.shared.start(config: config)
    DeviceWatcher.shared.start(config: config)
    
    print("[k330d] Logitech K330 driver daemon is active and listening.")
    RunLoop.current.run()

case "apply":
    print("Applying Logitech K330 key mappings...")
    let ok = HIDHardware.applyMappings(config: config)
    let shOk = HIDHardware.configureSystemSymbolicHotkeys()
    if ok && shOk {
        print("✓ Successfully applied all key mappings.")
    } else {
        print("⚠ Mappings applied with warnings. Is the receiver plugged in?")
    }

case "clear":
    print("Clearing Logitech K330 key mappings...")
    let ok = HIDHardware.clearMappings(config: config)
    print(ok ? "✓ Cleared mappings." : "✗ Failed to clear mappings.")

case "status":
    print("======================================================")
    print(" Logitech K330 Driver Status")
    print("======================================================")
    let connected = HIDHardware.isReceiverConnected(config: config)
    print("Receiver Connected:  \(connected ? "✓ Yes (0x046d:0xc52b)" : "✗ Not detected")")

    // Check launchd
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = ["list"]
    let pipe = Pipe()
    p.standardOutput = pipe
    try? p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    let out = String(data: data, encoding: .utf8) ?? ""
    let isDaemonRunning = out.contains("com.muzamil.k330d")
    print("Service (Launchd):   \(isDaemonRunning ? "✓ Running" : "○ Not loaded / Stopped")")

    print("\nConfiguration:")
    print("  • PrintScreen -> Clipboard:    \(config.printScreenToClipboard)")
    print("  • Shift+PrintScreen Area:      \(config.shiftPrintScreenInteractive)")
    print("  • Menu Key -> Copy (Cmd+C):    \(config.mapMenuKeyToCopy)")
    print("  • Insert Key -> Paste (Cmd+V): \(config.mapInsertKeyToPaste)")
    print("  • Swap Alt/Windows Keys:       \(config.swapAltAndWindows)")
    print("  • Camera Shutter Sound:        \(config.playShutterSound)")
    print("  • Config File:                 \(DriverConfig.configFile.path)")

case "test":
    DiagnosticTester.run(config: config)

case "install":
    print("Installing Logitech K330 driver...")
    let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0])
        .deletingLastPathComponent()
        .appendingPathComponent("../scripts/install.sh")
        .standardized
    if FileManager.default.fileExists(atPath: scriptPath.path) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptPath.path]
        try? task.run()
        task.waitUntilExit()
    } else {
        print("Install script not found at \(scriptPath.path). Run 'make install' from project root.")
    }

case "uninstall":
    print("Uninstalling Logitech K330 driver...")
    let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0])
        .deletingLastPathComponent()
        .appendingPathComponent("../scripts/uninstall.sh")
        .standardized
    if FileManager.default.fileExists(atPath: scriptPath.path) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptPath.path]
        try? task.run()
        task.waitUntilExit()
    } else {
        print("Uninstall script not found at \(scriptPath.path). Run 'make uninstall' from project root.")
    }

case "help", "--help", "-h":
    printUsage()

default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}
