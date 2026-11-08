import Sparkle
import SwiftUI

/// Sparkle 2: checks the appcast published with each GitHub release, signed with EdDSA.
/// Off when the build has no public key (local builds), so nothing unsigned is ever installed.
@MainActor
final class Updater {
    static let shared = Updater()

    private let controller: SPUStandardUpdaterController?

    private init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        controller = key.isEmpty || key.hasPrefix("$(")
            ? nil
            : SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var isEnabled: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

struct UpdateCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Rechercher les mises à jour…") { Updater.shared.checkForUpdates() }
                .disabled(!Updater.shared.isEnabled)
        }
    }
}
