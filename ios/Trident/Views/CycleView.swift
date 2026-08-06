import SwiftUI

/// Écran cycle — un candidat par écran, énorme. Gestes identiques à la webapp :
/// tap = suivant, tiers gauche = précédent, appui long 0,6 s sur le mot = "c'était lui"
/// (validation journal, feedback par brève baisse d'opacité). Dernier écran : question
/// de départage si le modèle hésite.
struct CycleView: View {
    @EnvironmentObject var app: AppState
    @State private var wordOpacity: Double = 1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    // ————— Barre du haut : trio + ✕ —————
                    HStack {
                        Text(app.currentWords.replacingOccurrences(of: " ", with: " · "))
                            .font(Theme.mono(11))
                            .tracking(1.5)
                            .foregroundColor(Theme.dim)
                        Spacer()
                        Text("✕")
                            .font(Theme.mono(13))
                            .foregroundColor(Theme.dim)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .onTapGesture { app.cycleClose() }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    // ————— Centre : mot / catégorie, ou question de départage —————
                    Spacer()
                    Group {
                        if let result = app.result {
                            if app.onQuestion {
                                VStack(spacing: 24) {
                                    Text("DÉPARTAGE")
                                        .font(Theme.mono(11))
                                        .tracking(4)
                                        .foregroundColor(Theme.ember)
                                    Text(result.question ?? "")
                                        .font(Theme.main(26, weight: .medium))
                                        .foregroundColor(Theme.bright)
                                        .lineSpacing(8)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 420)
                                }
                            } else {
                                let cur = result.candidats[app.idx]
                                VStack(spacing: 18) {
                                    Text(cur.mot)
                                        .textCase(.uppercase)
                                        .font(.system(size: cur.mot.count > 10 ? 44 : 58, weight: .bold))
                                        .foregroundColor(Theme.bright)
                                        .minimumScaleFactor(0.5)
                                        .multilineTextAlignment(.center)
                                        .opacity(wordOpacity)
                                    Text(cur.categorie ?? "")
                                        .font(Theme.mono(12))
                                        .tracking(1.2)
                                        .foregroundColor(Theme.mid)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    Spacer()

                    // ————— Bas : alerte (1er mot seulement), points, position —————
                    VStack(alignment: .leading, spacing: 14) {
                        if let alerte = app.result?.alerte, app.idx == 0 {
                            Text("⚠ " + alerte)
                                .font(Theme.mono(11))
                                .foregroundColor(Theme.ember)
                                .lineSpacing(4)
                        }
                        HStack {
                            HStack(spacing: 7) {
                                if let result = app.result {
                                    ForEach(result.candidats.indices, id: \.self) { i in
                                        Circle()
                                            .fill(i == app.idx ? Theme.ember : Theme.dim)
                                            .frame(width: 5, height: 5)
                                    }
                                    if result.question != nil {
                                        // point "question" : cerclé tant qu'inactif
                                        Circle()
                                            .stroke(app.onQuestion ? Theme.ember : Theme.dim, lineWidth: 1)
                                            .background(Circle().fill(app.onQuestion ? Theme.ember : .clear))
                                            .frame(width: 5, height: 5)
                                    }
                                }
                            }
                            Spacer()
                            Text(posText)
                                .font(Theme.mono(12))
                                .foregroundColor(Theme.mid)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 26)
                }
            }
            .contentShape(Rectangle())
            // L'appui long est EXCLUSIF du tap : valider ne fait pas défiler
            // (équivalent du flag holdFired de la webapp).
            .gesture(
                LongPressGesture(minimumDuration: 0.6)
                    .onEnded { _ in validateWithFeedback() }
                    .exclusively(before: SpatialTapGesture()
                        .onEnded { v in app.cycleTap(atX: v.location.x, width: geo.size.width) })
            )
        }
        .preferredColorScheme(.dark)
    }

    private var posText: String {
        guard let result = app.result else { return "" }
        if app.onQuestion { return "?" }
        let cur = result.candidats[app.idx]
        return "\(app.idx + 1)/\(result.candidats.count) · \(cur.score)"
    }

    private func validateWithFeedback() {
        guard !app.onQuestion else { return }
        app.validateCurrent()
        // feedback quasi invisible : brève baisse d'opacité du mot
        withAnimation(.easeInOut(duration: 0.25)) { wordOpacity = 0.25 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(.easeInOut(duration: 0.25)) { wordOpacity = 1 }
        }
    }
}
