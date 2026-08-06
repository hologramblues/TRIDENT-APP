import SwiftUI

@main
struct TridentApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .onAppear { app.boot(url: nil) }
                .onOpenURL { url in app.boot(url: url) } // trident://x?w=…&stealth=1 / ?mode=notes
        }
    }
}
