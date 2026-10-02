import Foundation
import CoreGraphics
import AppKit
import Carbon

public class ActionPerformer {
    public static let shared = ActionPerformer()
    private var shutterSound: NSSound?

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
