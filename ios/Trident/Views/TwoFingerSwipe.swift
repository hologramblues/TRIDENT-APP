import SwiftUI
import UIKit

/// Geste discret d'accès aux réglages : glissement à DEUX doigts vers le bas,
/// n'importe où dans l'app. SwiftUI ne sait pas faire de pan multi-doigts,
/// on attache donc un UIPanGestureRecognizer à la fenêtre (sans perturber
/// l'édition : cancelsTouchesInView = false).
struct TwoFingerSwipeCatcher: UIViewRepresentable {
    var onSwipeDown: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSwipeDown: onSwipeDown) }

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
            let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handle(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            pan.cancelsTouchesInView = false
            window.addGestureRecognizer(pan)
            coordinator.recognizer = pan
        }
    }

    final class Coordinator: NSObject {
        let onSwipeDown: () -> Void
        var recognizer: UIPanGestureRecognizer?
        init(onSwipeDown: @escaping () -> Void) { self.onSwipeDown = onSwipeDown }

        @objc func handle(_ g: UIPanGestureRecognizer) {
            guard g.state == .ended else { return }
            let t = g.translation(in: g.view)
            // franc vers le bas, sans dérive latérale
            if t.y > 80, abs(t.x) < 60 { onSwipeDown() }
        }
    }
}
