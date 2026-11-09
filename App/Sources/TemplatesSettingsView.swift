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
                // Fresh editor state (cursor position) per template.
                .id(draft.wrappedValue.id)
            } else {
                ContentUnavailableView("Aucun modèle sélectionné", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: selection) { oldID, id in
            if draft?.id == oldID { keepEdits() }
            draft = model.templates.first { $0.id == id }
        }
        // Closing Settings or switching tab keeps the edits too.
        .onDisappear { keepEdits() }
        .task { selection = selection ?? model.templates.first?.id }
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

    /// Leaving a template saves its edits, as long as it still has a name.
    private func keepEdits() {
        guard let draft, let saved = model.templates.first(where: { $0.id == draft.id }), draft != saved,
              !draft.title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.saveTemplate(draft)
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
/// ⌘ or ⌃ is required, so typing in the mail window never triggers a template.
private struct ShortcutRecorder: View {
    @Binding var shortcut: TemplateShortcut?
    @State private var recording = false
    /// While recording, key presses go here first: ⌘S or ⌘W are recorded instead of saving or closing.
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button {
                recording.toggle()
            } label: {
                Text(recording ? "Tape le raccourci…" : shortcut?.symbols ?? "Aucun")
                    .monospaced()
                    .frame(minWidth: 110)
            }
            .tint(recording ? .accentColor : nil)
            .buttonStyle(.bordered)
            .accessibilityLabel("Raccourci clavier")
            .accessibilityValue(shortcut?.symbols ?? "Aucun")
            .accessibilityHint("Active, puis tape la combinaison de touches")
            .onChange(of: recording) { _, isRecording in
                if isRecording { startMonitor() } else { stopMonitor() }
            }
            .onDisappear { recording = false }
            if shortcut != nil {
                Button("Effacer", systemImage: "xmark.circle.fill") { shortcut = nil }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { record(event) }
            return nil
        }
    }

    private func stopMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func record(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 53: // Escape
            recording = false
        case 51, 117: // Delete, forward delete
            shortcut = nil
            recording = false
        default:
            // The key itself, not what Shift or Option make of it: ⇧⌘1 is "1", not "!".
            guard flags.contains(.command) || flags.contains(.control),
                  let key = event.characters(byApplyingModifiers: [])?.first, !key.isWhitespace else {
                NSSound.beep()
                return
            }
            shortcut = TemplateShortcut(modifiers: Set(TemplateShortcut.Modifier.allCases.filter { flags.contains($0.eventFlag) }), key: key)
            recording = false
        }
    }
}
