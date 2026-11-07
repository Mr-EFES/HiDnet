import Foundation

enum AppIdentity {
    static var tunnelIdentifier: String? {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: plugins, includingPropertiesForKeys: nil
              ) else { return nil }
        return contents.compactMap { Bundle(url: $0) }.first {
            let extensionInfo = $0.object(forInfoDictionaryKey: "NSExtension") as? [String: Any]
            return extensionInfo?["NSExtensionPointIdentifier"] as? String == "com.apple.networkextension.packet-tunnel"
        }?.bundleIdentifier
    }
}
