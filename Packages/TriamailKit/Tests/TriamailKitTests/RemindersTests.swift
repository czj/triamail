import Foundation
import Testing
@testable import TriamailKit

@Suite struct RemindersTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    @Test func presetsAreDueAtNineInTheMorning() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 12, day: 30, hour: 18))!
        let due = ReminderDelay.days(3).dueDate(from: now, calendar: calendar)
        #expect(due.year == 2027 && due.month == 1 && due.day == 2)
        #expect(due.hour == 9 && due.minute == 0)
        #expect(ReminderDelay.presets.map(\.title) == ["J+1", "J+3", "J+7"])
    }

    @Test func chosenDayKeepsItsDate() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 15))!
        let due = ReminderDelay.on(day).dueDate(from: .now, calendar: calendar)
        #expect(due.month == 5 && due.day == 4 && due.hour == 9)
    }

    @Test func draftLinksBackToTheMailAndThePage() {
        let message = MailMessage(
            id: "18c0ffee", threadID: "t", account: "jeanne@exemple.com", from: "Boutique Exemple <commandes@exemple.com>",
            to: "", cc: "", subject: "Commande 1234 confirmée", date: .now, snippet: "", listID: nil, labelIDs: [],
            plainText: "Suivi : https://github.com/exemple/projet/issues/7", html: nil, attachments: []
        )
        let draft = ReminderDraft(message: message)
        #expect(draft.title == "Commande 1234 confirmée")
        #expect(draft.notes.contains("Mail : https://mail.google.com/mail/?authuser=jeanne@exemple.com#all/18c0ffee"))
        #expect(draft.notes.contains("Page : https://github.com/exemple/projet/issues/7"))
        #expect(draft.url?.absoluteString == "https://github.com/exemple/projet/issues/7")
    }
}
