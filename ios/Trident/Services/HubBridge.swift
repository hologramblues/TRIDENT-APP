import Foundation
import Combine
import WebKit
import UIKit

// ————————————————————— Pont natif du hub —————————————————————
// Contrat défini par CLAUDE-HUB-INTEGRATION.md : le HTML détecte
// window.webkit.messageHandlers.hub ; JS→natif via postMessage({cmd,...}),
// natif→JS via window.hubFromNative({type,...}).

@MainActor
final class HubBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private let app: AppState
    private let speech = SpeechCapture()
    private var cancellables = Set<AnyCancellable>()

    init(app: AppState) {
        self.app = app
        super.init()

        let ps = PeekSmithService.shared
        ps.onStatusChange = { [weak self] ok, nom in
            self?.emit(["type": "psStatus", "connected": ok, "name": nom ?? ""])
        }
        ps.onButton = { [weak self] btn in
            self?.emit(["type": "psButton", "btn": btn])
        }

        // le hub attend le transcript CUMULÉ — il fait son propre parsing
        speech.$rawTranscript
            .dropFirst()
            .sink { [weak self] t in self?.emit(["type": "speech", "text": t]) }
            .store(in: &cancellables)
        speech.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] e in self?.emit(["type": "speechError", "error": e]) }
            .store(in: &cancellables)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let cmd = body["cmd"] as? String else { return }
        switch cmd {
        case "haptic":
            // pattern [ms, pause, ms…] : léger si bref, medium sinon
            let pattern = (body["pattern"] as? [Int]) ?? []
            let style: UIImpactFeedbackGenerator.FeedbackStyle = pattern.reduce(0, +) > 60 ? .medium : .light
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        case "openURL":
            if let s = body["url"] as? String, let url = URL(string: s) {
                UIApplication.shared.open(url) // https ET schemes custom (shortcuts:// …)
            }
        case "psConnect":
            PeekSmithService.shared.start() // première popup Bluetooth ici, jamais avant
        case "psSend":
            if let texte = body["text"] as? String { PeekSmithService.shared.send(texte) }
        case "speechStart":
            speech.start()
        case "speechStop":
            speech.stop()
        case "openTrident":
            app.screen = .notes // la tuile Trident du hub bascule vers le faux Notes natif
        default:
            break
        }
    }

    private func emit(_ payload: [String: Any]) {
        guard let webView,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.hubFromNative(\(json))", completionHandler: nil)
    }
}
