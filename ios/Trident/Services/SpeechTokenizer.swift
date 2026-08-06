import Foundation

/// Tokenisation du transcript vocal — logique identique à la webapp :
/// minuscules, ponctuation → espace, on garde les 3 derniers mots pleins
/// (longueur > 1, hors mots-outils). Foundation uniquement : testable sans Xcode.
enum SpeechTokenizer {
    /// Copié VERBATIM depuis la constante STOPWORDS de index.html.
    static let stopwords: Set<String> = Set(
        "le la les un une des du de d l et ou où mais donc or ni car que qui quoi dont il elle on nous vous ils elles je tu me te se ce cet cette ces mon ton son ma ta sa mes tes ses notre votre leur nos vos leurs à au aux en dans par pour sur sous avec sans est sont était très plus moins alors oui non ok d'accord accord voilà bon ben euh hum donc alors ensuite puis après premier deuxième troisième mot mots pense penser dit dis dites choisi"
            .split(separator: " ").map(String.init)
    )

    /// Les 3 derniers mots pleins du transcript — on répète naturellement les mots
    /// du spectateur en dernier, c'est eux qu'on capte.
    static func lastFullWords(_ transcript: String) -> String {
        let cleaned = transcript.lowercased()
            .replacingOccurrences(of: "[.,!?';:]", with: " ", options: .regularExpression)
        let toks = cleaned.split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
        return toks.suffix(3).joined(separator: " ")
    }
}
