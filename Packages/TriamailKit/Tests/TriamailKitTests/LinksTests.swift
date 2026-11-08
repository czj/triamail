import Foundation
import Testing
@testable import TriamailKit

@Suite struct LinksTests {
    func message(text: String, html: String? = nil) -> MailMessage {
        MailMessage(id: "m", threadID: "t", account: "jeanne@exemple.com", from: "", to: "", cc: "", subject: "",
                    date: .now, snippet: "", listID: nil, labelIDs: [], plainText: text, html: html, attachments: [])
    }

    @Test func findsTheGitHubPageOfANotification() {
        let text = """
        Merci !

        —
        Reply to this email directly, view it on GitHub:
        https://github.com/exemple/projet/pull/12#issuecomment-1234
        You are receiving this because you were mentioned.
        """
        #expect(message(text: text).primaryLink?.absoluteString == "https://github.com/exemple/projet/pull/12#issuecomment-1234")
    }

    @Test func prefersTheCommentLinkOverThePlainOne() {
        let text = "Voir https://github.com/exemple/projet/issues/3 et https://github.com/exemple/projet/issues/3#issuecomment-9"
        #expect(message(text: text).primaryLink?.absoluteString == "https://github.com/exemple/projet/issues/3#issuecomment-9")
    }

    @Test func findsWorkflowRunsInHTML() {
        let html = #"<a href="https://github.com/exemple/projet/actions/runs/42">Voir le run</a>"#
        #expect(message(text: "", html: html).primaryLink?.absoluteString == "https://github.com/exemple/projet/actions/runs/42")
    }

    @Test func ignoresUnrelatedLinks() {
        #expect(message(text: "https://github.com/settings/notifications et https://exemple.com").primaryLink == nil)
    }
}
