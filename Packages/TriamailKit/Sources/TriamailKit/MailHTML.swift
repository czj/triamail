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
        // Only real image types go into the document (the type is copied into an attribute).
        let usable = images.filter { $0.value.mimeType.wholeMatch(of: /image\/[a-z0-9.+-]+/.ignoresCase()) != nil }
        guard !usable.isEmpty else { return html }
        let lowercased = Dictionary(usable.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        return html.replacing(cidReference) { match in
            guard let image = lowercased[contentID(match.2)] else { return String(match.0) }
            return "\(match.1)data:\(image.mimeType.lowercased());base64,\(image.data.base64EncodedString())"
        }
    }

    /// `cid:` as a URL scheme (not inside a word: the character before is captured and kept),
    /// up to a quote, a space, `)`, `>` or an entity's `&`.
    static var cidReference: Regex<(Substring, Substring, Substring)> { /(^|[^\w-])cid:([^"'\s)>&]+)/.ignoresCase() }

    static func contentID(_ reference: Substring) -> String {
        (String(reference).removingPercentEncoding ?? String(reference)).lowercased()
    }

    /// The Content-IDs the HTML shows, lowercased.
    static func referencedContentIDs(in html: String) -> Set<String> {
        Set(html.matches(of: cidReference).map { contentID($0.2) })
    }

    /// Whether the mail's HTML shows images that travel in the mail itself: show it once they are embedded.
    public static func hasInlineImages(_ message: MailMessage) -> Bool {
        !message.inlineParts.isEmpty && message.html != nil
    }

    /// The HTML with its inline images (`cid:`) embedded, fetched through `source` when Gmail only gave their ID.
    /// Nil when the mail has no inline image (show `message.html` as it is) or when the task was cancelled.
    /// Runs off the caller's actor; an image that cannot be fetched stays a `cid:` link.
    public static func withInlineImages(_ message: MailMessage, source: any MailSource) async -> String? {
        guard hasInlineImages(message), let html = message.html else { return nil }
        // In parallel: a newsletter can embed a dozen images (a handful of requests, well under Gmail's limits).
        let images = await withTaskGroup(of: (String, String, Data?).self) { group in
            for part in message.inlineParts {
                group.addTask {
                    if let data = part.data { return (part.contentID, part.mimeType, data) }
                    guard let attachment = part.asAttachment else { return (part.contentID, part.mimeType, nil) }
                    return (part.contentID, part.mimeType, try? await source.attachment(attachment, of: message))
                }
            }
            var images: [String: (mimeType: String, data: Data)] = [:]
            for await (id, mimeType, data) in group {
                if let data { images[id] = (mimeType, data) }
            }
            return images
        }
        // Another mail was selected meanwhile: nothing to show.
        guard !Task.isCancelled else { return nil }
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
