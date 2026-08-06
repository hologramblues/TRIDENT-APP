// Harness de vérification de la logique pure (parsing tolérant, nettoyage,
// tokenisation vocale, routeur d'URL) — à exécuter en phase B, après installation
// d'Xcode (les Command Line Tools seuls ont un bug de modulemap qui bloque swiftc) :
//
//   cd ios && xcrun swiftc -o /tmp/harness \
//     Trident/Models/DeductionResult.swift \
//     Trident/Services/DeductionService.swift \
//     Trident/Services/URLRouter.swift \
//     Trident/Services/SpeechTokenizer.swift \
//     scripts/harness.swift && /tmp/harness
//
// Tout doit afficher OK ; la moindre divergence avec la webapp est un échec.

import Foundation

var failures = 0
func check(_ name: String, _ ok: Bool) {
    print((ok ? "OK  " : "ÉCHEC ") + name)
    if !ok { failures += 1 }
}

// ————— extractJson : parsing tolérant —————
let jsonBloc = #"{"candidats": [{"mot": "tournevis", "categorie": "outil", "score": 9}], "alerte": null, "question": null}"#
let avecRaisonnement = "Notes: marteau=cat, T-O.\nHypothèses {1,2} vues.\n" + jsonBloc
let r1 = DeductionService.extractJson(avecRaisonnement)
check("extractJson : JSON précédé de raisonnement (avec accolades parasites)", r1?.candidats.first?.mot == "tournevis")

let avecFences = "```json\n" + jsonBloc + "\n```"
check("extractJson : fences markdown retirées", DeductionService.extractJson(avecFences)?.candidats.first?.mot == "tournevis")

check("extractJson : réponse tronquée → nil", DeductionService.extractJson("Notes: \"candidats\" à venir {") == nil)
check("extractJson : sans ancre candidats → nil", DeductionService.extractJson("{\"autre\": 1}") == nil)

let scoreDouble = #"{"candidats": [{"mot": "miroir", "categorie": "verre", "score": 7.5}]}"#
check("extractJson : score décimal toléré (7.5 → 8)", DeductionService.extractJson(scoreDouble)?.candidats.first?.score == 8)

let sansScore = #"{"candidats": [{"mot": "couteau"}]}"#
check("extractJson : score absent toléré (→ 0)", DeductionService.extractJson(sansScore)?.candidats.first?.score == 0)

// ————— cleanInput : mêmes remplacements que la webapp —————
check("cleanInput : virgules et retours ligne", DeductionService.cleanInput(" océan, spatule;\ncitadelle ") == "océan spatule citadelle")
check("cleanInput : espaces multiples", DeductionService.cleanInput("a   b\t c") == "a b c")

// ————— SpeechTokenizer : 3 derniers mots pleins —————
check("tokenizer : stopwords et ponctuation",
      SpeechTokenizer.lastFullWords("alors le premier mot est tourbillon, ensuite marteau et enfin oui.") == "tourbillon marteau oui")
check("tokenizer : mots d'une lettre ignorés",
      SpeechTokenizer.lastFullWords("a verre image mammouth") == "verre image mammouth")

// ————— URLRouter : reproduit boot() —————
func url(_ s: String) -> URL? { URL(string: s) }
check("router : pas de clé → réglages", URLRouter.route(url: url("trident://x?w=a,b,c"), hasKey: false) == .settings)
check("router : w + stealth → déduction furtive",
      URLRouter.route(url: url("trident://x?w=ocean,spatule,citadelle&stealth=1"), hasKey: true) == .stealthDeduce(words: "ocean spatule citadelle"))
check("router : w seul → déduction directe",
      URLRouter.route(url: url("trident://x?w=ocean+spatule+citadelle"), hasKey: true) == .deduce(words: "ocean spatule citadelle"))
check("router : mode=notes", URLRouter.route(url: url("trident://x?mode=notes"), hasKey: true) == .notes)
check("router : sans URL → saisie", URLRouter.route(url: nil, hasKey: true) == .input)

print(failures == 0 ? "\nTOUT EST OK" : "\n\(failures) ÉCHEC(S)")
exit(failures == 0 ? 0 : 1)
