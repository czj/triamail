import AppKit
import SwiftUI
import TriamailKit

/// Settings > Modèles: the reply templates, like Raycast's AI Commands. One `.md` file per template.
struct TemplatesSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: ReplyTemplate.ID?
    /// The selected template being edited; written to its file with "Enregistrer".
    @State private var draft: ReplyTemplate?
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(model.templates, selection: $selection) { template in
                    Label(template.title, systemImage: template.icon ?? "text.bubble")
                        .badge(template.shortcut.map { Text($0.symbols) })
                }
                Divider()
                HStack(spacing: 2) {
                    Button("Nouveau modèle", systemImage: "plus") {
                        add(ReplyTemplate(id: "", title: "Nouveau modèle", prompt: "{selection}"))
                    }
                    Button("Supprimer", systemImage: "minus") { confirmingDelete = true }
                        .disabled(selected == nil)
                    Button("Dupliquer", systemImage: "plus.square.on.square") {
                        guard var copy = draft else { return }
                        copy.id = ""
                        copy.title += " (copie)"
                        copy.shortcut = nil
                        add(copy)
                    }
                    .disabled(draft == nil)
                    Spacer()
                    Button("Dossier", systemImage: "folder") { NSWorkspace.shared.open(model.store.templatesFolder) }
                        .help("Ouvrir le dossier des modèles dans le Finder")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 220)
            Divider()
            if let draft = Binding($draft) {
                TemplateEditor(template: draft, saved: selected, problem: shortcutProblem) {
                    save()
                }
            } else {
                ContentUnavailableView("Aucun modèle sélectionné", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: selection) { oldID, id in
            // Moving to another template keeps the edits of this one.
            if let draft, draft.id == oldID, draft != model.templates.first(where: { $0.id == oldID }),
               !draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
                model.saveTemplate(draft)
            }
            draft = model.templates.first { $0.id == id }
        }
        .task {
            model.reloadTemplates()
            selection = selection ?? model.templates.first?.id
        }
        .confirmationDialog("Supprimer « \(selected?.title ?? "") » ?", isPresented: $confirmingDelete) {
            Button("Supprimer le modèle", role: .destructive) {
                guard let selected else { return }
                draft = nil
                model.deleteTemplate(selected)
                selection = model.templates.first?.id
            }
        } message: {
            Text("Son fichier est supprimé du dossier des réglages, sur tous tes Mac.")
        }
    }

    private var selected: ReplyTemplate? { model.templates.first { $0.id == selection } }

    /// The draft's shortcut checked against the other templates as saved.
    private var shortcutProblem: String? {
        guard let draft else { return nil }
        let others = model.templates.filter { $0.id != draft.id }
        return ReplyTemplate.shortcutProblems(in: others + [draft])[draft.id]
    }

    private func add(_ template: ReplyTemplate) {
        if let saved = model.saveTemplate(template) { selection = saved.id }
    }

    private func save() {
        guard let draft, let saved = model.saveTemplate(draft) else { return }
        self.draft = saved
        selection = saved.id
    }
}

private struct TemplateEditor: View {
    @Binding var template: ReplyTemplate
    /// The template as on disk, to know whether there is something to save.
    let saved: ReplyTemplate?
    let problem: String?
    let save: () -> Void
    @State private var promptSelection: TextSelection?

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $template.title)
                TextField("Libellé du bouton", text: $template.buttonLabel, prompt: Text(template.title))
                LabeledContent("Raccourci") {
                    ShortcutRecorder(shortcut: $template.shortcut)
                }
                if let problem {
                    Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                LabeledContent("Icône") {
                    HStack {
                        Image(systemName: template.icon ?? "text.bubble")
                            .frame(width: 20)
                            .foregroundStyle(.tint)
                        TextField("Icône", text: Binding(get: { template.icon ?? "" }, set: { template.icon = $0.isEmpty ? nil : $0 }),
                                  prompt: Text("nom d'un SF Symbol, ex. arrowshape.turn.up.left"))
                            .labelsHidden()
                    }
                }
            }
            Section {
                TextEditor(text: $template.prompt, selection: $promptSelection)
                    .font(.body.monospaced())
                    .frame(minHeight: 180)
            } header: {
                HStack {
                    Text("Prompt")
                    Spacer()
                    Menu("Insérer une variable") {
                        Button("Le fil du mail  {selection}") { insert("{selection}") }
                        Button("Un champ à remplir  {argument name=\"…\"}") { insert("{argument name=\"Consigne\"}") }
                        Section("Profil") {
                            ForEach(Profile().variables.keys.sorted(), id: \.self) { key in
                                Button("{profil.\(key)}") { insert("{profil.\(key)}") }
                            }
                        }
                    }
                    .fixedSize()
                }
            } footer: {
                Text(template.arguments.isEmpty
                     ? "Aucun champ : la rédaction commence dès le clic."
                     : "Demandé avant la rédaction : \(template.arguments.joined(separator: ", ")).")
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Spacer()
                    Button("Annuler les modifications") { if let saved { template = saved } }
                        .disabled(template == saved)
                    Button("Enregistrer", action: save)
                        .keyboardShortcut("s")
                        .buttonStyle(.borderedProminent)
                        .disabled(template == saved || template.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// At the cursor (replacing the selected text), else at the end.
    private func insert(_ token: String) {
        var range = template.prompt.endIndex..<template.prompt.endIndex
        if case let .selection(selected)? = promptSelection?.indices, selected.upperBound <= template.prompt.endIndex {
            range = selected
        }
        template.prompt.replaceSubrange(range, with: token)
        let end = template.prompt.index(range.lowerBound, offsetBy: token.count)
        promptSelection = TextSelection(insertionPoint: end)
    }
}

/// Click, then press the keys: the shortcut is recorded. ⌫ clears it, Échap cancels.
private struct ShortcutRecorder: View {
    @Binding var shortcut: TemplateShortcut?
    @State private var recording = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(recording ? "Tape le raccourci…" : shortcut?.symbols ?? "Aucun")
                .monospaced()
                .foregroundStyle(recording ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(minWidth: 120)
                .background(.quaternary, in: .rect(cornerRadius: 5))
                .overlay { if recording { RoundedRectangle(cornerRadius: 5).stroke(.tint) } }
                .focusable()
                .focused($focused)
                .onTapGesture {
                    recording = true
                    focused = true
                }
                .onKeyPress(phases: .down) { press in
                    guard recording else { return .ignored }
                    switch press.key {
                    case .escape:
                        break
                    case .delete, .deleteForward:
                        shortcut = nil
                    default:
                        guard let key = press.characters.first, !key.isWhitespace else { return .handled }
                        var modifiers: Set<TemplateShortcut.Modifier> = []
                        if press.modifiers.contains(.command) { modifiers.insert(.cmd) }
                        if press.modifiers.contains(.shift) { modifiers.insert(.shift) }
                        if press.modifiers.contains(.option) { modifiers.insert(.option) }
                        if press.modifiers.contains(.control) { modifiers.insert(.control) }
                        shortcut = TemplateShortcut(modifiers: modifiers, key: key)
                    }
                    recording = false
                    return .handled
                }
                .onChange(of: focused) { _, isFocused in if !isFocused { recording = false } }
                .accessibilityLabel("Raccourci clavier")
                .accessibilityValue(shortcut?.symbols ?? "Aucun")
                .accessibilityAddTraits(.isButton)
            if shortcut != nil {
                Button("Effacer", systemImage: "xmark.circle.fill") { shortcut = nil }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
