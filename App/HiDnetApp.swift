import SwiftUI
import HiDnetCore

@main
struct HiDnetApp: App {
    @StateObject private var profiles = ProfileStore()
    @StateObject private var vpn = VPNController()
    @State private var importedProfile: VPNProfile?
    @State private var importError: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profiles)
                .environmentObject(vpn)
                .tint(.cyan)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    do { importedProfile = try OpenFluxImport.parse(url.absoluteString) }
                    catch { importError = error.localizedDescription }
                }
                .sheet(item: $importedProfile) { profile in
                    ProfileEditor(profile: profile, isImported: true)
                        .environmentObject(profiles)
                }
                .alert("Не удалось импортировать", isPresented: Binding(
                    get: { importError != nil }, set: { if !$0 { importError = nil } }
                )) {
                    Button("Понятно", role: .cancel) { importError = nil }
                } message: { Text(importError ?? "") }
        }
    }
}
