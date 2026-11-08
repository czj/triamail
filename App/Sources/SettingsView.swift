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
                AISettingsView()
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
    @State private var choosingCodeRoot = false

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

            Section {
                @Bindable var model = model
                LabeledContent("Dossier des dépôts") {
                    HStack {
                        Text(model.settings.codeRoot ?? "Aucun").foregroundStyle(.secondary)
                        Button("Choisir…") { choosingCodeRoot = true }
                            .fileImporter(isPresented: $choosingCodeRoot, allowedContentTypes: [.folder]) { result in
                                if case let .success(url) = result {
                                    model.settings.codeRoot = url.path.abbreviatingHomeDirectory
                                    model.save()
                                }
                            }
                    }
                }
                Picker("Terminal", selection: $model.settings.terminalBundleID) {
                    ForEach(ClaudeCodeLauncher.terminals, id: \.bundleID) { Text($0.name).tag($0.bundleID) }
                }
                .onChange(of: model.settings.terminalBundleID) { model.save() }
            } header: {
                Text("Claude Code")
            } footer: {
                Text("Un dépôt « propriétaire/nom » est cherché dans ce dossier sous le nom « nom ». Claude Code est lancé en local, dans ce terminal.")
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
