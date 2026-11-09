import Foundation

/// The HTML body as the mail view loads it: the mail's own markup on a white page (senders design for one),
/// with the system font as a fallback and images kept within the width.
public enum MailHTML {
    public static func document(for html: String) -> String {
        let style = """
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width">
        <style>
        html { background: #fff; color: #1d1d1f; }
        body { margin: 16px; font: 14px -apple-system, system-ui, sans-serif; overflow-wrap: anywhere; }
        img, table { max-width: 100% !important; height: auto; }
        pre { white-space: pre-wrap; }
        </style>
        """
        // In the head when there is one, else before everything.
        if let head = html.range(of: "<head[^>]*>", options: [.regularExpression, .caseInsensitive]) {
            var document = html
            document.insert(contentsOf: style, at: head.upperBound)
            return document
        }
        return "<!doctype html><html><head>\(style)</head><body>\(html)</body></html>"
    }

    /// Images, stylesheets or frames loaded from the web: trackers often hide there, so they wait for a click.
    public static func hasRemoteContent(_ html: String) -> Bool {
        html.range(of: #"(src|background)\s*=\s*["']?\s*(https?:)?//"#, options: [.regularExpression, .caseInsensitive]) != nil
            || html.range(of: #"url\(\s*["']?\s*(https?:)?//"#, options: [.regularExpression, .caseInsensitive]) != nil
            || html.range(of: #"<link[^>]+href\s*=\s*["']?\s*(https?:)?//"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// For WebKit's content blocker: every web load is blocked until the user allows this mail's remote content.
    public static let blockRemoteContentRules = #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#
}
