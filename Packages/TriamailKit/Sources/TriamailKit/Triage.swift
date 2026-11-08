import Foundation

extension MailMessage {
    public var isUnread: Bool { labelIDs.contains("UNREAD") }

    /// The list's search: sender, subject or snippet, ignoring case and accents. An empty query matches everything.
    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.isEmpty || [from, subject, snippet].contains { $0.localizedStandardContains(query) }
    }

    /// What the right-hand pane can show for this mail: the invoice to archive, then the page it links to.
    public var sideContents: [SideContent] {
        (Mailbox.invoices.contains(self) ? [.invoice] : []) + (primaryLink.map { [.page($0)] } ?? [])
    }
}

public enum SideContent: Hashable, Sendable {
    case invoice
    case page(URL)
}

extension Array where Element == MailMessage {
    /// The mail to select once `id` leaves the list: the next one, else the previous one.
    /// Nil when `id` is not in the list (keep the selection as it is) or was the only mail.
    public func neighbor(afterRemoving id: MailMessage.ID) -> MailMessage? {
        guard let index = firstIndex(where: { $0.id == id }) else { return nil }
        if indices.contains(index + 1) { return self[index + 1] }
        return index > 0 ? self[index - 1] : nil
    }
}
