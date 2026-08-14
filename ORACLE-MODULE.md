# ORACLE-MODULE.md — intégration de L'Oracle dans le hub

Doc de passation pour Claude Code. À poser à la racine du projet, à côté de `CLAUDE-HUB-INTEGRATION.md`.
Fichiers de référence à fournir en même temps : `loracle-v4.jsx` (prototype React qui tourne — **croquis, pas architecture**) et `oracle-gauntlet-prompt.md` (boucle qualité).

> **Instruction courte à donner à Claude Code :**
> *« Lis ORACLE-MODULE.md et CLAUDE-HUB-INTEGRATION.md, puis intègre L'Oracle comme nouveau module du hub `enigma-remote.html`. Le prototype `loracle-v4.jsx` contient la logique et les tables de données à porter en vanilla JS. »*

---

## 1. Ce qu'est L'Oracle

Le module de **readings** du hub. Il reçoit en secret des bribes d'information sur un spectateur et rend au performeur, en quelques secondes, un reading si personnel que le spectateur croit qu'on lui a volé son journal intime.

Différence avec les autres modules du hub : Enigma, Anagrammes, Date de naissance et PIN **calculent une réponse exacte**. L'Oracle, lui, **fabrique du discours**. C'est le seul module qui appelle un LLM, et le seul dont la sortie est un texte à dire plutôt qu'une information à révéler.

Il sert deux familles de tours :
- **Q&A act** — billets remplis par le public, révélations en one-ahead.
- **Readings** — tarot, numérologie, astro, lecture de main, lecture de prénom, profil de naissance.

Même moteur pour tout : seul l'habillage change.

---

## 2. Le principe : trois couches

C'est le cœur du produit. Ne pas l'aplatir.

**Couche 1 — le socle invisible.** D'où viennent les vrais hits. À partir d'une date de naissance, d'un prénom et d'une question, on déduit : cohorte générationnelle (souvenirs marquants selon l'année, contexte français), effet d'âge relatif (position dans l'année scolaire, coupure au 31 décembre), stade d'Erikson selon l'âge, fenêtres de transition de Levinson (28-33, 40-45, 50+), retour de Saturne (~29 ans), sociologie du prénom en France (âge probable, milieu d'origine), événements de vie statistiques pour cet âge, et ce que la formulation de la question trahit du manque qui la dicte.

**Couche 2 — l'habillage.** Tout ce que la couche 1 a trouvé est retraduit dans le vocabulaire de l'art choisi. Le spectateur doit croire que ça vient des cartes, des chiffres ou de sa main. Le tarot dit « la Maison Dieu en position passé » ; le moteur, lui, sait qu'il parle de la crise de 2008 prise à 26 ans.

**Couche 3 — la formulation.** Rainbow ruse, vanishing negative, fine flattery, hit management (formuler pour qu'un « non » se retourne en hit), effet de récence (finir sur le hit le plus fort). Français parlé, vouvoiement, phrases prêtes à dire.

---

## 3. Deux sorties, deux usages

**Le script** — texte complet (ouverture / corps / chute), pour préparer en coulisses ou lire au prompteur.

**La partition** — l'invention centrale. Le performeur a appris par cœur un répertoire de scripts codés. L'app ne lui envoie plus que la séquence de codes + les mots-clés de personnalisation :

```
O3  HK:démission
LV40  CO:france98
VN:prudente
TA:pendu>soleil
CH:septembre
```

Cinq lignes = tout le reading. Le texte est dans sa tête, le mot-clé fait le sur-mesure, et entre les codes il improvise. Modèle mental : une grille d'accords de jazz.

**Contrainte de format non négociable : 14 caractères par ligne maximum.** C'est la largeur de l'écran PeekSmith. Toute la partition doit pouvoir partir telle quelle en BLE.

### Répertoire des codes

| Code | Rôle |
|---|---|
| O1 / O3 | Ouvertures (énergie / question cachée) |
| HK | Hook sur la vraie préoccupation |
| RR | Rainbow ruse |
| VN | Vanishing negative |
| FF | Flatterie fine |
| PO | Push-off vers un proche |
| SL | Énumération jusqu'au hit |
| FW | Fourchette double-gagnante |
| CO | Souvenir de cohorte générationnelle |
| RA | Effet d'âge relatif scolaire |
| LV30 / LV40 / LV50 | Fenêtres de transition |
| SR | Retour de Saturne (~29 ans) |
| ERG | Générativité (40+) |
| PR | Lecture du prénom |
| TA / NU / AS | Tarot / numérologie / astro |
| BR | Transition, respiration |
| CH | Chute finale |

Les textes complets de chaque code sont dans `loracle-v4.jsx` (constante `REPERTOIRE`). Ils sont éditables par le performeur et le répertoire est extensible : de nouvelles techniques deviendront de nouveaux codes.

---

## 4. Entrées

**Aujourd'hui — saisie manuelle**, avec un mini-langage tapable en quatre secondes :

```
prenom JJMMAA lettre± /détail
marie 270482 t+ /veut démissionner
```

Thèmes : `a` amour · `t` travail · `ar` argent · `s` santé · `f` famille · `e` enfants · `d` deuil · `v` voyage · `j` conflit · `x` autre.
Modificateurs : `+` espère un oui · `−` craint la réponse · `?` doit trancher.
Parser complet : `parseCode()` dans le prototype. Décodage affiché en direct pendant la frappe.

**Mode saisie aveugle** — écran noir, texte rouge très sombre, vibration à chaque frappe, toute la moitié basse de l'écran en bouton VALIDER. À la validation : grosse vibration, flash du prénom une seconde, et **génération IA lancée en arrière-plan** pendant que le performeur continue. La fiche arrive enrichie toute seule dans la file.

**Demain — ingestion par API.** C'est la cible. Les infos arriveront directement des outils de capture existants : Plum (impression pad), Inject, Goo, Elips, WikiTest, et les apps de capture perso (voix, note iPhone). Prévoir un point d'entrée unique — une fonction `oracleIngest(payload)` exposée globalement, appelable par le pont natif comme par une future webview — qui crée la fiche et déclenche l'enrichissement. Ne pas coupler la saisie manuelle au reste du moteur.

**Tirage tarot imposé.** Le spectateur tire trois cartes d'un jeu marqué. Le performeur lit les marques et saisit les trois arcanes dans une grille des 22 (trois taps), **avant de les retourner**. L'IA interprète exactement ces cartes-là, croisées avec le profil, et **formule au futur de la vision** — « la première carte parlera de… ». Le retournement physique arrive après et confirme mot pour mot. C'est l'inversion qui fait le miracle : les cartes ne sont pas interprétées, elles sont prédites. Le picker doit être accessible depuis la file **et** depuis le mode scène, dans la couleur du filtre actif.

---

## 5. Ce qui se calcule en local, sans réseau

Instantané, affiché dès la frappe de la date, et jamais dépendant d'un appel API :

- Signe du zodiaque + élément + planète + traits + face d'ombre (12 signes, table `ZODIAC_DATA`)
- Âge exact, signe chinois
- Chemin de vie numérologique, avec maîtres nombres 11 / 22 / 33
- Année personnelle (recalculée sur l'année courante)

Les 22 arcanes majeurs avec leurs significations authentiques sont également en dur (table `TAROT`). Le LLM ne sert jamais à retrouver une donnée qui peut être calculée ou tabulée — seulement à composer.

---

## 6. Écrans

**Saisie** — champ vrac ou code, décodage live, ligne de profil calculée en local, sélecteur d'habillage (7), sélecteur de modèle de billet, boutons : générer (IA) · brut · aveugle.

**File** — la queue one-ahead. La fiche du haut est celle à révéler maintenant, visuellement distincte. Fiche dépliée : profil complet, tirage, partition, script, et les actions (changer d'habillage et régénérer, tirage, marquer révélée, supprimer).

**Modèles** — les gabarits de billets, éditables. Trois par défaut : Standard (vague, ~80 % du public), Précis (les bombes, ~15 %), Nucléaire (le closer, ~5 %). **C'est un layer de deception, pas de la config** : tout le monde croit avoir eu la même question, et quand le performeur révèle le contenu d'une poche ou les derniers chiffres d'une carte bancaire, la salle hallucine. À garder tel quel dans l'intégration.

**Codes** — le répertoire, à apprendre par cœur.

**Mode scène** — noir absolu (`#000000`, pixels OLED éteints), quatre filtres de couleur (rouge par défaut pour la vision nocturne), wake lock, haptiques. Trois niveaux d'affichage cyclables au tap : *glance* (prénom seul, énorme) → *standard* (prénom, profil, résumé, cartes, partition) → *script* (bloc par bloc, en prompteur). Navigation gestuelle : swipe droite = révélée et suivante, swipe gauche = précédente, swipe vertical = niveau ou avance dans le script. Sortie par appui long dans le coin haut-gauche — jamais par un bouton atteignable par accident. Barre du bas qui s'efface seule après quatre secondes.

---

## 7. Contraintes de scène

Elles priment sur l'esthétique.

- Lisible en moins d'une seconde et demie, d'un regard oblique, à 3 % de luminosité.
- Toute saisie possible sans regarder l'écran, confirmée par haptique.
- Rien qui puisse se déclencher par accident pendant une performance.
- Rien qui ressemble à une app si un spectateur jette un œil.
- Aucune latence bloquante : la génération IA tourne en arrière-plan, jamais en modal qui fige l'écran.
- La perte de réseau ne doit jamais laisser le performeur sans rien — le profil local reste affiché.

---

## 8. Intégration technique dans le hub

- Nouveau module du hub, mêmes conventions que les autres (vanilla JS, pas de framework — porter la logique React du prototype).
- Persistance : `localStorage`, clés préfixées `oracle:` (séance en cours, modèles de billets, répertoire édité). La séance doit survivre à un crash en plein show.
- Pont natif (voir `CLAUDE-HUB-INTEGRATION.md`) : `haptic` pour toutes les confirmations de saisie aveugle, `psConnect`/`psSend` pour envoyer la partition au PeekSmith, `psButton`/`remoteKey` pour avancer dans la file ou le script **sans toucher le téléphone** — c'est le canal le plus discret, à câbler en priorité. Repli web automatique si le pont est absent.
- Appel LLM : même schéma que Master Word V2 — clé API stockée uniquement sur l'appareil, jamais dans le repo. Le prototype utilise l'API Messages d'Anthropic avec sortie JSON stricte (voir `aiEnrich()`) ; parser défensivement, et prévoir le cas d'échec (fiche ajoutée en brut, régénération possible depuis la file).
- Aucune donnée spectateur ne doit persister au-delà de la séance : bouton d'effacement complet, et effacement à la fermeture de la séance.

---

## 9. Hors périmètre pour l'instant

Connecteurs entrants Plum / Inject / Goo / Elips / WikiTest (poser le point d'entrée `oracleIngest`, pas les intégrations), app Apple Watch, oreillette TTS, ingestion des PDF de référence à venir.

---

## 10. La barre de qualité

Le vrai test n'est pas « est-ce que le code tourne ». C'est : **un spectateur reconnaît-il son reading parmi deux ?** La méthode complète (panel de spectateurs fictifs à biographie secrète, A/B en aveugle contre un leurre Barnum ou le reading d'un autre spectateur, boucle builder/critique) est dans `oracle-gauntlet-prompt.md`. Si le Barnum gagne un round, c'est que le moteur fait du Barnum — et c'est ça qu'il faut corriger, pas l'interface.
