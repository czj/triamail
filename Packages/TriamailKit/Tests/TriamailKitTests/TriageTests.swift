import Foundation
import Testing
@testable import TriamailKit

struct TriageTests {
    private func mail(_ id: String, from: String = "Paul Exemple <paul@exemple.com>", subject: String = "Devis",
                      text: String = "", labels: [String] = [], attachments: [MailMessage.Attachment] = []) -> MailMessage {
        MailMessage(id: id, threadID: id, account: "jeanne@exemple.com", from: from, to: "jeanne@exemple.com", cc: "",
                    subject: subject, date: .now, snippet: "", listID: nil, labelIDs: labels, plainText: text, html: nil,
                    attachments: attachments)
    }

    @Test func unreadComesFromTheGmailLabel() {
        #expect(mail("a", labels: ["UNREAD", "INBOX"]).isUnread)
        #expect(!mail("a", labels: ["INBOX"]).isUnread)
    }

    @Test func searchIgnoresCaseAndAccents() {
        let message = mail("a", subject: "Réunion de jeudi")
        #expect(message.matches("reunion"))
        #expect(message.matches("PAUL"))
        #expect(message.matches("  "))
        #expect(!message.matches("facture"))
    }

    @Test func sidePaneShowsTheInvoiceBeforeThePage() {
        let both = mail("a", subject: "Your receipt", text: "https://github.com/exemple/projet/pull/1")
        #expect(both.sideContents == [.invoice, .page(URL(string: "https://github.com/exemple/projet/pull/1")!)])
        #expect(mail("b").sideContents.isEmpty)
    }

    @Test func nextMailAfterArchiving() {
        let list = ["a", "b", "c"].map { mail($0) }
        #expect(list.neighbor(afterRemoving: "a")?.id == "b")
        #expect(list.neighbor(afterRemoving: "c")?.id == "b")
        #expect(list.neighbor(afterRemoving: "z") == nil)
        #expect([mail("a")].neighbor(afterRemoving: "a") == nil)
    }
}
