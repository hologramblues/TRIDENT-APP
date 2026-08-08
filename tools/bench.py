#!/usr/bin/env python3
"""Banc de test de la déduction — rejoue la batterie de trios N fois via l'API
Anthropic et mesure le rang du mot attendu à chaque exécution.

C'est l'outil de mesure OBLIGATOIRE avant/après tout affinage du prompt :
même à temperature 0 l'API n'est pas 100 % déterministe (voir CLAUDE.md),
donc seule une mesure multi-exécutions est significative.

Usage :
  export ANTHROPIC_API_KEY=sk-ant-...   # à faire TOI-MÊME dans ton terminal
  python3 tools/bench.py                # 3 exécutions par trio (défaut)
  python3 tools/bench.py -n 5           # 5 exécutions par trio
  python3 tools/bench.py -t "verre image mammouth:miroir"   # un trio ad hoc

Le prompt est extrait d'index.html (source de vérité) à chaque lancement.
Aucune clé n'est jamais écrite sur disque ni affichée.
"""
import argparse
import concurrent.futures
import json
import os
import re
import sys
import urllib.request
from collections import Counter
from pathlib import Path

RACINE = Path(__file__).resolve().parents[1]
MODELE = "claude-sonnet-5"

# Batterie de référence (voir CLAUDE.md) : "trio": "mot attendu au rang 1"
BATTERIE = [
    ("tourbillon marteau oui", "tournevis"),
    ("verre image mammouth", "miroir"),
    ("océan spatule citadelle", "couteau"),
    ('philosophe "sac à main" oiseau', "portefeuille"),
    ("flamant baguettes orange", "fourchette"),
    ("flamand baguette orange", "fourchette"),  # variantes de dictée
]


def extraire_prompt():
    src = (RACINE / "index.html").read_text(encoding="utf-8")
    m = re.search(r"const DEDUCTION_PROMPT = `(.*?)`;", src, re.DOTALL)
    if not m:
        sys.exit("ERREUR : DEDUCTION_PROMPT introuvable dans index.html")
    return m.group(1)


def extract_json(raw):
    """Port exact du parsing tolérant de la webapp."""
    cleaned = raw.replace("```json", "").replace("```", "")
    anchor = cleaned.rfind('"candidats"')
    if anchor == -1:
        return None
    start = cleaned.rfind("{", 0, anchor)
    end = cleaned.rfind("}")
    if start == -1 or end <= start:
        return None
    try:
        return json.loads(cleaned[start : end + 1])
    except json.JSONDecodeError:
        return None


def call_api(cle, messages, temperature=True):
    body = {"model": MODELE, "max_tokens": 2000, "messages": messages}
    if temperature:
        body["temperature"] = 0
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(body).encode(),
        headers={
            "content-type": "application/json",
            "x-api-key": cle,
            "anthropic-version": "2023-06-01",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            data = json.loads(r.read())
    except urllib.error.HTTPError as e:
        data = json.loads(e.read())
        msg = (data.get("error") or {}).get("message", f"HTTP {e.code}")
        if temperature and "temperature" in msg.lower():
            return call_api(cle, messages, temperature=False)  # repli comme l'app
        raise RuntimeError(msg) from None
    return "\n".join(b.get("text", "") for b in data.get("content", []) if b.get("type") == "text")


def deduire(cle, prompt, trio):
    user = {"role": "user", "content": f"{prompt}\n\nENTRÉE (ordre aléatoire) : {trio}"}
    texte = call_api(cle, [user])
    parsed = extract_json(texte)
    if parsed is None:
        texte = call_api(cle, [
            user,
            {"role": "assistant", "content": texte},
            {"role": "user", "content": "Conclus MAINTENANT : donne UNIQUEMENT le bloc JSON final, sans aucun autre texte."},
        ])
        parsed = extract_json(texte)
    if not parsed or not parsed.get("candidats"):
        return None
    return [c.get("mot", "").lower() for c in parsed["candidats"]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-n", type=int, default=3, help="exécutions par trio (défaut 3)")
    ap.add_argument("-t", action="append", default=[], metavar="TRIO:ATTENDU",
                    help='trio ad hoc, ex. -t "verre image mammouth:miroir" (remplace la batterie)')
    ap.add_argument("-j", type=int, default=4, help="appels API en parallèle (défaut 4)")
    args = ap.parse_args()

    cle = os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("TRIDENT_API_KEY")
    if not cle:
        sys.exit("Pose ta clé d'abord :  export ANTHROPIC_API_KEY=sk-ant-...  (elle ne quitte pas ton terminal)")

    batterie = [tuple(t.rsplit(":", 1)) for t in args.t] if args.t else BATTERIE
    prompt = extraire_prompt()
    travaux = [(trio, attendu.strip().lower(), i) for trio, attendu in batterie for i in range(args.n)]
    resultats = {}  # (trio, attendu) -> liste de rangs (None = absent/échec)
    tetes = {}      # (trio, attendu) -> Counter des mots vus au rang 1

    print(f"Banc de test — {len(batterie)} trios × {args.n} exécutions ({MODELE}, temperature 0)\n")

    def run(travail):
        trio, attendu, _ = travail
        try:
            mots = deduire(cle, prompt, trio)
        except Exception as e:
            return trio, attendu, None, f"erreur: {e}"
        if not mots:
            return trio, attendu, None, "sans candidats"
        rang = mots.index(attendu) + 1 if attendu in mots else None
        return trio, attendu, rang, mots[0]

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.j) as ex:
        for trio, attendu, rang, tete in ex.map(run, travaux):
            resultats.setdefault((trio, attendu), []).append(rang)
            tetes.setdefault((trio, attendu), Counter())[tete] += 1
            ok = "✓" if rang == 1 else ("→" + str(rang) if rang else "✗")
            print(f"  {ok:>3}  {trio}  (tête: {tete})")

    print("\n" + "=" * 72)
    total_ok = total = 0
    for (trio, attendu), rangs in resultats.items():
        n = len(rangs)
        ok1 = sum(1 for r in rangs if r == 1)
        present = [r for r in rangs if r]
        total_ok += ok1
        total += n
        moyen = f"{sum(present) / len(present):.1f}" if present else "—"
        absent = n - len(present)
        detail = " · ".join(f"{m}×{c}" for m, c in tetes[(trio, attendu)].most_common())
        print(f"{attendu.upper():>14}  rang1 {ok1}/{n}  rang moyen {moyen}  absent {absent}  | {trio}")
        print(f"{'':>14}  têtes vues : {detail}")
    print("=" * 72)
    print(f"SCORE GLOBAL rang 1 : {total_ok}/{total} ({100 * total_ok / total:.0f}%)")


if __name__ == "__main__":
    main()
