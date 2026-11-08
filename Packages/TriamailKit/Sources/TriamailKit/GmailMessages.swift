import Foundation

/// A mail as Triamail shows it, decoded from Gmail's `format=full` message.
public struct MailMessage: Identifiable, Hashable, Sendable {
    public struct Attachment: Hashable, Sendable {
        public var fileName: String
        public var mimeType: String
        public var attachmentID: String
        public var size: Int
    }

    public var id: String
    public var threadID: String
    public var account: String
    public var from: String
    public var to: String
    public var cc: String
    public var subject: String
    public var date: Date
    public var snippet: String
    public var listID: String?
    public var labelIDs: [String]
    public var plainText: String
    public var html: String?
    public var attachments: [Attachment]
    /// RFC 822 headers, for replies in the same thread.
    public var rfcMessageID: String? = nil
    public var references: String? = nil
    public var replyTo: String? = nil

    /// "Prénom Nom <adresse@exemple.com>" → "Prénom Nom".
    public var senderName: String {
        let name = from.split(separator: "<").first.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) } ?? ""
        return name.isEmpty ? senderAddress : name
    }

    public var senderAddress: String {
        guard let start = from.firstIndex(of: "<"), let end = from.firstIndex(of: ">"), start < end else {
            return from.trimmingCharacters(in: .whitespaces)
        }
        return String(from[from.index(after: start)..<end])
    }

    /// "owner/repo" for a GitHub notification (List-ID: <repo.owner.github.com>).
    public var gitHubRepository: String? {
        guard let listID, let match = listID.firstMatch(of: /<?([A-Za-z0-9_.-]+)\.([A-Za-z0-9_-]+)\.github\.com>?/) else { return nil }
        return "\(match.2)/\(match.1)"
    }
}

/// The filters on top of the mail list.
public enum Mailbox: String, CaseIterable, Identifiable, Sendable {
    case toTriage, github, invoices, direct

    public var id: Self { self }

    public func contains(_ message: MailMessage) -> Bool {
        switch self {
        case .toTriage: Self.github.contains(message) || Self.invoices.contains(message) || Self.direct.contains(message)
        case .github: message.gitHubRepository != nil || message.senderAddress.hasSuffix("@github.com")
        case .invoices: Self.looksLikeInvoice(message)
        case .direct: Self.isAddressedDirectly(message)
        }
    }

    static let invoiceWords = ["facture", "invoice", "receipt", "reçu", "commande", "order", "rechnung", "fattura", "factura"]

    static func looksLikeInvoice(_ message: MailMessage) -> Bool {
        let subject = message.subject.lowercased()
        if invoiceWords.contains(where: subject.contains) { return true }
        return message.attachments.contains { attachment in
            let name = attachment.fileName.lowercased()
            return attachment.mimeType == "application/pdf" && invoiceWords.contains(where: name.contains)
        }
    }

    /// The account's address is in To (not only in Cc, not a mailing list).
    static func isAddressedDirectly(_ message: MailMessage) -> Bool {
        message.listID == nil && message.to.lowercased().contains(message.account.lowercased())
    }
}

// MARK: - Decoding Gmail's JSON

struct GmailMessageResource: Decodable {
    struct Part: Decodable {
        struct Header: Decodable {
            var name: String
            var value: String
        }

        struct Body: Decodable {
            var attachmentId: String?
            var size: Int?
            var data: String?
        }

        var mimeType: String?
        var filename: String?
        var headers: [Header]?
        var body: Body?
        var parts: [Part]?
    }

    var id: String
    var threadId: String
    var labelIds: [String]?
    var snippet: String?
    var internalDate: String?
    var payload: Part

    func message(account: String) -> MailMessage {
        func header(_ name: String) -> String? {
            payload.headers?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
        var plain: [String] = []
        var html: [String] = []
        var attachments: [MailMessage.Attachment] = []
        walk(payload, plain: &plain, html: &html, attachments: &attachments)

        let milliseconds = Double(internalDate ?? "") ?? 0
        let htmlText = html.first
        return MailMessage(
            id: id,
            threadID: threadId,
            account: account,
            from: header("From") ?? "",
            to: header("To") ?? "",
            cc: header("Cc") ?? "",
            subject: header("Subject") ?? "",
            date: Date(timeIntervalSince1970: milliseconds / 1000),
            snippet: (snippet ?? "").htmlEntitiesDecoded,
            listID: header("List-ID"),
            labelIDs: labelIds ?? [],
            plainText: plain.first ?? htmlText.map(\.strippingHTML) ?? "",
            html: htmlText,
            attachments: attachments,
            rfcMessageID: header("Message-ID"),
            references: header("References"),
            replyTo: header("Reply-To")
        )
    }

    private func walk(_ part: Part, plain: inout [String], html: inout [String], attachments: inout [MailMessage.Attachment]) {
        if let filename = part.filename, !filename.isEmpty, let attachmentID = part.body?.attachmentId {
            attachments.append(.init(fileName: filename, mimeType: part.mimeType ?? "", attachmentID: attachmentID, size: part.body?.size ?? 0))
        } else if let data = part.body?.data, let text = Data(base64URLEncoded: data).flatMap({ String(data: $0, encoding: .utf8) }) {
            switch part.mimeType {
            case "text/plain": plain.append(text)
            case "text/html": html.append(text)
            default: break
            }
        }
        for child in part.parts ?? [] {
            walk(child, plain: &plain, html: &html, attachments: &attachments)
        }
    }
}

extension GmailAPI {
    /// Messages in the inbox, newest first.
    public func inbox(account: String, limit: Int = 50) async throws -> [MailMessage] {
        struct List: Decodable {
            struct Ref: Decodable { var id: String }
            var messages: [Ref]?
        }
        let list = try await get("messages", query: [
            URLQueryItem(name: "labelIds", value: "INBOX"),
            URLQueryItem(name: "maxResults", value: String(limit)),
        ], as: List.self)
        let ids = (list.messages ?? []).map(\.id)
        return try await withThrowingTaskGroup(of: MailMessage.self) { group in
            // At most `parallelFetches` requests at once: Gmail answers 429 to bursts.
            var pending = ids.makeIterator()
            for _ in 0..<Self.parallelFetches {
                guard let id = pending.next() else { break }
                group.addTask { try await message(id: id, account: account) }
            }
            var messages: [MailMessage] = []
            for try await fetched in group {
                messages.append(fetched)
                if let id = pending.next() {
                    group.addTask { try await self.message(id: id, account: account) }
                }
            }
            return messages.sorted { $0.date > $1.date }
        }
    }

    static let parallelFetches = 8

    public func message(id: String, account: String) async throws -> MailMessage {
        try await get("messages/\(id)", query: [URLQueryItem(name: "format", value: "full")], as: GmailMessageResource.self)
            .message(account: account)
    }

    /// "Done": the mail leaves the inbox (Gmail's archive), nothing is deleted.
    public func archive(messageID: String) async throws {
        try await post("messages/\(messageID)/modify", json: ["removeLabelIds": ["INBOX"]])
    }
}

extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}

extension String {
    var htmlEntitiesDecoded: String {
        [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")]
            .reduce(self) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }

    /// A rough plain-text version of an HTML body, for mails without a text part.
    var strippingHTML: String {
        replacing(/<(style|script)[^>]*>[\s\S]*?<\/\1>/.ignoresCase(), with: "")
            .replacing(/<br\s*\/?>|<\/p>|<\/div>|<\/tr>/.ignoresCase(), with: "\n")
            .replacing(/<[^>]+>/, with: "")
            .htmlEntitiesDecoded
            .replacing(/\n{3,}/, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
