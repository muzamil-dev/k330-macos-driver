import Foundation
import CoreGraphics
import AppKit
import Carbon

public class ActionPerformer {
    public static let shared = ActionPerformer()
    private var shutterSound: NSSound?

    public enum MediaKey: UInt32 {
        case soundUp = 0
        case soundDown = 1
        case mute = 7
        case play = 16
        case next = 17
        case previous = 18
        case stop = 19
    }

    init() {
        let soundPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"
        if FileManager.default.fileExists(atPath: soundPath) {
            shutterSound = NSSound(contentsOfFile: soundPath, byReference: true)
        }
    }

    public func playSound() {
        if let sound = shutterSound {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    public func takeScreenshot(interactive: Bool, config: DriverConfig) {
        if config.playShutterSound {
            playSound()
        }

        // Method A: Execute screencapture CLI in Aqua session
        DispatchQueue.global(qos: .userInteractive).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            if interactive {
                task.arguments = ["-i", "-c"] // Interactive selection directly to clipboard
            } else {
                task.arguments = ["-c"]      // Entire screen directly to clipboard
            }

            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus != 0 {
                    // Fallback to posting synthetic key combination
                    self.postScreenshotKeyFallback(interactive: interactive)
                }
            } catch {
                self.postScreenshotKeyFallback(interactive: interactive)
            }
        }
    }

    private func postScreenshotKeyFallback(interactive: Bool) {
        DispatchQueue.main.async {
            let src = CGEventSource(stateID: .hidSystemState)
            // 0x14 = '3', 0x15 = '4'
            let vk: CGKeyCode = interactive ? 0x15 : 0x14
            let flags: CGEventFlags = [.maskCommand, .maskControl, .maskShift]

            if let down = CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: false) {
                down.flags = flags
                up.flags = flags
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
        }
    }

    public func performCopy() {
        let src = CGEventSource(stateID: .hidSystemState)
        // 0x08 = kVK_ANSI_C ('c')
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true),
           let up = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false) {
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            print("[k330d] Executed Copy (Cmd+C)")
        }
    }

    public func performPaste() {
        let src = CGEventSource(stateID: .hidSystemState)
        // 0x09 = kVK_ANSI_V ('v')
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
           let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) {
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            print("[k330d] Executed Paste (Cmd+V)")
        }
    }

    public func performAppSwitch() {
        let src = CGEventSource(stateID: .hidSystemState)
        // 0x30 = kVK_Tab
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 0x30, keyDown: true),
           let up = CGEvent(keyboardEventSource: src, virtualKey: 0x30, keyDown: false) {
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            print("[k330d] Executed App Switcher (Cmd+Tab)")
        }
    }

    public func performShowDesktop() {
        let src = CGEventSource(stateID: .hidSystemState)
        // 0x67 = kVK_F11 (Show Desktop)
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 0x67, keyDown: true),
           let up = CGEvent(keyboardEventSource: src, virtualKey: 0x67, keyDown: false) {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            print("[k330d] Executed Show Desktop (F11)")
        }
    }

    public func performMediaKey(_ key: MediaKey) {
        let source = CGEventSource(stateID: .hidSystemState)
        let data1 = Int64(key.rawValue << 16 | 0xA00)

        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseDown,
            mouseCursorPosition: .zero,
            mouseButton: .left
        ), let up = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseUp,
            mouseCursorPosition: .zero,
            mouseButton: .left
        ) else {
            print("[k330d] Failed to create media key event \(key).")
            return
        }

        down.type = CGEventType(rawValue: 14)!
        up.type = CGEventType(rawValue: 14)!
        down.setIntegerValueField(CGEventField(rawValue: 1)!, value: data1)
        up.setIntegerValueField(CGEventField(rawValue: 1)!, value: data1)
        down.setIntegerValueField(CGEventField(rawValue: 2)!, value: -1)
        up.setIntegerValueField(CGEventField(rawValue: 2)!, value: 0)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    public func performBrowserBack() {
        performKeyCombo(keyCode: 0x7B, flags: .maskCommand)
    }

    public func performBrowserForward() {
        performKeyCombo(keyCode: 0x7C, flags: .maskCommand)
    }

    public func performBrowserRefresh() {
        performKeyCombo(keyCode: 0x0F, flags: .maskCommand)
    }

    public func performSearch() {
        performKeyCombo(keyCode: 0x0C, flags: .maskCommand)
    }

    public func performFavorites() {
        performKeyCombo(keyCode: 0x2F, flags: [.maskCommand, .maskAlternate])
    }

    private func performKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("[k330d] Failed to create keyboard event for key code \(keyCode).")
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    public func launchEmail() {
        if let url = URL(string: "mailto:") {
            NSWorkspace.shared.open(url)
            print("[k330d] Launched Mail")
        }
    }

    public func launchBrowser() {
        if let url = URL(string: "https://google.com") {
            NSWorkspace.shared.open(url)
            print("[k330d] Launched Browser")
        }
    }

    public func launchMusic() {
        let path = "/System/Applications/Music.app"
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            print("[k330d] Launched Music")
        }
    }

    public func launchCalculator() {
        let path = "/System/Applications/Calculator.app"
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            print("[k330d] Launched Calculator")
        }
    }

    public func lockScreen() {
        let cgsession = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        if FileManager.default.fileExists(atPath: cgsession) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: cgsession)
            task.arguments = ["-suspend"]
            try? task.run()
            print("[k330d] Locked Screen via CGSession")
        } else {
            // Fallback: Ctrl+Cmd+Q
            let src = CGEventSource(stateID: .hidSystemState)
            if let down = CGEvent(keyboardEventSource: src, virtualKey: 0x0C /* 'q' */, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: 0x0C, keyDown: false) {
                down.flags = [.maskCommand, .maskControl]
                up.flags = [.maskCommand, .maskControl]
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
        }
    }
}
