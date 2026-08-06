import SwiftUI

/// Écran de saisie — champ unique "trois mots", bouton DÉDUIRE, bouton ● micro.
/// Appui long 0,7 s sur "MASTER WORD" → réglages (même geste que la webapp).
struct InputView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var speech = SpeechCapture()

    private var ready: Bool {
        app.inputText.split(whereSeparator: { $0.isWhitespace }).count >= 3
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("MASTER WORD")
                    .font(Theme.mono(11))
                    .tracking(4)
                    .foregroundColor(Theme.dim)
                    .padding(.bottom, 28)
                    .onLongPressGesture(minimumDuration: 0.7) { app.openSettings() }

                TextField("trois mots", text: $app.inputText)
                    .font(Theme.main(26, weight: .medium))
                    .foregroundColor(Theme.bright)
                    .tint(Theme.ember)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.dim), alignment: .bottom)
                    .onSubmit { Task { await app.deduce(app.inputText, fromNotes: false) } }

                if !app.errorMessage.isEmpty {
                    Text(app.errorMessage)
                        .font(Theme.main(12))
                        .foregroundColor(Theme.ember)
                        .padding(.top, 14)
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await app.deduce(app.inputText, fromNotes: false) }
                    } label: {
                        Text("DÉDUIRE")
                            .font(Theme.mono(13))
                            .tracking(4)
                            .foregroundColor(ready ? Theme.ember : Theme.dim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(Rectangle().stroke(ready ? Theme.ember : Theme.dim, lineWidth: 1))
                    }
                    Button {
                        speech.toggle()
                    } label: {
                        Text("●")
                            .font(Theme.mono(16))
                            .foregroundColor(speech.isListening ? Theme.ember : Theme.dim)
                            .opacity(speech.isListening ? (pulse ? 0.7 : 0.15) : 1)
                            .frame(width: 58)
                            .padding(.vertical, 16)
                            .overlay(Rectangle().stroke(speech.isListening ? Theme.ember : Theme.dim, lineWidth: 1))
                    }
                }
                .padding(.top, 40)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
        // le micro alimente le champ avec les 3 derniers mots pleins (hors mots-outils)
        .onReceive(speech.$lastWords) { words in
            if speech.isListening { app.inputText = words }
        }
        .onReceive(speech.$errorMessage) { msg in
            if let msg { app.errorMessage = msg }
        }
        // même animation "breathe" que la webapp pendant l'écoute
        .onChange(of: speech.isListening) { listening in
            if listening {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                withAnimation(.default) { pulse = false }
            }
        }
        .onDisappear { speech.stop() }
    }

    @State private var pulse = false
}
