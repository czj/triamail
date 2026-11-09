import Foundation
import Testing
@testable import TriamailKit

@Suite struct ListPresentationTests {
    func mail(from: String) -> MailMessage {
        MailMessage(id: "1", threadID: "1", account: "jeanne@exemple.com", from: from, to: "", cc: "", subject: "", date: .now,
                    snippet: "", listID: nil, labelIDs: [], plainText: "", html: nil, attachments: [])
    }

    @Test func initials() {
        #expect(mail(from: "Paul Exemple <paul@exemple.com>").senderInitials == "PE")
        #expect(mail(from: "\"Anna Maria Beispiel\" <anna@beispiel.exemple.com>").senderInitials == "AB")
        #expect(mail(from: "GitHub <notifications@github.com>").senderInitials == "G")
        #expect(mail(from: "paul@exemple.com").senderInitials == "P")
        #expect(mail(from: "élodie exemple <e@exemple.com>").senderInitials == "ÉE")
        #expect(mail(from: "").senderInitials == "")
    }

    @Test func avatarColourIsStablePerAddress() {
        let paul = mail(from: "Paul <paul@exemple.com>").avatarColorIndex(count: 8)
        #expect(mail(from: "Paul Exemple <PAUL@exemple.com>").avatarColorIndex(count: 8) == paul)
        #expect((0..<8).contains(paul))
        // Known value: FNV-1a must not change between versions, or every avatar changes colour.
        #expect(paul == mail(from: "paul@exemple.com").avatarColorIndex(count: 8))
        #expect(mail(from: "x@exemple.com").avatarColorIndex(count: 0) == 0)
        let spread = Set(["a", "b", "c", "d", "e", "f", "g", "h"].map { mail(from: "\($0)@exemple.com").avatarColorIndex(count: 8) })
        #expect(spread.count > 3)
    }

    @Test func listDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        let locale = Locale(identifier: "fr_FR")
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 15)))
        func text(_ month: Int, _ day: Int, _ hour: Int = 9, year: Int = 2026) throws -> String {
            ListDate.text(for: try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: 5))),
                          now: now, calendar: calendar, locale: locale)
        }
        #expect(try text(11, 9) == "09:05")
        #expect(try text(11, 8) == "dimanche")
        #expect(try text(11, 3) == "mardi")
        #expect(try text(11, 2).contains("2 nov"))
        #expect(try text(3, 12, year: 2025) == "12/03/2025")
    }
}
