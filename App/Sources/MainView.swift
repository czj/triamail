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
        @Bindable var model = model
        let selected = selectedMessage
        let sideContents = selected?.sideContents ?? []
        NavigationSplitView {
            messageList
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 480)
        } detail: {
            Group {
                if let message = selected {
                    MessageDetailView(message: message, translations: translations, replies: replies, summaries: summaries, settings: model.settings) {
                        markDone(message)
                    }
                } else {
                    ContentUnavailableView("Aucun mail sélectionné", systemImage: "envelope.open")
                }
            }
            .inspector(isPresented: Binding(get: { showsSidePane && !sideContents.isEmpty }, set: { showsSidePane = $0 })) {
                if let message = selected {
                    SidePane(message: message, contents: sideContents, settings: model.settings) { markDone(message) }
                        .inspectorColumnWidth(min: 320, ideal: 520, max: 1000)
                }
            }
        }
        .navigationTitle(mailbox.title)
        .searchable(text: $search, placement: .sidebar, prompt: "Rechercher")
        .sheet(isPresented: $tidying) { TidySheet(settings: model.settings) }
        .sheet(isPresented: $model.asksForOAuthClient) { OAuthClientSheet() }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Ranger", systemImage: "folder.badge.gearshape") { tidying = true }
                    .help("Ranger Téléchargements, Bureau et scans selon les règles d'archivage")
            }
            ToolbarItem(placement: .navigation) {
                AccountMenu()
            }
            ToolbarItem {
                Button("Actualiser", systemImage: "arrow.clockwise") {
                    Task { await inbox.refresh(accounts: model.accounts) }
                }
                .keyboardShortcut("r")
                .disabled(inbox.loading || !hasInbox)
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $showsSidePane) {
                    Label("Panneau latéral", systemImage: "sidebar.right")
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
                .help("Afficher la page ou la pièce jointe à droite (⌥⌘0)")
                .disabled(sideContents.isEmpty)
            }
        }
        .task(id: model.accounts) {
            await inbox.refresh(accounts: model.accounts)
            // `-demo -demoSelection demo-2`: open on a given mail, for screenshots.
            if InboxModel.demo, selection == nil { selection = UserDefaults.standard.string(forKey: "demoSelection") }
        }
        .task(id: inbox.messages.map(\.id)) { await translations.process(inbox.messages) }
    }

    @ViewBuilder private var messageList: some View {
        if !hasInbox {
            ContentUnavailableView {
                Label("Aucun compte connecté", systemImage: "envelope.badge.shield.half.filled")
            } description: {
                Text(model.signInMessage ?? "Connecte un compte Google pour voir les mails à traiter.")
            } actions: {
                Button(model.signingIn ? "Connexion dans le navigateur…" : "Ajouter un compte Google", systemImage: "plus") {
                    model.addGoogleAccount()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.signingIn)
            }
        } else {
            let messages = visibleMessages
            List(messages, selection: $selection) { message in
                MessageRow(message: message, language: translations.language(of: message))
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                MailboxFilter(selection: $mailbox, counts: inbox.counts)
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

    private var hasInbox: Bool { InboxModel.demo || !model.accounts.isEmpty }

    private var visibleMessages: [MailMessage] {
        inbox.messages(in: mailbox).filter { $0.matches(search) }
    }

    private var selectedMessage: MailMessage? {
        inbox.messages.first { $0.id == selection }
    }

    /// Archives the mail and moves to the next one, like Mimestream: triage never stops on an empty pane.
    /// If Gmail refuses, the mail stays selected with the error shown.
    private func markDone(_ message: MailMessage) {
        let visible = visibleMessages
        // Not in the list (filtered out by a search): the first visible mail.
        let next = visible.firstIndex { $0.id == message.id } == nil ? visible.first : visible.neighbor(afterRemoving: message.id)
        Task {
            if await inbox.markDone(message), selection == message.id {
                selection = next?.id
            }
        }
    }
}

/// The categories, as a compact filter on top of the list instead of a sidebar.
private struct MailboxFilter: View {
    @Binding var selection: Mailbox
    let counts: [Mailbox: Int]

    var body: some View {
        Picker("Filtre", selection: $selection) {
            ForEach(Mailbox.allCases) { mailbox in
                (Text(mailbox.shortTitle) + Text(verbatim: " \(counts[mailbox, default: 0])").foregroundStyle(.secondary))
                    .tag(mailbox)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(.tint)
                .frame(width: 7, height: 7)
                .opacity(message.isUnread ? 1 : 0)
                .accessibilityHidden(true)
            details
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(message.isUnread ? Text("Non lu") : Text(""))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(message.senderName)
                    .fontWeight(message.isUnread ? .semibold : .regular)
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
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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
        }
    }
}

struct MessageDetailView: View {
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
    /// For a translated mail: the original instead of the translation.
    @State private var showsOriginal = false
    @State private var download: TranslationSession.Configuration?

    var body: some View {
        Group {
            if isTranslated && !showsOriginal { translationBody } else { mailBody }
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
            if isTranslated {
                ToolbarItem {
                    Picker("Affichage", selection: $showsOriginal) {
                        Text("Traduction").tag(false)
                        Text("Original").tag(true)
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

    private var isTranslated: Bool { translations.language(of: message) != nil }

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
    /// `message.sideContents`, already computed by the caller: never empty when the pane shows.
    let contents: [SideContent]
    let settings: SharedSettings
    let markDone: () -> Void
    @State private var chosen: SideContent?

    var body: some View {
        let current = chosen ?? contents.first
        VStack(spacing: 0) {
            if contents.count > 1 {
                Picker("Affichage", selection: Binding(get: { current }, set: { chosen = $0 })) {
                    ForEach(contents, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(8)
                Divider()
            }
            switch current {
            case .invoice:
                InvoicePane(message: message, settings: settings, markDone: markDone)
            case let .page(link):
                HStack {
                    Image(systemName: "globe").foregroundStyle(.secondary)
                    Text(link.host() ?? "").font(.caption.weight(.medium))
                    Text(link.path(percentEncoded: false)).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                Divider()
                WebPanel(url: link)
            case nil:
                EmptyView()
            }
        }
        .id(message.id)
    }
}

extension SideContent {
    var title: LocalizedStringKey {
        switch self {
        case .invoice: "Facture"
        case .page: "Page"
        }
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
}
