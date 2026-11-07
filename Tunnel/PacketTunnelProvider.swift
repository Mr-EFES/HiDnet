import Foundation
import HiDnetCore
import HiDnetEngine
import Network
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let lifecycle = DispatchQueue(label: "HiDnet.TunnelLifecycle")
    private let outputQueue = DispatchQueue(label: "HiDnet.TunnelOutput", qos: .userInitiated)
    private let runningLock = NSLock()
    private var runningEpoch: Int?
    private var epoch = 0
    private var monitor: NWPathMonitor?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        lifecycle.async {
            self.epoch += 1
            let epoch = self.epoch
            do {
                guard let configuration = self.protocolConfiguration as? NETunnelProviderProtocol,
                      let id = configuration.providerConfiguration?["profileID"] as? String,
                      let profileID = UUID(uuidString: id) else { throw TunnelError.profile }
                let profile = try ProfileKeychain.load(id: profileID)
                let configurationData = try profile.engineConfiguration()
                guard let engineJSON = String(data: configurationData, encoding: .utf8) else {
                    throw TunnelError.profile
                }
                self.setTunnelNetworkSettings(self.networkSettings(mtu: profile.mtu)) { error in
                    self.lifecycle.async {
                        guard epoch == self.epoch else {
                            completionHandler(TunnelError.cancelled)
                            return
                        }
                        if let error { completionHandler(error); return }
                        let result = engineJSON.withCString { pointer in
                            HidnetStart(UnsafeMutablePointer(mutating: pointer))
                        }
                        guard result == 0 else {
                            HidnetStop()
                            completionHandler(TunnelError.engine(Int(result)))
                            return
                        }
                        self.runningLock.lock()
                        self.runningEpoch = epoch
                        self.runningLock.unlock()
                        self.readDevicePackets(epoch: epoch)
                        self.readEnginePackets(epoch: epoch)
                        if profile.autoReconnect { self.monitorNetwork(epoch: epoch) }
                        completionHandler(nil)
                    }
                }
            } catch { completionHandler(error) }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        lifecycle.async {
            self.epoch += 1
            self.runningLock.lock()
            self.runningEpoch = nil
            self.runningLock.unlock()
            self.monitor?.cancel()
            self.monitor = nil
            HidnetStop()
            self.outputQueue.sync {}
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard messageData == Data("status".utf8), let pointer = HidnetStatusJSON() else {
            completionHandler?(nil)
            return
        }
        defer { HidnetFree(pointer) }
        completionHandler?(Data(String(cString: pointer).utf8))
    }

    private func networkSettings(mtu: Int) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let ipv4 = NEIPv4Settings(addresses: ["10.10.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [.default()]
        settings.ipv4Settings = ipv4
        let ipv6 = NEIPv6Settings(addresses: ["fd71:d7e7::2"], networkPrefixLengths: [128])
        ipv6.includedRoutes = [.default()]
        settings.ipv6Settings = ipv6
        let dns = NEDNSSettings(servers: ["10.10.0.53"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns
        settings.mtu = NSNumber(value: mtu)
        return settings
    }

    private func isRunning(epoch: Int) -> Bool {
        runningLock.lock()
        defer { runningLock.unlock() }
        return runningEpoch == epoch
    }

    private func readDevicePackets(epoch: Int) {
        guard isRunning(epoch: epoch) else { return }
        packetFlow.readPackets { [weak self] packets, _ in
            guard let self, self.isRunning(epoch: epoch) else { return }
            for packet in packets {
                guard self.writeDevicePacket(packet, epoch: epoch) else { return }
            }
            self.readDevicePackets(epoch: epoch)
        }
    }

    private func writeDevicePacket(_ packet: Data, epoch: Int) -> Bool {
        runningLock.lock()
        defer { runningLock.unlock() }
        guard runningEpoch == epoch else { return false }
        packet.withUnsafeBytes { raw in
            if let base = raw.bindMemory(to: CChar.self).baseAddress {
                _ = HidnetWritePacket(UnsafeMutablePointer(mutating: base), Int32(packet.count))
            }
        }
        return true
    }

    private func readEnginePackets(epoch: Int) {
        outputQueue.async {
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 1500)
            defer { buffer.deallocate() }
            while self.isRunning(epoch: epoch) {
                let count = HidnetReadPacket(buffer, 1500)
                guard self.isRunning(epoch: epoch) else { break }
                if count < 0 {
                    self.cancelTunnelWithError(TunnelError.packetIO)
                    break
                }
                if count > 0 {
                    self.packetFlow.writePackets(
                        [Data(bytes: buffer, count: Int(count))],
                        withProtocols: [NSNumber(value: AF_INET)]
                    )
                }
            }
        }
    }

    private func monitorNetwork(epoch: Int) {
        let monitor = NWPathMonitor()
        var observedInitialPath = false
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self, self.isRunning(epoch: epoch) else { return }
            defer { observedInitialPath = true }
            if observedInitialPath && path.status == .satisfied { HidnetNetworkChanged() }
        }
        monitor.start(queue: lifecycle)
        self.monitor = monitor
    }
}

private enum TunnelError: LocalizedError {
    case profile, cancelled, packetIO
    case engine(Int)

    var errorDescription: String? {
        switch self {
        case .profile: return "Профиль подключения не найден. Откройте HiDnet и выберите профиль."
        case .cancelled: return "Подключение отменено."
        case .packetIO: return "Обмен пакетами остановлен. Подключитесь заново."
        case .engine(let code): return "Не удалось запустить OpenFlux (\(code)). Проверьте настройки профиля."
        }
    }
}
