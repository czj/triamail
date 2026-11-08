import Foundation
import Testing
@testable import TriamailKit

@Suite struct GmailMessagesTests {
    static func b64(_ text: String) -> String {
        Data(text.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }

    static let gitHubJSON = """
    {
      "id": "m1", "threadId": "t1", "labelIds": ["INBOX", "UNREAD"], "snippet": "Build failed &amp; more",
      "internalDate": "1772874000000",
      "payload": {
        "mimeType": "multipart/alternative",
        "headers": [
          { "name": "From", "value": "Jeanne Exemple <notifications@github.com>" },
          { "name": "To", "value": "exemple/projet <projet@noreply.github.com>" },
          { "name": "Subject", "value": "[exemple/projet] CI échouée (PR #12)" },
          { "name": "List-ID", "value": "exemple/projet <projet.exemple.github.com>" }
        ],
        "parts": [
          { "mimeType": "text/plain", "body": { "data": "\(b64("La CI a échoué."))" } },
          { "mimeType": "text/html", "body": { "data": "\(b64("<p>La CI a <b>échoué</b>.</p>"))" } }
        ]
      }
    }
    """

    static let invoiceJSON = """
    {
      "id": "m2", "threadId": "t2", "labelIds": ["INBOX"], "internalDate": "1772874000000",
      "payload": {
        "mimeType": "multipart/mixed",
        "headers": [
          { "name": "From", "value": "\\"Exemple SAS\\" <factures@exemple.com>" },
          { "name": "To", "value": "jeanne@exemple.com" },
          { "name": "Subject", "value": "Votre facture de mars" }
        ],
        "parts": [
          { "mimeType": "text/html", "body": { "data": "\(b64("<style>p{}</style><p>Bonjour,<br>ci-joint.</p>"))" } },
          { "mimeType": "application/pdf", "filename": "FA-2026-03.pdf", "body": { "attachmentId": "att1", "size": 1234 } }
        ]
      }
    }
    """

    func decode(_ json: String, account: String = "jeanne@exemple.com") throws -> MailMessage {
        try JSONDecoder().decode(GmailMessageResource.self, from: Data(json.utf8)).message(account: account)
    }

    @Test func decodesHeadersBodyAndDate() throws {
        let message = try decode(Self.gitHubJSON)
        #expect(message.subject == "[exemple/projet] CI échouée (PR #12)")
        #expect(message.senderName == "Jeanne Exemple")
        #expect(message.senderAddress == "notifications@github.com")
        #expect(message.plainText == "La CI a échoué.")
        #expect(message.snippet == "Build failed & more")
        #expect(message.date == Date(timeIntervalSince1970: 1_772_874_000))
    }

    @Test func gitHubNotificationsAreRecognisedWithTheirRepository() throws {
        let message = try decode(Self.gitHubJSON)
        #expect(message.gitHubRepository == "exemple/projet")
        #expect(Mailbox.github.contains(message))
        #expect(Mailbox.toTriage.contains(message))
        #expect(!Mailbox.direct.contains(message))
    }

    @Test func invoicesAreRecognisedAndAttachmentsListed() throws {
        let message = try decode(Self.invoiceJSON)
        #expect(message.senderName == "Exemple SAS")
        #expect(message.attachments == [.init(fileName: "FA-2026-03.pdf", mimeType: "application/pdf", attachmentID: "att1", size: 1234)])
        #expect(message.plainText == "Bonjour,\nci-joint.")
        #expect(Mailbox.invoices.contains(message))
        #expect(Mailbox.direct.contains(message))
        #expect(!Mailbox.github.contains(message))
    }

    @Test func ordinaryNewsletterIsNotToTriage() throws {
        var message = try decode(Self.invoiceJSON)
        message.subject = "Nos nouveautés"
        message.attachments = []
        message.listID = "<news.exemple.com>"
        #expect(!Mailbox.toTriage.contains(message))
    }
}
