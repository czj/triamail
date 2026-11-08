import Foundation
import Testing
@testable import TriamailKit

@Suite struct InvoiceArchivingTests {
    @Test func writesIntoTheDatedFolderWithoutOverwriting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("triamail-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = ArchiveFolder(name: "Achats", path: root.path, subfolder: .yearMonth)
        let rule = ArchiveRule(senderContains: "@exemple.com", folderID: folder.id, renameTo: "Facture Exemple")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
        let plan = try #require(ArchivePlanner(folders: [folder], rules: [rule], calendar: calendar)
            .plan(for: Document(fileName: "FA-1.pdf", sender: "factures@exemple.com", date: date)))

        let first = try Archiver.write(Data("un".utf8), plan: plan)
        let second = try Archiver.write(Data("deux".utf8), plan: plan)
        #expect(first.path == root.appendingPathComponent("2026-03/2026-03-07 - Facture Exemple.pdf").path)
        #expect(second.lastPathComponent == "2026-03-07 - Facture Exemple - 1.pdf")
        #expect(try String(contentsOf: first, encoding: .utf8) == "un")
    }

    @Test func oldSettingsWithoutAccountingEmailStillDecode() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Achats","path":"~/Achats","datePrefix":true,"subfolder":"year"}"#
        let folder = try JSONDecoder().decode(ArchiveFolder.self, from: Data(json.utf8))
        #expect(folder.accountingEmail == nil)
    }

    @Test func outgoingMailIsValidMIMEWithEncodedHeaders() throws {
        let mail = OutgoingMail(to: "import@exemple.com", subject: "Facture Exemple – mars", body: "Facture jointe.",
                                attachmentName: "2026-03-07 - Facture Exemple.pdf", attachment: Data("%PDF-1.4".utf8))
        let raw = try #require(String(data: mail.rfc2822(boundary: "B"), encoding: .utf8))
        #expect(raw.hasPrefix("To: import@exemple.com\r\nSubject: =?UTF-8?B?"))
        #expect(raw.contains("Content-Type: multipart/mixed; boundary=\"B\""))
        #expect(raw.contains("filename*=UTF-8''2026-03-07%20-%20Facture%20Exemple.pdf"))
        #expect(raw.contains(Data("%PDF-1.4".utf8).base64EncodedString()))
        #expect(raw.hasSuffix("--B--\r\n"))
    }

    @Test func noTextInAnEmptyPDF() {
        #expect(PDFText.extract(from: Data("pas un pdf".utf8)) == nil)
    }
}
