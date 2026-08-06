import SwiftUI

/// Point "breathe" — équivalent exact de l'animation CSS de la webapp
/// (8 pt, opacité 0.15 ↔ 0.7 sur 1.6 s). Aucun spinner système (discrétion scénique).
struct LoadingView: View {
    @State private var bright = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Circle()
                .fill(Theme.ember)
                .frame(width: 8, height: 8)
                .opacity(bright ? 0.7 : 0.15)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                bright = true
            }
        }
        .preferredColorScheme(.dark)
    }
}
