# Backend Vercel — /api/deduire

Fonction serverless portant le prompt et l'appel Anthropic : la clé API quitte l'appareil. Le prompt est **généré** dans `_prompt.js` par `ios/scripts/sync_prompt.py` depuis `index.html` — ne jamais l'éditer à la main, relancer le script après chaque patch du prompt.

## Déploiement (une fois, ~10 minutes, par Jérémie)

1. [vercel.com](https://vercel.com) → Add New → Project → importer le repo GitHub `TRIDENT-APP`. Aucun réglage de build à changer (le site statique + `api/` sont détectés).
2. Dans le projet Vercel → Settings → Environment Variables, ajouter :
   - `ANTHROPIC_API_KEY` : ta clé Anthropic
   - `APP_TOKEN` : un jeton inventé, long et aléatoire (ex. sortie de `openssl rand -hex 24`) — c'est ce que l'app iOS présentera
3. Deploy. L'endpoint devient `https://<ton-projet>.vercel.app/api/deduire`

Si le plan Hobby refuse `maxDuration: 90` (vercel.json), redescendre à 60 — la déduction prend 15-40 s.

## Test

```bash
curl -s -X POST https://<ton-projet>.vercel.app/api/deduire \
  -H "content-type: application/json" \
  -H "x-app-token: <ton APP_TOKEN>" \
  -d '{"mots":"tourbillon marteau oui"}'
```

Attendu : un JSON `{"candidats":[{"mot":"tournevis",...}],...}`.

## Étape 2 (à venir)

- Base Postgres (Vercel Storage) pour le journal des tours partagé entre appareils.
- Bascule de l'app iOS sur cet endpoint, avec repli automatique en appel direct (Keychain) si le serveur ne répond pas — un tour sur scène ne dépend jamais d'un seul point de défaillance.
- Injection des cas validés dans le prompt (few-shot) et trios de régression rejoués à chaque patch.
