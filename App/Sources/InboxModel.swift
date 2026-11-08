import Foundation
import Observation
import TriamailKit

/// Mails of every connected account, merged and sorted.
@MainActor @Observable
final class InboxModel {
    private(set) var messages: [MailMessage] = []
    private(set) var loading = false
    var error: String?

    private let authenticator = GmailAuthenticator()

    func refresh(accounts: [GmailAccount]) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        var all: [MailMessage] = []
        var failures: [String] = []
        for account in accounts {
            do {
                all += try await authenticator.api(for: account).inbox(account: account.email)
            } catch {
                failures.append("\(account.email) : \(error.localizedDescription)")
            }
        }
        messages = all.sorted { $0.date > $1.date }
        error = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    func messages(in mailbox: Mailbox) -> [MailMessage] {
        messages.filter(mailbox.contains)
    }

    /// The mail leaves the list (archived in Gmail, never deleted).
    func markDone(_ message: MailMessage) async {
        do {
            try await authenticator.api(for: message.gmailAccount).archive(messageID: message.id)
            messages.removeAll { $0.id == message.id }
        } catch {
            self.error = "Impossible d'archiver : \(error.localizedDescription)"
        }
    }
}
