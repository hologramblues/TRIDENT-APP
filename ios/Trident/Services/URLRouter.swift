import Foundation

/// Destination au lancement ou à l'ouverture d'une URL trident://
enum Route: Equatable {
    case settings                       // pas de clé → réglages
    case stealthDeduce(words: String)   // ?w=…&stealth=1 → Notes + déduction silencieuse
    case deduce(words: String)          // ?w=… → déduction directe
    case notes                          // ?mode=notes → déguisement Notes
    case input                          // défaut : écran de saisie
}

/// Reproduit boot() de la webapp — mêmes noms de paramètres (w, mode, stealth),
/// même remplacement [+,]→espace, même ordre de priorité. Ces paramètres sont
/// l'API d'entrée des apps de capture externes (Raccourcis iOS) : ne pas les changer.
enum URLRouter {
    static func route(url: URL?, hasKey: Bool) -> Route {
        var w = "", mode = "", stealth = false
        if let url, let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let items = comps.queryItems ?? []
            w = (items.first { $0.name == "w" }?.value ?? "")
                .replacingOccurrences(of: "[+,]", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            mode = items.first { $0.name == "mode" }?.value ?? ""
            stealth = (items.first { $0.name == "stealth" }?.value ?? "") == "1"
        }
        if !hasKey { return .settings }
        if !w.isEmpty && stealth { return .stealthDeduce(words: w) }
        if !w.isEmpty { return .deduce(words: w) }
        if mode == "notes" { return .notes }
        return .input
    }
}
