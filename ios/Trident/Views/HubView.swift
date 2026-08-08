import SwiftUI
import WebKit

/// La WKWebView du hub est créée UNE fois et conservée : naviguer vers Trident
/// puis revenir ne recharge pas le hub (l'effet en cours et l'écran restent).
@MainActor
final class HubStore {
    static let shared = HubStore()
    private var webView: WKWebView?
    private var bridge: HubBridge?

    func webView(app: AppState) -> WKWebView {
        if let webView { return webView }

        let bridge = HubBridge(app: app)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // le hub persiste listes/arbres/réglages en localStorage
        config.userContentController.add(bridge, name: "hub")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.scrollView.isScrollEnabled = false // les gestes internes du hub gèrent tout
        wv.scrollView.bounces = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.isOpaque = false
        wv.backgroundColor = .black
        bridge.webView = wv

        if let url = Bundle.main.url(forResource: "enigma-remote", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        self.bridge = bridge
        self.webView = wv
        return wv
    }
}

/// Hôte SwiftUI de la webview du hub — plein écran, le HTML gère les safe areas.
struct HubView: UIViewRepresentable {
    let app: AppState

    func makeUIView(context: Context) -> WKWebView {
        HubStore.shared.webView(app: app)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
