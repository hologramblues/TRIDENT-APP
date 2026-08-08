// ————————————————————— POST /api/deduire —————————————————————
// Backend de déduction (Vercel Function). Transposition EXACTE de la logique
// de la webapp : prompt verbatim (api/_prompt.js, synchronisé depuis index.html),
// temperature 0 avec repli, parsing tolérant, appel de rattrapage.
//
// Entrée  : { "mots": "tourbillon marteau oui" } + header x-app-token
// Sortie  : { "candidats": [...], "alerte": ..., "question": ... }
//
// Variables d'environnement (dashboard Vercel, jamais dans le repo) :
//   ANTHROPIC_API_KEY  — la clé Anthropic (quitte enfin l'appareil)
//   APP_TOKEN          — jeton partagé avec l'app iOS (chaîne longue aléatoire)

const { DEDUCTION_PROMPT } = require("./_prompt.js");

const MODELE = "claude-sonnet-5";

async function doCall(messages, avecTemperature) {
  const body = { model: MODELE, max_tokens: 2000, messages };
  if (avecTemperature) body.temperature = 0; // sortie stable et reproductible
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": process.env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(body),
  });
  const data = await r.json();
  if (!r.ok || data.error) {
    const msg = (data.error && data.error.message) || `HTTP ${r.status}`;
    throw new Error(msg);
  }
  return (data.content || []).filter((b) => b.type === "text").map((b) => b.text).join("\n");
}

async function callAPI(messages) {
  try {
    return await doCall(messages, true);
  } catch (e) {
    // repli automatique sans le paramètre si le modèle le refuse
    if (/temperature/i.test(String(e.message || e))) return doCall(messages, false);
    throw e;
  }
}

// parsing tolérant : remontée depuis "candidats" vers l'accolade ouvrante
function extractJson(raw) {
  const cleaned = raw.replace(/```json|```/g, "");
  const anchor = cleaned.lastIndexOf('"candidats"');
  if (anchor === -1) return null;
  const start = cleaned.lastIndexOf("{", anchor);
  const end = cleaned.lastIndexOf("}");
  if (start === -1 || end <= start) return null;
  try { return JSON.parse(cleaned.slice(start, end + 1)); } catch (_) { return null; }
}

module.exports = async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST uniquement" });
  if (!process.env.APP_TOKEN || req.headers["x-app-token"] !== process.env.APP_TOKEN) {
    return res.status(401).json({ error: "non autorisé" });
  }
  if (!process.env.ANTHROPIC_API_KEY) {
    return res.status(500).json({ error: "ANTHROPIC_API_KEY manquante côté serveur" });
  }

  const brut = (req.body && req.body.mots) || "";
  const mots = String(brut).trim().replace(/[,;\n]+/g, " ").replace(/\s+/g, " ");
  if (mots.split(" ").filter(Boolean).length < 3) {
    return res.status(400).json({ error: "trois mots requis" });
  }

  try {
    const userMsg = { role: "user", content: `${DEDUCTION_PROMPT}\n\nENTRÉE (ordre aléatoire) : ${mots}` };
    let texte = await callAPI([userMsg]);
    let parsed = extractJson(texte);
    if (!parsed) {
      // rattrapage : réponse tronquée avant le JSON
      texte = await callAPI([
        userMsg,
        { role: "assistant", content: texte },
        { role: "user", content: "Conclus MAINTENANT : donne UNIQUEMENT le bloc JSON final, sans aucun autre texte." },
      ]);
      parsed = extractJson(texte);
    }
    if (!parsed || !parsed.candidats || !parsed.candidats.length) {
      return res.status(502).json({ error: "Réponse sans candidats" });
    }
    return res.status(200).json(parsed);
  } catch (e) {
    return res.status(502).json({ error: String(e.message || e) });
  }
};
