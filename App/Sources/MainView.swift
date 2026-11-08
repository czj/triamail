import SwiftUI
@preconcurrency import Translation
import TriamailKit

/// Three panes, like Mimestream or Reeder: the mails in one long list, the mail itself,
/// and on the right what the mail points to (the GitHub page, the invoice PDF).
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var inbox = InboxModel()
    @State private var translations = TranslationModel()
    @State private var replies = ReplyModel()
    @State private var summaries = SummaryModel()
    @State private var mailbox: Mailbox = .toTriage
    @State private var selection: MailMessage.ID?
    @State private var search = ""
    @State private var tidying = false
    /// The user's choice; the pane only shows when the mail has something to show there.
    @AppStorage("showsSidePane") private var showsSidePane = true

    var body: some View {
        NavigationSplitView {
            messageList
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 480)
        } detail: {
            Group {
                if let message = selectedMessage {
                    MessageDetailView(message: message, translations: translations, replies: replies, summaries: summaries, settings: model.settings) {
                        markDone(message)
                    }
                } else {
                    ContentUnavailableView("Aucun mail sélectionné", systemImage: "envelope.open")
                }
            }
            .inspector(isPresented: sidePanePresented) {
                if let message = selectedMessage {
                    SidePane(message: message, settings: model.settings) { markDone(message) }
                        .inspectorColumnWidth(min: 320, ideal: 520, max: 1000)
                }
            }
        }
        .navigationTitle(mailbox.title)
        .searchable(text: $search, placement: .sidebar, prompt: "Rechercher")
        .sheet(isPresented: $tidying) { TidySheet(settings: model.settings) }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Ranger", systemImage: "folder.badge.gearshape") { tidying = true }
                    .help("Ranger Téléchargements, Bureau et scans selon les règles d'archivage")
            }
            ToolbarItem {
                Button("Actualiser", systemImage: "arrow.clockwise") {
                    Task { await inbox.refresh(accounts: model.accounts) }
                }
                .keyboardShortcut("r")
                .disabled(inbox.loading || (model.accounts.isEmpty && !InboxModel.demo))
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $showsSidePane) {
                    Label("Panneau latéral", systemImage: "sidebar.right")
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
                .help("Afficher la page ou la pièce jointe à droite (⌥⌘0)")
                .disabled(!(selectedMessage.map(SidePane.hasContent) ?? false))
            }
        }
        .task(id: model.accounts) {
            await inbox.refresh(accounts: model.accounts)
            // `-demo -demoSelection demo-2`: open on a given mail, for screenshots.
            if InboxModel.demo, selection == nil { selection = UserDefaults.standard.string(forKey: "demoSelection") }
        }
        .task(id: inbox.messages.map(\.id)) { await translations.process(inbox.messages) }
    }

    private var sidePanePresented: Binding<Bool> {
        Binding(
            get: { showsSidePane && (selectedMessage.map(SidePane.hasContent) ?? false) },
            set: { showsSidePane = $0 }
        )
    }

    @ViewBuilder private var messageList: some View {
        if model.accounts.isEmpty && !InboxModel.demo {
            ContentUnavailableView {
                Label("Aucun compte connecté", systemImage: "envelope.badge.shield.half.filled")
            } description: {
                Text("Connecte un compte Gmail dans les réglages pour voir les mails à traiter.")
            } actions: {
                SettingsLink { Text("Ouvrir les réglages") }
            }
        } else {
            let messages = visibleMessages
            List(messages, selection: $selection) { message in
                MessageRow(message: message, language: translations.language(of: message))
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                MailboxFilter(selection: $mailbox, count: { inbox.messages(in: $0).count })
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

    private var visibleMessages: [MailMessage] {
        let messages = inbox.messages(in: mailbox)
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return messages }
        return messages.filter { message in
            [message.from, message.subject, message.snippet].contains { $0.localizedStandardContains(query) }
        }
    }

    private var selectedMessage: MailMessage? {
        inbox.messages.first { $0.id == selection }
    }

    /// Archives the mail and moves to the next one, like Mimestream: triage never stops on an empty pane.
    private func markDone(_ message: MailMessage) {
        let list = visibleMessages
        if let index = list.firstIndex(where: { $0.id == message.id }) {
            let next = list.indices.contains(index + 1) ? list[index + 1] : (index > 0 ? list[index - 1] : nil)
            selection = next?.id
        }
        Task { await inbox.markDone(message) }
    }
}

/// The categories, as a compact filter on top of the list instead of a sidebar.
private struct MailboxFilter: View {
    @Binding var selection: Mailbox
    let count: (Mailbox) -> Int

    var body: some View {
        Picker("Filtre", selection: $selection) {
            ForEach(Mailbox.allCases) { mailbox in
                Label {
                    Text(mailbox.shortTitle) + Text(verbatim: " \(count(mailbox))").foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: mailbox.symbol)
                }
                .tag(mailbox)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .labelStyle(.titleOnly)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            // ⌘1…⌘4 switch the filter.
            ForEach(Array(Mailbox.allCases.enumerated()), id: \.offset) { index, mailbox in
                Button("") { selection = mailbox }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct MessageRow: View {
    let message: MailMessage
    let language: Locale.Language?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle()
                    .fill(.tint)
                    .frame(width: 7, height: 7)
                    .opacity(isUnread ? 1 : 0)
                    .accessibilityHidden(true)
                Text(message.senderName)
                    .fontWeight(isUnread ? .semibold : .regular)
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
            Group {
                Text(message.subject)
                    .lineLimit(1)
                Text(message.snippet)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.leading, 15)
            Group {
                if let repository = message.gitHubRepository {
                    Label(repository, systemImage: "chevron.left.forwardslash.chevron.right")
                } else if !message.attachments.isEmpty {
                    Label(message.attachments.map(\.fileName).joined(separator: ", "), systemImage: "paperclip")
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.leading, 15)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var isUnread: Bool { message.labelIDs.contains("UNREAD") }
}

struct MessageDetailView: View {
    enum Pane: Hashable {
        case translation, mail

        var title: LocalizedStringKey {
            switch self {
            case .translation: "Traduction"
            case .mail: "Original"
            }
        }
    }

    let message: MailMessage
    let translations: TranslationModel
    let replies: ReplyModel
    let summaries: SummaryModel
    let settings: SharedSettings
    @State private var replying = false
    let markDone: () -> Void
    @State private var status: String?
    @State private var choosingReminderDate = false
    @State private var reminderDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var pane: Pane = .translation
    @State private var download: TranslationSession.Configuration?

    var body: some View {
        Group {
            switch visiblePane {
            case .translation: translationBody
            case .mail: mailBody
            }
        }
        .id(message.id)
        .safeAreaInset(edge: .top) { SummaryBanner(message: message, summaries: summaries) }
        .safeAreaInset(edge: .bottom) { ReplyBanner(message: message, replies: replies) }
        .sheet(isPresented: $replying) { ReplySheet(message: message, replies: replies) }
        .safeAreaInset(edge: .bottom) {
            if let status {
                Label(status, systemImage: "info.circle")
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
                    .task(id: status) {
                        try? await Task.sleep(for: .seconds(4))
                        self.status = nil
                    }
            }
        }
        .translationTask(download) { session in
            await translations.translate(message, with: session)
        }
        .toolbar {
            if panes.count > 1 {
                ToolbarItem {
                    Picker("Affichage", selection: $pane) {
                        ForEach(panes, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            if let repository = message.gitHubRepository {
                ToolbarItem {
                    Button("Claude Code", systemImage: "terminal") {
                        Task {
                            do {
                                try await ClaudeCodeLauncher.launch(message, settings: settings)
                                status = "Claude Code lancé dans \(repository)"
                            } catch {
                                status = error.localizedDescription
                            }
                        }
                    }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                    .help("Ouvrir Claude Code sur le dépôt, avec la notification")
                }
            }
            ToolbarItem {
                Button("Résumer", systemImage: "text.line.first.and.arrowtriangle.forward") {
                    summaries.summarize(message, settings: settings)
                }
                .keyboardShortcut("y", modifiers: [.command, .shift])
                .help("Résumer le mail ou tout le fil")
            }
            ToolbarItem {
                Button("Répondre avec l'IA", systemImage: "sparkles") { replying = true }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            ToolbarItem {
                Menu("Rappel", systemImage: "bell") {
                    ForEach(ReminderDelay.presets, id: \.self) { delay in
                        Button(delay.title) { addReminder(delay) }
                    }
                    Divider()
                    Button("Choisir une date…") { choosingReminderDate = true }
                }
                .help("Créer un rappel dans Rappels")
                .popover(isPresented: $choosingReminderDate) {
                    VStack {
                        DatePicker("Rappel le", selection: $reminderDate, in: Date.now..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Button("Créer le rappel") {
                            choosingReminderDate = false
                            addReminder(.on(reminderDate))
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding()
                }
            }
            ToolbarItem {
                Button("Traité", systemImage: "checkmark") { markDone() }
                    .keyboardShortcut("e")
                    .help("Archive le mail dans Gmail : il sort de la liste")
            }
        }
    }

    private func addReminder(_ delay: ReminderDelay) {
        Task {
            do {
                let list = try await RemindersService.shared.add(ReminderDraft(message: message), due: delay.dueDate(from: .now), listName: settings.remindersListName)
                status = "Rappel \(delay.title) créé dans « \(list) »"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private var panes: [Pane] {
        (translations.language(of: message) != nil ? [.translation] : []) + [.mail]
    }

    /// The chosen pane if this mail has it, else the original.
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

/// The right-hand pane: the page a notification points to, or the invoice to archive.
struct SidePane: View {
    let message: MailMessage
    let settings: SharedSettings
    let markDone: () -> Void

    static func hasContent(_ message: MailMessage) -> Bool {
        Mailbox.invoices.contains(message) || message.primaryLink != nil
    }

    var body: some View {
        Group {
            if Mailbox.invoices.contains(message) {
                InvoicePane(message: message, settings: settings, markDone: markDone)
            } else if let link = message.primaryLink {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "globe").foregroundStyle(.secondary)
                        Text(link.host() ?? "").font(.caption.weight(.medium))
                        Text(link.path()).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Link(destination: link) { Image(systemName: "safari") }
                            .help("Ouvrir dans le navigateur")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    Divider()
                    WebPanel(url: link)
                }
            }
        }
        .id(message.id)
    }
}

extension Mailbox {
    var shortTitle: LocalizedStringKey {
        switch self {
        case .toTriage: "Tout"
        case .github: "GitHub"
        case .invoices: "Factures"
        case .direct: "Pour moi"
        }
    }

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
