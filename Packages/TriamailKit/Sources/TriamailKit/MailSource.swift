import CoreGraphics
import CoreText
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
        (messages.filter { $0.threadID == message.threadID && $0.id != message.id } + [message]).sorted { $0.date < $1.date }
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

/// A one-page PDF with a few lines of text: the sample invoice.
enum SamplePDF {
    static func make(lines: [String]) -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        context.beginPDFPage(nil)
        for (index, line) in lines.enumerated() {
            let font = CTFontCreateWithName("Helvetica" as CFString, index == 0 ? 20 : 12, nil)
            let text = NSAttributedString(string: line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
            context.textPosition = CGPoint(x: 56, y: 780 - CGFloat(index) * 28)
            CTLineDraw(CTLineCreateWithAttributedString(text), context)
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
