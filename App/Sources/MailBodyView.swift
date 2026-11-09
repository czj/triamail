import AppKit
import SwiftUI
import TriamailKit
import WebKit

/// The mail's HTML body: no JavaScript, remote content blocked until allowed for this mail (the document's own
/// Content-Security-Policy, see `MailHTML`), links opened in the default browser, never inside the app.
/// One view per mail: the caller gives it `.id(message.id)`.
struct HTMLMailBody: NSViewRepresentable {
    let html: String
    let allowsRemoteContent: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        // Nothing kept between mails: no cookies, no cache a tracker could use.
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        // Reloads when the remote content choice changes, or when the inline images arrive (the HTML grows).
        let key = "\(allowsRemoteContent)-\(html.utf8.count)"
        guard context.coordinator.loaded != key else { return }
        context.coordinator.loaded = key
        view.loadHTMLString(MailHTML.document(for: html, allowingRemoteContent: allowsRemoteContent), baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            // The mail itself (loaded as about:blank) and its in-page anchors stay here.
            if url.scheme == "about" { return .allow }
            // A click on a link goes to the browser; anything else (a redirect, a form) goes nowhere.
            if action.navigationType == .linkActivated, ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
            return .cancel
        }
    }
}

/// A plain-text body (or its translation), at a comfortable line length.
struct ReadableText: View {
    let text: String

    var body: some View {
        Text(text)
            .lineSpacing(3)
            .textSelection(.enabled)
            .frame(maxWidth: 680, alignment: .leading)
    }
}

/// Above the body: the subject in large type, then who, to whom and when.
struct MailHeader: View {
    let message: MailMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message.subject)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)
            HStack(alignment: .top, spacing: 10) {
                SenderAvatar(message: message, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(message.senderName).font(.headline)
                        if message.senderName != message.senderAddress {
                            Text(message.senderAddress)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    if !message.to.isEmpty {
                        Text("À : \(message.to)\(message.cc.isEmpty ? "" : "  Cc : \(message.cc)")")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(message.date, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
