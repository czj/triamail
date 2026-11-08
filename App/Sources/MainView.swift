import SwiftUI
@preconcurrency import Translation
import TriamailKit

/// The three columns: mailboxes, mails to triage, and the action panel on the right.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var inbox = InboxModel()
    @State private var translations = TranslationModel()
    @State private var mailbox: Mailbox? = .toTriage
    @State private var selection: MailMessage.ID?

    var body: some View {
        NavigationSplitView {
            List(Mailbox.allCases, selection: $mailbox) { mailbox in
                Label(mailbox.title, systemImage: mailbox.symbol)
                    .badge(inbox.messages(in: mailbox).count)
                    .tag(mailbox)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } content: {
            messageList
                .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        } detail: {
            if let message = selectedMessage {
                MessageDetailView(message: message, translations: translations) {
                    Task { await inbox.markDone(message) }
                }
            } else {
                ContentUnavailableView("Aucun mail sélectionné", systemImage: "sidebar.right")
            }
        }
        .navigationTitle(mailbox?.title ?? "Triamail")
        .toolbar {
            ToolbarItem {
                Button("Actualiser", systemImage: "arrow.clockwise") {
                    Task { await inbox.refresh(accounts: model.accounts) }
                }
                .keyboardShortcut("r")
                .disabled(inbox.loading || model.accounts.isEmpty)
            }
        }
        .task(id: model.accounts) { await inbox.refresh(accounts: model.accounts) }
        .task(id: inbox.messages.map(\.id)) { await translations.process(inbox.messages) }
    }

    @ViewBuilder private var messageList: some View {
        if model.accounts.isEmpty {
            ContentUnavailableView {
                Label("Aucun compte connecté", systemImage: "envelope.badge.shield.half.filled")
            } description: {
                Text("Connecte un compte Gmail dans les réglages pour voir les mails à traiter.")
            } actions: {
                SettingsLink { Text("Ouvrir les réglages") }
            }
        } else {
            let messages = inbox.messages(in: mailbox ?? .toTriage)
            List(messages, selection: $selection) { message in
                MessageRow(message: message, language: translations.language(of: message))
            }
            .overlay {
                if inbox.loading && messages.isEmpty {
                    ProgressView()
                } else if messages.isEmpty {
                    ContentUnavailableView("Rien à traiter", systemImage: "checkmark.circle")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let error = inbox.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.bar)
                }
            }
        }
    }

    private var selectedMessage: MailMessage? {
        inbox.messages.first { $0.id == selection }
    }
}

private struct MessageRow: View {
    let message: MailMessage
    let language: Locale.Language?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(message.senderName)
                    .fontWeight(message.labelIDs.contains("UNREAD") ? .semibold : .regular)
                    .lineLimit(1)
                Spacer()
                if let language {
                    Text("\(language.shortCode) → FR")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 4)
                        .background(.tint.opacity(0.15), in: .capsule)
                        .help("Traduit automatiquement sur ce Mac")
                }
                Text(message.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(message.subject)
                .lineLimit(1)
            Text(message.snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let repository = message.gitHubRepository {
                Label(repository, systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !message.attachments.isEmpty {
                Label(message.attachments.map(\.fileName).joined(separator: ", "), systemImage: "paperclip")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MessageDetailView: View {
    enum Pane: Hashable { case mail, translation, page }

    let message: MailMessage
    let translations: TranslationModel
    let markDone: () -> Void
    @State private var pane: Pane = .page
    @State private var download: TranslationSession.Configuration?

    var body: some View {
        Group {
            switch visiblePane {
            case .page: if let link = message.primaryLink { WebPanel(url: link) }
            case .translation: translationBody
            case .mail: mailBody
            }
        }
        .id(message.id)
        .translationTask(download) { session in
            await translations.translate(message, with: session)
        }
        .toolbar {
            if panes.count > 1 {
                ToolbarItem {
                    Picker("Affichage", selection: $pane) {
                        ForEach(panes, id: \.self) { pane in
                            switch pane {
                            case .page: Text("Page").tag(pane)
                            case .translation: Text("Traduction").tag(pane)
                            case .mail: Text("Mail").tag(pane)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            if let link = message.primaryLink {
                ToolbarItem {
                    Link(destination: link) { Label("Ouvrir dans le navigateur", systemImage: "safari") }
                        .help(link.absoluteString)
                }
            }
            ToolbarItem {
                Button("Traité", systemImage: "checkmark") { markDone() }
                    .keyboardShortcut("e")
                    .help("Archive le mail dans Gmail : il sort de la liste")
            }
        }
    }

    private var panes: [Pane] {
        (message.primaryLink != nil ? [.page] : []) + (translations.language(of: message) != nil ? [.translation] : []) + [.mail]
    }

    /// The chosen pane if this mail has it, else the first one (page, then translation, then mail).
    private var visiblePane: Pane {
        panes.contains(pane) ? pane : panes[0]
    }

    @ViewBuilder private var translationBody: some View {
        switch translations.state(of: message) {
        case let .done(text):
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(message.subject).font(.title2.weight(.semibold))
                    Label("Traduit sur ce Mac, depuis \(Locale.current.localizedString(forLanguageCode: translations.language(of: message)?.languageCode?.identifier ?? "") ?? "une autre langue")", systemImage: "translate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        case .needsDownload:
            ContentUnavailableView {
                Label("Langue à télécharger", systemImage: "arrow.down.circle")
            } description: {
                Text("macOS doit télécharger cette langue une fois ; ensuite, la traduction se fait toute seule, hors ligne.")
            } actions: {
                Button("Télécharger et traduire") {
                    if let language = translations.language(of: message) {
                        download = .init(source: language, target: Locale.Language(identifier: "fr"))
                    }
                }
            }
        case let .failed(reason):
            ContentUnavailableView("Traduction impossible", systemImage: "exclamationmark.triangle", description: Text(reason))
        case .translating, nil:
            ProgressView("Traduction…")
        }
    }

    private var mailBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(message.subject)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)
                HStack {
                    Text(message.from)
                    Spacer()
                    Text(message.date, format: .dateTime.day().month().hour().minute())
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                Divider()
                Text(message.plainText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
}

extension Mailbox {
    var title: LocalizedStringKey {
        switch self {
        case .toTriage: "À traiter"
        case .github: "GitHub"
        case .invoices: "Factures et commandes"
        case .direct: "Pour moi"
        }
    }

    var symbol: String {
        switch self {
        case .toTriage: "tray"
        case .github: "chevron.left.forwardslash.chevron.right"
        case .invoices: "doc.text"
        case .direct: "person"
        }
    }
}
