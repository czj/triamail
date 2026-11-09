import Foundation

/// The HTML body as the mail view loads it: the mail's own markup on a white page (senders design for one),
/// with the system font as a fallback and images kept within the width.
public enum MailHTML {
    /// A Content-Security-Policy in the document itself: applied before anything loads, and closed by default.
    /// No scripts, no forms, no frames; web images, styles and fonts only once the user allowed them.
    static func policy(allowingRemoteContent: Bool) -> String {
        let remote = allowingRemoteContent ? " https: http:" : ""
        return "default-src 'none'; img-src data: cid:\(remote); style-src 'unsafe-inline'\(remote); font-src data:\(remote); form-action 'none'; base-uri 'none'"
    }

    public static func document(for html: String, allowingRemoteContent: Bool) -> String {
        let head = """
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(policy(allowingRemoteContent: allowingRemoteContent))">
        <meta name="viewport" content="width=device-width">
        <style>
        html { background: #fff; color: #1d1d1f; }
        body { margin: 16px; font: 14px -apple-system, system-ui, sans-serif; overflow-wrap: anywhere; }
        img { max-width: 100% !important; }
        img:not([height]) { height: auto; }
        pre { white-space: pre-wrap; }
        </style>
        """
        // At the top of the head when there is one (not `<header>`), else around everything.
        if let open = html.range(of: #"<head(\s[^>]*)?>"#, options: [.regularExpression, .caseInsensitive]) {
            var document = html
            document.insert(contentsOf: head, at: open.upperBound)
            return document
        }
        return "<!doctype html><html><head>\(head)</head><body>\(html)</body></html>"
    }

    /// `cid:logo@exemple` → `data:image/png;base64,…` for each image found, so the mail's own images show
    /// without any load. Unknown IDs stay as they are.
    public static func resolvingInlineImages(in html: String, images: [String: (mimeType: String, data: Data)]) -> String {
        guard !images.isEmpty else { return html }
        let lowercased = Dictionary(images.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        return html.replacing(/cid:([^"'\s)>]+)/.ignoresCase()) { match in
            let id = String(match.1).removingPercentEncoding ?? String(match.1)
            guard let image = lowercased[id.lowercased()] else { return String(match.0) }
            return "data:\(image.mimeType);base64,\(image.data.base64EncodedString())"
        }
    }

    /// The HTML with its inline images (`cid:`) embedded, fetched through `source` when Gmail only gave their ID.
    /// Nil when the mail has no HTML or refers to no inline image: show `message.html` as it is.
    /// Runs off the caller's actor; an image that cannot be fetched stays a `cid:` link.
    public static func withInlineImages(_ message: MailMessage, source: any MailSource) async -> String? {
        guard let html = message.html, !message.inlineParts.isEmpty, html.range(of: "cid:", options: .caseInsensitive) != nil else { return nil }
        var images: [String: (mimeType: String, data: Data)] = [:]
        for part in message.inlineParts {
            if let data = part.data {
                images[part.contentID] = (part.mimeType, data)
            } else if let attachment = part.asAttachment, let data = try? await source.attachment(attachment, of: message) {
                images[part.contentID] = (part.mimeType, data)
            }
        }
        return resolvingInlineImages(in: html, images: images)
    }

    /// Whether the mail would load something from the web (images, stylesheets, fonts): trackers often hide
    /// there, so the view offers "Charger". Links (`<a href>`) do not count: they load nothing.
    public static func hasRemoteContent(_ html: String) -> Bool {
        let withoutLinks = html.replacing(/<a\b[^>]*>/.ignoresCase(), with: "")
        let patterns = [
            #"(?<![\w-])(src|srcset|background|poster|data|href)\s*=\s*["']?\s*(https?:)?//"#,
            #"url\(\s*["']?\s*(https?:)?//"#,
            #"@import\s+["']?\s*(https?:)?//"#,
        ]
        return patterns.contains { withoutLinks.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }
}
