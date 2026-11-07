import Foundation

public enum OpenFluxTransport: String, Codable, CaseIterable, Identifiable, Sendable {
    case yandex, volga, max, mailru, boards, mts, telemost
    case yandexMultistream = "yandex_multistream"
    case cups = "cupsonline"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .yandex: return "Yandex Docs"
        case .volga: return "Volga"
        case .max: return "MAX"
        case .mailru: return "Mail.ru"
        case .boards: return "Boards"
        case .mts: return "MTS"
        case .telemost: return "Telemost"
        case .yandexMultistream: return "Yandex Multistream"
        case .cups: return "Cups Online"
        }
    }
}

public enum ProfileMode: String, Codable, CaseIterable, Sendable {
    case manual, key
}

public struct VPNProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var mode: ProfileMode
    public var transport: OpenFluxTransport
    public var documentURL: String
    public var documentURLs: [String]
    public var controlURL: String
    public var keyToken: String
    public var maxToken: String
    public var maxUID: Int64
    public var mtu: Int
    public var dnsUpstream: String
    public var forceBootstrapDNS: String
    public var autoReconnect: Bool
    public var e2eEncryption: Bool

    public init(
        id: UUID = UUID(), name: String = "Новый профиль",
        mode: ProfileMode = .manual, transport: OpenFluxTransport = .yandex,
        documentURL: String = "", documentURLs: [String] = [],
        controlURL: String = "", keyToken: String = "", maxToken: String = "",
        maxUID: Int64 = 0, mtu: Int = 1400, dnsUpstream: String = "77.88.8.8",
        forceBootstrapDNS: String = "", autoReconnect: Bool = true,
        e2eEncryption: Bool = false
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.transport = transport
        self.documentURL = documentURL
        self.documentURLs = documentURLs
        self.controlURL = controlURL
        self.keyToken = keyToken
        self.maxToken = maxToken
        self.maxUID = maxUID
        self.mtu = mtu
        self.dnsUpstream = dnsUpstream
        self.forceBootstrapDNS = forceBootstrapDNS
        self.autoReconnect = autoReconnect
        self.e2eEncryption = e2eEncryption
    }

    public func validate(requireConnection: Bool = false) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 120 else { throw ProfileError.invalidName }
        guard (1280...1500).contains(mtu) else { throw ProfileError.invalidMTU }
        guard Self.isIPv4(dnsUpstream),
              forceBootstrapDNS.isEmpty || Self.isIPv4(forceBootstrapDNS) else {
            throw ProfileError.invalidDNS
        }
        if mode == .key {
            let hasEmbeddedConnection: Bool
            switch transport {
            case .max: hasEmbeddedConnection = !maxToken.isEmpty && maxUID > 0
            case .yandexMultistream: hasEmbeddedConnection = documentURLs.count >= 2
            default: hasEmbeddedConnection = !documentURL.isEmpty
            }
            guard controlURL.isEmpty || Self.isHTTPS(controlURL),
                  hasEmbeddedConnection || (Self.isHTTPS(controlURL) && !keyToken.isEmpty) else {
                throw ProfileError.invalidKey
            }
        }
        if e2eEncryption {
            guard !keyToken.isEmpty else { throw ProfileError.missingEncryptionKey }
            guard ![.mailru, .boards, .telemost, .cups].contains(transport) else {
                throw ProfileError.unsupportedEncryption
            }
        }
        if !documentURL.isEmpty && !Self.isHTTPS(documentURL) {
            throw ProfileError.invalidDocumentURL
        }
        guard documentURLs.allSatisfy(Self.isHTTPS) else {
            throw ProfileError.invalidDocumentURL
        }
        if transport == .max {
            guard !maxToken.isEmpty, maxUID > 0 else { throw ProfileError.invalidMAX }
        } else if transport == .yandexMultistream {
            guard (2...8).contains(documentURLs.count),
                  Set(documentURLs).count == documentURLs.count else {
                throw ProfileError.invalidMultistream
            }
        } else if documentURL.isEmpty && (mode == .manual || requireConnection) {
            throw mode == .key ? ProfileError.unresolvedKey : ProfileError.invalidDocumentURL
        }
    }

    public func engineConfiguration() throws -> Data {
        try validate(requireConnection: true)
        var result: [String: Any] = [
            "mode": "manual", "transport": transport.rawValue,
            "doc_url": documentURL, "doc_urls": documentURLs,
            "max_token": maxToken, "max_uid": maxUID,
            "mtu": mtu, "dns_upstream": dnsUpstream,
            "key_token": keyToken, "e2e_encryption": e2eEncryption,
            "verbose_logging": false
        ]
        if !forceBootstrapDNS.isEmpty {
            result["force_bootstrap_dns"] = forceBootstrapDNS
        }
        return try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    }

    public static func isHTTPS(_ value: String) -> Bool {
        guard let url = URLComponents(string: value),
              url.scheme?.lowercased() == "https", let host = url.host,
              !host.isEmpty, url.user == nil, url.password == nil,
              url.fragment == nil else { return false }
        return true
    }

    private static func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy {
            !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber }
                && $0.count <= 3 && (Int($0).map { (0...255).contains($0) } ?? false)
        }
    }
}

public enum ProfileError: Error, LocalizedError, Equatable {
    case invalidName, invalidMTU, invalidDNS, invalidKey, invalidDocumentURL
    case invalidMAX, invalidMultistream, invalidImport, oversizedImport
    case unsupportedTransport, missingEncryptionKey, unsupportedEncryption, unresolvedKey

    public var errorDescription: String? {
        switch self {
        case .invalidName: return "Введите название профиля длиной до 120 символов."
        case .invalidMTU: return "MTU должен быть от 1280 до 1500."
        case .invalidDNS: return "Укажите IPv4-адрес DNS-сервера."
        case .invalidKey: return "Для ключа нужны HTTPS-адрес сервера и токен доступа."
        case .invalidDocumentURL: return "Укажите корректную HTTPS-ссылку транспорта."
        case .invalidMAX: return "Для MAX нужны токен и положительный ID пользователя."
        case .invalidMultistream: return "Добавьте от 2 до 8 разных HTTPS-ссылок документов."
        case .invalidImport: return "Не удалось прочитать ссылку OpenFlux."
        case .oversizedImport: return "Ссылка слишком большая. Максимальный размер — 64 КБ."
        case .unsupportedTransport: return "Этот транспорт пока не поддерживается HiDnet."
        case .missingEncryptionKey: return "Для сквозного шифрования нужен общий ключ."
        case .unsupportedEncryption: return "Этот режим шифрования не совместим с выбранным транспортом OpenFlux 0.0.8."
        case .unresolvedKey: return "Сначала проверьте ключ, чтобы получить ссылку подключения."
        }
    }
}
