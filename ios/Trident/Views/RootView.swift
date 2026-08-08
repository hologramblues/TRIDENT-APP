import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .onChange(of: app.screen, perform: updateIdleTimer)
            // discrétion : dès que l'app passe en arrière-plan (sélecteur d'apps,
            // capture iOS), la révélation est cachée — aucun mot ne doit apparaître
            // sur la vignette du multitâche
            .onChange(of: scenePhase) { phase in
                if phase != .active { app.notesHide() }
            }
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
