import Foundation

extension MailMessage {
    /// "Paul Exemple <paul@exemple.com>" → "PE", "GitHub <notifications@github.com>" → "G",
    /// "paul@exemple.com" → "P": the letters of the sender's avatar.
    public var senderInitials: String {
        let words = senderName.split { !$0.isLetter && !$0.isNumber }
        let letters: [Character]
        if senderName.contains("@") || words.count < 2 {
            letters = words.first?.first.map { [$0] } ?? []
        } else {
            letters = [words[0].first, words[words.count - 1].first].compactMap { $0 }
        }
        return String(letters).uppercased()
    }

    /// The avatar's colour among `count` colours: always the same for an address, on every Mac and every launch
    /// (Swift's `hashValue` changes at each launch).
    public func avatarColorIndex(count: Int) -> Int {
        guard count > 0 else { return 0 }
        // FNV-1a on the lowercased address.
        var hash: UInt32 = 2_166_136_261
        for byte in senderAddress.lowercased().utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return Int(hash % UInt32(count))
    }
}

/// The date column of the mail list: the time today, the weekday this week, the day and month this year,
/// the full date before.
public enum ListDate {
    public static func text(for date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if calendar.isDate(date, inSameDayAs: now) {
            style = style.hour().minute()
        } else if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day,
                  days >= 0, days < 7 {
            style = style.weekday(.wide)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            style = style.day().month(.abbreviated)
        } else {
            style = style.day(.twoDigits).month(.twoDigits).year()
        }
        return date.formatted(style)
    }
}
