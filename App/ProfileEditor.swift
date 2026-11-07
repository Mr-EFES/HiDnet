import SwiftUI
import HiDnetCore

struct ProfileEditor: View {
    @EnvironmentObject private var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State var profile: VPNProfile
    var isImported = false
    @State private var error: String?
    @State private var isResolving = false
    @State private var resolutionSucceeded = false

    var body: some View {
        NavigationStack {
            Form {
                if isImported {
                    Section {
                        Label("Проверьте настройки перед сохранением. Импорт не запускает VPN.", systemImage: "checkmark.shield")
                            .font(.subheadline)
                    }
                }
                Section("Профиль") {
                    TextField("Название", text: $profile.name)
                    Picker("Способ настройки", selection: $profile.mode) {
                        Text("Вручную").tag(ProfileMode.manual)
                        Text("Ключ доступа").tag(ProfileMode.key)
                    }
                    Picker("Транспорт", selection: $profile.transport) {
                        ForEach(OpenFluxTransport.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                }
                if profile.mode == .key {
                    Section {
                        urlField("Адрес сервера ключей", text: $profile.controlURL)
                        SecureField("Ключ доступа", text: $profile.keyToken)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button {
                            isResolving = true
                            resolutionSucceeded = false
                            Task {
                                do {
                                    profile = try await KeyResolver.resolve(profile)
                                    resolutionSucceeded = true
                                } catch { self.error = error.localizedDescription }
                                isResolving = false
                            }
                        } label: {
                            HStack {
                                Text(resolutionSucceeded ? "Ключ проверен" : "Проверить ключ")
                                Spacer()
                                if isResolving { ProgressView() }
                                else if resolutionSucceeded { Image(systemName: "checkmark.circle.fill") }
                            }
                        }
                        .disabled(isResolving || profile.controlURL.isEmpty || profile.keyToken.isEmpty)
                    } header: {
                        Text("Ключ доступа")
                    } footer: {
                        Text("Проверка отправляет ключ указанному серверу по HTTPS. Если ссылка подключения уже заполнена, проверка необязательна.")
                    }
                }
                Section("Подключение") {
                    if profile.transport == .max {
                        SecureField("Токен MAX", text: $profile.maxToken)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("ID пользователя", value: $profile.maxUID, format: .number.grouping(.never))
                            .keyboardType(.numberPad)
                    } else if profile.transport == .yandexMultistream {
                        ForEach(profile.documentURLs.indices, id: \.self) { index in
                            urlField("Документ \(index + 1)", text: $profile.documentURLs[index])
                        }
                        if profile.documentURLs.count < 8 {
                            Button("Добавить документ") { profile.documentURLs.append("") }
                        }
                        if !profile.documentURLs.isEmpty {
                            Button("Удалить последний документ", role: .destructive) {
                                profile.documentURLs.removeLast()
                            }
                        }
                    } else {
                        urlField("HTTPS-ссылка транспорта", text: $profile.documentURL)
                    }
                }
                Section {
                    Toggle("Сквозное шифрование", isOn: $profile.e2eEncryption)
                    if profile.mode != .key && profile.e2eEncryption {
                        SecureField("Общий ключ шифрования", text: $profile.keyToken)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                } header: { Text("Шифрование") } footer: {
                    Text("Режим и ключ должны совпадать с настройками сервера. Шифрование выключено по умолчанию для совместимости с OpenFlux 0.0.8.")
                }
                Section("Дополнительно") {
                    TextField("DNS", text: $profile.dnsUpstream).keyboardType(.decimalPad)
                    TextField("Начальный DNS, необязательно", text: $profile.forceBootstrapDNS)
                        .keyboardType(.decimalPad)
                    TextField("MTU", value: $profile.mtu, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    Toggle("Восстанавливать при смене сети", isOn: $profile.autoReconnect)
                }
            }
            .disabled(isResolving)
            .navigationTitle(isImported ? "Импорт профиля" : "Настройки профиля")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }.disabled(isResolving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        do {
                            profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            try store.save(profile)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }
                    .disabled(isResolving)
                }
            }
            .alert("Проверьте настройки", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) { Button("Понятно", role: .cancel) { error = nil } }
                message: { Text(error ?? "") }
        }
    }

    private func urlField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text, axis: .vertical)
            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            .privacySensitive()
    }
}
