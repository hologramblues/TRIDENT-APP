import Foundation

// ————————————————————— Cœur de la déduction —————————————————————
// Transposition EXACTE de la logique de ../index.html (prompt verbatim, temperature 0
// avec repli, parsing tolérant, appel de rattrapage). Foundation uniquement — aucun
// import UIKit/SwiftUI, exprès : ce fichier se vérifie par typecheck sans Xcode.

enum DeductionError: LocalizedError {
    case api(String)
    case noCandidates

    var errorDescription: String? {
        switch self {
        case .api(let m): return m
        case .noCandidates: return "Réponse sans candidats"
        }
    }
}

struct APIMessage {
    let role: String
    let content: String
}

final class DeductionService {

    // Prompt de déduction — copié VERBATIM depuis index.html (const DEDUCTION_PROMPT).
    // NE JAMAIS reformuler : chaque phrase corrige un échec de test réel (voir PROJET.md).
    // Injecté par script depuis index.html (scripts/sync_prompt.py), vérifié par --check.
    static let deductionPrompt = """
Tu es un moteur de déduction pour un jeu d'association de mots en français. Une personne pense à un MOT SECRET et a donné trois mots, DANS UN ORDRE ALÉATOIRE :

- un mot de la MÊME CATÉGORIE que le mot secret
- un mot commençant par la PREMIÈRE lettre du mot secret
- un mot commençant par la DEUXIÈME lettre du mot secret

Tu ne sais pas quel mot joue quel rôle. Ta mission : déduire le mot secret. Le mot secret n'est jamais IDENTIQUE à un des trois mots donnés — mais il peut fortement leur RESSEMBLER (mêmes premières lettres, sonorité proche) : c'est même fréquent et c'est un INDICE FAVORABLE, car le spectateur qui cherche "un mot commençant par la même lettre" part de son mot secret et pense souvent à un mot qui lui ressemble (qui pense TOURNEVIS donne volontiers "tourbillon"). Ne pénalise JAMAIS un candidat pour sa ressemblance avec un mot donné.

ENTRÉE ISSUE DE DICTÉE VOCALE : les trois mots proviennent souvent d'une reconnaissance vocale, qui confond les homophones. Si un mot donné a un homophone ou quasi-homophone français plus concret ou plus courant (flamand→flamant, vers→verre, mère→mer, saut→seau, chant→champ...), évalue AUSSI les hypothèses avec cette variante, comme si elle avait été donnée. La variante ne change généralement pas le préfixe (mêmes premières lettres) ; elle change surtout la catégorie. Si un candidat de tête repose sur une variante corrigée, signale-le très brièvement dans "alerte" (ex : "lu flamant, pas flamand").

POLYSÉMIE ET PLURIELS : la dictée perd aussi les pluriels, et chaque mot donné peut avoir PLUSIEURS sens courants ("baguette" = pain, mais aussi baguettes chinoises pour manger, baguette magique, baguette de tambour ; "orange" = fruit ou couleur). Quand tu testes un mot comme mot-catégorie, explore les catégories de TOUS ses sens courants, au singulier comme au pluriel — ne t'ancre JAMAIS sur le seul sens le plus fréquent : si un autre sens produit un candidat courant qui colle au préfixe, cette lecture est aussi valable que la première.

MÉTHODE (raisonne en interne, étape par étape) :

1. HYPOTHÈSES DE RÔLES : il existe 6 attributions possibles (3 choix de mot-catégorie × 2 ordres pour les lettres). ÉVALUE SÉRIEUSEMENT LES 6, mais PRIORISE-les avec ces indices forts, issus de la façon dont les mots ont été demandés au spectateur :
   - Le mot "1ère lettre" a été demandé comme "un mot intéressant" : il y a de GRANDES CHANCES que ce soit le mot le plus LONG, le plus obscur ou le plus compliqué des trois
   - Le mot "2ème lettre" a été demandé simple : c'est très souvent le mot le plus COURT des trois
   - Le mot-catégorie est souvent un archétype courant de sa catégorie
   Une hypothèse conforme à ce schéma (mot long/obscur = 1ère lettre, mot court = 2ème lettre) part avec un net avantage dans le classement, et ses candidats doivent être remontés en tête à crédibilité comparable. MAIS ces indices ne sont jamais ÉLIMINATOIRES : les trois mots peuvent être de taille similaire et tous appartenir à des catégories évidentes — dans ce cas seule l'étape 3 tranche, et une hypothèse non conforme au schéma qui produit un candidat bien plus évident gagne quand même.

2. Pour CHAQUE hypothèse :
   a. Liste les catégories du mot-catégorie supposé, du plus spécifique au plus général. Les "catégories" incluent aussi les ASSOCIATIONS NATURELLES, pas seulement les familles taxonomiques : la matière (miroir→verre), l'usage, le lieu, le thème (avion→voyage). Le spectateur donne le premier mot qui lui vient, pas une taxonomie rigoureuse.
   b. Construis le préfixe : [initiale mot A] + [initiale mot B] (ignore les accents, E = É = È)
   c. Cherche des noms communs français dans ces catégories commençant par ce préfixe
   d. Les gens pensent à des mots SIMPLES, CONCRETS, COURANTS — c'est un critère DÉCISIF, pas une préférence molle. Le mot secret est presque toujours un objet du quotidien, un animal connu, un aliment, un vêtement, un meuble... Un mot abstrait, savant, ou qu'on n'emploie presque jamais dans la vie courante (mousson, zéphyr, ostracisme) est un très mauvais candidat même s'il colle parfaitement à la catégorie et au préfixe : classe-le loin derrière tout candidat concret et banal.

3. ÉLIMINATION CROISÉE — c'est ton outil principal de décision : pour chaque hypothèse, la question n'est pas "ce mot peut-il être une catégorie ?" mais "existe-t-il un mot COURANT dans cette catégorie avec ce préfixe ?". Une hypothèse est forte quand elle produit un candidat évident ET que les concurrentes ne produisent rien. Une hypothèse qui ne produit que des mots rares ou tirés par les cheveux est quasi morte, même si son mot-catégorie semblait le plus évident. Pour départager deux hypothèses vivantes, privilégie l'ASSOCIATION LA PLUS NATURELLE dans le sens master word → mot donné, ET le candidat le plus concret et courant : quelqu'un qui pense "vipère" dirait "serpent", pas "mammouth" ; quelqu'un qui pense "portefeuille" dit spontanément "sac à main" ; entre TOURNEVIS (cat=marteau, outil↔outil, objet banal) et MOUSSON (cat=tourbillon, mot rare), tournevis gagne largement.

4. FALLBACKS — si aucune hypothèse ne produit de candidat solide :
   a. Catégorie comprise de façon encore plus large ou décalée par le spectateur
   b. Le spectateur a mal compté ses lettres (teste 1ère + 3ème lettre)
   c. Mot secret très court ou avec H muet

FORMAT DE SORTIE — raisonne d'abord en notes ULTRA-BRÈVES (style télégraphique, 120 mots maximum au total), puis TERMINE IMPÉRATIVEMENT ta réponse par ce bloc JSON (sans backticks), qui doit être la toute dernière chose écrite :

{
  "candidats": [
    {"mot": "...", "categorie": "...", "score": 7}
  ],
  "alerte": null,
  "question": null
}

"candidats" : liste EXHAUSTIVE des mots possibles, toutes hypothèses confondues, y compris celles jugées faibles — classés STRICTEMENT du plus probable au moins probable. N'écarte aucun mot plausible : mieux vaut un candidat improbable en fin de liste qu'un mot manquant. MAIS chaque candidat listé doit avoir un VRAI lien de catégorie ou d'association avec le mot-catégorie de son hypothèse : un mot qui matche seulement le préfixe sans lien de catégorie crédible n'est PAS un candidat et ne doit pas figurer dans la liste (si "tourbillon" est le mot-catégorie, "moto" ou "mouche" n'ont aucun lien réel avec lui — on ne les liste pas). Une liste courte et juste vaut mieux qu'une liste gonflée de faux candidats. Entre candidats d'une même hypothèse, classe par PROXIMITÉ FINE avec le mot-catégorie : le plus proche cousin d'abord (tablette→téléphone avant tablette→télé ; écharpe→chapeau avant écharpe→chemise). Score de 1 à 10.
"alerte" : null, ou avertissement très court si plusieurs lectures restent crédibles.
"question" : null, ou si les candidats de tête sont proches : une courte question à poser au spectateur pour départager, formulée comme une perception de mentaliste et non comme une question binaire (ex : "je le sens plutôt vers le haut, non ?").
"""

    private let keyProvider: () -> String

    init(keyProvider: @escaping () -> String) {
        self.keyProvider = keyProvider
    }

    // ————— Appel API : temperature 0 + repli automatique sans le paramètre si refusé —————
    func callAPI(_ messages: [APIMessage]) async throws -> String {
        do {
            return try await doCall(messages, withTemperature: true)
        } catch {
            let msg = (error as? DeductionError)?.errorDescription ?? error.localizedDescription
            if msg.range(of: "temperature", options: .caseInsensitive) != nil {
                return try await doCall(messages, withTemperature: false)
            }
            throw error
        }
    }

    private func doCall(_ messages: [APIMessage], withTemperature: Bool) async throws -> String {
        var body: [String: Any] = [
            "model": "claude-sonnet-5",
            "max_tokens": 2000,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        if withTemperature { body["temperature"] = 0 } // sortie stable et reproductible

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(keyProvider(), forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("true", forHTTPHeaderField: "anthropic-dangerous-direct-browser-access")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if !(200...299).contains(status) || json?["error"] != nil {
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(status)"
            throw DeductionError.api(msg)
        }
        let blocks = (json?["content"] as? [[String: Any]]) ?? []
        return blocks
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
    }

    // ————— Parsing tolérant : remontée depuis "candidats" vers l'accolade ouvrante —————
    static func extractJson(_ raw: String) -> DeductionResult? {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        guard let anchor = cleaned.range(of: "\"candidats\"", options: .backwards) else { return nil }
        guard let start = cleaned.range(of: "{", options: .backwards, range: cleaned.startIndex..<anchor.lowerBound) else { return nil }
        guard let end = cleaned.range(of: "}", options: .backwards), end.lowerBound > start.lowerBound else { return nil }
        let slice = String(cleaned[start.lowerBound..<end.upperBound])
        return try? JSONDecoder().decode(DeductionResult.self, from: Data(slice.utf8))
    }

    // ————— Nettoyage d'entrée : mêmes remplacements que la webapp —————
    static func cleanInput(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[,;\n]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Déduction complète : nettoyage, appel, rattrapage si le JSON manque.
    /// Retourne nil si moins de 3 mots (comportement silencieux de la webapp).
    func deduce(_ raw: String) async throws -> (mots: String, result: DeductionResult)? {
        let clean = Self.cleanInput(raw)
        guard clean.split(separator: " ").count >= 3 else { return nil }

        let userMsg = APIMessage(role: "user", content: Self.deductionPrompt + "\n\nENTRÉE (ordre aléatoire) : " + clean)
        var text = try await callAPI([userMsg])
        var parsed = Self.extractJson(text)
        if parsed == nil {
            // rattrapage : réponse tronquée avant le JSON
            text = try await callAPI([
                userMsg,
                APIMessage(role: "assistant", content: text),
                APIMessage(role: "user", content: "Conclus MAINTENANT : donne UNIQUEMENT le bloc JSON final, sans aucun autre texte."),
            ])
            parsed = Self.extractJson(text)
        }
        guard let result = parsed, !result.candidats.isEmpty else { throw DeductionError.noCandidates }
        return (clean, result)
    }
}
