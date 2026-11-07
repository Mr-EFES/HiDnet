import Foundation
import HiDnetCore

enum KeyResolver {
    static func resolve(_ profile: VPNProfile) async throws -> VPNProfile {
        guard VPNProfile.isHTTPS(profile.controlURL), !profile.keyToken.isEmpty,
              let base = URL(string: profile.controlURL) else { throw ProfileError.invalidKey }
        var request = URLRequest(url: base.appendingPathComponent("v1/resolve"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(profile.keyToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              data.count < 65_536 else { throw ResolutionError.unavailable }
        let value = try JSONDecoder().decode(Response.self, from: data)
        guard value.status == "active" else { throw ResolutionError.inactive }
        guard let doc = value.docURL, VPNProfile.isHTTPS(doc),
              let transport = OpenFluxTransport(rawValue: value.transport ?? "yandex") else {
            throw ResolutionError.invalidResponse
        }
        var result = profile
        result.documentURL = doc
        result.transport = transport
        try result.validate(requireConnection: true)
        return result
    }

    private struct Response: Decodable {
        var status: String
        var docURL: String?
        var transport: String?

        enum CodingKeys: String, CodingKey {
            case status, transport
            case docURL = "doc_url"
        }
    }

    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession, task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }

    private enum ResolutionError: LocalizedError {
        case unavailable, inactive, invalidResponse

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Сервер проверки ключа недоступен или отклонил запрос."
            case .inactive: return "Ключ не найден, отключён или исчерпал лимит трафика."
            case .invalidResponse: return "Сервер не вернул поддерживаемую конфигурацию подключения."
            }
        }
    }
}
