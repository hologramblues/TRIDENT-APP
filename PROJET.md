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

## Fusion Hub + Trident (2026-08-08)

L'app iOS est devenue le **hub unique** des outils de scène :

- `enigma-remote.html` (racine du repo, source de vérité unique) : webapp autonome multi-effets (Enigma, Prénoms, PIN, Anagrammes, Date de naissance, Converge, fallback vocal, PeekSmith), embarquée dans l'app en ressource et affichée dans une **WKWebView persistante** (l'état du hub survit aux allers-retours). Pont natif `hub` (voir `CLAUDE-HUB-INTEGRATION.md`) : haptique, openURL, PeekSmith BLE, reconnaissance vocale (transcript brut cumulé), et `openTrident`.
- **Entrée de l'app : faux écran de verrouillage iOS** (« Saisissez le code », secousse si code inconnu). Code `111111` → hub ; code `222222` → faux Notes (Trident). Codes modifiables dans RÉGLAGES, persistants. Les URL `?w=`/`stealth`/`mode=notes` court-circuitent le verrou (apps de capture).
- **Trident reste 100 % natif** : tuile « Trident » sur l'accueil du hub → faux Notes ; retour par RÉGLAGES → bouton HUB.
- **PeekSmith réel** (UUIDs du brief hub) : scan par nom `PeekSmith`, HM-10 `FFE0`/`FFE1` + service alternatif, boutons `isb0/1/2` → 0=passer 1=OUI 2=NON, service partagé hub/Trident, instancié seulement au premier `psConnect` (pas de popup Bluetooth au lancement).
- **DOB phase 2 — année en faux code** (2026-08-08) : après la date trouvée, bouton ANNÉE sur l'écran peek → faux « Enter Passcode ». L'année de naissance tapée nonchalamment comme un code (+ 2 chiffres de bourrage, ex. 198200) révèle sous les points, en gris discret : jour de la semaine de naissance + jours écoulés depuis (vérifiable par Siri). Glissement 1 doigt bas = retour au peek.
- **Effet Cryptogramme** (2026-08-12) : divination propless d'un code 3 chiffres d'après la méthode 3CSC de Fraser Parker (manuscrit possédé par Jérémie ; l'app n'encode que l'arbre de décision, les formulations de scène restent à écrire par lui). Tuile sur l'accueil → écran perf : zones OUI/NON invisibles pour les deux « touches » (9 puis 1), aboutit à l'issue unique (envoyée au PeekSmith) ou à la paire recto/verso pour la sortie écrite à deux faces. Undo par glissement horizontal (2 niveaux), 1 doigt bas = accueil, remote A/B/D. Consigne visible en mode guide uniquement (elle contient de la méthode) ; seules les issues s'affichent en gris discret en perf. Décision : **rester à 3 chiffres** — l'espace des suites contraintes triple à 4, la pêche s'allonge, et la justification « cryptogramme de carte » ne vaut que pour 3 ; pour du 4 chiffres, module PIN existant ou future variante « Reverse Guess » (code forcé, extensible).
- **Effet Carte pensée** (2026-08-12) : réduction de choix psychologique, conception originale (tendances du « pense à une carte » = savoir commun de la littérature, aucun script commercial repris). Le cadrage parlé retire figures et as, pousse vers une valeur médiane impaire et vers le rouge : le pool de 16 s'effondre à 1-3 cartes. Deux modes depuis une grille : **FORCE** (cible 7 cœur, prédiction posée avant, sortie écrite recto/verso — repli 7 pique/7 trèfle si la couleur rate) et **DIVINATION** (trois perceptions affirmées — rouge, le 7, la famille — qui filtrent le pool ; candidats classés par poids, tap pour défiler, envoi PeekSmith `carte (n)` puis `= carte`). Un filtre qui viderait le pool est ignoré : le performeur n'est jamais sans issue. Undo par glissement horizontal (historique complet), 1 doigt bas = retour au choix de mode, remote A/B/C/D. Scripts en mode guide uniquement, candidats en gris discret en perf.
- À tester sur iPhone réel : fallback vocal du hub (transcript via pont), CORS du fetch API du hub depuis `file://` (repli prévu : cmd de pont), clavier dans les panels du hub, PeekSmith avec le matériel.

## Écrans et modes

- **Saisie** (défaut) : champ unique pour les trois mots + bouton ● (reconnaissance vocale fr-FR, garde les 3 derniers mots pleins hors mots-outils, pour capter les mots en répétant naturellement ceux du spectateur).
- **Cycle** (résultat) : un candidat par écran, énorme, catégorie dessous, points de progression + rang + score en bas. Tap = suivant, tiers gauche = précédent. Dernier écran : la **question de départage** (formulée comme une perception de mentaliste) si le modèle hésite. Alerte éventuelle affichée sur le premier mot.
- **Mode Notes** (`?mode=notes`) : réplique d'Apple Notes (date du jour, clair/sombre auto). On tape les mots comme une note banale, « OK » lance la déduction en silence, **appui long** n'importe où bascule sur le cycle. « ‹ Notes » revient à l'écran normal.
- **Entrée par URL** : `?w=mot1,mot2,mot3` → déduction directe ; `?w=...&stealth=1` → déduction silencieuse derrière l'écran Notes (révélation par appui long). C'est l'API d'entrée des apps de capture existantes de Jérémie (dictée vocale, note iPhone, impression pad électronique), typiquement via Raccourcis iOS.
- **App iOS — démarrage sur le déguisement Notes** (2026-08-06, divergence voulue avec la webapp) : l'app native s'ouvre directement sur le faux éditeur Notes (cohérent avec son nom « Notes » sur l'écran d'accueil). **Le black mode est sorti de la navigation** : « ‹ Notes » est purement décoratif, et les réglages s'ouvrent par un **double tap sur « Notes »** dans la barre du haut ; retour par **double tap sur « RÉGLAGES »**. (Essais précédents abandonnés : glissement 2 doigts = défilement de la note, 3 doigts = conflit avec les gestes d'édition iOS, triple tap global = collisions avec le tap de date.) Le micro n'a donc plus d'accès dans l'interface (les captures passent par Raccourcis/`?w=`) ; l'écran cycle plein écran ne sert plus qu'aux déductions lancées par `?w=` sans stealth, et son ✕ ramène au faux Notes. Une erreur de déduction s'affiche dans la zone grise de révélation. La webapp, elle, garde la saisie comme écran par défaut.
- **App iOS — révélation dans la fausse note** (2026-08-06) : tout le tour se joue sans quitter le déguisement. « OK » déduit en silence ; signal « résultat prêt » ultra-discret : le « : » de l'heure devient « . » (17:35 → 17.35), et y reste tant qu'un résultat est disponible. Appui long → le candidat s'affiche en bas en gris (la couleur de la date, pour se fondre), avec sa position (ex. « pochette 2/4 »). Tap = suivant, tiers gauche = précédent, double tap = tout cacher. **Appui long sur le mot révélé = « prédiction »** : validation ✓ au journal ET la note entière est remplacée par ce mot (capitalisé) — l'app affiche alors une prédiction apparemment écrite à l'avance, montrable au spectateur. **Triple tap sur la ligne de date = remise à zéro complète** (note vide, résultat effacé, l'heure retrouve son « : » et l'heure réelle) pour enchaîner sur le spectateur suivant — triple pour éviter l'effacement accidentel si un spectateur manipule la note. **Antidatage réglable** dans RÉGLAGES (valeur + MIN/H, persistant, défaut 5 min) : la note-prédiction est datée de X minutes/heures en arrière, avec un « : » normal puisque le spectateur peut la lire. L'écran cycle plein écran reste accessible via les déductions lancées du black mode.
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
12. **Banalité absolue, noms communs, départage par usage** (2026-08-12, validé au banc en boucle Gauntlet — 2 tours retenus, 1 tour annulé) : (a) hiérarchie absolue — la banalité écrase les indices de présentation (bouvreuil/fougasse ne battent jamais fourchette) ; (b) noms communs uniquement, noms propres exclus (Socrate) ; (c) entre candidats de même catégorie ou entre sens d'un même mot-catégorie, l'objet le plus quotidien passe devant (portefeuille avant pochette, fourchette avant fougasse). Mesures : batterie 10/18 (56 %) → 14/18 (78 %) ; PORTEFEUILLE 0/3→2/3, FOURCHETTE (`flamant baguettes orange`) 0/3→3/3. Le tour 3 (« représenter chaque sens dans le JSON ») a été ANNULÉ après mesure en régression (PORTEFEUILLE 0/3, têtes paon/boa) — leçon : forcer l'exhaustivité réarme les lectures concurrentes. Au même moment : **max_tokens 2000→8000 partout** (le raisonnement interne du modèle consommait le budget → réponses vides/coupées, cause des « Réponse sans candidats »). **Limite connue** : `flamand baguette orange` (double correction homophone + sens minoritaire) reste à 0/3 — à reprendre par prétraitement code ou few-shot serveur, PAS en chargeant encore le prompt.

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
