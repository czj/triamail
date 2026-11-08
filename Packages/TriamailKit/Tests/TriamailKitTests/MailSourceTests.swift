import Foundation
import Testing
@testable import TriamailKit

@Suite struct MailSourceTests {
    let account = SampleMailSource.account

    @Test func inboxHasTheSamplesNewestFirst() async throws {
        let source = SampleMailSource()
        let inbox = try await source.inbox(account: account)
        #expect(inbox.map(\.id) == MailMessage.samples.sorted { $0.date > $1.date }.map(\.id))
        #expect(try await source.inbox(account: GmailAccount(email: "autre@exemple.com")).isEmpty)
    }

    @Test func archivedMailLeavesTheInboxForGood() async throws {
        let source: any MailSource = SampleMailSource()
        let first = try #require(try await source.inbox(account: account).first)
        try await source.archive(first)
        let inbox = try await source.inbox(account: account)
        #expect(!inbox.contains { $0.id == first.id })
        #expect(inbox.count == MailMessage.samples.count - 1)
    }

    @Test func draftsAndSentMailsAreRecorded() async throws {
        let source = SampleMailSource()
        let mail = MailMessage.samples[0]
        #expect(try await source.createDraft(ReplyDraft(original: mail, body: "Merci !")) == "draft-1")
        #expect(await source.drafts.map(\.body) == ["Merci !"])
        try await source.send(OutgoingMail(to: "comptabilite@exemple.com", subject: "Facture", body: "Facture jointe.",
                                           attachmentName: "facture.pdf", attachment: Data("x".utf8)), from: account)
        #expect(await source.sent.map(\.to) == ["comptabilite@exemple.com"])
        #expect(try await source.thread(of: mail) == [mail])
    }

    @Test func sampleInvoiceIsAReadablePDF() async throws {
        let invoice = try #require(MailMessage.samples.first { !$0.attachments.isEmpty })
        let data = try await SampleMailSource().attachment(invoice.attachments[0], of: invoice)
        let text = try #require(PDFText.extract(from: data))
        #expect(text.contains("2026-118"))
        #expect(text.contains("Boutique Exemple"))
        #expect(text.contains("n° 2026-118"))
    }

    @Test func demoSettingsFileTheSampleInvoice() throws {
        let folder = URL(fileURLWithPath: "/tmp/triamail-demo-test", isDirectory: true)
        let settings = SharedSettings.demo(in: folder)
        let invoice = try #require(MailMessage.samples.first { !$0.attachments.isEmpty })
        let document = Document(fileName: invoice.attachments[0].fileName, sender: invoice.from, date: invoice.date, text: { nil })
        let plan = try #require(ArchivePlanner(folders: settings.archiveFolders, rules: settings.archiveRules).plan(for: document))
        #expect(plan.destination.path.hasPrefix(folder.path))
        #expect(plan.folder.accountingEmail?.hasSuffix("@exemple.com") == true)
    }
}
