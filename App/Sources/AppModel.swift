import Foundation
import Observation
import TriamailKit

/// App-wide state: where the settings live and what they say.
@MainActor @Observable
final class AppModel {
    private static let settingsFolderKey = "settingsFolderPath"

    private(set) var store: SettingsStore
    var settings = SharedSettings()
    var lastError: String?

    init() {
        let path = UserDefaults.standard.string(forKey: Self.settingsFolderKey)
        store = SettingsStore(folder: path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? SettingsStore.defaultFolder)
        reload()
    }

    var settingsFolderPath: String { store.folder.path.abbreviatingHomeDirectory }

    func reload() {
        do {
            settings = try store.load()
            if let bundled = Bundle.main.url(forResource: "modeles", withExtension: nil) {
                try store.installTemplates(from: bundled)
            }
            lastError = nil
        } catch {
            lastError = "Impossible de lire les réglages : \(error.localizedDescription)"
        }
    }

    func save() {
        do {
            try store.save(settings)
            lastError = nil
        } catch {
            lastError = "Impossible d'enregistrer les réglages : \(error.localizedDescription)"
        }
    }

    /// Points this Mac at another settings folder (this choice itself stays on this Mac).
    func useSettingsFolder(_ folder: URL) {
        UserDefaults.standard.set(folder.path, forKey: Self.settingsFolderKey)
        store = SettingsStore(folder: folder)
        reload()
    }
}
