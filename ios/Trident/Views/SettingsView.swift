import SwiftUI

/// Réglages : clé API (Keychain) + section JOURNAL (liste, export, vider).
/// Accessible uniquement par appui long sur "MASTER WORD" — jamais visible sur scène.
struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var confirmClear = false
    @State private var antedateValue = ""
    @State private var antedateHours = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // double tap sur le titre : retour au déguisement Notes
                    Text("RÉGLAGES")
                        .font(Theme.mono(11))
                        .tracking(4)
                        .foregroundColor(Theme.dim)
                        .padding(.bottom, 28)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { app.screen = .notes }

                    SecureField("clé API Anthropic (sk-ant-…)", text: $app.apiKeyField)
                        .font(Theme.mono(14))
                        .foregroundColor(Theme.bright)
                        .tint(Theme.ember)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .padding(.vertical, 10)
                        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.dim), alignment: .bottom)

                    Button { app.saveKey() } label: {
                        Text("ENREGISTRER")
                            .font(Theme.mono(13))
                            .tracking(4)
                            .foregroundColor(Theme.dim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(Rectangle().stroke(Theme.dim, lineWidth: 1))
                    }
                    .padding(.top, 40)

                    Text("La clé reste sur cet appareil (Keychain). Console Anthropic → API Keys.")
                        .font(Theme.main(11))
                        .foregroundColor(Theme.dim)
                        .lineSpacing(4)
                        .padding(.top, 16)

                    // ————— Antidatage de la prédiction —————
                    Text("PRÉDICTION ANTIDATÉE DE")
                        .font(Theme.mono(11))
                        .tracking(4)
                        .foregroundColor(Theme.dim)
                        .padding(.top, 44)
                        .padding(.bottom, 6)

                    HStack(spacing: 12) {
                        TextField("5", text: $antedateValue)
                            .keyboardType(.numberPad)
                            .font(Theme.mono(14))
                            .foregroundColor(Theme.bright)
                            .tint(Theme.ember)
                            .multilineTextAlignment(.center)
                            .frame(width: 72)
                            .padding(.vertical, 10)
                            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.dim), alignment: .bottom)
                        unitButton("MIN", isOn: !antedateHours) { antedateHours = false }
                        unitButton("H", isOn: antedateHours) { antedateHours = true }
                        Spacer()
                    }
                    .onChange(of: antedateValue) { _ in pushAntedate() }
                    .onChange(of: antedateHours) { _ in pushAntedate() }

                    // ————— JOURNAL —————
                    Text("JOURNAL")
                        .font(Theme.mono(11))
                        .tracking(4)
                        .foregroundColor(Theme.dim)
                        .padding(.top, 44)
                        .padding(.bottom, 6)

                    JournalListView()

                    HStack(spacing: 12) {
                        ShareLink(item: app.journal.exportText()) {
                            Text("EXPORTER")
                                .font(Theme.mono(13))
                                .tracking(4)
                                .foregroundColor(Theme.dim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .overlay(Rectangle().stroke(Theme.dim, lineWidth: 1))
                        }
                        Button { if !app.journal.entries.isEmpty { confirmClear = true } } label: {
                            Text("VIDER")
                                .font(Theme.mono(13))
                                .tracking(4)
                                .foregroundColor(Theme.dim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .overlay(Rectangle().stroke(Theme.dim, lineWidth: 1))
                        }
                    }
                    .padding(.top, 20)

                    Text("Un tour = un appui long sur le mot trouvé pendant le cycle. Toucher une entrée pour renseigner le mot réel si l'app l'a raté. EXPORTER partage tout pour analyse.")
                        .font(Theme.main(11))
                        .foregroundColor(Theme.dim)
                        .lineSpacing(4)
                        .padding(.top, 16)
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 28)
                .padding(.top, 44)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("Vider le journal (\(app.journal.entries.count) tours) ?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Vider", role: .destructive) { app.journal.clear() }
            Button("Annuler", role: .cancel) {}
        }
        .onAppear {
            // présente la valeur stockée dans l'unité la plus lisible
            let m = app.antedateMinutes
            if m >= 60 && m % 60 == 0 { antedateHours = true; antedateValue = "\(m / 60)" }
            else { antedateHours = false; antedateValue = "\(m)" }
        }
    }

    private func pushAntedate() {
        let v = Int(antedateValue) ?? 0
        guard v > 0 else { return } // champ vide ou invalide : on garde le réglage courant
        app.antedateMinutes = v * (antedateHours ? 60 : 1)
    }

    private func unitButton(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(12))
                .tracking(2)
                .foregroundColor(isOn ? Theme.ember : Theme.dim)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .overlay(Rectangle().stroke(isOn ? Theme.ember : Theme.dim, lineWidth: 1))
        }
    }
}
