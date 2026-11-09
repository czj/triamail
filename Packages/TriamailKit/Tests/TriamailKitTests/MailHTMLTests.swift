import Foundation
import Testing
@testable import TriamailKit

@Suite struct MailHTMLTests {
    @Test func wrapsFragmentsAndInjectsIntoHead() {
        let fragment = MailHTML.document(for: "<p>Bonjour</p>")
        #expect(fragment.hasPrefix("<!doctype html>"))
        #expect(fragment.contains("<body><p>Bonjour</p></body>"))
        let full = MailHTML.document(for: "<html><HEAD lang=\"fr\"><title>x</title></head><body>y</body></html>")
        #expect(full.contains("<HEAD lang=\"fr\"><meta charset=\"utf-8\">"))
        #expect(full.contains("<title>x</title>"))
    }

    @Test func detectsRemoteContent() {
        #expect(MailHTML.hasRemoteContent(#"<img src="https://exemple.com/pixel.gif">"#))
        #expect(MailHTML.hasRemoteContent(#"<img SRC='//exemple.com/a.png'>"#))
        #expect(MailHTML.hasRemoteContent(#"<td style="background: url('https://exemple.com/b.png')">"#))
        #expect(MailHTML.hasRemoteContent(#"<link rel="stylesheet" href="https://exemple.com/s.css">"#))
        #expect(!MailHTML.hasRemoteContent(#"<a href="https://exemple.com">lien</a><img src="cid:logo">"#))
        #expect(!MailHTML.hasRemoteContent("<p>Rien</p>"))
    }

    @Test func blockingRulesAreValidJSON() throws {
        let rules = try JSONSerialization.jsonObject(with: Data(MailHTML.blockRemoteContentRules.utf8)) as? [[String: Any]]
        #expect(rules?.count == 1)
    }
}
