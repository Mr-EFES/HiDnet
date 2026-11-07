import Foundation
import Combine
import HiDnetCore
import NetworkExtension

@MainActor
final class VPNController: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var snapshot = TunnelSnapshot()
    @Published private(set) var isWorking = false
    @Published private(set) var activeProfileID: UUID?
    @Published var error: String?

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?
    private var timer: Timer?

    var isActive: Bool { [.connected, .connecting, .reasserting, .disconnecting].contains(status) }

    var title: String {
        switch status {
        case .connected: return "VPN подключён"
        case .connecting, .reasserting: return "Подключение…"
        case .disconnecting: return "Отключение…"
        default: return "VPN отключён"
        }
    }

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        Task {
            do { try await load() }
            catch { self.error = "Не удалось загрузить настройки VPN: \(error.localizedDescription)" }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        timer?.invalidate()
    }

    func connect(_ profile: VPNProfile) async {
        guard !isWorking, !isActive else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try profile.engineConfiguration()
            if manager == nil { try await load() }
            guard let tunnelID = AppIdentity.tunnelIdentifier else { throw ControllerError.configuration }
            let selectedManager = manager ?? NETunnelProviderManager()
            let configuration = NETunnelProviderProtocol()
            configuration.providerBundleIdentifier = tunnelID
            configuration.serverAddress = "OpenFlux"
            configuration.providerConfiguration = ["profileID": profile.id.uuidString]
            configuration.disconnectOnSleep = false
            selectedManager.protocolConfiguration = configuration
            selectedManager.localizedDescription = "HiDnet"
            selectedManager.isEnabled = true
            try await selectedManager.saveToPreferences()
            try await selectedManager.loadFromPreferences()
            manager = selectedManager
            snapshot = TunnelSnapshot(state: "connecting")
            try selectedManager.connection.startVPNTunnel()
            refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        refresh()
    }

    private func load() async throws {
        let tunnelID = AppIdentity.tunnelIdentifier
        let managers: [NETunnelProviderManager] = try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { values, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: values ?? []) }
            }
        }
        manager = managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == tunnelID
        }
        refresh()
    }

    private func refresh() {
        status = manager?.connection.status ?? .invalid
        let configuration = manager?.protocolConfiguration as? NETunnelProviderProtocol
        activeProfileID = (configuration?.providerConfiguration?["profileID"] as? String)
            .flatMap(UUID.init(uuidString:))
        if !isActive { snapshot = TunnelSnapshot() }
        poll()
    }

    private func poll() {
        guard status == .connected, let session = manager?.connection as? NETunnelProviderSession else { return }
        try? session.sendProviderMessage(Data("status".utf8)) { [weak self] data in
            guard let data, let value = try? JSONDecoder().decode(TunnelSnapshot.self, from: data) else { return }
            Task { @MainActor in
                guard let self, self.status == .connected else { return }
                self.snapshot = value
            }
        }
    }

    private enum ControllerError: LocalizedError {
        case configuration
        var errorDescription: String? { "VPN-расширение не найдено. При установке сохраните расширение HiDnetTunnel." }
    }
}
