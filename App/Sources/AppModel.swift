import AppKit
import Foundation
import Observation
import TriamailKit

/// App-wide state: where the settings live and what they say.
@MainActor @Observable
final class AppModel {
    private static let settingsFolderKey = "settingsFolderPath"
    private static let accountsKey = "gmailAccounts"

    private(set) var store: SettingsStore
    /// Every change is saved by the model itself, half a second after the last edit:
    /// no view has to remember to save, and typing does not rewrite the iCloud file per keystroke.
    var settings = SharedSettings() {
        didSet { if settings != oldValue { scheduleSave() } }
    }
    private var saveTask: Task<Void, Never>?
    /// While loading from disk, the change is not an edit to save back.
    private var loading = false
    var lastError: String?
    /// True when reglages.json exists but could not be read: saving would overwrite it with defaults.
    private var loadFailed = false
    /// Connected Gmail accounts on this Mac (their tokens are in this Mac's keychain).
    private(set) var accounts: [GmailAccount] = []

    /// `-demo` launch argument: a fake `exemple.com` account whose mails live in memory, and settings in a
    /// temporary folder. Every action works (archive, invoice, summary, reply) and nothing real is read or
    /// changed: not the Gmail accounts, the keychain, the shared settings nor the archive folders.
    static let isDemo = ProcessInfo.processInfo.arguments.contains("-demo")
    /// `-demo -demoSelection demo-2`: the mail selected at launch, for screenshots.
    let initialSelection = AppModel.isDemo ? UserDefaults.standard.string(forKey: "demoSelection") : nil
    /// Gmail, or the in-memory sample in demo mode: the only place that knows which.
    let mailSource: any MailSource
    /// Shared by every window: the inbox, and replies and summaries in progress per mail.
    let inbox: InboxModel
    let replies: ReplyModel
    let summaries: SummaryModel

    init() {
        let source: any MailSource = Self.isDemo ? SampleMailSource() : GmailSource()
        mailSource = source
        inbox = InboxModel(source: source)
        replies = ReplyModel(source: source)
        summaries = SummaryModel(source: source)
        if Self.isDemo {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Triamail-demo", isDirectory: true)
            store = SettingsStore(folder: folder)
            try? store.save(.demo(in: folder))
        } else {
            let path = UserDefaults.standard.string(forKey: Self.settingsFolderKey)
            store = SettingsStore(folder: path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? SettingsStore.defaultFolder)
        }
        reload()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
        if Self.isDemo {
            accounts = [SampleMailSource.account]
        } else if let data = UserDefaults.standard.data(forKey: Self.accountsKey) {
            accounts = (try? JSONDecoder().decode([GmailAccount].self, from: data)) ?? []
        }
    }

    /// Where the last "Ajouter un compte Google" stands: in the browser, connected, or the error.
    private(set) var signInMessage: String?
    private var signInTask: Task<Void, Never>?

    /// "Ajouter un compte Google": Google's sign-in in the browser, the account is added once Google answers.
    /// False when no OAuth client is saved yet: the caller asks for it, then calls again.
    /// Clicking again while the browser is open starts over (closed tab, wrong account…).
    func addGoogleAccount() -> Bool {
        guard !Self.isDemo else {
            signInMessage = "Mode démo : relance Triamail sans -demo pour connecter un vrai compte."
            return true
        }
        let authenticator = GmailAuthenticator()
        guard authenticator.client != nil else { return false }
        signInTask?.cancel()
        signInMessage = "Termine la connexion dans le navigateur…"
        signInTask = Task {
            do {
                let account = try await authenticator.signIn { url in
                    await MainActor.run { _ = NSWorkspace.shared.open(url) }
                }
                if !accounts.contains(account) { accounts.append(account) }
                saveAccounts()
                signInMessage = "\(account.email) est connecté."
            } catch {
                // A newer attempt replaced this one: its message wins.
                if !Task.isCancelled { signInMessage = error.localizedDescription }
            }
        }
        return true
    }

    func removeAccount(_ account: GmailAccount) {
        // The demo account has no token; a real one with the same address keeps its own.
        if !Self.isDemo {
            Task { try? await GmailAuthenticator().signOut(account) }
        }
        accounts.removeAll { $0 == account }
        saveAccounts()
        signInMessage = nil
    }

    private func saveAccounts() {
        // The demo's fake account never replaces the real list.
        guard !Self.isDemo else { return }
        UserDefaults.standard.set(try? JSONEncoder().encode(accounts), forKey: Self.accountsKey)
    }

    var settingsFolderPath: String { store.folder.path.abbreviatingHomeDirectory }

    func reload() {
        loading = true
        defer { loading = false }
        saveTask?.cancel()
        do {
            settings = try store.load()
            loadFailed = false
            if let bundled = Bundle.main.url(forResource: "modeles", withExtension: nil) {
                try store.installTemplates(from: bundled)
            }
            lastError = nil
        } catch {
            loadFailed = true
            lastError = "Impossible de lire les réglages : \(error.localizedDescription). Rien ne sera enregistré tant que le fichier n'est pas corrigé."
        }
    }

    private func scheduleSave() {
        guard !loading else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    /// Writes now: pending edits are not lost when the app quits.
    func flush() {
        guard saveTask != nil else { return }
        saveTask?.cancel()
        saveTask = nil
        save()
    }

    func save() {
        guard !loadFailed else { return }
        do {
            try store.save(settings)
            lastError = nil
        } catch {
            lastError = "Impossible d'enregistrer les réglages : \(error.localizedDescription)"
        }
    }

    /// Points this Mac at another settings folder (this choice itself stays on this Mac).
    func useSettingsFolder(_ folder: URL) {
        if !Self.isDemo { UserDefaults.standard.set(folder.path, forKey: Self.settingsFolderKey) }
        store = SettingsStore(folder: folder)
        reload()
    }
}
