import Foundation

/// Where the mails come from and where actions go: Gmail, or the in-memory sample of `-demo` and tests.
/// Chosen once when the app starts; no view needs to know which one it talks to.
public protocol MailSource: Sendable {
    /// Inbox messages of the account, newest first.
    func inbox(account: GmailAccount) async throws -> [MailMessage]
    /// "Done": the mail leaves the inbox, nothing is deleted.
    func archive(_ message: MailMessage) async throws
    /// Every message of the mail's thread, oldest first.
    func thread(of message: MailMessage) async throws -> [MailMessage]
    /// Saves a reply in the thread's drafts; returns the draft's ID.
    func createDraft(_ reply: ReplyDraft) async throws -> String
    func attachment(_ attachment: MailMessage.Attachment, of message: MailMessage) async throws -> Data
    /// Sends a raw RFC 2822 mail from the account; returns the sent message's ID once confirmed.
    func send(raw: Data, from account: GmailAccount) async throws -> String
    /// Moves a message to the trash (recoverable).
    func trash(messageID: String, account: GmailAccount) async throws
}

/// The real mailbox: each call signs in as the mail's account.
public struct GmailSource: MailSource {
    let authenticator: GmailAuthenticator

    public init(authenticator: GmailAuthenticator = GmailAuthenticator()) {
        self.authenticator = authenticator
    }

    public func inbox(account: GmailAccount) async throws -> [MailMessage] {
        try await authenticator.api(for: account).inbox(account: account.email)
    }

    public func archive(_ message: MailMessage) async throws {
        try await authenticator.api(for: message.gmailAccount).archive(messageID: message.id)
    }

    public func thread(of message: MailMessage) async throws -> [MailMessage] {
        try await authenticator.api(for: message.gmailAccount).thread(id: message.threadID, account: message.account)
    }

    public func createDraft(_ reply: ReplyDraft) async throws -> String {
        try await authenticator.api(for: reply.original.gmailAccount).createDraft(reply)
    }

    public func attachment(_ attachment: MailMessage.Attachment, of message: MailMessage) async throws -> Data {
        try await authenticator.api(for: message.gmailAccount).attachment(messageID: message.id, attachmentID: attachment.attachmentID)
    }

    public func send(raw: Data, from account: GmailAccount) async throws -> String {
        try await authenticator.api(for: account).send(raw: raw)
    }

    public func trash(messageID: String, account: GmailAccount) async throws {
        try await authenticator.api(for: account).trash(messageID: messageID)
    }
}

/// A fake mailbox in memory, built from `MailMessage.samples`: `-demo` (screenshots, trying the app
/// without a Google account) and tests. Every action works; nothing leaves the Mac.
public actor SampleMailSource: MailSource {
    /// The account the samples were sent to.
    public static let account = GmailAccount(email: "jeanne@exemple.com")

    public private(set) var messages: [MailMessage]
    public private(set) var drafts: [ReplyDraft] = []
    public private(set) var sent: [Data] = []
    public private(set) var trashed: [String] = []

    public init(messages: [MailMessage] = MailMessage.samples) {
        self.messages = messages
    }

    public func inbox(account: GmailAccount) -> [MailMessage] {
        messages.filter { $0.account == account.email }.sorted { $0.date > $1.date }
    }

    public func archive(_ message: MailMessage) {
        messages.removeAll { $0.id == message.id }
    }

    public func thread(of message: MailMessage) -> [MailMessage] {
        [message]
    }

    public func createDraft(_ reply: ReplyDraft) -> String {
        drafts.append(reply)
        return "draft-\(drafts.count)"
    }

    public func attachment(_ attachment: MailMessage.Attachment, of message: MailMessage) -> Data {
        SamplePDF.make(lines: [message.subject, message.senderName, attachment.fileName])
    }

    public func send(raw: Data, from account: GmailAccount) -> String {
        sent.append(raw)
        return "sent-\(sent.count)"
    }

    public func trash(messageID: String, account: GmailAccount) {
        trashed.append(messageID)
    }
}

/// A one-page PDF with a few lines of text, written by hand: the sample invoice.
enum SamplePDF {
    static func make(lines: [String]) -> Data {
        // Helvetica in PDF strings: ASCII only, with ( ) \ escaped.
        let text = lines.enumerated().map { index, line in
            let ascii = line.folding(options: .diacriticInsensitive, locale: nil).unicodeScalars
                .map { $0.isASCII ? String($0) : "?" }.joined()
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)")
            return "BT /F1 \(index == 0 ? 20 : 12) Tf 56 \(780 - index * 28) Td (\(ascii)) Tj ET"
        }.joined(separator: "\n")
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
            "<< /Length \(text.utf8.count) >>\nstream\n\(text)\nendstream",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        ]
        var pdf = "%PDF-1.4\n"
        var offsets: [Int] = []
        for (index, object) in objects.enumerated() {
            offsets.append(pdf.utf8.count)
            pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
        }
        let xref = pdf.utf8.count
        pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        pdf += offsets.map { String(format: "%010d 00000 n \n", $0) }.joined()
        pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        return Data(pdf.utf8)
    }
}
