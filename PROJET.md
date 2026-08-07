# PROJET.md — TRIDENT / Master Word

## Ce qu'est cette application

Outil de scène pour un tour de mentalisme de Jérémie ("Master Word"). Webapp autonome en un seul fichier (`index.html`), hébergée sur GitHub Pages, installée sur l'écran d'accueil iPhone en PWA.

## Le tour (méthode)

1. Le spectateur pense à un **mot secret** ("master word") et le garde en tête.
2. Jeu d'association : on lui demande **trois mots** —
   - un mot de la **même catégorie** que son mot secret ;
   - « un mot intéressant » commençant par la **1ère lettre** du mot secret (la formulation pousse vers un mot long/recherché) ;
   - « un mot simple » commençant par la **2ème lettre** (pousse vers un mot court).
3. Il énonce ses trois mots **dans l'ordre qu'il veut** (pour masquer la méthode).
4. L'app déduit le mot secret par élimination : quel mot est la catégorie, quel préfixe de 2 lettres forment les deux autres, et quel mot courant de cette catégorie porte ce préfixe.

Exemple canonique : `tourbillon marteau oui` → marteau = catégorie (outil), préfixe T-O (tourbillon + oui) → **TOURNEVIS**.

## Architecture

- **Un seul fichier `index.html`** : HTML + CSS + JS vanilla, aucun build, aucun framework.
- **Appel direct navigateur → API Anthropic** (`claude-sonnet-5`, `temperature: 0`, headers `x-api-key` + `anthropic-version` + `anthropic-dangerous-direct-browser-access: true`).
- **Clé API** : uniquement dans le localStorage de l'appareil (écran RÉGLAGES, appui long sur "MASTER WORD"). Jamais dans le repo.
- **Le prompt `DEDUCTION_PROMPT`** demande un raisonnement bref puis un bloc JSON final `{candidats: [{mot, categorie, score}], alerte, question}`. Parsing tolérant (extraction du dernier bloc JSON) + appel de rattrapage si la réponse est tronquée.

## Écrans et modes

- **Saisie** (défaut) : champ unique pour les trois mots + bouton ● (reconnaissance vocale fr-FR, garde les 3 derniers mots pleins hors mots-outils, pour capter les mots en répétant naturellement ceux du spectateur).
- **Cycle** (résultat) : un candidat par écran, énorme, catégorie dessous, points de progression + rang + score en bas. Tap = suivant, tiers gauche = précédent. Dernier écran : la **question de départage** (formulée comme une perception de mentaliste) si le modèle hésite. Alerte éventuelle affichée sur le premier mot.
- **Mode Notes** (`?mode=notes`) : réplique d'Apple Notes (date du jour, clair/sombre auto). On tape les mots comme une note banale, « OK » lance la déduction en silence, **appui long** n'importe où bascule sur le cycle. « ‹ Notes » revient à l'écran normal.
- **Entrée par URL** : `?w=mot1,mot2,mot3` → déduction directe ; `?w=...&stealth=1` → déduction silencieuse derrière l'écran Notes (révélation par appui long). C'est l'API d'entrée des apps de capture existantes de Jérémie (dictée vocale, note iPhone, impression pad électronique), typiquement via Raccourcis iOS.
- **App iOS — démarrage sur le déguisement Notes** (2026-08-06, divergence voulue avec la webapp) : l'app native s'ouvre directement sur le faux éditeur Notes (cohérent avec son nom « Notes » sur l'écran d'accueil). **Le black mode est sorti de la navigation** : « ‹ Notes » est purement décoratif, et les réglages s'ouvrent par un **glissement à deux doigts vers le bas** (même geste pour en sortir). Le micro n'a donc plus d'accès dans l'interface (les captures passent par Raccourcis/`?w=`) ; l'écran cycle plein écran ne sert plus qu'aux déductions lancées par `?w=` sans stealth, et son ✕ ramène au faux Notes. Une erreur de déduction s'affiche dans la zone grise de révélation. La webapp, elle, garde la saisie comme écran par défaut.
- **App iOS — révélation dans la fausse note** (2026-08-06) : tout le tour se joue sans quitter le déguisement. « OK » déduit en silence ; signal « résultat prêt » ultra-discret : le « : » de l'heure devient « . » (17:35 → 17.35), et y reste tant qu'un résultat est disponible. Appui long → le candidat s'affiche en bas en gris (la couleur de la date, pour se fondre), avec sa position (ex. « pochette 2/4 »). Tap = suivant, tiers gauche = précédent, double tap = tout cacher. **Appui long sur le mot révélé = « prédiction »** : validation ✓ au journal ET la note entière est remplacée par ce mot (capitalisé) — l'app affiche alors une prédiction apparemment écrite à l'avance, montrable au spectateur. **Tap sur la ligne de date = remise à zéro complète** (note vide, résultat effacé, l'heure retrouve son « : ») pour enchaîner sur le spectateur suivant. L'écran cycle plein écran reste accessible via les déductions lancées du black mode.
- **Journal des tours** (2026-08-06) : chaque déduction est enregistrée en localStorage (`mw_journal`, 200 tours max : date, trio, candidats, alerte). Pendant le cycle, **appui long sur le mot affiché = « c'était lui »** (enregistre le mot validé + son rang, feedback discret par baisse d'opacité). Dans RÉGLAGES, section JOURNAL : toucher une entrée pour renseigner le mot réel si l'app l'a raté (s'il était en fait dans la liste, il est reclassé comme trouvé avec son rang), EXPORTER copie tout le journal en texte (à coller à Claude pour analyse), VIDER efface. C'est le carburant de la boucle d'amélioration : échecs réels → nouveaux trios de régression → patchs ciblés du prompt.

## Historique des affinages du prompt (chaque règle corrige un échec réel)

1. **Ordre aléatoire** : les 6 hypothèses de rôles sont évaluées (le spectateur donne ses mots dans l'ordre qu'il veut).
2. **Élimination croisée** = outil principal : une hypothèse est forte si elle produit un candidat courant ET que les concurrentes ne produisent rien.
3. **Catégories associatives** : matière (miroir→verre), usage, lieu, thème (avion→voyage) — pas seulement les taxonomies.
4. **Ressemblance = indice favorable** : le mot secret peut ressembler aux mots donnés (TOURNEVIS ← "tourbillon") ; seule l'identité exacte est exclue. [échec corrigé : tournevis pénalisé pour ressemblance]
5. **Concrétude décisive** : un mot rare/abstrait (mousson) est classé loin derrière tout candidat banal (tournevis), même si catégorie et préfixe collent. [échec corrigé : "mousson" classé premier]
6. **Vrai lien de catégorie exigé** pour chaque candidat listé : le préfixe seul ne suffit pas. [échec corrigé : "moto", "mouche" listés sans lien avec tourbillon]
7. **Proximité fine** pour classer dans une même hypothèse : tablette→téléphone avant tablette→télé. [échec corrigé : télé devant téléphone]
8. **Priors de présentation renforcés** : mot long/obscur = probablement 1ère lettre, mot court = probablement 2ème lettre — net avantage au classement, jamais éliminatoire.
9. **Balayage systématique** : pour chaque hypothèse vivante, TOUS les mots courants de la catégorie avec le préfixe, liste stable et reproductible (avec `temperature: 0`).
10. **Homophones de dictée vocale** (2026-08-05) : les mots venant souvent d'une reconnaissance vocale, le modèle évalue aussi les variantes homophones plus concrètes/courantes (flamand→flamant, vers→verre...) et signale la substitution dans `alerte`. Le préfixe est généralement inchangé, c'est la catégorie qui bascule. [échec corrigé : "flamant" entendu "flamand", catégorie oiseau perdue]
11. **Polysémie et pluriels** (2026-08-05) : pour chaque mot testé comme mot-catégorie, explorer TOUS ses sens courants (baguette = pain, baguettes chinoises, baguette magique...) au singulier comme au pluriel, sans s'ancrer sur le sens le plus fréquent. [échec corrigé : `flamant baguettes orange` → le modèle a lu baguette=pain, jamais exploré cat=baguettes (ustensiles) → FOURCHETTE manqué, BOUVREUIL proposé]

## Constats de la campagne de tests app native (2026-08-06)

Batterie rejouée dans l'app iOS (simulateur, prompt identique octet pour octet à la webapp) :

- **Pas de divergence native/web** : les différences observées entre plateformes se sont révélées être de la variance API (cf. ci-dessous).
- **`temperature: 0` ne garantit pas le déterminisme absolu** : `verre image mammouth` a donné VISON puis MIROIR sur deux exécutions natives identiques (la webapp donnait MIROIR). Les trios limites basculent. Conséquence : un échec isolé n'est pas une régression ; seuls les échecs reproductibles justifient un patch.
- **Échec reproductible identifié** : `philosophe "sac à main" oiseau` → POCHETTE en tête (2/2 exécutions), PORTEFEUILLE relégué voire absent, SOCRATE (nom propre, pourtant interdit) apparu une fois. À traiter par patch ciblé, validé sur plusieurs exécutions.
- `flamant baguettes orange` → BOA (1 exécution, non reclassifié flippant/reproductible).
- Passent : `tourbillon marteau oui` → TOURNEVIS (rang 1), `océan spatule citadelle` → COUTEAU (rang 1).
- Piste outillage : banc de test API (script rejouant la batterie N fois avec stats de rang par trio, clé fournie par variable d'environnement) avant tout prochain affinage du prompt.

## Note technique (2026-08-05)

`temperature: 0` avec repli automatique (fonction `doCall` dans `callAPI`) avait disparu du fichier déployé — restauré le 2026-08-05. Symptôme observé : deux essais du même trio donnaient des résultats différents.

## Trios de test de référence

Voir CLAUDE.md (tests de régression). Toujours les rejouer après un patch du prompt.

## App iOS native (`ios/`, créée le 2026-08-06)

Réplique SwiftUI exacte de la webapp, v1 complète : saisie + micro natif (SFSpeechRecognizer fr-FR, mêmes stopwords et logique "3 derniers mots"), cycle (mêmes gestes : tap, tiers gauche, appui long = validation journal), réglages (clé dans le **Keychain**), journal (même modèle et même format d'export), mode Notes déguisé (clair/sombre auto), URL scheme `trident://x?w=…` / `?mode=notes` / `?stealth=1` (mêmes noms de paramètres). Squelette CoreBluetooth PeekSmith présent mais jamais démarré en v1 (aucune popup Bluetooth). Keep-awake pendant le cycle (gain vs PWA). Nom affiché « Notes », icône sobre. Compte Apple gratuit : re-signer tous les 7 jours (Run dans Xcode), la veille de chaque prestation.

- Projet généré par XcodeGen : `cd ios && xcodegen` (project.yml versionné, xcodeproj non).
- **Le prompt Swift est injecté verbatim depuis index.html** par `ios/scripts/sync_prompt.py` (vérif : `--check`). index.html reste la source de vérité du prompt tant que les deux apps coexistent.
- Harness de logique pure (parsing tolérant, nettoyage, tokenizer, routeur) : `ios/scripts/harness.swift`.
- État au 2026-08-06 : phase A terminée (tout le code écrit, parse syntaxique OK, prompt et stopwords vérifiés octet pour octet). Phase B en attente d'installation d'Xcode : premier build, trios de régression, simulateur, iPhone réel. NB : les Command Line Tools seuls ont un bug de modulemap qui empêche `swiftc -typecheck` — vérifications complètes possibles uniquement avec Xcode.

## Roadmap

- **Court terme** : retours de perfs réelles → nouveaux trios récalcitrants → patchs ciblés du prompt.
- **App iOS native (décidée)** : URL scheme enregistré (in/out, x-callback), clé dans le Keychain, micro sans Safari, et **CoreBluetooth pour envoyer le cycle sur le PeekSmith** (impossible en web sur iOS, Safari ne supporte pas Web Bluetooth). Toute la logique (prompt, parsing, rattrapage, cycle) se transpose telle quelle.
- **Serveur + base de données (décidé 2026-08-06, hébergement choisi : Vercel)** : l'app native appellera un backend (`POST /deduire`, Vercel Functions + Postgres géré) qui porte le prompt et l'appel Anthropic (la clé quitte l'appareil), et une base qui remplace le journal localStorage. Objectifs : journal partagé entre appareils, injection automatique des cas validés dans le prompt (few-shot), trios de régression rejoués automatiquement à chaque patch, itération sur le prompt sans redéploiement App Store. Vigilance : garder dans l'app un mode secours en appel direct API (Keychain) si le serveur ne répond pas — un tour sur scène ne doit jamais dépendre d'un seul point de défaillance. Le format d'export du journal actuel servira de format de migration.
- **Piste si besoin d'exhaustivité garantie** : lexique français embarqué filtré par préfixe, que le modèle ne ferait que classer.
