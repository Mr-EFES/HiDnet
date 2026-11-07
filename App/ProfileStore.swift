import Foundation
import Combine
import HiDnetCore

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [VPNProfile] = []
    @Published var selectedID: UUID? {
        didSet { UserDefaults.standard.set(selectedID?.uuidString, forKey: "selectedProfileID") }
    }
    @Published var error: String?

    var selected: VPNProfile? { profiles.first { $0.id == selectedID } }

    init() {
        selectedID = UserDefaults.standard.string(forKey: "selectedProfileID").flatMap(UUID.init(uuidString:))
        reload()
    }

    func reload() {
        do {
            profiles = try ProfileKeychain.all()
            if !profiles.contains(where: { $0.id == selectedID }) {
                selectedID = profiles.first?.id
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save(_ profile: VPNProfile) throws {
        try ProfileKeychain.save(profile)
        selectedID = profile.id
        reload()
    }

    func remove(_ profile: VPNProfile) {
        do {
            try ProfileKeychain.delete(id: profile.id)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
