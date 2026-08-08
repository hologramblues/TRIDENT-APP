# Intégration du Remote Hub (mentalisme) dans l'app iOS

## Vue d'ensemble

`enigma-remote.html` est une webapp autonome (HTML/CSS/JS, un seul fichier, zéro dépendance)
qui contient tous les moteurs : Enigma binaire, Prénoms, PIN, Anagrammes
(arbres JTA, générateurs TA/Progressif/Frontloaded/Commutatif, scans, entraînement),
Date de naissance (numérologie double), Converge, fallback vocal, out URL, PeekSmith.

**Stratégie d'intégration : WKWebView + pont natif.** Le fichier HTML reste la source
de vérité unique. Il détecte automatiquement le pont
(`window.webkit.messageHandlers.hub`) : présent → il route BLE/haptique/voix/URL
vers le natif ; absent → il retombe sur les API web (le fichier reste testable
dans un navigateur).

## Côté Swift — checklist

1. **WKWebView**
   - Charger le fichier depuis le bundle : `webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())`.
   - `WKWebViewConfiguration` : ajouter un `WKScriptMessageHandler` nommé **`hub`**.
   - `websiteDataStore = .default()` (le hub persiste listes/arbres/réglages en `localStorage` — ne pas utiliser `.nonPersistent()`).
   - Désactiver le rebond/zoom : `scrollView.isScrollEnabled = false`, `scrollView.bounces = false` (les gestes internes du hub gèrent tout).
   - Fond noir, `isOpaque = false`, ignorer safe area (le hub gère `env(safe-area-inset-*)`).
   - Clavier matériel / remote HID : les événements arrivent nativement dans la WKWebView, rien à faire. Si l'app capte les touches ailleurs, les relayer via `remoteKey` (voir plus bas).

2. **Messages JS → natif** (reçus dans `userContentController(_:didReceive:)`, `message.body` est un dictionnaire avec `cmd`) :

   | cmd | payload | action Swift |
   |---|---|---|
   | `haptic` | `pattern: [Int]` (ms, alternance vibration/pause) | `UIImpactFeedbackGenerator` (léger si pattern court, medium sinon) ou CoreHaptics pour respecter le pattern |
   | `psConnect` | — | scanner/connecter le PeekSmith en CoreBluetooth (voir §3) |
   | `psSend` | `text: String` | écrire le texte sur la characteristic du PeekSmith |
   | `speechStart` | `lang: String` ("fr-FR") | démarrer `SFSpeechRecognizer` + `AVAudioEngine`, résultats partiels activés |
   | `speechStop` | — | arrêter la reco et l'audio engine |
   | `openURL` | `url: String` | `UIApplication.shared.open(url)` — gère https ET les schemes custom (shortcuts://, etc.) |

3. **PeekSmith 3 (CoreBluetooth)**
   - Scan par préfixe de nom : `PeekSmith`.
   - Service principal HM-10 : `FFE0`, characteristic données : `FFE1` (notify + write / writeWithoutResponse).
   - Service alternatif : `8D53DC1D-1DB7-4CD3-868B-8A527460AA84` (prendre la char notify pour lire, la char write pour écrire).
   - Notifications entrantes (UTF-8) : contiennent `isb0,click` / `isb1,click` / `isb2,click` (boutons du PS).
   - Écriture : texte UTF-8 brut (le hub envoie p.ex. `E (7)` ou `= SCORPION`).

4. **Messages natif → JS** : appeler
   `webView.evaluateJavaScript("window.hubFromNative(\(json))")` avec :

   | type | payload | quand |
   |---|---|---|
   | `psStatus` | `connected: Bool, name: String?` | à chaque changement d'état BLE |
   | `psButton` | `btn: 0\|1\|2` | bouton PS pressé (isb0/1/2 → 0=passer, 1=OUI, 2=NON) |
   | `speech` | `text: String` | transcript **cumulé** de la session (partiels inclus) — le hub parse mot+trigger lui-même |
   | `speechError` | `error: String` | erreur/refus micro |
   | `remoteKey` | `key: String` ("1", "a", "ArrowLeft"…) | optionnel, si l'app relaie une remote captée ailleurs |

5. **Permissions Info.plist** : `NSBluetoothAlwaysUsageDescription`,
   `NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`.

6. **Extension future (déjà prévue côté hub)** : la remote nRF52840 custom peut être
   gérée par le même CBCentralManager ; relayer ses appuis via `remoteKey` (chiffres
   "1"/"2"/"3"/"0") — le hub les traite comme des touches (A/B/confirm/effacer).

## Conventions côté hub (si Claude Code doit modifier le JS)

- Un seul fichier, vanilla JS, pas de framework. Fonctions déclarées (hoisting utilisé).
- Persistance : `localStorage`, clés `er_lists`, `er_anag`, `er_assoc`, `er_map`, `er_opts`.
- Arbres anagrammes : sérialisation préordre compatible permalinks JTA
  (`lettre, branche NON, branche OUI`, `.` = non développé), champ `tree` de chaque liste ;
  set commutatif dans `commut`.
- Écrans = divs `.screen`, navigation par `show(id)` ; écrans de performance listés
  dans `perfIds` (guide + gestes). Gestes : 2 doigts bas = accueil, 1 doigt bas = écran
  précédent, horizontal = undo.
- Normalisation des mots : `norm()` (majuscules, accents retirés, A-Z uniquement).
- Ne jamais afficher d'information de méthode hors mode guide (`store.opts.guide`).
