import Foundation
import AppKit
import IOKit
import IOKit.usb

public class DeviceWatcher {
    public static let shared = DeviceWatcher()
    private var timer: Timer?
    private var lastConnectedState = false
    private var config = DriverConfig.load()

    public func start(config: DriverConfig) {
        self.config = config

        // 1. Initial check & apply
        let connected = HIDHardware.isReceiverConnected(config: config)
        lastConnectedState = connected
        if connected {
            print("[k330d] Logitech K330 receiver detected on startup.")
            _ = HIDHardware.applyMappings(config: config)
        } else {
            print("[k330d] Waiting for Logitech K330 receiver to connect...")
        }

        // 2. Watch for system wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeNotification),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // 3. Periodic check for device connect/reconnect every 4 seconds
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                self?.checkDeviceConnection()
            }
        }
    }

    @objc private func handleWakeNotification() {
        print("[k330d] System woke from sleep; refreshing key mappings...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            _ = HIDHardware.applyMappings(config: self.config)
        }
    }

    private func checkDeviceConnection() {
        let connected = HIDHardware.isReceiverConnected(config: config)
        if connected && !lastConnectedState {
            print("[k330d] Logitech K330 receiver reconnected! Re-applying mappings...")
            _ = HIDHardware.applyMappings(config: config)
        }
        lastConnectedState = connected
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
