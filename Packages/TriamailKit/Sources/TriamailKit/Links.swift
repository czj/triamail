import Foundation

extension MailMessage {
    /// The page a notification is about, opened in the right-hand panel (C1).
    /// For GitHub: the issue, pull request, discussion, commit or workflow run the mail links to.
    public var primaryLink: URL? {
        let pattern = /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/(?:pull|issues|discussions|commit|actions\/runs|security\/advisories)\/[\w.\/-]+(?:#[\w-]+)?/
        let candidates = plainText.matches(of: pattern).map { String($0.output) }
            + (html ?? "").matches(of: pattern).map { String($0.output) }
        // Prefer a link to a precise comment or review, then the first one.
        let best = candidates.first { $0.contains("#") } ?? candidates.first
        return best.flatMap(URL.init(string:))
    }
}
