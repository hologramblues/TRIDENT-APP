import Foundation
import Combine

/// Journal des tours — même modèle de données et même format d'export que la webapp
/// (localStorage `mw_journal`), persisté dans Application Support/journal.json, cap 200.
/// L'export texte est le format de migration prévu vers la future base (PROJET.md).
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("journal.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded
        }
    }

    private func save() {
        entries = Array(entries.suffix(200)) // même cap que slice(-200)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    /// Enregistre une déduction réussie ; retourne son identifiant (ts en millisecondes).
    func logDeduction(mots: String, result: DeductionResult) -> Int64 {
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        entries.append(JournalEntry(
            ts: ts,
            mots: mots,
            candidats: result.candidats.map { JournalCandidate(mot: $0.mot, categorie: $0.categorie ?? "", score: $0.score) },
            alerte: result.alerte,
            valide: nil, rang: nil, vrai: nil
        ))
        save()
        return ts
    }

    /// Appui long pendant le cycle : "c'était lui".
    func validate(ts: Int64, mot: String, rang: Int) {
        guard let i = entries.firstIndex(where: { $0.ts == ts }) else { return }
        entries[i].valide = mot
        entries[i].rang = rang
        entries[i].vrai = nil
        save()
    }

    /// Saisie du mot réellement pensé quand l'app l'a raté. S'il était en fait
    /// dans la liste, il est reclassé comme trouvé avec son rang (même logique que la webapp).
    func setTrueWord(ts: Int64, word: String) {
        guard let i = entries.firstIndex(where: { $0.ts == ts }) else { return }
        let v = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        entries[i].vrai = v.isEmpty ? nil : v
        if !v.isEmpty {
            if let r = entries[i].candidats.firstIndex(where: { $0.mot.lowercased() == v }) {
                entries[i].valide = entries[i].candidats[r].mot
                entries[i].rang = r + 1
                entries[i].vrai = nil
            } else {
                entries[i].valide = nil
                entries[i].rang = nil
            }
        }
        save()
    }

    func clear() {
        entries = []
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    /// Export texte — format STRICTEMENT identique à exportJournal() de la webapp.
    func exportText() -> String {
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "fr_FR")
        dateFmt.dateFormat = "dd/MM/yyyy"
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "fr_FR")
        timeFmt.dateFormat = "HH:mm"

        var lines = ["MASTER WORD — journal (\(entries.count) tours)", ""]
        for e in entries {
            let d = Date(timeIntervalSince1970: Double(e.ts) / 1000)
            lines.append(dateFmt.string(from: d) + " " + timeFmt.string(from: d) + " · " + e.mots)
            lines.append("  proposés : " + e.candidats.map { "\($0.mot.uppercased()) (\($0.categorie.isEmpty ? "?" : $0.categorie), \($0.score))" }.joined(separator: " · "))
            if let alerte = e.alerte { lines.append("  alerte : " + alerte) }
            if let valide = e.valide, let rang = e.rang {
                lines.append("  ✓ trouvé : " + valide.uppercased() + " — rang \(rang)")
            } else if let vrai = e.vrai {
                lines.append("  ✗ raté : le vrai mot était " + vrai.uppercased())
            } else {
                lines.append("  (résultat non renseigné)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
