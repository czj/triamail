import Foundation
import Testing
@testable import TriamailKit

@Suite struct AITests {
    @Test func mistralRequestCarriesKeyModelAndPrompt() throws {
        let request = try MistralClient(apiKey: "cle-exemple", model: "").request(prompt: "Bonjour")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer cle-exemple")
        let body = try JSONDecoder().decode(MistralClient.ChatRequest.self, from: try #require(request.httpBody))
        #expect(body.model == MistralClient.defaultModel)
        #expect(body.messages.first?.content == "Bonjour")
    }

    @Test func mistralResponseIsTrimmed() throws {
        let json = #"{"id":"x","choices":[{"index":0,"message":{"role":"assistant","content":"  Bonjour Jeanne,\n\nMerci.  "}}]}"#
        #expect(try MistralClient.content(of: Data(json.utf8)) == "Bonjour Jeanne,\n\nMerci.")
        #expect(throws: AIFailure.empty) { try MistralClient.content(of: Data(#"{"choices":[]}"#.utf8)) }
    }

    @Test func replyStaysInTheThread() throws {
        let original = MailMessage(
            id: "m", threadID: "t", account: "jeanne@exemple.com", from: "Paul Exemple <paul@exemple.com>", to: "jeanne@exemple.com",
            cc: "", subject: "Devis été", date: .now, snippet: "", listID: nil, labelIDs: [], plainText: "", html: nil, attachments: [],
            rfcMessageID: "<abc@exemple.com>", references: "<prev@exemple.com>", replyTo: "devis@exemple.com"
        )
        let raw = try #require(String(data: ReplyDraft(original: original, body: "Merci Paul.").rfc2822(), encoding: .utf8))
        #expect(raw.hasPrefix("To: devis@exemple.com\r\nSubject: =?UTF-8?B?"))
        #expect(raw.contains("In-Reply-To: <abc@exemple.com>\r\nReferences: <prev@exemple.com> <abc@exemple.com>"))
        #expect(raw.hasSuffix("\r\n\r\nMerci Paul."))
        #expect(ReplyDraft(original: original, body: "").subject == "Re: Devis été")
    }

    @Test func oldSettingsUseTheLocalModel() throws {
        let settings = try JSONDecoder().decode(SharedSettings.self, from: Data(#"{"version":1}"#.utf8))
        #expect(settings.aiProvider == .appleLocal)
    }
}
