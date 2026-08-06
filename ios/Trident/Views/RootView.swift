import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Group {
            switch app.screen {
            case .settings: SettingsView()
            case .input: InputView()
            case .loading: LoadingView()
            case .cycle: CycleView()
            case .notes: NotesView()
            }
        }
        // Keep-awake : l'écran ne doit JAMAIS se verrouiller pendant le tour
        // (cycle, chargement, ou Notes en attente de révélation). Gain vs la PWA.
        .onChange(of: app.screen) { s in
            UIApplication.shared.isIdleTimerDisabled = (s == .cycle || s == .loading || s == .notes)
        }
    }
}
