import SwiftUI
import TriamailKit

/// Choose a template, fill its fields, start writing.
struct ReplySheet: View {
    let message: MailMessage
    let replies: ReplyModel
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var templates: [ReplyTemplate] = []
    @State private var templateID: ReplyTemplate.ID?
    @State private var arguments: [String: String] = [:]

    var body: some View {
        Form {
            Picker("Modèle", selection: $templateID) {
                ForEach(templates) { Text($0.title).tag(Optional($0.id)) }
            }
            if let template {
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
                    if let template {
                        replies.write(message, template: template, arguments: arguments, settings: model.settings)
                    }
                    dismiss()
                }
                .disabled(template == nil)
            }
        }
        .task {
            templates = (try? model.store.templates()) ?? []
            templateID = templateID ?? templates.first?.id
        }
    }

    private var template: ReplyTemplate? { templates.first { $0.id == templateID } }
}

/// The reply under the mail: writing, then the text to review and send to Gmail's drafts.
struct ReplyBanner: View {
    let message: MailMessage
    let replies: ReplyModel
    @State private var text = ""

    var body: some View {
        if let state = replies.state(of: message) {
            VStack(alignment: .leading, spacing: 8) {
                switch state {
                case let .writing(template):
                    ProgressView("Rédaction « \(template) »… tu peux continuer à trier.")
                        .controlSize(.small)
                case let .ready(draft):
                    Text("Réponse proposée : relis-la, modifie-la").font(.headline)
                    TextEditor(text: $text)
                        .font(.body)
                        .frame(minHeight: 160, maxHeight: 320)
                        .onAppear { text = draft }
                        .onChange(of: text) { replies.update(message, text: text) }
                    HStack {
                        Button("Jeter", role: .destructive) { replies.discard(message) }
                        Spacer()
                        Button("Créer le brouillon dans Gmail") { Task { await replies.saveDraft(message, text: text) } }
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
