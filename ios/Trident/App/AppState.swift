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
    @Published var notesError = ""
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
        if cameFromNotes { screen = .notes }
        else { inputText = ""; errorMessage = ""; screen = .input }
    }

    /// Appui long sur le mot affiché : "c'était lui" — pas de validation sur l'écran question.
    func validateCurrent() {
        guard let result, idx < result.candidats.count, let ts = currentTs else { return }
        journal.validate(ts: ts, mot: result.candidats[idx].mot, rang: idx + 1)
    }

    // ————— Mode Notes —————
    func notesOK() {
        notesReady = false
        notesError = ""
        Task { await deduce(noteText, fromNotes: true) }
    }

    func notesLongPress() {
        if notesReady, result != nil { screen = .cycle }
        else if !notesError.isEmpty { errorMessage = notesError; screen = .input }
    }

    func notesBack() {
        errorMessage = ""
        screen = .input
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
