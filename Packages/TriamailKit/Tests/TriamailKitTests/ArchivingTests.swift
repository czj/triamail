import Foundation
import Testing
@testable import TriamailKit

@Suite struct ArchivingTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    var mailDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 10))!
    }

    let purchases = ArchiveFolder(name: "Achats Exemple", path: "/tmp/achats", datePrefix: true, subfolder: .yearMonth)
    let statements = ArchiveFolder(name: "Relevés", path: "/tmp/releves", datePrefix: false, subfolder: .year)

    func planner(_ rules: [ArchiveRule]) -> ArchivePlanner {
        ArchivePlanner(folders: [purchases, statements], rules: rules, calendar: calendar)
    }

    @Test func renamesWithMailDateIntoYearMonthSubfolder() throws {
        let rule = ArchiveRule(fileNamePattern: "^INV-\\d+", folderID: purchases.id, renameTo: "Facture Exemple", sendToAccounting: true)
        let plan = try #require(planner([rule]).plan(for: Document(fileName: "INV-0042.PDF", date: mailDate)))
        #expect(plan.fileName == "2026-03-07 - Facture Exemple.pdf")
        #expect(plan.directory.path == "/tmp/achats/2026-03")
        #expect(plan.rule.sendToAccounting)
    }

    @Test func keepsOriginalNameWithoutPrefixWhenFolderSaysSo() throws {
        let rule = ArchiveRule(senderContains: "@banque.exemple.com", folderID: statements.id)
        let document = Document(fileName: "releve_mars.pdf", sender: "Banque <noreply@BANQUE.exemple.com>", date: mailDate)
        let plan = try #require(planner([rule]).plan(for: document))
        #expect(plan.fileName == "releve_mars.pdf")
        #expect(plan.directory.path == "/tmp/releves/2026")
    }

    @Test func neverDatesTwice() throws {
        let rule = ArchiveRule(fileNamePattern: "facture", folderID: purchases.id)
        let plan = try #require(planner([rule]).plan(for: Document(fileName: "2025-12-01 - facture.pdf", date: mailDate)))
        #expect(plan.fileName == "2025-12-01 - facture.pdf")
    }

    @Test func textMustContainEveryWordCaseInsensitive() {
        let rule = ArchiveRule(textContainsAll: ["Exemple SAS", "Allemagne"], folderID: purchases.id, renameTo: "Facture Exemple Allemagne")
        let german = Document(fileName: "invoice.pdf", date: mailDate, text: { "EXEMPLE SAS — Allemagne — 12,00 €" })
        let french = Document(fileName: "invoice.pdf", date: mailDate, text: { "Exemple SAS — France" })
        #expect(planner([rule]).plan(for: german)?.fileName == "2026-03-07 - Facture Exemple Allemagne.pdf")
        #expect(planner([rule]).plan(for: french) == nil)
    }

    @Test func firstMatchingRuleWins() throws {
        let specific = ArchiveRule(fileNamePattern: "Exemple.+Allemagne", folderID: purchases.id, renameTo: "Spécifique")
        let general = ArchiveRule(fileNamePattern: "Exemple", folderID: purchases.id, renameTo: "Général")
        let plan = try #require(planner([specific, general]).plan(for: Document(fileName: "Exemple Allemagne.pdf", date: mailDate)))
        #expect(plan.fileName.hasSuffix("Spécifique.pdf"))
    }

    @Test func ruleWithoutConditionOrUnknownFolderNeverMatches() {
        let empty = ArchiveRule(folderID: purchases.id)
        let orphan = ArchiveRule(fileNamePattern: ".", folderID: UUID())
        #expect(planner([empty, orphan]).plan(for: Document(fileName: "a.pdf", date: mailDate)) == nil)
    }

    @Test func invalidRegexDoesNotMatch() {
        let rule = ArchiveRule(fileNamePattern: "([", folderID: purchases.id)
        #expect(planner([rule]).plan(for: Document(fileName: "([.pdf", date: mailDate)) == nil)
    }

    @Test func uniquedAddsSuffixWhenNameIsTaken() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wanted = directory.appendingPathComponent("Facture.pdf")
        #expect(wanted.uniqued() == wanted)
        FileManager.default.createFile(atPath: wanted.path, contents: Data())
        #expect(wanted.uniqued().lastPathComponent == "Facture - 1.pdf")
    }
}
