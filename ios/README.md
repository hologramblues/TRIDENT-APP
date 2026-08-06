# Trident — app iOS native

Portage SwiftUI de la webapp `../index.html` (référence fonctionnelle exacte). Voir `../PROJET.md` et `../CLAUDE.md` pour la méthode du tour et les points à ne jamais casser.

## Prérequis

- Xcode installé depuis l'App Store, puis :

```bash
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -runFirstLaunch
```

- XcodeGen : `brew install xcodegen`

## Générer et ouvrir le projet

```bash
cd ios
xcodegen
open Trident.xcodeproj
```

Le `.xcodeproj` est régénérable, seul `project.yml` est versionné. Après chaque `xcodegen`, re-sélectionner l'équipe personnelle dans Signing & Capabilities (ou ajouter `DEVELOPMENT_TEAM` dans project.yml une fois l'ID connu).

## Installer sur l'iPhone (compte Apple gratuit)

1. Brancher l'iPhone, le choisir comme destination, Run.
2. Sur l'iPhone : Réglages → Général → VPN et gestion de l'appareil → faire confiance au certificat développeur.
3. **L'app expire tous les 7 jours** : relancer Run depuis Xcode pour re-signer. À faire systématiquement la veille d'une prestation.

## Tests de régression

Après tout patch du prompt ou du parsing : rejouer les trios listés dans `../CLAUDE.md` (deux fois chacun — les listes doivent être identiques).

Vérifications automatiques (nécessitent Xcode installé — les Command Line Tools seuls ont un bug de modulemap qui bloque `swiftc -typecheck`) :

```bash
cd ios && python3 scripts/sync_prompt.py --check
```

```bash
cd ios && xcrun swiftc -o /tmp/harness Trident/Models/DeductionResult.swift Trident/Services/DeductionService.swift Trident/Services/URLRouter.swift Trident/Services/SpeechTokenizer.swift scripts/harness.swift && /tmp/harness
```

`sync_prompt.py` (sans `--check`) réinjecte le prompt depuis `../index.html` — à relancer après chaque patch de `DEDUCTION_PROMPT` tant que la webapp reste la source de vérité.

URL scheme (mêmes paramètres que la webapp) :

```bash
xcrun simctl openurl booted "trident://x?w=ocean,spatule,citadelle"
```

Formes supportées : `trident://x?w=a,b,c` · `trident://x?w=a,b,c&stealth=1` · `trident://x?mode=notes`
