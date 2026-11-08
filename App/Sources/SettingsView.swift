import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Général", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Comptes", systemImage: "person.crop.circle") {
                AccountsSettingsView()
            }
            Tab("Profil", systemImage: "person.text.rectangle") {
                ProfileSettingsView()
            }
            Tab("Archivage", systemImage: "folder") {
                ArchiveSettingsView()
            }
            Tab("IA", systemImage: "sparkles") {
                placeholder("Modèles d'IA", "Modèle local de macOS ou API Mistral.")
            }
        }
        .frame(width: 640, height: 520)
    }

    private func placeholder(_ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text(message))
    }
}

struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var choosingFolder = false
    @State private var reminderLists: [String] = []

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

            Section("Rappels") {
                @Bindable var model = model
                Picker("Liste", selection: $model.settings.remindersListName) {
                    Text("Liste par défaut").tag(String?.none)
                    ForEach(reminderLists, id: \.self) { Text($0).tag(Optional($0)) }
                }
                .onChange(of: model.settings.remindersListName) { model.save() }
            }

            if let error = model.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            if (try? await RemindersService.shared.requestAccess()) == true {
                reminderLists = RemindersService.shared.lists.map(\.title).sorted()
            }
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result {
                model.useSettingsFolder(folder)
            }
        }
    }
}
