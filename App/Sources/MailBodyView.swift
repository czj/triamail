import AppKit
import SwiftUI
import TriamailKit
import WebKit

/// The mail's HTML body: no JavaScript, remote content blocked until allowed for this mail,
/// links opened in the default browser, never inside the app.
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
        let key = "\(allowsRemoteContent)\(html.hashValue)"
        guard context.coordinator.loaded != key else { return }
        context.coordinator.loaded = key
        let document = MailHTML.document(for: html)
        let allows = allowsRemoteContent
        Task { @MainActor in
            let controller = view.configuration.userContentController
            controller.removeAllContentRuleLists()
            if !allows, let rules = await Self.blockingRules() {
                controller.add(rules)
            }
            view.loadHTMLString(document, baseURL: nil)
        }
    }

    /// Compiled once per launch.
    @MainActor private static var compiled: WKContentRuleList?

    @MainActor private static func blockingRules() async -> WKContentRuleList? {
        if let compiled { return compiled }
        compiled = try? await WKContentRuleListStore.default()
            .compileContentRuleList(forIdentifier: "triamail.block-remote", encodedContentRuleList: MailHTML.blockRemoteContentRules)
        return compiled
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate {
        /// What is on screen, so a SwiftUI update does not reload the same mail.
        var loaded: String?

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            // The body itself loads; a click on a link goes to the browser.
            guard action.navigationType == .linkActivated || action.targetFrame == nil else { return .allow }
            if let url = action.request.url, ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
            return .cancel
        }
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
