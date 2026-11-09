import Foundation
import Observation
import TriamailKit

/// Mails of every connected account, merged and sorted.
@Observable
final class InboxModel {
    private(set) var messages: [MailMessage] = [] {
        didSet { counts = Dictionary(uniqueKeysWithValues: Mailbox.allCases.map { mailbox in (mailbox, messages.count(where: mailbox.contains)) }) }
    }
    /// Mails left to triage per mailbox (the sidebar's badges), computed once per change of the list rather than on every render.
    private(set) var counts: [Mailbox: Int] = [:]
    private(set) var loading = false
    var error: String?

    private let source: any MailSource

    init(source: any MailSource) {
        self.source = source
    }

    func refresh(accounts: [GmailAccount]) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        let source = source
        // Every account at once: the refresh lasts as long as the slowest one, not their sum.
        let results = await withTaskGroup(of: Result<[MailMessage], AccountError>.self) { group in
            for account in accounts {
                group.addTask {
                    do {
                        return .success(try await source.inbox(account: account))
                    } catch {
                        return .failure(AccountError(message: "\(account.email) : \(error.localizedDescription)"))
                    }
                }
            }
            var collected: [Result<[MailMessage], AccountError>] = []
            for await result in group { collected.append(result) }
            return collected
        }
        var all: [MailMessage] = []
        var failures: [String] = []
        for result in results {
            switch result {
            case let .success(messages): all += messages
            case let .failure(error): failures.append(error.message)
            }
        }
        messages = all.sorted { $0.date > $1.date }
        error = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    func messages(in mailbox: Mailbox) -> [MailMessage] {
        messages.filter(mailbox.contains)
    }

    /// The mail leaves the list (archived, never deleted). False when the mailbox refused.
    func markDone(_ message: MailMessage) async -> Bool {
        do {
            try await source.archive(message)
            messages.removeAll { $0.id == message.id }
            return true
        } catch {
            self.error = "Impossible d'archiver : \(error.localizedDescription)"
            return false
        }
    }
}

private struct AccountError: Error {
    var message: String
}
