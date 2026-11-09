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

    @Test func embedsInlineImages() {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let html = #"<img src="cid:Logo@exemple"><img src='cid:inconnu@exemple'><div style="background:url(cid:logo@exemple)">"#
        let resolved = MailHTML.resolvingInlineImages(in: html, images: ["logo@exemple": ("image/png", png)])
        #expect(resolved.contains(#"<img src="data:image/png;base64,iVBORw==">"#))
        #expect(resolved.contains("cid:inconnu@exemple"))
        #expect(resolved.contains("url(data:image/png;base64,iVBORw==)"))
        #expect(MailHTML.resolvingInlineImages(in: html, images: [:]) == html)
        // Only image types; a reference stops at an entity; "placid:" is not a reference.
        #expect(MailHTML.resolvingInlineImages(in: html, images: ["logo@exemple": (#"image/png" onload="x"#, png)]) == html)
        let quoted = MailHTML.resolvingInlineImages(in: "url(&quot;cid:logo@exemple&quot;) placid:logo@exemple", images: ["logo@exemple": ("image/png", png)])
        #expect(quoted == "url(&quot;data:image/png;base64,iVBORw==&quot;) placid:logo@exemple")
    }

    @Test func fetchesInlineImagesThroughTheSource() async throws {
        var message = try #require(MailMessage.samples.first { $0.html != nil })
        message.html = #"<p>Logo : <img src="cid:logo@atelier"> et <img src="cid:photo@atelier"></p>"#
        message.inlineParts = [
            .init(contentID: "logo@atelier", mimeType: "image/svg+xml", data: Data("<svg/>".utf8)),
            .init(contentID: "photo@atelier", mimeType: "image/png", attachmentID: "p1"),
        ]
        let html = try #require(await MailHTML.withInlineImages(message, source: SampleMailSource()))
        #expect(html.contains("data:image/svg+xml;base64,PHN2Zy8+"))
        #expect(html.contains("data:image/png;base64,"))
        #expect(!html.contains("cid:"))
        message.inlineParts = []
        #expect(await MailHTML.withInlineImages(message, source: SampleMailSource()) == nil)
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
