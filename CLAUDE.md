# CLAUDE.md — TRIDENT-APP

## Règles de travail

- **Après chaque modification validée : commit avec un message clair (en français) et push sur `main`.** Le site est servi par GitHub Pages depuis `main` / racine — chaque push déploie en production (~1 min).
- Travailler en français (code commenté en français, messages de commit en français).
- Lire `PROJET.md` en début de session pour le contexte complet de l'application et l'historique des décisions.
- Tenir `PROJET.md` à jour : toute évolution notable (patch du prompt de déduction, nouveau mode, changement de modèle API) doit y être consignée dans la section Historique.

## Structure

- `index.html` — TOUTE l'application (HTML + CSS + JS dans un seul fichier, c'est voulu : simple à déployer, pas de build). Ne pas introduire de bundler, de framework ou de fichiers séparés sans demande explicite.
- `CLAUDE.md` — ce fichier.
- `PROJET.md` — état du projet, fonctionnement du tour, logique de déduction, roadmap.

## Points critiques — à ne JAMAIS casser

1. **Aucune clé API dans le repo.** La clé Anthropic vit uniquement dans le localStorage de l'appareil (écran RÉGLAGES, accessible par appui long sur "MASTER WORD"). Ne jamais coder une clé en dur, même pour tester.
2. **Le prompt de déduction (`DEDUCTION_PROMPT`)** est le cœur de l'app, affiné par itérations sur des cas réels. Ne pas le reformuler, le raccourcir ou le "nettoyer" spontanément : chaque phrase corrige un échec de test précis (voir PROJET.md). Le modifier uniquement sur demande, par ajouts ciblés.
3. **Le parsing tolérant** : le modèle raisonne avant le JSON final ; l'extraction remonte depuis `"candidats"` vers l'accolade ouvrante. En cas d'échec, un appel de rattrapage demande uniquement le JSON. Conserver ce mécanisme.
4. **`temperature: 0`** sur l'appel API (sortie stable et reproductible), avec repli automatique sans le paramètre si le modèle le refuse. Conserver.
5. **Les paramètres d'URL** (`?w=`, `?mode=notes`, `?stealth=1`) sont l'API d'entrée des apps de capture externes de Jérémie. Ne pas changer leurs noms ni leur comportement sans demande.
6. **Discrétion scénique** : l'app est un outil de mentalisme utilisé en conditions réelles. Pas de logos, de textes "IA", de spinners voyants ou d'éléments qui trahissent la nature de l'app si un spectateur aperçoit l'écran.

## Modèle API

- Actuel : `claude-sonnet-5` (une seule occurrence dans `callAPI`, fonction `doCall`).
- Headers requis pour l'appel navigateur : `x-api-key`, `anthropic-version: 2023-06-01`, `anthropic-dangerous-direct-browser-access: true`.

## Tests de régression

Après toute modification du prompt ou du parsing, vérifier ces trios de référence (entrée → premier mot attendu) :

- `tourbillon marteau oui` → TOURNEVIS (cat=marteau, préfixe T-O)
- `verre image mammouth` → MIROIR (cat=verre par matière, préfixe M-I)
- `océan spatule citadelle` → COUTEAU (cat=spatule, préfixe C-O)
- `philosophe "sac à main" oiseau` → PORTEFEUILLE (cat=sac à main, préfixe P-O)

Et vérifier la stabilité : deux exécutions du même trio doivent donner la même liste.
