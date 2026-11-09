import SwiftUI
import TriamailKit

/// One button per reply template under the mail, with its icon, label and shortcut.
/// A template without `{argument …}` starts drafting on click; the others ask for their fields first.
struct TemplateBar: View {
    let message: MailMessage
    let replies: ReplyModel
    @Environment(AppModel.self) private var model
    @State private var asking: ReplyTemplate?
    /// A template clicked while a reply is already there: confirm before replacing it.
    @State private var replacing: ReplyTemplate?

    var body: some View {
        if !model.templates.isEmpty {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(model.templates) { template in
                        // A shortcut that clashes (Settings > Modèles shows why) is not bound.
                        let shortcut = model.shortcutProblems[template.id] == nil ? template.shortcut : nil
                        Button(template.label, systemImage: template.icon ?? "sparkles") { reply(with: template) }
                            .keyboardShortcut(shortcut?.keyboardShortcut)
                            .help([template.title, shortcut?.symbols].compactMap { $0 }.joined(separator: "  "))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.never)
            .background(.bar)
            .sheet(item: $asking) { ReplySheet(message: message, template: $0, replies: replies) }
            .confirmationDialog("Remplacer la réponse en cours ?", isPresented: Binding(get: { replacing != nil }, set: { if !$0 { replacing = nil } })) {
                Button("Rédiger « \(replacing?.label ?? "") »", role: .destructive) {
                    if let template = replacing { start(template) }
                }
            } message: {
                Text("La réponse proposée sous le mail, et tes modifications, seront perdues.")
            }
        }
    }

    private func reply(with template: ReplyTemplate) {
        switch replies.state(of: message) {
        case .writing, .ready: replacing = template
        case .failed, .saved, nil: start(template)
        }
    }

    private func start(_ template: ReplyTemplate) {
        if template.arguments.isEmpty {
            replies.write(message, template: template, arguments: [:], settings: model.settings)
        } else {
            asking = template
        }
    }
}

extension TemplateShortcut {
    var keyboardShortcut: KeyboardShortcut {
        var modifiers: EventModifiers = []
        if self.modifiers.contains(.cmd) { modifiers.insert(.command) }
        if self.modifiers.contains(.shift) { modifiers.insert(.shift) }
        if self.modifiers.contains(.option) { modifiers.insert(.option) }
        if self.modifiers.contains(.control) { modifiers.insert(.control) }
        return KeyboardShortcut(KeyEquivalent(key), modifiers: modifiers)
    }
}

/// The fields a template asks for (`{argument name="…"}`), then drafting starts.
struct ReplySheet: View {
    let message: MailMessage
    let template: ReplyTemplate
    let replies: ReplyModel
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var arguments: [String: String] = [:]

    var body: some View {
        Form {
            Section(template.title) {
                ForEach(template.arguments, id: \.self) { name in
                    TextField(name, text: Binding(get: { arguments[name, default: ""] }, set: { arguments[name] = $0 }), axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            Text(model.settings.aiProvider == .mistral ? "Rédigé par Mistral : le fil du mail part chez Mistral." : "Rédigé sur ce Mac : rien ne sort.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Rédiger") {
                    replies.write(message, template: template, arguments: arguments, settings: model.settings)
                    dismiss()
                }
            }
        }
    }
}

/// The reply under the mail: writing, then the text to review and send to Gmail's drafts.
struct ReplyBanner: View {
    let message: MailMessage
    let replies: ReplyModel

    var body: some View {
        if let state = replies.state(of: message) {
            VStack(alignment: .leading, spacing: 8) {
                switch state {
                case let .writing(template):
                    ProgressView("Rédaction « \(template) »… tu peux continuer à trier.")
                        .controlSize(.small)
                case let .ready(draft):
                    Text("Réponse proposée : relis-la, modifie-la").font(.headline)
                    // Bound to the model: the text belongs to this mail, never to the view.
                    TextEditor(text: Binding(get: { draft }, set: { replies.update(message, text: $0) }))
                        .font(.body)
                        .frame(minHeight: 160, maxHeight: 320)
                    HStack {
                        Button("Jeter", role: .destructive) { replies.discard(message) }
                        Spacer()
                        Button("Créer le brouillon dans Gmail") { Task { await replies.saveDraft(message) } }
                            .buttonStyle(.borderedProminent)
                    }
                case let .failed(reason):
                    Label(reason, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    Button("Fermer") { replies.discard(message) }
                case .saved:
                    Label("Brouillon créé dans Gmail : relis-le et envoie-le depuis ton client mail.", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
            .padding(12)
            .background(.bar)
        }
    }
}

/// The summary on top of the mail.
struct SummaryBanner: View {
    let message: MailMessage
    let summaries: SummaryModel

    var body: some View {
        if let state = summaries.state(of: message) {
            HStack(alignment: .top) {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .foregroundStyle(.tint)
                switch state {
                case .working:
                    ProgressView("Résumé en cours…").controlSize(.small)
                case let .done(text):
                    Text(text).textSelection(.enabled)
                case let .failed(reason):
                    Text(reason).foregroundStyle(.red)
                }
                Spacer()
                Button("Fermer", systemImage: "xmark") { summaries.dismiss(message) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
            .padding(12)
            .background(.tint.opacity(0.08))
        }
    }
}
