import Foundation
import Carbon
import IOKit
import IOKit.hid
import AppKit

public class DiagnosticTester {
    private static var manager: IOHIDManager?

    public static func run(config: DriverConfig) {
        print("======================================================")
        print(" Logitech K330 Live Diagnostic Key Tester")
        print("======================================================")
        print("Checking hardware receiver...")
        let connected = HIDHardware.isReceiverConnected(config: config)
        if connected {
            print("  ✓ Logitech Unifying Receiver (0x046d:0xc52b) CONNECTED")
        } else {
            print("  ✗ Warning: Receiver not detected yet. Plug it in to test.")
        }

        print("\nApplying driver key mappings for testing...")
        _ = HIDHardware.applyMappings(config: config)

        print("\nListening for inputs in real-time. Try pressing:")
        print("  - Print Screen (PrtScn)")
        print("  - Shift + Print Screen")
        print("  - Context Menu Key (next to right Ctrl)")
        print("  - Insert Key")
        print("  - Top Multimedia Buttons (Email, Home, Music, Desktop, etc.)")
        print("  (Press Ctrl + C in this terminal to exit)\n")

        // 1. Carbon hotkey handler
        let eventHandler: EventHandlerUPP = { (handlerCallRef, eventRef, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return noErr }

            switch hotKeyID.id {
            case 13:
                print("  \u{001B}[32m[DETECTED]\u{001B}[0m Print Screen (F13) -> Copied entire screen to clipboard! 📸")
                ActionPerformer.shared.playSound()
            case 113:
                print("  \u{001B}[32m[DETECTED]\u{001B}[0m Shift + Print Screen -> Interactive area selection! ✂️")
                ActionPerformer.shared.playSound()
            case 14:
                print("  \u{001B}[32m[DETECTED]\u{001B}[0m Context Menu Key (F14) -> Triggered Copy (Cmd+C)! 📋")
            case 15:
                print("  \u{001B}[32m[DETECTED]\u{001B}[0m Insert Key (F15) -> Triggered Paste (Cmd+V)! 📥")
            default:
                print("  [DETECTED] HotKey ID: \(hotKeyID.id)")
            }
            return noErr
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), eventHandler, 1, &eventType, nil, nil)

        var ref1: EventHotKeyRef?
        var ref2: EventHotKeyRef?
        var ref3: EventHotKeyRef?
        var ref4: EventHotKeyRef?

        RegisterEventHotKey(UInt32(kVK_F13), 0, EventHotKeyID(signature: 0x4B33, id: 13), GetApplicationEventTarget(), 0, &ref1)
        RegisterEventHotKey(UInt32(kVK_F13), UInt32(shiftKey), EventHotKeyID(signature: 0x4B33, id: 113), GetApplicationEventTarget(), 0, &ref2)
        RegisterEventHotKey(UInt32(kVK_F14), 0, EventHotKeyID(signature: 0x4B33, id: 14), GetApplicationEventTarget(), 0, &ref3)
        RegisterEventHotKey(UInt32(kVK_F15), 0, EventHotKeyID(signature: 0x4B33, id: 15), GetApplicationEventTarget(), 0, &ref4)

        // 2. Consumer & Vendor HID listener
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr
        let matchCriteria: [[String: Any]] = [
            [
                kIOHIDVendorIDKey as String: config.vendorID,
                kIOHIDProductIDKey as String: config.productID,
                kIOHIDPrimaryUsagePageKey as String: 0x0C
            ],
            [
                kIOHIDVendorIDKey as String: config.vendorID,
                kIOHIDProductIDKey as String: config.productID,
                kIOHIDPrimaryUsagePageKey as String: 0xFF00
            ]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(mgr, matchCriteria as CFArray)

        let valueCallback: IOHIDValueCallback = { context, result, sender, value in
            let element = IOHIDValueGetElement(value)
            let page = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let val = IOHIDValueGetIntegerValue(value)

            var desc = "Usage 0x\(String(usage, radix: 16))"
            switch usage {
            case 0x18A: desc = "Launch Email"
            case 0x223: desc = "Home (Browser)"
            case 0x183: desc = "Launch Media Player"
            case 0x192: desc = "Calculator"
            case 0x19E: desc = "Lock PC"
            case 0x1A2: desc = "App Switcher"
            case 0x18B, 0x230: desc = "Show Desktop"
            case 0xCD: desc = "Play/Pause"
            case 0xB5: desc = "Next Track"
            case 0xB6: desc = "Previous Track"
            case 0xE2: desc = "Mute"
            case 0xE9: desc = "Volume Up"
            case 0xEA: desc = "Volume Down"
            default: break
            }

            print("  \u{001B}[34m[HID EVENT]\u{001B}[0m Page: 0x\(String(page, radix: 16)), Usage: \(desc), State: \(val == 1 ? "Down" : "Up") (\(val))")
        }

        IOHIDManagerRegisterInputValueCallback(mgr, valueCallback, nil)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))

        CFRunLoopRun()
    }
}
