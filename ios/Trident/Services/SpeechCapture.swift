import Foundation
import Combine
import AVFoundation
import Speech

/// Reconnaissance vocale continue fr-FR — équivalent du mode voix de la webapp.
/// Publie en continu les 3 derniers mots pleins (hors mots-outils) via SpeechTokenizer.
/// Les permissions (micro + reconnaissance) sont demandées au PREMIER tap sur ●,
/// jamais au lancement (discrétion scénique : zéro popup à l'ouverture).
/// SFSpeechRecognizer limite chaque requête à ~1 min : la session est relancée
/// automatiquement à 55 s en conservant le transcript accumulé.
final class SpeechCapture: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var lastWords = ""
    /// Transcript brut cumulé de la session (partiels inclus) — consommé par le hub,
    /// qui fait son propre parsing (mot + trigger). `lastWords` reste pour Trident.
    @Published var rawTranscript = ""
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var accumulated = "" // transcript des sessions précédentes (redémarrages)
    private var current = ""     // transcript de la session en cours
    private var restartTimer: Timer?
    private var generation = 0   // invalide les callbacks des sessions périmées

    func toggle() { isListening ? stop() : start() }

    func start() {
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            DispatchQueue.main.async {
                guard let self else { return }
                guard auth == .authorized else {
                    self.errorMessage = "Reconnaissance vocale non autorisée."
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    DispatchQueue.main.async {
                        guard ok else { self.errorMessage = "Accès micro refusé."; return }
                        self.beginListening()
                    }
                }
            }
        }
    }

    private func beginListening() {
        guard !isListening else { return }
        let rec = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
        guard let rec, rec.isAvailable else {
            errorMessage = "Reconnaissance vocale non disponible."
            return
        }
        recognizer = rec
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            accumulated = ""
            lastWords = ""
            rawTranscript = ""
            isListening = true
            try startRecognitionSession()
        } catch {
            isListening = false
            errorMessage = "Micro indisponible."
        }
    }

    private func startRecognitionSession() throws {
        generation += 1
        let gen = generation
        current = ""

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.isListening, gen == self.generation else { return }
                if let result {
                    self.current = result.bestTranscription.formattedString
                    self.rawTranscript = (self.accumulated + " " + self.current).trimmingCharacters(in: .whitespaces)
                    self.lastWords = SpeechTokenizer.lastFullWords(self.rawTranscript)
                    if result.isFinal { self.rollSession() }
                } else if error != nil {
                    self.rollSession()
                }
            }
        }

        // redémarrage préventif avant la limite ~1 min de SFSpeechRecognizer
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: 55, repeats: false) { [weak self] _ in
            self?.request?.endAudio() // force isFinal → rollSession
        }
    }

    /// Fin d'une requête (limite de durée, silence ou erreur) : on enchaîne une
    /// nouvelle session sans perdre le transcript déjà capté.
    private func rollSession() {
        guard isListening else { return }
        accumulated = (accumulated + " " + current).trimmingCharacters(in: .whitespaces)
        teardownSession()
        do { try startRecognitionSession() }
        catch { stop() }
    }

    func stop() {
        isListening = false
        generation += 1 // périme les callbacks en vol
        teardownSession()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func teardownSession() {
        restartTimer?.invalidate()
        restartTimer = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
}
