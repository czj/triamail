import AppKit
import Combine
import SwiftUI
@preconcurrency import Translation
import TriamailKit

/// A native mail client's layout: mailboxes and accounts in the sidebar, the mails, the mail itself,
/// and on the right what the mail points to (the GitHub page, the invoice PDF).
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var translations = TranslationModel()
    @State private var mailbox: Mailbox = .toTriage
    @State private var selection: MailMessage.ID?
    @State private var search = ""
    @State private var tidying = false
    /// Feedback of the list's own actions (a reminder created from a row).
    @State private var listStatus: ListStatus?
    /// The day the list's dates are relative to.
    @State private var today = Date.now

    struct ListStatus: Equatable {
        let id = UUID()
        var text: String
        var failed = false
    }
    /// The user's choice; the pane only shows when the mail has something to show there.
    @AppStorage("showsSidePane") private var showsSidePane = true
    /// Whether the mail column can hold the mail and the side pane: a narrow one hides the pane rather than squeezing the mail.
    @State private var roomForSidePane = true

    var body: some View {
        let selected = selectedMessage
        let sideContents = selected?.sideContents ?? []
        NavigationSplitView {
            Sidebar(mailbox: $mailbox, counts: inbox.counts)
                .navigationSplitViewColumnWidth(min: MainWindowLayout.sidebarMin, ideal: MainWindowLayout.sidebarIdeal, max: MainWindowLayout.sidebarMax)
        } content: {
            messageList
                .navigationSplitViewColumnWidth(min: MainWindowLayout.listMin, ideal: MainWindowLayout.listIdeal, max: MainWindowLayout.listMax)
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
            // The mail stays readable next to the side pane: without it, the pane squeezed it to one letter per line.
            .frame(minWidth: MainWindowLayout.mailMin, maxWidth: .infinity)
            // Only the toolbar toggle changes the preference: the pane collapsing for lack of room does not.
            .inspector(isPresented: .constant(showsSidePane && roomForSidePane && !sideContents.isEmpty)) {
                if let message = selected {
                    SidePane(message: message, contents: sideContents, settings: model.settings) { markDone(message) }
                        .inspectorColumnWidth(min: MainWindowLayout.sidePaneMin, ideal: 440, max: 720)
                }
            }
            // Measured on the column itself (sidebar and list widths included), changing only when the threshold is crossed.
            .onGeometryChange(for: Bool.self) { $0.size.width > MainWindowLayout.mailMin + MainWindowLayout.sidePaneMin } action: {
                roomForSidePane = $0
            }
        }
        .navigationTitle(mailbox.title)
        .searchable(text: $search, placement: .toolbar, prompt: "Rechercher")
        // ⌘1…⌘4 in the "Boîte" menu (MailboxCommands) switch the mailbox of the window in front.
        .focusedSceneValue(\.mailbox, $mailbox)
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
                .disabled(inbox.loading || !hasInbox)
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $showsSidePane) {
                    Label("Panneau latéral", systemImage: "sidebar.right")
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
                .help(roomForSidePane ? "Afficher la page ou la pièce jointe à droite (⌥⌘0)" : "Agrandis la fenêtre pour afficher la page ou la pièce jointe")
                .disabled(sideContents.isEmpty || !roomForSidePane)
            }
        }
        .task(id: model.accounts) {
            await inbox.refresh(accounts: model.accounts)
            if selection == nil { selection = model.initialSelection }
        }
        .task(id: inbox.messages.map(\.id)) { await translations.process(inbox.messages) }
        // Templates edited by hand or synced from another Mac: their buttons follow when you come back.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.reloadTemplates()
        }
    }

    @ViewBuilder private var messageList: some View {
        if !hasInbox {
            ContentUnavailableView {
                Label("Aucun compte connecté", systemImage: "envelope.badge.shield.half.filled")
            } description: {
                Text(model.signInMessage ?? "Connecte un compte Google pour voir les mails à traiter.")
            } actions: {
                AddGoogleAccountButton()
                    .buttonStyle(.borderedProminent)
            }
        } else {
            let messages = visibleMessages
            List(messages, selection: $selection) { message in
                MessageRow(message: message, language: translations.language(of: message), today: today,
                           markDone: { markDone(message) }, remind: { remind(message, $0) })
            }
            // One event a day for the whole list: "09:05" becomes "lundi" after midnight.
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                today = .now
            }
            .overlay {
                if inbox.loading && messages.isEmpty {
                    ProgressView()
                } else if messages.isEmpty {
                    ContentUnavailableView("Rien à traiter", systemImage: "checkmark.circle")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if inbox.error != nil || listStatus != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if let error = inbox.error {
                            Text(error).foregroundStyle(.red)
                        }
                        if let listStatus {
                            Label(listStatus.text, systemImage: listStatus.failed ? "exclamationmark.triangle" : "bell")
                                .foregroundStyle(listStatus.failed ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                                // Keyed on the status itself: a second identical message restarts the timer.
                                .task(id: listStatus.id) {
                                    try? await Task.sleep(for: .seconds(listStatus.failed ? 8 : 4))
                                    if self.listStatus?.id == listStatus.id { self.listStatus = nil }
                                }
                        }
                    }
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
                }
            }
        }
    }

    /// A reminder from the list (hover or right-click), without opening the mail.
    private func remind(_ message: MailMessage, _ delay: ReminderDelay) {
        Task {
            let result = await RemindersService.shared.remind(message, delay, listName: model.settings.remindersListName)
            listStatus = ListStatus(text: result.text, failed: result.failed)
        }
    }

    private var hasInbox: Bool { !model.accounts.isEmpty }
    private var inbox: InboxModel { model.inbox }
    private var replies: ReplyModel { model.replies }
    private var summaries: SummaryModel { model.summaries }

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

/// Column widths of the main window.
enum MainWindowLayout {
    static let sidebarMin: CGFloat = 170
    static let sidebarIdeal: CGFloat = 190
    static let sidebarMax: CGFloat = 280
    static let listMin: CGFloat = 260
    /// The list opens at this width.
    static let listIdeal: CGFloat = 290
    static let listMax: CGFloat = 480
    static let mailMin: CGFloat = 360
    static let sidePaneMin: CGFloat = 300
    /// Sidebar, list and mail, without the side pane (which hides in a narrower window), and the dividers.
    static let windowMin = sidebarIdeal + listIdeal + mailMin + 2
}

/// The mailboxes with the mails left to triage, then the connected accounts.
private struct Sidebar: View {
    @Binding var mailbox: Mailbox
    let counts: [Mailbox: Int]
    @Environment(AppModel.self) private var model

    var body: some View {
        List(selection: Binding(get: { mailbox }, set: { if let new = $0 { mailbox = new } })) {
            Section("Boîtes") {
                ForEach(Mailbox.allCases) { box in
                    Label(box.title, systemImage: box.symbol)
                        // A zero badge is hidden.
                        .badge(counts[box, default: 0])
                        .tag(box)
                }
            }
            // Without an account, the mail list's empty state already offers the button.
            if !model.accounts.isEmpty {
                Section("Comptes") {
                    ForEach(model.accounts) { account in
                        Label(account.email, systemImage: "person.crop.circle")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(account.email)
                            .contextMenu {
                                SettingsLink { Text("Gérer les comptes…") }
                            }
                    }
                    AddGoogleAccountButton()
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

extension FocusedValues {
    /// The mailbox shown in the window in front, for the "Boîte" menu.
    @Entry var mailbox: Binding<Mailbox>?
}

/// The "Boîte" menu: ⌘1…⌘4 switch the mailbox of the window in front.
struct MailboxCommands: Commands {
    @FocusedBinding(\.mailbox) private var mailbox

    var body: some Commands {
        CommandMenu("Boîte") {
            ForEach(Array(Mailbox.allCases.enumerated()), id: \.element) { index, box in
                Button(box.title) { mailbox = box }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                    .disabled(mailbox == nil)
            }
        }
    }
}

/// The sender's initials on a colour of their own (the same address always gets the same colour).
struct SenderAvatar: View {
    let message: MailMessage
    var size: CGFloat = 32

    private static let palette: [Color] = [.blue, .purple, .pink, .red, .orange, .green, .teal, .indigo]

    var body: some View {
        Circle()
            .fill(Self.palette[message.avatarColorIndex(count: Self.palette.count)].gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(message.senderInitials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// A mail in the list: avatar, sender and date, subject, two lines of preview, discreet badges.
/// Hovering shows "Traité" and "Rappel"; swiping left archives.
private struct MessageRow: View {
    let message: MailMessage
    let language: Locale.Language?
    let today: Date
    let markDone: () -> Void
    let remind: (ReminderDelay) -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SenderAvatar(message: message)
                .overlay(alignment: .topLeading) {
                    if message.isUnread {
                        Circle()
                            .fill(.tint)
                            .stroke(.background, lineWidth: 2)
                            .frame(width: 10, height: 10)
                            .offset(x: -2, y: -2)
                            .accessibilityHidden(true)
                    }
                }
            details
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottomTrailing) {
            if hovering { hoverActions }
        }
        .onHover { hovering = $0 }
        // A row archived or scrolled away under the pointer gets no hover-exit.
        .onDisappear { hovering = false }
        .contextMenu {
            doneButton
            Menu("Rappel", systemImage: "bell") { ReminderPresetItems(action: remind) }
        }
        .swipeActions(edge: .trailing) {
            doneButton.tint(.green)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(message.isUnread ? Text("Non lu") : Text(""))
        .accessibilityAction(named: "Traité", markDone)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(message.senderName)
                    .fontWeight(message.isUnread ? .semibold : .medium)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(ListDate.text(for: message.date, now: today))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(message.isUnread ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            Text(message.subject)
                .font(.callout)
                .fontWeight(message.isUnread ? .medium : .regular)
                .lineLimit(1)
            Text(message.snippet)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            badges
        }
    }

    @ViewBuilder private var badges: some View {
        let repository = message.gitHubRepository
        if language != nil || repository != nil || !message.attachments.isEmpty {
            HStack(spacing: 8) {
                if let language {
                    Text("\(language.shortCode) → FR")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.tint.opacity(0.15), in: .capsule)
                        .help("Traduit automatiquement sur ce Mac")
                }
                if let repository {
                    Label(repository, systemImage: "chevron.left.forwardslash.chevron.right")
                        .lineLimit(1)
                } else if !message.attachments.isEmpty {
                    Label(message.attachments.map(\.fileName).joined(separator: ", "), systemImage: "paperclip")
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
    }

    private var hoverActions: some View {
        HStack(spacing: 2) {
            doneButton
                .help("Traité : archive le mail")
            Menu {
                ReminderPresetItems(action: remind)
            } label: {
                Label("Rappel", systemImage: "bell")
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Créer un rappel")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: .capsule)
        .accessibilityHidden(true)
    }

    private var doneButton: some View {
        Button("Traité", systemImage: "checkmark", action: markDone)
    }
}

/// "J+1", "J+3", "J+7": the reminder presets, in every reminder menu.
struct ReminderPresetItems: View {
    let action: (ReminderDelay) -> Void

    var body: some View {
        ForEach(ReminderDelay.presets, id: \.self) { delay in
            Button(delay.title) { action(delay) }
        }
    }
}

struct MessageDetailView: View {
    let message: MailMessage
    let translations: TranslationModel
    let replies: ReplyModel
    let summaries: SummaryModel
    let settings: SharedSettings
    let markDone: () -> Void
    @State private var status: String?
    @State private var choosingReminderDate = false
    @State private var reminderDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    /// For a translated mail: the original instead of the translation.
    @State private var showsOriginal = false
    /// The mail whose remote images the user chose to load (this view is reused from mail to mail).
    @State private var remoteContentAllowedFor: MailMessage.ID?
    /// Scanned once per mail (newsletters can be hundreds of KB), not on every render.
    @State private var hasRemoteContent = false
    @State private var download: TranslationSession.Configuration?

    var body: some View {
        Group {
            if isTranslated && !showsOriginal { translationBody } else { mailBody }
        }
        .id(message.id)
        .safeAreaInset(edge: .top) { SummaryBanner(message: message, summaries: summaries) }
        .safeAreaInset(edge: .bottom) { ReplyBanner(message: message, replies: replies) }
        .safeAreaInset(edge: .bottom, spacing: 0) { TemplateBar(message: message, replies: replies) }
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
        .task(id: message.id) { hasRemoteContent = message.html.map(MailHTML.hasRemoteContent) ?? false }
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
                Menu("Rappel", systemImage: "bell") {
                    ReminderPresetItems(action: addReminder)
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
        Task { status = await RemindersService.shared.remind(message, delay, listName: settings.remindersListName).text }
    }

    private var isTranslated: Bool { translations.language(of: message) != nil }

    @ViewBuilder private var translationBody: some View {
        switch translations.state(of: message) {
        case let .done(text):
            VStack(spacing: 0) {
                MailHeader(message: message)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Traduit sur ce Mac, depuis \(Locale.current.localizedString(forLanguageCode: translations.language(of: message)?.languageCode?.identifier ?? "") ?? "une autre langue")", systemImage: "translate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ReadableText(text: text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
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
        VStack(spacing: 0) {
            MailHeader(message: message)
            Divider()
            if let html = message.html, !html.isEmpty {
                let allowsRemote = remoteContentAllowedFor == message.id
                if !allowsRemote && hasRemoteContent {
                    HStack {
                        Label("Images et contenu distant bloqués", systemImage: "eye.slash")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Charger") { remoteContentAllowedFor = message.id }
                            .controlSize(.small)
                    }
                    .font(.callout)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(.bar)
                }
                HTMLMailBody(html: html, allowsRemoteContent: allowsRemote)
                    .id(message.id)
            } else {
                ScrollView {
                    ReadableText(text: message.plainText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
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
    var symbol: String {
        switch self {
        case .toTriage: "tray"
        case .github: "chevron.left.forwardslash.chevron.right"
        case .invoices: "doc.text"
        case .direct: "person"
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
