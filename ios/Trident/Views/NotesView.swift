import SwiftUI

/// Mode Notes déguisé — réplique d'Apple Notes, clair/sombre AUTO (suit le système,
/// c'est pour ça qu'aucun .preferredColorScheme n'est forcé ici). « OK » lance la
/// déduction en silence, l'écran ne bouge pas ; appui long 0,6 s n'importe où bascule
/// sur le cycle quand le résultat est prêt. « ‹ Notes » revient à l'écran normal.
struct NotesView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool

    private var dark: Bool { scheme == .dark }
    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM yyyy 'à' HH:mm"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            // ————— Barre "‹ Notes" / "OK" —————
            HStack {
                HStack(spacing: 4) {
                    Text("‹").font(.system(size: 24)).padding(.top, -2)
                    Text("Notes").font(.system(size: 17))
                }
                .foregroundColor(Theme.notesYellow)
                .contentShape(Rectangle())
                .onTapGesture { app.notesBack() }
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
                .foregroundColor(dark ? Color(hex: 0x8E8E93) : Color(hex: 0x6D6D72))
                .padding(.top, 10)

            TextEditor(text: $app.noteText)
                .font(.system(size: 17))
                .lineSpacing(4)
                .foregroundColor(dark ? .white : Color(hex: 0x1C1C1E))
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.top, 4)
        }
        .background((dark ? Color.black : Color.white).ignoresSafeArea())
        // appui long n'importe où : révèle le cycle quand c'est prêt
        // (.simultaneousGesture pour ne pas casser l'édition du TextEditor)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in app.notesLongPress() }
        )
    }
}
