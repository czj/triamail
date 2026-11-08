import PDFKit
import SwiftUI
import TriamailKit
import WebKit

/// C5: the invoice on the right, where it will go, and one button to archive it.
struct InvoicePane: View {
    let message: MailMessage
    let settings: SharedSettings
    let markDone: () -> Void

    @State private var pdf: Data?
    @State private var plan: ArchivePlan?
    @State private var fileName = ""
    @State private var status: String?
    @State private var working = false

    private let authenticator = GmailAuthenticator()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let pdf {
                    PDFPreview(data: pdf)
                } else {
                    ProgressView("Préparation de la facture…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            footer
                .padding(12)
                .background(.bar)
        }
        .task(id: message.id) { await prepare() }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let plan {
                Label(plan.destination.path.abbreviatingHomeDirectory, systemImage: "folder")
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if plan.rule.sendToAccounting {
                    Label(plan.folder.accountingEmail.map { "Copie à \($0), puis à la corbeille une fois envoyée" }
                          ?? "Envoi à la comptabilité demandé, mais ce dossier n'a pas d'adresse", systemImage: "paperplane")
                        .foregroundStyle(plan.folder.accountingEmail == nil ? .orange : .secondary)
                }
            } else if pdf != nil {
                Label("Aucune règle ne correspond : ajoute-en une dans Réglages > Archivage.", systemImage: "questionmark.folder")
                    .foregroundStyle(.secondary)
            }
            HStack {
                if let status {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Archiver", systemImage: "archivebox") { Task { await archive() } }
                    .keyboardShortcut("s")
                    .buttonStyle(.borderedProminent)
                    .disabled(plan == nil || pdf == nil || working)
            }
        }
    }

    private func prepare() async {
        pdf = nil
        plan = nil
        status = nil
        do {
            let token = try await authenticator.accessToken(for: GmailAccount(email: message.account))
            let api = GmailAPI(accessToken: token)
            let data: Data
            if let attachment = message.attachments.first(where: { $0.mimeType == "application/pdf" || $0.fileName.lowercased().hasSuffix(".pdf") }) {
                data = try await api.attachment(messageID: message.id, attachmentID: attachment.attachmentID)
                fileName = attachment.fileName
            } else {
                // The invoice is the mail itself: print it to PDF.
                data = try await HTMLToPDF.render(message.html ?? "<pre>\(message.plainText)</pre>")
                fileName = "\(message.subject).pdf"
            }
            pdf = data
            let text = PDFText.extract(from: data)
            let document = Document(fileName: fileName, sender: message.from, date: message.date, text: { text })
            plan = ArchivePlanner(folders: settings.archiveFolders, rules: settings.archiveRules).plan(for: document)
        } catch {
            status = error.localizedDescription
        }
    }

    private func archive() async {
        guard let pdf, let plan else { return }
        working = true
        defer { working = false }
        do {
            let saved = try Archiver.write(pdf, plan: plan)
            status = "Enregistrée : \(saved.lastPathComponent)"
            if plan.rule.sendToAccounting, let address = plan.folder.accountingEmail, !address.isEmpty {
                let token = try await authenticator.accessToken(for: GmailAccount(email: message.account))
                let api = GmailAPI(accessToken: token)
                let mail = OutgoingMail(to: address, subject: saved.deletingPathExtension().lastPathComponent,
                                        body: "Facture jointe.", attachmentName: saved.lastPathComponent, attachment: pdf)
                let sentID = try await api.send(raw: mail.rfc2822())
                // Sent and confirmed: the copy has nothing to do in Sent mail.
                try await api.trash(messageID: sentID)
                status = "Enregistrée et envoyée à \(address)"
            }
            markDone()
        } catch {
            status = "Échec : \(error.localizedDescription)"
        }
    }
}

struct PDFPreview: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(data: data)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.dataRepresentation() != data {
            view.document = PDFDocument(data: data)
        }
    }
}

/// Prints an HTML mail to PDF with an offscreen web view.
@MainActor
enum HTMLToPDF {
    static func render(_ html: String) async throws -> Data {
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1100))
        let loader = Loader()
        view.navigationDelegate = loader
        view.loadHTMLString(html, baseURL: nil)
        try await loader.finished()
        return try await view.pdf(configuration: WKPDFConfiguration())
    }

    private final class Loader: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Void, Error>?
        private var done = false

        func finished() async throws {
            if done { return }
            try await withCheckedThrowingContinuation { self.continuation = $0 }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            done = true
            continuation?.resume()
            continuation = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            done = true
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
