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
