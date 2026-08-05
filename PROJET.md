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

## Note technique (2026-08-05)

`temperature: 0` avec repli automatique (fonction `doCall` dans `callAPI`) avait disparu du fichier déployé — restauré le 2026-08-05. Symptôme observé : deux essais du même trio donnaient des résultats différents.

## Trios de test de référence

Voir CLAUDE.md (tests de régression). Toujours les rejouer après un patch du prompt.

## Roadmap

- **Court terme** : retours de perfs réelles → nouveaux trios récalcitrants → patchs ciblés du prompt.
- **App iOS native (décidée)** : URL scheme enregistré (in/out, x-callback), clé dans le Keychain, micro sans Safari, et **CoreBluetooth pour envoyer le cycle sur le PeekSmith** (impossible en web sur iOS, Safari ne supporte pas Web Bluetooth). Toute la logique (prompt, parsing, rattrapage, cycle) se transpose telle quelle.
- **Piste si besoin d'exhaustivité garantie** : lexique français embarqué filtré par préfixe, que le modèle ne ferait que classer.
