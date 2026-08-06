import SwiftUI

/// Liste du journal (du plus récent au plus ancien). Toucher une entrée ouvre la saisie
/// du mot réellement pensé — même logique que la webapp : s'il était dans la liste,
/// il est reclassé comme trouvé avec son rang.
struct JournalListView: View {
    @EnvironmentObject var app: AppState
    @State private var editedTs: Int64?
    @State private var trueWordField = ""

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd/MM HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if app.journal.entries.isEmpty {
                Text("aucun tour enregistré")
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.dim)
                    .padding(.vertical, 10)
            } else {
                ForEach(app.journal.entries.reversed()) { e in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Self.dateFmt.string(from: Date(timeIntervalSince1970: Double(e.ts) / 1000)))
                            .font(Theme.mono(10))
                            .tracking(1)
                            .foregroundColor(Theme.dim)
                        Text(e.mots)
                            .font(Theme.main(13))
                            .foregroundColor(Theme.mid)
                        statusText(e)
                            .font(Theme.mono(11))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .overlay(Color(hex: 0x1A1C22).frame(height: 1), alignment: .bottom)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        trueWordField = e.vrai ?? ""
                        editedTs = e.ts
                    }
                }
            }
        }
        .alert("Mot réellement pensé (si l'app l'a raté) :", isPresented: Binding(
            get: { editedTs != nil },
            set: { if !$0 { editedTs = nil } }
        )) {
            TextField("mot", text: $trueWordField)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            Button("Enregistrer") {
                if let ts = editedTs { app.journal.setTrueWord(ts: ts, word: trueWordField) }
                editedTs = nil
            }
            Button("Annuler", role: .cancel) { editedTs = nil }
        }
    }

    @ViewBuilder
    private func statusText(_ e: JournalEntry) -> some View {
        if let valide = e.valide, let rang = e.rang {
            Text("✓ \(valide.uppercased()) · rang \(rang)").foregroundColor(Theme.ember)
        } else if let vrai = e.vrai {
            Text("✗ raté · c'était \(vrai.uppercased())").foregroundColor(Theme.bright)
        } else {
            Text("non renseigné").foregroundColor(Theme.dim)
        }
    }
}
