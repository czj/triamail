import EventKit
import Foundation
import TriamailKit

/// Creates reminders in the Reminders app (synced to the iPhone by iCloud).
final class RemindersService {
    static let shared = RemindersService()
    private let store = EKEventStore()

    var lists: [EKCalendar] { store.calendars(for: .reminder) }

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    /// Returns the list the reminder went into.
    @discardableResult
    func add(_ draft: ReminderDraft, due: DateComponents, listName: String?) async throws -> String {
        guard try await requestAccess() else { throw RemindersError.denied }
        let reminder = EKReminder(eventStore: store)
        reminder.title = draft.title
        reminder.notes = draft.notes
        reminder.url = draft.url
        reminder.dueDateComponents = due
        reminder.addAlarm(EKAlarm(absoluteDate: Calendar.current.date(from: due) ?? .now))
        let list = lists.first { $0.title == listName } ?? store.defaultCalendarForNewReminders()
        guard let list else { throw RemindersError.noList }
        reminder.calendar = list
        try store.save(reminder, commit: true)
        return list.title
    }

    /// A reminder for the mail, from the list or the mail itself: the line to show the user, or the error's.
    func remind(_ message: MailMessage, _ delay: ReminderDelay, listName: String?) async -> (text: String, failed: Bool) {
        do {
            let list = try await add(ReminderDraft(message: message), due: delay.dueDate(from: .now), listName: listName)
            return ("Rappel \(delay.title) créé dans « \(list) »", false)
        } catch {
            return (error.localizedDescription, true)
        }
    }

    enum RemindersError: LocalizedError {
        case denied, noList

        var errorDescription: String? {
            switch self {
            case .denied: "Triamail n'a pas accès à Rappels : autorise-le dans Réglages Système > Confidentialité > Rappels."
            case .noList: "Aucune liste dans Rappels."
            }
        }
    }
}
