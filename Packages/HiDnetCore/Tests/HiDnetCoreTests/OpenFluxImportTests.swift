import Foundation
import XCTest
@testable import HiDnetCore

final class OpenFluxImportTests: XCTestCase {
    func testImportsAndroidManualProfileWithDefaults() throws {
        let profile = try OpenFluxImport.parse(link([
            "name": "Дом", "mode": "manual", "doc_url": "https://docs.yandex.ru/example"
        ]))
        XCTAssertEqual(profile.name, "Дом")
        XCTAssertEqual(profile.transport, .yandex)
        XCTAssertEqual(profile.mtu, 1400)
        XCTAssertEqual(profile.dnsUpstream, "77.88.8.8")
        XCTAssertTrue(profile.autoReconnect)
        XCTAssertFalse(profile.e2eEncryption)
    }

    func testEveryImportCreatesANewProfileIdentity() throws {
        let value = try link([
            "id": UUID().uuidString, "mode": "manual", "doc_url": "https://docs.yandex.ru/example"
        ])
        XCTAssertNotEqual(try OpenFluxImport.parse(value).id, try OpenFluxImport.parse(value).id)
    }

    func testKeyProfileWithEmbeddedURLUsesManualEngineConfigWithoutResolving() throws {
        let profile = try OpenFluxImport.parse(link([
            "mode": "key", "control_url": "https://control.example.com",
            "key_token": "test-secret", "doc_url": "https://docs.yandex.ru/example",
            "e2e_encryption": true
        ]))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: profile.engineConfiguration()) as? [String: Any])
        XCTAssertEqual(config["mode"] as? String, "manual")
        XCTAssertEqual(config["key_token"] as? String, "test-secret")
        XCTAssertEqual(config["e2e_encryption"] as? Bool, true)
        XCTAssertNil(config["control_url"])
        XCTAssertEqual(config["verbose_logging"] as? Bool, false)
    }

    func testUnresolvedKeyCanBeReviewedButCannotConnect() throws {
        let profile = try OpenFluxImport.parse(link([
            "mode": "key", "control_url": "https://control.example.com", "key_token": "test-secret"
        ]))
        XCTAssertThrowsError(try profile.engineConfiguration()) { error in
            XCTAssertEqual(error as? ProfileError, .unresolvedKey)
        }
    }

    func testEmbeddedKeyProfileDoesNotRequireAnUnusedControlServer() throws {
        let profile = try OpenFluxImport.parse(link([
            "mode": "key", "doc_url": "https://docs.yandex.ru/example"
        ]))
        XCTAssertNoThrow(try profile.engineConfiguration())
    }

    func testRejectsUnknownTransportInsteadOfUsingYandex() throws {
        XCTAssertThrowsError(try OpenFluxImport.parse(link([
            "mode": "manual", "transport": "unknown", "doc_url": "https://docs.yandex.ru/example"
        ]))) { XCTAssertEqual($0 as? ProfileError, .unsupportedTransport) }
    }

    func testImportsAllSupportedTransportNames() throws {
        for transport in OpenFluxTransport.allCases {
            let profile = try OpenFluxImport.parse(link([
                "mode": "manual", "transport": transport.rawValue,
                "doc_url": "https://transport.example.com/room",
                "doc_urls": ["https://docs.yandex.ru/a", "https://docs.yandex.ru/b"],
                "max_token": "test-token", "max_uid": Int64(9_000_000_001)
            ]))
            XCTAssertEqual(profile.transport, transport)
            XCTAssertNoThrow(try profile.engineConfiguration())
        }
    }

    func testRejectsMalformedOrForeignLinks() throws {
        let valid = try link(["mode": "manual", "doc_url": "https://docs.yandex.ru/a"])
        let invalid = [
            "https://example.com", "openflux://import", "openflux://import?data=%",
            "openflux://import?data=e30&data=e30", "openflux://import?data=***",
            valid.replacingOccurrences(of: "://import", with: "://user@import"),
            valid.replacingOccurrences(of: "://import", with: "://import:8080"),
            valid + "#fragment", valid.replacingOccurrences(of: "//import?", with: "//import/other?")
        ]
        for value in invalid { XCTAssertThrowsError(try OpenFluxImport.parse(value), value) }
    }

    func testRejectsOversizedImportsBeforeDecoding() {
        XCTAssertThrowsError(try OpenFluxImport.parse("openflux://import?data=" + String(repeating: "A", count: 70_000))) {
            XCTAssertEqual($0 as? ProfileError, .oversizedImport)
        }
    }

    func testRejectsHTTPAndCredentialBearingTransportURLs() throws {
        for url in ["http://example.com", "https://user:password@example.com", "file:///tmp/profile", "https://example.com/#token"] {
            XCTAssertThrowsError(try OpenFluxImport.parse(link(["mode": "manual", "doc_url": url])))
        }
    }

    func testRejectsOutOfRangeMTUAndInvalidDNS() throws {
        for mtu in [0, 1279, 1501, 65_535] {
            XCTAssertThrowsError(try OpenFluxImport.parse(link([
                "mode": "manual", "doc_url": "https://docs.yandex.ru/a", "mtu": mtu
            ])))
        }
        for dns in ["256.1.1.1", "1.1.1", "1.1.1.1:53", "one.one.one.one", "1.1.1.1\n"] {
            XCTAssertThrowsError(try OpenFluxImport.parse(link([
                "mode": "manual", "doc_url": "https://docs.yandex.ru/a", "dns_upstream": dns
            ])))
        }
    }

    func testRejectsDuplicateMultistreamDocuments() throws {
        XCTAssertThrowsError(try OpenFluxImport.parse(link([
            "mode": "manual", "transport": "yandex_multistream",
            "doc_urls": ["https://docs.yandex.ru/a", "https://docs.yandex.ru/a"]
        ]))) { XCTAssertEqual($0 as? ProfileError, .invalidMultistream) }
    }

    func testEncryptionCannotSilentlyLoseItsKey() throws {
        XCTAssertThrowsError(try OpenFluxImport.parse(link([
            "mode": "manual", "doc_url": "https://docs.yandex.ru/a", "e2e_encryption": true
        ]))) { XCTAssertEqual($0 as? ProfileError, .missingEncryptionKey) }
    }

    func testWrongJSONFieldTypesAreRejected() throws {
        XCTAssertThrowsError(try OpenFluxImport.parse(link([
            "mode": "manual", "doc_url": "https://docs.yandex.ru/a", "e2e_encryption": "false"
        ]))) { XCTAssertEqual($0 as? ProfileError, .invalidImport) }
    }

    func testProfilePersistenceRoundTripPreservesSecretsAndIdentity() throws {
        let profile = VPNProfile(
            name: "Дом", documentURL: "https://docs.yandex.ru/a", keyToken: "test-key", e2eEncryption: true
        )
        XCTAssertEqual(try JSONDecoder().decode(VPNProfile.self, from: JSONEncoder().encode(profile)), profile)
    }

    private func link(_ payload: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let encoded = data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "openflux://import?data=\(encoded)"
    }
}
