import Foundation

/// When a reminder is due (C4): in 1, 3 or 7 days, or on a chosen day, at 9:00.
public enum ReminderDelay: Hashable, Sendable {
    case days(Int)
    case on(Date)

    public static let presets: [ReminderDelay] = [.days(1), .days(3), .days(7)]

    public var title: String {
        switch self {
        case let .days(count): "J+\(count)"
        case let .on(date): date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    public func dueDate(from now: Date, calendar: Calendar = .current, hour: Int = 9) -> DateComponents {
        let day: Date = switch self {
        case let .days(count): calendar.date(byAdding: .day, value: count, to: now) ?? now
        case let .on(date): date
        }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        return components
    }
}

/// What goes into the reminder: the subject, then links back to the mail and to its page.
public struct ReminderDraft: Equatable, Sendable {
    public var title: String
    public var notes: String
    public var url: URL?

    public init(message: MailMessage) {
        title = message.subject.isEmpty ? "Mail de \(message.senderName)" : message.subject
        let mail = message.gmailWebURL
        let page = message.primaryLink
        notes = [
            "De : \(message.from)",
            "Mail : \(mail.absoluteString)",
            page.map { "Page : \($0.absoluteString)" },
        ].compactMap { $0 }.joined(separator: "\n")
        url = page ?? mail
    }
}

extension MailMessage {
    /// The mail in Gmail on the web, in the right account.
    public var gmailWebURL: URL {
        var components = URLComponents(string: "https://mail.google.com/mail/")!
        components.queryItems = [URLQueryItem(name: "authuser", value: account)]
        components.fragment = "all/\(id)"
        return components.url!
    }
}
