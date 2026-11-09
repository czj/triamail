import Foundation

extension MailMessage {
    /// "Paul Exemple <paul@exemple.com>" → "PE", "GitHub <notifications@github.com>" → "G",
    /// "paul@exemple.com" → "P": the letters of the sender's avatar.
    /// "Exemple, Jeanne" → "JE"; notes like "(via LinkedIn)" or "- GitHub" after the name are left out.
    public var senderInitials: String {
        var name = senderName
            .replacing(/\s*\(.*\)\s*$/, with: "")
            .replacing(/\s+[-–—|]\s+.*$/, with: "")
        if !name.contains("@"), let comma = name.firstIndex(of: ",") {
            name = "\(name[name.index(after: comma)...]) \(name[..<comma])"
        }
        let words = name.split { !$0.isLetter && !$0.isNumber }
        let firsts: [Character]
        if name.contains("@") || words.count < 2 {
            firsts = words.first?.first.map { [$0] } ?? []
        } else {
            firsts = [words[0].first, words[words.count - 1].first].compactMap { $0 }
        }
        // One letter each, even when uppercasing makes two ("ß" → "SS").
        return firsts.map { String($0.uppercased().prefix(1)) }.joined()
    }

    /// The avatar's colour among `count` colours: always the same for a sender, on every Mac and every launch
    /// (Swift's `hashValue` changes at each launch). Based on the name: GitHub sends every actor from one address.
    public func avatarColorIndex(count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(Self.fnv1a(senderName.lowercased()) % UInt32(count))
    }

    static func fnv1a(_ text: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return hash
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
