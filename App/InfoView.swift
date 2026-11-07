import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("HiDnet", systemImage: "shield.lefthalf.filled")
                        .font(.title2.weight(.semibold))
                    Text("Нативный клиент OpenFlux для iPhone. Первая версия для разработки и проверки подключения.")
                    Text("Версия 0.1.0").foregroundStyle(.secondary)
                }
                Section("Совместимость") {
                    Text("Импорт ссылок клиента OpenFlux 0.0.8. Настройки транспорта и шифрования должны совпадать с вашим сервером.")
                    Text("IPv6 захватывается и отбрасывается. Работа UDP и QUIC зависит от транспорта и сервера.")
                    Text("Прохождение CAPTCHA, разделение приложений и балансировка профилей пока не поддерживаются.")
                }
                Section("Подключение") {
                    Text("Статус VPN показывает состояние системного подключения. Статус канала и счётчики отображают данные OpenFlux. Доступ в интернет проверяйте после подключения.")
                }
                Section {
                    Link("Исходный код HiDnet", destination: URL(string: "https://github.com/Mr-EFES/HiDnet")!)
                    Link("Проект OpenFlux", destination: URL(string: "https://github.com/wlruscfd/openflux-server")!)
                }
            }
            .navigationTitle("О приложении")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
    }
}
