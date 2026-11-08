import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Général", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Comptes", systemImage: "person.crop.circle") {
                placeholder("Comptes Gmail", "La connexion à Gmail arrive dans une prochaine version.")
            }
            Tab("Archivage", systemImage: "folder") {
                placeholder("Dossiers et règles", "Les dossiers locaux et les règles de rangement arrivent dans une prochaine version.")
            }
            Tab("IA", systemImage: "sparkles") {
                placeholder("Modèles d'IA", "Modèle local de macOS ou API Mistral.")
            }
        }
        .frame(width: 560, height: 340)
    }

    private func placeholder(_ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text(message))
    }
}

struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var choosingFolder = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Dossier") {
                    Text(model.settingsFolderPath)
                        .textSelection(.enabled)
                        .truncationMode(.middle)
                        .lineLimit(1)
                }
                HStack {
                    Button("Choisir…") { choosingFolder = true }
                    Button("Afficher dans le Finder") {
                        try? FileManager.default.createDirectory(at: model.store.folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.activateFileViewerSelecting([model.store.folder])
                    }
                }
            } header: {
                Text("Réglages et modèles de réponse")
            } footer: {
                Text("Un dossier dans iCloud Drive partage les réglages entre tes Mac. Les secrets restent dans le trousseau de chaque Mac.")
                    .foregroundStyle(.secondary)
            }

            if let error = model.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result {
                model.useSettingsFolder(folder)
            }
        }
    }
}
