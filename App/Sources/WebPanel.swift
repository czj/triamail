import SwiftUI
import WebKit

/// A web page in the right-hand panel. Cookies persist in the app's own store:
/// sign in once (GitHub…), it stays signed in. Safari's sessions are not shared.
struct WebPanel: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if view.url?.absoluteString != url.absoluteString, !view.isLoading || view.url == nil {
            view.load(URLRequest(url: url))
        }
    }
}
