import Foundation
import Carbon

public class HotKeyManager {
    public static let shared = HotKeyManager()

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var config: DriverConfig = DriverConfig.load()

    private static let hotKeyEventHandler: EventHandlerUPP = { (handlerCallRef, eventRef, userData) -> OSStatus in
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

        HotKeyManager.shared.handleHotKey(id: hotKeyID.id)
        return noErr
    }

    public func start(config: DriverConfig) {
        self.config = config
        unregisterAll()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            HotKeyManager.hotKeyEventHandler,
            1,
            &eventType,
            nil,
            nil
        )

        // Register F13 (PrintScreen): Full-screen screenshot to clipboard
        registerKey(keyCode: UInt32(kVK_F13), modifiers: 0, id: 13)

        // Register Shift + F13 (Shift + PrintScreen): Interactive area screenshot to clipboard
        registerKey(keyCode: UInt32(kVK_F13), modifiers: UInt32(shiftKey), id: 113)

        // Register F14 (Context Menu Key): Copy (Cmd + C)
        if config.mapMenuKeyToCopy {
            registerKey(keyCode: UInt32(kVK_F14), modifiers: 0, id: 14)
        }

        // Register F15 (Insert Key): Paste (Cmd + V)
        if config.mapInsertKeyToPaste {
            registerKey(keyCode: UInt32(kVK_F15), modifiers: 0, id: 15)
        }

        print("[k330d] Global hotkeys registered successfully (F13=PrtScn, Shift+F13=SelectPrtScn, F14=Copy, F15=Paste).")
    }

    private func registerKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 0x4B333330 /* 'K330' */, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRefs.append(ref)
        } else {
            print("[k330d] Warning: Failed to register hotkey ID \(id), OSStatus: \(status)")
        }
    }

    public func unregisterAll() {
        for ref in hotKeyRefs {
            if let r = ref {
                UnregisterEventHotKey(r)
            }
        }
        hotKeyRefs.removeAll()
    }

    fileprivate func handleHotKey(id: UInt32) {
        switch id {
        case 13:
            print("[k330d] HotKey: Print Screen -> Entire Screen Screenshot")
            ActionPerformer.shared.takeScreenshot(interactive: false, config: config)
        case 113:
            print("[k330d] HotKey: Shift + Print Screen -> Interactive Selection Screenshot")
            ActionPerformer.shared.takeScreenshot(interactive: true, config: config)
        case 14:
            print("[k330d] HotKey: Context Menu Key -> Copy (Cmd+C)")
            ActionPerformer.shared.performCopy()
        case 15:
            print("[k330d] HotKey: Insert Key -> Paste (Cmd+V)")
            ActionPerformer.shared.performPaste()
        default:
            break
        }
    }
}
