import Foundation
import PDFKit

extension GmailAPI {
    /// The bytes of an attachment.
    public func attachment(messageID: String, attachmentID: String) async throws -> Data {
        struct Body: Decodable { var data: String }
        let body = try await get("messages/\(messageID)/attachments/\(attachmentID)", as: Body.self)
        guard let data = Data(base64URLEncoded: body.data) else { throw GmailFailure.unreadableAttachment }
        return data
    }

    /// Sends a raw RFC 2822 mail; returns the sent message's ID once Gmail confirms it.
    public func send(raw: Data) async throws -> String {
        struct Sent: Decodable { var id: String; var labelIds: [String]? }
        let sent = try await post("messages/send", json: ["raw": raw.base64URLEncoded], as: Sent.self)
        guard sent.labelIds?.contains("SENT") ?? true else { throw GmailFailure.sendNotConfirmed }
        return sent.id
    }

    /// Moves a message to Gmail's trash (recoverable for 30 days).
    public func trash(messageID: String) async throws {
        try await post("messages/\(messageID)/trash", json: [:])
    }
}

public enum PDFText {
    /// The text of a PDF, for rules that look at the content. Nil for a scan without text.
    public static func extract(from data: Data) -> String? {
        guard let text = PDFDocument(data: data)?.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}

public enum Archiver {
    /// Writes the file where the plan says, never overwriting: "name - 1.pdf" if the name is taken.
    @discardableResult
    public static func write(_ data: Data, plan: ArchivePlan, fileManager: FileManager = .default) throws -> URL {
        try fileManager.createDirectory(at: plan.directory, withIntermediateDirectories: true)
        let destination = plan.destination.uniqued(fileManager: fileManager)
        try data.write(to: destination, options: .withoutOverwriting)
        return destination
    }
}

/// A plain mail with one attachment, as Gmail's `messages.send` expects it.
public struct OutgoingMail: Sendable {
    public var to: String
    public var subject: String
    public var body: String
    public var attachmentName: String
    public var attachmentType: String
    public var attachment: Data

    public init(to: String, subject: String, body: String, attachmentName: String, attachmentType: String = "application/pdf", attachment: Data) {
        self.to = to
        self.subject = subject
        self.body = body
        self.attachmentName = attachmentName
        self.attachmentType = attachmentType
        self.attachment = attachment
    }

    public func rfc2822(boundary: String = "triamail-\(UUID().uuidString)") -> Data {
        let lines = [
            "To: \(to)",
            "Subject: \(Self.encodedWord(subject))",
            "MIME-Version: 1.0",
            "Content-Type: multipart/mixed; boundary=\"\(boundary)\"",
            "",
            "--\(boundary)",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Transfer-Encoding: 8bit",
            "",
            body,
            "",
            "--\(boundary)",
            "Content-Type: \(attachmentType); name=\"\(Self.encodedWord(attachmentName))\"",
            "Content-Disposition: attachment; filename*=UTF-8''\(Self.percentEncoded(attachmentName))",
            "Content-Transfer-Encoding: base64",
            "",
            attachment.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed]),
            "--\(boundary)--",
            "",
        ]
        return Data(lines.joined(separator: "\r\n").utf8)
    }

    /// RFC 2047 for non-ASCII headers.
    static func encodedWord(_ text: String) -> String {
        guard !text.allSatisfy(\.isASCII) else { return text }
        return "=?UTF-8?B?\(Data(text.utf8).base64EncodedString())?="
    }

    static func percentEncoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlUnreserved) ?? text
    }
}
