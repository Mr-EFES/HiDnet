import Foundation
import HiDnetCore
import Security

enum ProfileKeychain {
    private static let service = "HiDnet.OpenFluxProfiles.v1"

    static func load(id: UUID) throws -> VPNProfile {
        var query = baseQuery()
        query[kSecAttrAccount] = id.uuidString
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.operation(status)
        }
        return try JSONDecoder().decode(VPNProfile.self, from: data)
    }

    static func all() throws -> [VPNProfile] {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let values = result as? [Data] else {
            throw KeychainError.operation(status)
        }
        return try values.map { try JSONDecoder().decode(VPNProfile.self, from: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func save(_ profile: VPNProfile) throws {
        try profile.validate()
        var query = baseQuery()
        query[kSecAttrAccount] = profile.id.uuidString
        let attributes: [CFString: Any] = [
            kSecValueData: try JSONEncoder().encode(profile),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            let result = SecItemAdd(query as CFDictionary, nil)
            guard result == errSecSuccess else { throw KeychainError.operation(result) }
        } else if status != errSecSuccess {
            throw KeychainError.operation(status)
        }
    }

    static func delete(id: UUID) throws {
        var query = baseQuery()
        query[kSecAttrAccount] = id.uuidString
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operation(status)
        }
    }

    private static func baseQuery() -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service]
    }
}

enum KeychainError: LocalizedError {
    case operation(OSStatus)

    var errorDescription: String? {
        switch self {
        case .operation(let status):
            return "Не удалось открыть защищённое хранилище (\(status)). Проверьте подпись приложения."
        }
    }
}
