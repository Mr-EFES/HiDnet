import Foundation

public enum OpenFluxImport {
    public static func parse(_ text: String) throws -> VPNProfile {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf8.count <= 65_536 else { throw ProfileError.oversizedImport }
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "openflux",
              components.host?.lowercased() == "import",
              components.user == nil, components.password == nil,
              components.port == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw ProfileError.invalidImport
        }
        let values = components.queryItems?.filter { $0.name == "data" } ?? []
        guard values.count == 1, let payload = values.first?.value,
              !payload.isEmpty,
              payload.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "_-=".contains($0)) }) else {
            throw ProfileError.invalidImport
        }
        var base64 = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), data.count <= 49_152 else {
            throw ProfileError.invalidImport
        }
        let value: Payload
        do {
            value = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw ProfileError.invalidImport
        }
        guard let transport = OpenFluxTransport(rawValue: value.transport ?? "yandex") else {
            throw ProfileError.unsupportedTransport
        }
        guard let mode = ProfileMode(rawValue: value.mode ?? "key") else {
            throw ProfileError.invalidImport
        }
        let name = value.name.flatMap { $0.isEmpty ? nil : $0 } ?? "Импортированный профиль"
        let profile = VPNProfile(
            name: name,
            mode: [.mailru, .boards].contains(transport) ? .manual : mode,
            transport: transport, documentURL: value.docURL ?? "",
            documentURLs: value.docURLs ?? [], controlURL: value.controlURL ?? "",
            keyToken: value.keyToken ?? "", maxToken: value.maxToken ?? "",
            maxUID: value.maxUID ?? 0, mtu: value.mtu ?? 1400,
            dnsUpstream: value.dnsUpstream ?? "77.88.8.8",
            forceBootstrapDNS: value.forceBootstrapDNS ?? "",
            autoReconnect: value.autoReconnect ?? true,
            e2eEncryption: value.e2eEncryption ?? false
        )
        try profile.validate()
        return profile
    }

    private struct Payload: Decodable {
        var name: String?
        var mode: String?
        var transport: String?
        var docURL: String?
        var docURLs: [String]?
        var controlURL: String?
        var keyToken: String?
        var maxToken: String?
        var maxUID: Int64?
        var mtu: Int?
        var dnsUpstream: String?
        var forceBootstrapDNS: String?
        var autoReconnect: Bool?
        var e2eEncryption: Bool?

        enum CodingKeys: String, CodingKey {
            case name, mode, transport
            case docURL = "doc_url", docURLs = "doc_urls", controlURL = "control_url"
            case keyToken = "key_token", maxToken = "max_token", maxUID = "max_uid"
            case mtu, dnsUpstream = "dns_upstream", forceBootstrapDNS = "force_bootstrap_dns"
            case autoReconnect = "auto_reconnect", e2eEncryption = "e2e_encryption"
        }
    }
}
