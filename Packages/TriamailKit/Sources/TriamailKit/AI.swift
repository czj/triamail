import Foundation

/// Which model writes: the Mac's own (Apple Intelligence) or Mistral's API.
public enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleLocal
    case mistral

    public var id: Self { self }
}

/// Mistral's chat completions API. The key lives in the keychain.
public struct MistralClient: Sendable {
    public static let keychainAccount = "mistral.api-key"
    public static let defaultModel = "mistral-large-latest"
    static let endpoint = URL(string: "https://api.mistral.ai/v1/chat/completions")!

    public var apiKey: String
    public var model: String
    public var session: URLSession

    public init(apiKey: String, model: String = defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model.isEmpty ? Self.defaultModel : model
        self.session = session
    }

    public static func storedKey() -> String? { try? Keychain.get(keychainAccount) }

    public func request(prompt: String) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(model: model, messages: [.init(role: "user", content: prompt)]))
        return request
    }

    public func complete(prompt: String) async throws -> String {
        let (data, response) = try await session.data(for: request(prompt: prompt))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIFailure.server("Mistral HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) : \(String(decoding: data.prefix(300), as: UTF8.self))")
        }
        return try Self.content(of: data)
    }

    static func content(of data: Data) throws -> String {
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content else { throw AIFailure.empty }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct ChatRequest: Codable {
        struct Message: Codable { var role: String; var content: String }
        var model: String
        var messages: [Message]
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable { var message: ChatRequest.Message }
        var choices: [Choice]
    }
}

public enum AIFailure: Error, LocalizedError, Equatable {
    case server(String)
    case empty
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case let .server(message): message
        case .empty: "Le modèle n'a rien répondu."
        case let .unavailable(reason): reason
        }
    }
}

/// A reply to a mail, as a Gmail draft in the same thread.
public struct ReplyDraft: Sendable {
    public var original: MailMessage
    public var body: String

    public init(original: MailMessage, body: String) {
        self.original = original
        self.body = body
    }

    public var to: String { original.replyTo ?? original.from }

    public var subject: String {
        original.subject.lowercased().hasPrefix("re:") ? original.subject : "Re: \(original.subject)"
    }

    public func rfc2822() -> Data {
        var headers = [
            "To: \(to)",
            "Subject: \(OutgoingMail.encodedWord(subject))",
            "MIME-Version: 1.0",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Transfer-Encoding: 8bit",
        ]
        if let id = original.rfcMessageID {
            headers.append("In-Reply-To: \(id)")
            headers.append("References: \([original.references, id].compactMap { $0 }.joined(separator: " "))")
        }
        return Data((headers + ["", body]).joined(separator: "\r\n").utf8)
    }
}

extension GmailAPI {
    /// Saves a draft in the thread: it shows in Gmail and in any mail client (Mimestream…).
    public func createDraft(_ reply: ReplyDraft) async throws -> String {
        struct Draft: Decodable { var id: String }
        let draft = try await post("drafts", json: [
            "message": ["raw": reply.rfc2822().base64URLEncoded, "threadId": reply.original.threadID],
        ], as: Draft.self)
        return draft.id
    }
}
