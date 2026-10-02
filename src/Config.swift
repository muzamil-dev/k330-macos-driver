import Foundation

public struct DriverConfig: Codable {
    public var vendorID: Int = 1133        // 0x046d (Logitech)
    public var productID: Int = 50475     // 0xc52b (Unifying Receiver)
    public var printScreenToClipboard: Bool = true
    public var shiftPrintScreenInteractive: Bool = true
    public var mapMenuKeyToCopy: Bool = true
    public var mapInsertKeyToPaste: Bool = true
    public var swapAltAndWindows: Bool = false
    public var playShutterSound: Bool = true

    public static let configDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config")
        .appendingPathComponent("k330")
    public static let configFile = configDir.appendingPathComponent("config.json")

    public static func load() -> DriverConfig {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(DriverConfig.self, from: data) else {
            let def = DriverConfig()
            def.save()
            return def
        }
        return config
    }

    public func save() {
        try? FileManager.default.createDirectory(at: DriverConfig.configDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: DriverConfig.configFile)
        }
    }
}
