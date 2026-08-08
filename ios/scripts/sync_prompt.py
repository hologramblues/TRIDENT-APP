#!/usr/bin/env python3
"""Synchronise le prompt de déduction depuis index.html (source de vérité) vers :
  - ios/Trident/Services/DeductionService.swift (app native)
  - api/_prompt.js (fonction Vercel)
et vérifie l'identité octet pour octet.

Usage :
  python3 sync_prompt.py          # injecte le prompt dans les deux cibles
  python3 sync_prompt.py --check  # vérifie sans modifier (code retour 1 si divergence)

À relancer après CHAQUE patch de DEDUCTION_PROMPT dans index.html.
"""
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
HTML = RACINE / "index.html"
SWIFT = RACINE / "ios" / "Trident" / "Services" / "DeductionService.swift"
JS = RACINE / "api" / "_prompt.js"

EN_TETE_JS = (
    "// GÉNÉRÉ par ios/scripts/sync_prompt.py depuis index.html — NE PAS ÉDITER À LA MAIN.\n"
    "// Le prompt de déduction est copié VERBATIM : chaque phrase corrige un échec réel (PROJET.md).\n"
)

def extraire_prompt_js_source():
    src = HTML.read_text(encoding="utf-8")
    m = re.search(r"const DEDUCTION_PROMPT = `(.*?)`;", src, re.DOTALL)
    if not m:
        sys.exit("ERREUR : DEDUCTION_PROMPT introuvable dans index.html")
    prompt = m.group(1)
    # garde-fous : caractères incompatibles avec les literals Swift """ et JS `
    for interdit in ("\\", '"""', "`", "${"):
        if interdit in prompt:
            sys.exit(f"ERREUR : le prompt contient {interdit!r} — l'injection doit être adaptée")
    return prompt

def sync_swift(prompt, check):
    src = SWIFT.read_text(encoding="utf-8")
    m = re.search(r'static let deductionPrompt = """\n(.*?)\n"""', src, re.DOTALL)
    if not m:
        sys.exit("ERREUR : bloc deductionPrompt introuvable dans DeductionService.swift")
    if m.group(1) == prompt:
        return True
    if check:
        return False
    SWIFT.write_text(src[: m.start(1)] + prompt + src[m.end(1) :], encoding="utf-8")
    return True

def sync_js(prompt, check):
    attendu = EN_TETE_JS + "module.exports.DEDUCTION_PROMPT = `" + prompt + "`;\n"
    if JS.exists() and JS.read_text(encoding="utf-8") == attendu:
        return True
    if check:
        return False
    JS.parent.mkdir(parents=True, exist_ok=True)
    JS.write_text(attendu, encoding="utf-8")
    return True

def main():
    check = "--check" in sys.argv
    prompt = extraire_prompt_js_source()
    ok_swift = sync_swift(prompt, check)
    ok_js = sync_js(prompt, check)
    if check:
        if ok_swift and ok_js:
            print("OK : Swift et JS identiques à index.html (octet pour octet)")
        else:
            divergents = [n for n, ok in (("Swift", ok_swift), ("api/_prompt.js", ok_js)) if not ok]
            sys.exit(f"DIVERGENCE : {', '.join(divergents)} — relancer sync_prompt.py")
    else:
        print("Prompt synchronisé : DeductionService.swift + api/_prompt.js")

if __name__ == "__main__":
    main()
