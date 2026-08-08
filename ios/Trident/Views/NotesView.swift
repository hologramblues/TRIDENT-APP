import SwiftUI

/// Mode Notes déguisé — réplique d'Apple Notes, clair/sombre AUTO (suit le système,
/// c'est pour ça qu'aucun .preferredColorScheme n'est forcé ici).
///
/// Chorégraphie scène (tout se passe dans la fausse note, l'écran ne change jamais) :
/// - « OK » lance la déduction en silence.
/// - Signal discret « résultat prêt » : le ":" de l'heure devient "." (17:35 → 17.35).
/// - Appui long n'importe où : le candidat s'affiche en gris discret en bas
///   (même couleur que la date, il se fond dans l'interface).
/// - Une fois révélé : tap = mot suivant, tiers gauche = précédent,
///   appui long = valider ✓ dans le journal (bref clignotement), double tap = cacher.
/// - « ‹ Notes » mène au black mode (saisie MASTER WORD).
struct NotesView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool

    private var dark: Bool { scheme == .dark }
    /// Gris de la date Apple Notes — utilisé aussi pour la révélation (camouflage parfait).
    private var grayText: Color { dark ? Color(hex: 0x8E8E93) : Color(hex: 0x6D6D72) }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM yyyy 'à' HH:mm"
        var s = f.string(from: Date())
        // signal discret : résultat prêt → le ":" de l'heure devient "."
        if app.notesReady { s = s.replacingOccurrences(of: ":", with: ".") }
        return s
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // ————— Barre "‹ Notes" / "OK" —————
                HStack {
                    // costume Apple Notes — le double tap sur "Notes" ouvre les réglages
                    HStack(spacing: 4) {
                        Text("‹").font(.system(size: 24)).padding(.top, -2)
                        Text("Notes").font(.system(size: 17))
                    }
                    .foregroundColor(Theme.notesYellow)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { app.openSettings() }
                    Spacer()
                    Text("OK")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.notesYellow)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focused = false
                            app.notesOK()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(dark ? Color(hex: 0x141414).opacity(0.94) : Color(hex: 0xF9F9F9).opacity(0.94))

                Text(dateText)
                    .font(.system(size: 12))
                    .foregroundColor(grayText)
                    .padding(.top, 10)
                    .padding(.horizontal, 40)
                    .contentShape(Rectangle())
                    // tour terminé : un tap sur la date remet tout à zéro pour le spectateur suivant
                    .onTapGesture { app.notesReset() }

                TextEditor(text: $app.noteText)
                    .font(.system(size: 17))
                    .lineSpacing(4)
                    .foregroundColor(dark ? .white : Color(hex: 0x1C1C1E))
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
            }

            // ————— Couche de gestes pendant la révélation (bloque l'édition, invisible) —————
            if app.notesRevealed { revealGestureLayer }
        }
        .background((dark ? Color.black : Color.white).ignoresSafeArea())
        .overlay(alignment: .bottomLeading) {
            if app.notesRevealed { revealBar }
        }
        // appui long n'importe où : révèle le candidat quand le résultat est prêt
        // (.simultaneousGesture pour ne pas casser l'édition du TextEditor)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                focused = false
                app.notesLongPress()
            }
        )
    }

    // ————— Révélation : le candidat (ou l'erreur) en gris discret, en bas de la note —————
    private var revealBar: some View {
        Group {
            if let result = app.result {
                Group {
                    if app.onQuestion {
                        Text(result.question ?? "")
                    } else {
                        let cur = result.candidats[app.idx]
                        Text("\(cur.mot)  \(app.idx + 1)/\(result.candidats.count)")
                    }
                }
            } else if !app.notesError.isEmpty {
                Text(app.notesError)
            }
        }
        .font(.system(size: 15))
        .foregroundColor(grayText)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var revealGestureLayer: some View {
        GeometryReader { geo in
            Color.black.opacity(0.001) // capte les gestes sans rien montrer
                .ignoresSafeArea()
                .gesture(
                    LongPressGesture(minimumDuration: 0.6)
                        .onEnded { _ in
                            // "c'était lui" : journal ✓ + la note devient la prédiction
                            app.notesPredict()
                        }
                        .exclusively(before: SpatialTapGesture(count: 2)
                            .onEnded { _ in app.notesHide() }
                            .exclusively(before: SpatialTapGesture()
                                .onEnded { v in app.cycleTap(atX: v.location.x, width: geo.size.width) })))
        }
    }
}
