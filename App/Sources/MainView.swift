import SwiftUI
import TriamailKit

/// The three columns: mailboxes, mails to triage, and the action panel on the right.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var inbox = InboxModel()
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
                MessageDetailView(message: message) {
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
                MessageRow(message: message)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(message.senderName)
                    .fontWeight(message.labelIDs.contains("UNREAD") ? .semibold : .regular)
                    .lineLimit(1)
                Spacer()
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
    let message: MailMessage
    let markDone: () -> Void

    var body: some View {
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
        .toolbar {
            ToolbarItem {
                Button("Traité", systemImage: "checkmark") { markDone() }
                    .keyboardShortcut("e")
                    .help("Archive le mail dans Gmail : il sort de la liste")
            }
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
