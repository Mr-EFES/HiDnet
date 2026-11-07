import SwiftUI
import HiDnetCore

struct ContentView: View {
    @EnvironmentObject private var profiles: ProfileStore
    @EnvironmentObject private var vpn: VPNController
    @State private var editor: VPNProfile?
    @State private var showImport = false
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    connectionCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 20, leading: 0, bottom: 24, trailing: 0))
                }
                Section {
                    if profiles.profiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Начните с профиля").font(.headline)
                            Text("Импортируйте ссылку или QR-код OpenFlux либо добавьте настройки вручную.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                    }
                    ForEach(profiles.profiles) { profile in
                        HStack(spacing: 12) {
                            Button {
                                profiles.selectedID = profile.id
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: profiles.selectedID == profile.id ? "checkmark.circle.fill" : "circle")
                                        .font(.title3).foregroundStyle(profiles.selectedID == profile.id ? .cyan : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(profile.name).foregroundStyle(.primary).lineLimit(1)
                                        Text(profile.transport.title).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(vpn.isActive)
                            Button { editor = profile } label: {
                                Image(systemName: "slider.horizontal.3").padding(8)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Изменить профиль \(profile.name)")
                        }
                        .padding(.vertical, 5)
                        .deleteDisabled(vpn.isActive && vpn.activeProfileID == profile.id)
                    }
                    .onDelete { indices in
                        let removed = indices.map { profiles.profiles[$0] }
                        for profile in removed where !(vpn.isActive && vpn.activeProfileID == profile.id) {
                            profiles.remove(profile)
                        }
                    }
                    Button { showImport = true } label: {
                        Label("Импортировать профиль", systemImage: "qrcode")
                    }
                    Button { editor = VPNProfile() } label: {
                        Label("Добавить вручную", systemImage: "plus")
                    }
                } header: {
                    Text("Профили")
                } footer: {
                    Text("Ключи и настройки хранятся в защищённом хранилище iPhone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.035, green: 0.055, blue: 0.09))
            .navigationTitle("HiDnet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showInfo = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("О приложении")
                }
            }
            .sheet(item: $editor) { ProfileEditor(profile: $0) }
            .sheet(isPresented: $showImport) { ImportView() }
            .sheet(isPresented: $showInfo) { InfoView() }
            .alert("HiDnet", isPresented: Binding(
                get: { vpn.error != nil || profiles.error != nil },
                set: { if !$0 { vpn.error = nil; profiles.error = nil } }
            )) {
                Button("Понятно", role: .cancel) { vpn.error = nil; profiles.error = nil }
            } message: { Text(vpn.error ?? profiles.error ?? "") }
        }
    }

    private var connectionCard: some View {
        VStack(spacing: 20) {
            Text("OPENFLUX · IPHONE").font(.caption.weight(.semibold))
                .tracking(3).foregroundStyle(.secondary)
            Button {
                if vpn.isActive { vpn.disconnect() }
                else if let profile = profiles.selected { Task { await vpn.connect(profile) } }
                else { showImport = true }
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(vpn.isActive ? Color.cyan : Color.white)
                    .frame(width: 140, height: 140)
                    .background(Color.cyan.opacity(vpn.isActive ? 0.13 : 0.04), in: Circle())
                    .overlay(Circle().stroke(Color.cyan.opacity(vpn.isActive ? 0.9 : 0.22), lineWidth: 2))
            }
            .buttonStyle(.plain)
            .disabled(vpn.isWorking || vpn.status == .disconnecting)
            .accessibilityLabel(vpn.isActive ? "Отключить VPN" : "Подключить VPN")
            VStack(spacing: 8) {
                Text(vpn.title).font(.title2.weight(.semibold))
                Text(vpn.isActive ? vpn.snapshot.detail : profiles.selected?.name ?? "Добавьте профиль для подключения")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if vpn.isActive {
                HStack(spacing: 36) {
                    traffic("Отправлено", value: vpn.snapshot.bytesSent, symbol: "arrow.up")
                    traffic("Получено", value: vpn.snapshot.bytesReceived, symbol: "arrow.down")
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func traffic(_ title: String, value: Int64, symbol: String) -> some View {
        VStack(spacing: 5) {
            Label(ByteCountFormatter.string(fromByteCount: value, countStyle: .binary), systemImage: symbol)
                .font(.subheadline.monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}
