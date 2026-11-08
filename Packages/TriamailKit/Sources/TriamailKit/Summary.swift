import Foundation

/// C7: a few lines on top of a long mail or thread.
public enum SummaryPrompt {
    /// `thread` oldest first; `account` is the reader's address, to find "since my last message".
    public static func make(thread: [MailMessage], account: String) -> String {
        let messages = thread.sorted { $0.date < $1.date }
        let lastMine = messages.lastIndex { $0.senderAddress.caseInsensitiveCompare(account) == .orderedSame }
        let text = messages.enumerated().map { index, message in
            let marker = index == lastMine ? " (mon dernier message)" : ""
            return "--- \(message.from), \(message.date.formatted(date: .abbreviated, time: .shortened))\(marker)\n\(String(message.plainText.prefix(6_000)))"
        }.joined(separator: "\n\n")

        var instructions = """
        Résume en français, en 3 à 6 lignes courtes, sans formule de politesse ni Markdown :
        - qui demande quoi ;
        - ce qu'on attend de moi, et pour quand ;
        - les dates, montants et références importants.
        """
        if messages.count > 1, let lastMine, lastMine < messages.count - 1 {
            instructions += "\nC'est un fil : commence par ce qui a changé depuis mon dernier message."
        } else if messages.count > 1 {
            instructions += "\nC'est un fil : résume-le en entier, en commençant par le plus récent."
        }
        return "\(instructions)\n\nMail(s) :\n\n\(text)"
    }
}

extension GmailAPI {
    /// Every message of a thread, oldest first.
    public func thread(id: String, account: String) async throws -> [MailMessage] {
        struct Thread: Decodable { var messages: [GmailMessageResource] }
        return try await get("threads/\(id)", query: [URLQueryItem(name: "format", value: "full")], as: Thread.self)
            .messages.map { $0.message(account: account) }
            .sorted { $0.date < $1.date }
    }
}
