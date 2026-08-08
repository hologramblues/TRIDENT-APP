import SwiftUI
import UIKit

/// Geste discret d'accès aux réglages : TRIPLE TAP (un doigt), n'importe où.
/// (Historique : le glissement 2 doigts faisait défiler la note, le 3 doigts
/// entrait en conflit avec les gestes d'édition de texte d'iOS.)
/// Reconnaisseur UIKit attaché à la fenêtre, cancelsTouchesInView = false
/// pour ne pas perturber l'édition ni les autres taps.
struct SettingsGestureCatcher: UIViewRepresentable {
    var onTripleTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTripleTap: onTripleTap) }

    func makeUIView(context: Context) -> AttachView {
        let v = AttachView()
        v.coordinator = context.coordinator
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: AttachView, context: Context) {}

    static func dismantleUIView(_ uiView: AttachView, coordinator: Coordinator) {
        if let r = coordinator.recognizer { r.view?.removeGestureRecognizer(r) }
        coordinator.recognizer = nil
    }

    final class AttachView: UIView {
        weak var coordinator: Coordinator?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, let coordinator, coordinator.recognizer == nil else { return }
            let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handle(_:)))
            tap.numberOfTapsRequired = 3
            tap.numberOfTouchesRequired = 1
            tap.cancelsTouchesInView = false
            window.addGestureRecognizer(tap)
            coordinator.recognizer = tap
        }
    }

    final class Coordinator: NSObject {
        let onTripleTap: () -> Void
        var recognizer: UITapGestureRecognizer?
        init(onTripleTap: @escaping () -> Void) { self.onTripleTap = onTripleTap }

        @objc func handle(_ g: UITapGestureRecognizer) {
            guard g.state == .ended else { return }
            onTripleTap()
        }
    }
}
