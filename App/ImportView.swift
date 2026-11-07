import SwiftUI
import HiDnetCore

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?
    @State private var candidate: VPNProfile?
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("openflux://import?data=…", text: $text, axis: .vertical)
                        .lineLimit(4...8).keyboardType(.URL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .privacySensitive()
                    PasteButton(payloadType: String.self) { strings in
                        if let value = strings.first { text = value }
                    }
                    Button { showScanner = true } label: {
                        Label("Сканировать QR-код", systemImage: "qrcode.viewfinder")
                    }
                } header: { Text("Ссылка OpenFlux") } footer: {
                    Text("Поддерживается формат импорта клиента OpenFlux 0.0.8. После импорта вы сможете проверить и сохранить профиль.")
                }
                Section {
                    Button("Продолжить") {
                        do { candidate = try OpenFluxImport.parse(text) }
                        catch { self.error = error.localizedDescription }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Импорт профиля")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showScanner) {
                QRScannerView { value in
                    text = value
                    showScanner = false
                }
            }
            .sheet(item: $candidate) { ProfileEditor(profile: $0, isImported: true) }
            .alert("Не удалось импортировать", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) { Button("Понятно", role: .cancel) { error = nil } }
                message: { Text(error ?? "") }
        }
    }
}
