import SwiftUI
import Combine

enum Screen: Equatable { case settings, input, loading, cycle, notes }

/// État global de l'app — équivalent des variables globales + show(id) de la webapp.
/// Toute la chorégraphie des écrans (déduction, cycle, mode Notes, réglages) vit ici ;
/// les vues ne font qu'afficher et renvoyer les gestes.
@MainActor
final class AppState: ObservableObject {
    @Published var screen: Screen = .input
    @Published var result: DeductionResult?
    @Published var idx = 0
    @Published var currentWords = ""
    @Published var cameFromNotes = false
    @Published var notesReady = false
    @Published var notesRevealed = false // candidat affiché en bas de la fausse note
    @Published var notesError = ""
    @Published var predictionDate: Date? // date antidatée affichée après une prédiction
    @Published var errorMessage = ""
    @Published var inputText = ""
    @Published var noteText = ""
    @Published var apiKeyField = ""

    let journal = JournalStore()
    private(set) var currentTs: Int64? // entrée de journal de la déduction en cours
    private lazy var service = DeductionService(keyProvider: { KeychainStore.getKey() })
    private var cancellables = Set<AnyCancellable>()

    init() {
        // le journal est un objet imbriqué : relayer ses changements aux vues qui observent AppState
        journal.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // ————— Boot / URL scheme (reproduit boot() de la webapp) —————
    func boot(url: URL?) {
        switch URLRouter.route(url: url, hasKey: !KeychainStore.getKey().isEmpty) {
        case .settings:
            apiKeyField = ""
            screen = .settings
        case .stealthDeduce(let w):
            noteText = ""
            screen = .notes
            Task { await deduce(w, fromNotes: true) }
        case .deduce(let w):
            inputText = w
            Task { await deduce(w, fromNotes: false) }
        case .notes:
            screen = .notes
        case .input:
            // Divergence voulue avec la webapp (choix Jérémie 2026-08-06) : l'app native
            // démarre sur le déguisement Notes — cohérent avec le nom "Notes" de l'icône.
            // Le black mode (saisie MASTER WORD) reste accessible par "‹ Notes".
            screen = .notes
        }
    }

    // ————— Déduction (même ordre de contrôle que la webapp) —————
    func deduce(_ raw: String, fromNotes: Bool) async {
        let clean = DeductionService.cleanInput(raw)
        guard clean.split(separator: " ").count >= 3 else { return } // silencieux, comme la webapp
        guard !KeychainStore.getKey().isEmpty else { apiKeyField = ""; screen = .settings; return }
        currentWords = clean
        cameFromNotes = fromNotes
        if !fromNotes { screen = .loading }
        do {
            guard let (mots, res) = try await service.deduce(clean) else { return }
            result = res
            idx = 0
            currentTs = journal.logDeduction(mots: mots, result: res)
            if fromNotes {
                notesReady = true // résultat prêt, on reste déguisé jusqu'au geste
            } else {
                screen = .cycle
            }
        } catch {
            let msg = (error as? DeductionError)?.errorDescription ?? error.localizedDescription
            if fromNotes { notesReady = false; notesError = msg }
            else { errorMessage = msg; screen = .input }
        }
    }

    // ————— Cycle —————
    var onQuestion: Bool {
        guard let result else { return false }
        return idx >= result.candidats.count
    }

    func cycleTap(atX x: CGFloat, width: CGFloat) {
        guard let result else { return }
        let lastIdx = result.candidats.count - (result.question != nil ? 0 : 1)
        if x < width * 0.3 { idx = max(idx - 1, 0) }
        else { idx = min(idx + 1, lastIdx) }
    }

    func cycleClose() {
        // le black mode n'est plus dans la navigation : ✕ ramène toujours au déguisement
        inputText = ""
        errorMessage = ""
        screen = .notes
    }

    /// Appui long sur le mot affiché : "c'était lui" — pas de validation sur l'écran question.
    func validateCurrent() {
        guard let result, idx < result.candidats.count, let ts = currentTs else { return }
        journal.validate(ts: ts, mot: result.candidats[idx].mot, rang: idx + 1)
    }

    // ————— Mode Notes —————
    func notesOK() {
        notesReady = false
        notesRevealed = false
        notesError = ""
        Task { await deduce(noteText, fromNotes: true) }
    }

    /// Appui long dans la note : révèle le candidat en gris discret en bas.
    /// En cas d'erreur de déduction, c'est l'erreur qui s'affiche au même endroit.
    func notesLongPress() {
        if (notesReady && result != nil) || !notesError.isEmpty { notesRevealed = true }
    }

    func notesHide() {
        notesRevealed = false
    }

    /// Appui long sur le candidat révélé : validation ✓ au journal + la note entière
    /// devient ce mot — l'app affiche alors une "prédiction" écrite à l'avance,
    /// avec une date antidatée crédible (la note "existait" avant le tour).
    func notesPredict() {
        guard let result, idx < result.candidats.count else { return }
        validateCurrent()
        let mot = result.candidats[idx].mot
        noteText = mot.prefix(1).uppercased() + mot.dropFirst()
        predictionDate = Self.antedatedDate()
        notesRevealed = false
    }

    /// Date crédible d'une prédiction "écrite à l'avance" : le matin même (9 h 0x-5x)
    /// si le tour se joue l'après-midi ou le soir, sinon la veille au soir (21 h 0x-5x).
    static func antedatedDate(now: Date = Date()) -> Date {
        let cal = Calendar.current
        if cal.component(.hour, from: now) >= 14 {
            var c = cal.dateComponents([.year, .month, .day], from: now)
            c.hour = 9
            c.minute = Int.random(in: 4...57)
            return cal.date(from: c) ?? now
        } else {
            let veille = cal.date(byAdding: .day, value: -1, to: now) ?? now
            var c = cal.dateComponents([.year, .month, .day], from: veille)
            c.hour = 21
            c.minute = Int.random(in: 4...57)
            return cal.date(from: c) ?? now
        }
    }

    /// Tap sur la ligne de date : remise à zéro complète pour le spectateur suivant
    /// (note vide, résultat effacé, l'heure retrouve son ":").
    func notesReset() {
        noteText = ""
        result = nil
        idx = 0
        currentWords = ""
        notesReady = false
        notesRevealed = false
        notesError = ""
        predictionDate = nil
    }

    // ————— Réglages —————
    func openSettings() {
        apiKeyField = KeychainStore.getKey()
        screen = .settings
    }

    func saveKey() {
        let k = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        KeychainStore.setKey(k)
        screen = .notes // retour au déguisement par défaut
    }
}
