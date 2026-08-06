import Foundation

/// Candidat retourné par le modèle. Décodage tolérant du score : le modèle renvoie
/// parfois 7.5 ou omet le champ — JSON.parse côté web l'acceptait, on ne doit pas
/// échouer là où la webapp réussissait.
struct Candidate: Codable, Equatable {
    let mot: String
    let categorie: String?
    let score: Int

    enum CodingKeys: String, CodingKey { case mot, categorie, score }

    init(mot: String, categorie: String?, score: Int) {
        self.mot = mot
        self.categorie = categorie
        self.score = score
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mot = try c.decode(String.self, forKey: .mot)
        categorie = try? c.decodeIfPresent(String.self, forKey: .categorie)
        if let i = try? c.decode(Int.self, forKey: .score) { score = i }
        else if let d = try? c.decode(Double.self, forKey: .score) { score = Int(d.rounded()) }
        else { score = 0 }
    }
}

/// Bloc JSON final du modèle : {candidats, alerte, question}.
struct DeductionResult: Codable, Equatable {
    let candidats: [Candidate]
    let alerte: String?
    let question: String?
}
