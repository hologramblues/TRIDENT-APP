import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        content
            .onChange(of: app.screen, perform: updateIdleTimer)
            // triple tap : Notes ↔ Réglages (le black mode n'est plus dans la
            // navigation, les réglages passent par ce geste). Inactif pendant la
            // révélation, où le tap simple navigue entre les candidats.
            .background(SettingsGestureCatcher {
                switch app.screen {
                case .notes: if !app.notesRevealed { app.openSettings() }
                case .settings: app.screen = .notes
                default: break
                }
            })
    }

    /// Keep-awake : l'écran ne doit JAMAIS se verrouiller pendant le tour
    /// (cycle, chargement, ou Notes en attente de révélation). Gain vs la PWA.
    private func updateIdleTimer(_ s: Screen) {
        let keepAwake = s == .cycle || s == .loading || s == .notes
        UIApplication.shared.isIdleTimerDisabled = keepAwake
    }

    // AnyView par cas : coupe l'inférence de type combinée des 5 écrans,
    // qui faisait dépasser le budget du type-checker.
    private var content: AnyView {
        switch app.screen {
        case .settings: return AnyView(SettingsView())
        case .input: return AnyView(InputView())
        case .loading: return AnyView(LoadingView())
        case .cycle: return AnyView(CycleView())
        case .notes: return AnyView(NotesView())
        }
    }
}
