import Foundation

public class HIDHardware {
    public static func applyMappings(config: DriverConfig) -> Bool {
        var mappings: [[String: UInt64]] = []

        // Print Screen (0x700000046) -> F13 (0x700000068)
        mappings.append([
            "HIDKeyboardModifierMappingSrc": 0x700000046,
            "HIDKeyboardModifierMappingDst": 0x700000068
        ])

        // Context Menu Key (0x700000065) -> F14 (0x700000069)
        if config.mapMenuKeyToCopy {
            mappings.append([
                "HIDKeyboardModifierMappingSrc": 0x700000065,
                "HIDKeyboardModifierMappingDst": 0x700000069
            ])
        }

        // Insert Key (0x700000049) -> F15 (0x70000006A)
        if config.mapInsertKeyToPaste {
            mappings.append([
                "HIDKeyboardModifierMappingSrc": 0x700000049,
                "HIDKeyboardModifierMappingDst": 0x70000006A
            ])
        }

        // Optional: Swap Alt and Windows keys
        if config.swapAltAndWindows {
            // Left Alt (0x7000000E2) <-> Left GUI (0x7000000E3)
            mappings.append([
                "HIDKeyboardModifierMappingSrc": 0x7000000E2,
                "HIDKeyboardModifierMappingDst": 0x7000000E3
            ])
            mappings.append([
                "HIDKeyboardModifierMappingSrc": 0x7000000E3,
                "HIDKeyboardModifierMappingDst": 0x7000000E2
            ])
            // Right Alt (0x7000000E6) <-> Right GUI (0x7000000E7)
            mappings.append([
                "HIDKeyboardModifierMappingSrc": 0x7000000E6,
                "HIDKeyboardModifierMappingDst": 0x7000000E7
            ])
        }

        let matchingJSON = "{\"VendorID\": \(config.vendorID), \"ProductID\": \(config.productID)}"
        
        guard let mappingsData = try? JSONSerialization.data(withJSONObject: mappings, options: []),
              let mappingsStr = String(data: mappingsData, encoding: .utf8) else {
            return false
        }
        let propertyJSON = "{\"UserKeyMapping\": \(mappingsStr)}"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        task.arguments = ["property", "--matching", matchingJSON, "--set", propertyJSON]

        do {
            try task.run()
            task.waitUntilExit()
            let success = (task.terminationStatus == 0)
            if success {
                print("[k330d] Applied hardware key mappings successfully to K330 receiver.")
            }
            return success
        } catch {
            print("[k330d] Error executing hidutil: \(error)")
            return false
        }
    }

    public static func clearMappings(config: DriverConfig) -> Bool {
        let matchingJSON = "{\"VendorID\": \(config.vendorID), \"ProductID\": \(config.productID)}"
        let propertyJSON = "{\"UserKeyMapping\": []}"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        task.arguments = ["property", "--matching", matchingJSON, "--set", propertyJSON]

        do {
            try task.run()
            task.waitUntilExit()
            return (task.terminationStatus == 0)
        } catch {
            return false
        }
    }

    public static func configureSystemSymbolicHotkeys() -> Bool {
        // Read current symbolichotkeys
        let exportTask = Process()
        exportTask.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        exportTask.arguments = ["export", "com.apple.symbolichotkeys", "-"]
        let pipe = Pipe()
        exportTask.standardOutput = pipe

        do {
            try exportTask.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            exportTask.waitUntilExit()

            guard var plist = (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil)) as? [String: Any] else {
                return false
            }

            var hotkeys = (plist["AppleSymbolicHotKeys"] as? [String: Any]) ?? [:]

            // Key 29: Copy entire screen to clipboard -> F13 (kVK_F13 = 105, char = 65535, mod = 0)
            hotkeys["29"] = [
                "enabled": true,
                "value": [
                    "parameters": [65535, 105, 0],
                    "type": "standard"
                ]
            ]

            // Key 31: Copy selected area to clipboard -> Shift + F13 (kVK_F13 = 105, char = 65535, mod = 131072)
            hotkeys["31"] = [
                "enabled": true,
                "value": [
                    "parameters": [65535, 105, 131072],
                    "type": "standard"
                ]
            ]

            plist["AppleSymbolicHotKeys"] = hotkeys

            let updatedData = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)

            let importTask = Process()
            importTask.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            importTask.arguments = ["import", "com.apple.symbolichotkeys", "-"]
            let inPipe = Pipe()
            importTask.standardInput = inPipe
            try importTask.run()
            inPipe.fileHandleForWriting.write(updatedData)
            inPipe.fileHandleForWriting.closeFile()
            importTask.waitUntilExit()

            // Notify system preferences daemon
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["cfprefsd"]
            try? killTask.run()
            killTask.waitUntilExit()

            print("[k330d] Configured macOS system screenshot symbolic hotkeys.")
            return true
        } catch {
            print("[k330d] Failed to configure symbolic hotkeys: \(error)")
            return false
        }
    }

    public static func isReceiverConnected(config: DriverConfig) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        task.arguments = ["list"]
        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            if let out = String(data: data, encoding: .utf8) {
                let hexVID = String(format: "0x%x", config.vendorID)
                let hexPID = String(format: "0x%x", config.productID)
                return out.contains(hexVID) && out.contains(hexPID)
            }
        } catch {
            return false
        }
        return false
    }
}
