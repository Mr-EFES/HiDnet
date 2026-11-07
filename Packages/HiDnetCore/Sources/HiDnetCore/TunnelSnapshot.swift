import Foundation

public struct TunnelSnapshot: Codable, Equatable, Sendable {
    public var state: String
    public var bytesSent: Int64
    public var bytesReceived: Int64
    public var issue: String

    public init(state: String = "stopped", bytesSent: Int64 = 0, bytesReceived: Int64 = 0, issue: String = "") {
        self.state = state
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.issue = issue
    }

    public var detail: String {
        switch state {
        case "connecting": return "Устанавливаем канал OpenFlux…"
        case "connected": return "Канал OpenFlux установлен"
        case "captcha": return "Транспорт требует CAPTCHA. Её прохождение пока не поддерживается."
        case "error": return "Не удалось подключиться. Проверьте профиль и доступность сервера."
        default: return "Канал OpenFlux не запущен"
        }
    }
}
