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
    /// Sends a mail from the account (an invoice to accounting) and keeps no copy in Sent.
    func send(_ mail: OutgoingMail, from account: GmailAccount) async throws
}

/// The real mailbox: each call signs in as the mail's account.
public struct GmailSource: MailSource {
    let authenticator = GmailAuthenticator()

    public init() {}

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

    public func send(_ mail: OutgoingMail, from account: GmailAccount) async throws {
        let api = try await authenticator.api(for: account)
        let sentID = try await api.send(raw: mail.rfc2822())
        // Sent and confirmed: the copy has nothing to do in Sent mail.
        try await api.trash(messageID: sentID)
    }
}

/// A fake mailbox in memory, built from `MailMessage.samples`: `-demo` (screenshots, trying the app
/// without a Google account) and tests. Every action works; nothing leaves the Mac.
public actor SampleMailSource: MailSource {
    /// The account the samples were sent to.
    public static let account = GmailAccount(email: "jeanne@exemple.com")

    public private(set) var messages: [MailMessage]
    public private(set) var drafts: [ReplyDraft] = []
    public private(set) var sent: [OutgoingMail] = []

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

    public func send(_ mail: OutgoingMail, from account: GmailAccount) {
        sent.append(mail)
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
