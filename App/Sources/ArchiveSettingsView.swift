import SwiftUI
import TriamailKit

/// Settings > Archiving: local folders, then rules (the first matching rule wins).
struct ArchiveSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var addingFolder = false
    @State private var editedRule: ArchiveRule?
    @State private var sampleFileName = ""
    @State private var sampleSender = ""

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                ForEach($model.settings.archiveFolders) { $folder in
                    FolderRow(folder: $folder)
                }
                .onDelete { model.settings.archiveFolders.remove(atOffsets: $0) }
                Button("Ajouter un dossier…", systemImage: "plus") { addingFolder = true }
            } header: {
                Text("Dossiers")
            } footer: {
                Text("Des dossiers locaux : Google Drive pour ordinateur ou iCloud Drive se chargent de la synchronisation.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(model.settings.archiveRules) { rule in
                    RuleRow(rule: rule, folderName: folderName(rule.folderID))
                        .contentShape(.rect)
                        .onTapGesture(count: 2) { editedRule = rule }
                        .contextMenu {
                            Button("Modifier…") { editedRule = rule }
                            Button("Supprimer", role: .destructive) { model.settings.archiveRules.removeAll { $0.id == rule.id } }
                        }
                }
                .onMove { model.settings.archiveRules.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { model.settings.archiveRules.remove(atOffsets: $0) }
                Button("Ajouter une règle…", systemImage: "plus") {
                    if let folder = model.settings.archiveFolders.first {
                        editedRule = ArchiveRule(folderID: folder.id)
                    }
                }
                .disabled(model.settings.archiveFolders.isEmpty)
            } header: {
                Text("Règles")
            } footer: {
                Text("La première règle qui correspond l'emporte. Glisse pour réordonner, double-clic pour modifier.")
                    .foregroundStyle(.secondary)
            }

            Section("Essayer") {
                TextField("Nom de fichier", text: $sampleFileName, prompt: Text("Facture-2026-001.pdf"))
                TextField("Expéditeur", text: $sampleSender, prompt: Text("factures@exemple.com"))
                Text(samplePlanDescription)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $addingFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(url) = result {
                model.settings.archiveFolders.append(
                    ArchiveFolder(name: url.lastPathComponent, path: url.path.abbreviatingHomeDirectory)
                )
            }
        }
        .sheet(item: $editedRule) { rule in
            RuleEditor(rule: rule, folders: model.settings.archiveFolders) { saved in
                if let index = model.settings.archiveRules.firstIndex(where: { $0.id == saved.id }) {
                    model.settings.archiveRules[index] = saved
                } else {
                    model.settings.archiveRules.append(saved)
                }
            }
        }
        .onChange(of: model.settings) { model.save() }
    }

    private func folderName(_ id: ArchiveFolder.ID) -> String {
        model.settings.archiveFolders.first { $0.id == id }?.name ?? "Dossier supprimé"
    }

    private var samplePlanDescription: String {
        guard !sampleFileName.isEmpty else { return "Saisis un nom de fichier pour voir où il irait." }
        let planner = ArchivePlanner(folders: model.settings.archiveFolders, rules: model.settings.archiveRules)
        let document = Document(fileName: sampleFileName, sender: sampleSender.isEmpty ? nil : sampleSender, date: .now)
        guard let plan = planner.plan(for: document) else { return "Aucune règle ne correspond." }
        return "→ \(plan.destination.path.abbreviatingHomeDirectory)"
    }
}

private struct FolderRow: View {
    @Binding var folder: ArchiveFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Nom", text: $folder.name)
                    .labelsHidden()
                    .font(.headline)
                Spacer()
                Text(folder.path)
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
                    .lineLimit(1)
            }
            HStack {
                Toggle("Préfixe de date", isOn: $folder.datePrefix)
                Picker("Sous-dossier", selection: $folder.subfolder) {
                    Text("Aucun").tag(ArchiveFolder.Subfolder.none)
                    Text("Année").tag(ArchiveFolder.Subfolder.year)
                    Text("Année-mois").tag(ArchiveFolder.Subfolder.yearMonth)
                }
                .fixedSize()
            }
            .controlSize(.small)
        }
    }
}

private struct RuleRow: View {
    let rule: ArchiveRule
    let folderName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(rule.renameTo ?? "Nom d'origine")
                Text(conditions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if rule.sendToAccounting {
                Image(systemName: "paperplane")
                    .help("Envoyée à la comptabilité")
            }
            Text(folderName)
                .foregroundStyle(.secondary)
        }
    }

    private var conditions: String {
        var parts: [String] = []
        if let sender = rule.senderContains, !sender.isEmpty { parts.append("de \(sender)") }
        if let pattern = rule.fileNamePattern, !pattern.isEmpty { parts.append("fichier ~ \(pattern)") }
        if !rule.textContainsAll.isEmpty { parts.append("texte : \(rule.textContainsAll.joined(separator: " + "))") }
        return parts.isEmpty ? "Aucune condition : ne s'applique jamais" : parts.joined(separator: " · ")
    }
}

private struct RuleEditor: View {
    @State var rule: ArchiveRule
    let folders: [ArchiveFolder]
    let onSave: (ArchiveRule) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Si") {
                TextField("L'expéditeur contient", text: $rule.senderContains.orEmpty, prompt: Text("@exemple.com"))
                TextField("Le nom du fichier correspond à", text: $rule.fileNamePattern.orEmpty, prompt: Text("^Facture-\\d+"))
                TextField("Le texte contient (séparés par des virgules)", text: words, prompt: Text("Exemple SAS, Allemagne"))
            }
            Section("Alors") {
                Picker("Dossier", selection: $rule.folderID) {
                    ForEach(folders) { Text($0.name).tag($0.id) }
                }
                TextField("Nouveau nom", text: $rule.renameTo.orEmpty, prompt: Text("Facture Exemple (vide : garder le nom)"))
                Toggle("Envoyer à la comptabilité", isOn: $rule.sendToAccounting)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    onSave(rule)
                    dismiss()
                }
            }
        }
    }

    private var words: Binding<String> {
        Binding(
            get: { rule.textContainsAll.joined(separator: ", ") },
            set: { rule.textContainsAll = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }
}

extension Binding where Value == String? {
    /// Edits an optional string with a text field: an empty field means nil.
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
