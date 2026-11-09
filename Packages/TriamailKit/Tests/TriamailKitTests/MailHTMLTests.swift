import Foundation
import Testing
@testable import TriamailKit

@Suite struct MailHTMLTests {
    @Test func wrapsFragmentsAndInjectsIntoHead() {
        let fragment = MailHTML.document(for: "<p>Bonjour</p>", allowingRemoteContent: false)
        #expect(fragment.hasPrefix("<!doctype html>"))
        #expect(fragment.contains("<body><p>Bonjour</p></body>"))
        let full = MailHTML.document(for: "<html><HEAD lang=\"fr\"><title>x</title></head><body>y</body></html>", allowingRemoteContent: false)
        #expect(full.contains("<HEAD lang=\"fr\">\n<meta charset=\"utf-8\">") || full.contains("<HEAD lang=\"fr\"><meta charset=\"utf-8\">"))
        #expect(full.contains("<title>x</title>"))
        // `<header>` is not the head: the fragment is wrapped.
        let header = MailHTML.document(for: "<div><header class=\"top\">Logo</header></div>", allowingRemoteContent: false)
        #expect(header.hasPrefix("<!doctype html>"))
        #expect(header.contains("<header class=\"top\">Logo</header>"))
    }

    @Test func policyBlocksTheWebUntilAllowed() {
        let blocked = MailHTML.policy(allowingRemoteContent: false)
        #expect(blocked.contains("default-src 'none'"))
        #expect(blocked.contains("form-action 'none'"))
        #expect(!blocked.contains("https:"))
        #expect(!blocked.contains("script"))
        let allowed = MailHTML.policy(allowingRemoteContent: true)
        #expect(allowed.contains("img-src data: cid: https: http:"))
        #expect(!allowed.contains("script"))
        #expect(MailHTML.document(for: "<p>x</p>", allowingRemoteContent: false).contains("Content-Security-Policy"))
    }

    @Test func detectsRemoteContent() {
        #expect(MailHTML.hasRemoteContent(#"<img src="https://exemple.com/pixel.gif">"#))
        #expect(MailHTML.hasRemoteContent(#"<img SRC='//exemple.com/a.png'>"#))
        #expect(MailHTML.hasRemoteContent(#"<img srcset="https://exemple.com/a@2x.png 2x">"#))
        #expect(MailHTML.hasRemoteContent(#"<td style="background: url('https://exemple.com/b.png')">"#))
        #expect(MailHTML.hasRemoteContent(#"<link rel="stylesheet" href="https://exemple.com/s.css">"#))
        #expect(MailHTML.hasRemoteContent(#"<style>@import "https://exemple.com/s.css";</style>"#))
        #expect(!MailHTML.hasRemoteContent(#"<a href="https://exemple.com">lien</a><img src="cid:logo">"#))
        #expect(!MailHTML.hasRemoteContent(#"<img data-src="https://exemple.com/lazy.png" src="cid:a">"#))
        #expect(!MailHTML.hasRemoteContent("<p>Rien</p>"))
    }
}
