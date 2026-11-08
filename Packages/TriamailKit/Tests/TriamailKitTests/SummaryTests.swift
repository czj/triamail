import Foundation
import Testing
@testable import TriamailKit

@Suite struct SummaryTests {
    func mail(_ from: String, _ text: String, minutes: Double) -> MailMessage {
        MailMessage(id: UUID().uuidString, threadID: "t", account: "jeanne@exemple.com", from: from, to: "", cc: "",
                    subject: "Devis", date: Date(timeIntervalSince1970: minutes * 60), snippet: "", listID: nil,
                    labelIDs: [], plainText: text, html: nil, attachments: [])
    }

    @Test func singleMailAsksForAShortSummary() {
        let prompt = SummaryPrompt.make(thread: [mail("Paul <paul@exemple.com>", "Pouvez-vous valider ?", minutes: 1)], account: "jeanne@exemple.com")
        #expect(prompt.contains("3 à 6 lignes"))
        #expect(!prompt.contains("C'est un fil"))
        #expect(prompt.contains("Pouvez-vous valider ?"))
    }

    @Test func threadStartsWithWhatChangedSinceMyLastMessage() {
        let thread = [
            mail("Paul <paul@exemple.com>", "Premier devis", minutes: 1),
            mail("Jeanne <JEANNE@exemple.com>", "Trop cher", minutes: 2),
            mail("Paul <paul@exemple.com>", "Nouveau prix : 900 €", minutes: 3),
        ]
        let prompt = SummaryPrompt.make(thread: thread.reversed(), account: "jeanne@exemple.com")
        #expect(prompt.contains("ce qui a changé depuis mon dernier message"))
        #expect(prompt.contains("(mon dernier message)\nTrop cher"))
        #expect(prompt.range(of: "Premier devis")!.lowerBound < prompt.range(of: "Nouveau prix")!.lowerBound)
    }

    @Test func threadWhereIHaveTheLastWord() {
        let thread = [mail("Paul <paul@exemple.com>", "Question", minutes: 1), mail("Jeanne <jeanne@exemple.com>", "Réponse", minutes: 2)]
        #expect(SummaryPrompt.make(thread: thread, account: "jeanne@exemple.com").contains("résume-le en entier"))
    }
}
