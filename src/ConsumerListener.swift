import Foundation
import IOKit
import IOKit.hid

public class ConsumerListener {
    public static let shared = ConsumerListener()
    private var manager: IOHIDManager?

    private static let inputValueCallback: IOHIDValueCallback = { context, result, sender, value in
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intVal = IOHIDValueGetIntegerValue(value)

        // Only process key-down (value == 1)
        if intVal == 1 {
            ConsumerListener.shared.handleConsumerInput(page: page, usage: usage)
        }
    }

    public func start(config: DriverConfig) {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = mgr

        // Match Logitech receiver consumer (0x0c) & vendor (0xff00) interfaces
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
        IOHIDManagerRegisterInputValueCallback(mgr, ConsumerListener.inputValueCallback, nil)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        let ret = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        if ret == kIOReturnSuccess {
            print("[k330d] Consumer control listener started successfully.")
        } else {
            print("[k330d] Note: IOHIDManagerOpen returned \(ret)")
        }
    }

    public func stop() {
        if let mgr = manager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            manager = nil
        }
    }

    fileprivate func handleConsumerInput(page: UInt32, usage: UInt32) {
        print("[k330d] Consumer Input -> Page: 0x\(String(page, radix: 16)), Usage: 0x\(String(usage, radix: 16))")

        switch usage {
        case 0x18A: // AL Email Reader
            ActionPerformer.shared.launchEmail()
        case 0x223: // AC Home
            ActionPerformer.shared.launchBrowser()
        case 0x183: // AL Media Player
            ActionPerformer.shared.launchMusic()
        case 0x192: // AL Calculator
            ActionPerformer.shared.launchCalculator()
        case 0x19E: // AL Lock PC
            ActionPerformer.shared.lockScreen()
        case 0x1A2: // App Switcher
            ActionPerformer.shared.performAppSwitch()
        case 0x18B, 0x230: // Show Desktop
            ActionPerformer.shared.performShowDesktop()
        case 0xB0: // Play
            ActionPerformer.shared.performMediaKey(.play)
        case 0xB1, 0xCD: // Pause / Play-Pause
            ActionPerformer.shared.performMediaKey(.play)
        case 0xB3: // Fast Forward
            ActionPerformer.shared.performMediaKey(.next)
        case 0xB4: // Rewind
            ActionPerformer.shared.performMediaKey(.previous)
        case 0xB5: // Scan Next Track
            ActionPerformer.shared.performMediaKey(.next)
        case 0xB6: // Scan Previous Track
            ActionPerformer.shared.performMediaKey(.previous)
        case 0xB7: // Stop
            ActionPerformer.shared.performMediaKey(.stop)
        case 0xE2: // Mute
            ActionPerformer.shared.performMediaKey(.mute)
        case 0xE9: // Volume Increment
            ActionPerformer.shared.performMediaKey(.soundUp)
        case 0xEA: // Volume Decrement
            ActionPerformer.shared.performMediaKey(.soundDown)
        case 0x221: // AL Search
            ActionPerformer.shared.performSearch()
        case 0x224: // AC Back
            ActionPerformer.shared.performBrowserBack()
        case 0x225: // AC Forward
            ActionPerformer.shared.performBrowserForward()
        case 0x227: // AC Refresh
            ActionPerformer.shared.performBrowserRefresh()
        case 0x22A: // AC Bookmarks
            ActionPerformer.shared.performFavorites()
        default:
            break
        }
    }
}
