import Foundation

/// Candidat tel que journalisé — mêmes champs que la webapp (categorie toujours présente, "" si absente).
struct JournalCandidate: Codable, Equatable {
    let mot: String
    let categorie: String
    let score: Int
}

/// Une entrée du journal des tours. Mêmes noms et types que le localStorage `mw_journal`
/// de la webapp (ts en MILLISECONDES epoch) : l'export texte reste le format de migration
/// prévu vers la future base de données (voir PROJET.md).
struct JournalEntry: Codable, Equatable, Identifiable {
    var ts: Int64
    var mots: String
    var candidats: [JournalCandidate]
    var alerte: String?
    var valide: String?
    var rang: Int?
    var vrai: String?

    var id: Int64 { ts }
}
