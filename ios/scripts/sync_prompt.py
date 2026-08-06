#!/usr/bin/env python3
"""Synchronise le prompt de déduction depuis index.html (source de vérité) vers
DeductionService.swift, et vérifie l'identité octet pour octet.

Usage :
  python3 sync_prompt.py          # injecte le prompt dans le fichier Swift
  python3 sync_prompt.py --check  # vérifie sans modifier (code retour 1 si divergence)

À relancer après CHAQUE patch de DEDUCTION_PROMPT dans index.html.
"""
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
HTML = RACINE / "index.html"
SWIFT = RACINE / "ios" / "Trident" / "Services" / "DeductionService.swift"

def extraire_prompt_js():
    src = HTML.read_text(encoding="utf-8")
    m = re.search(r"const DEDUCTION_PROMPT = `(.*?)`;", src, re.DOTALL)
    if not m:
        sys.exit("ERREUR : DEDUCTION_PROMPT introuvable dans index.html")
    prompt = m.group(1)
    # garde-fous : caractères incompatibles avec un literal Swift multiligne brut
    if "\\" in prompt or '"""' in prompt:
        sys.exit("ERREUR : le prompt contient \\ ou \"\"\" — l'injection Swift doit être adaptée")
    return prompt

def extraire_prompt_swift(src):
    m = re.search(r'static let deductionPrompt = """\n(.*?)\n"""', src, re.DOTALL)
    if not m:
        sys.exit("ERREUR : bloc deductionPrompt introuvable dans DeductionService.swift")
    return m

def main():
    check = "--check" in sys.argv
    prompt = extraire_prompt_js()
    src = SWIFT.read_text(encoding="utf-8")
    m = extraire_prompt_swift(src)
    if m.group(1) == prompt:
        print("OK : prompt Swift identique à index.html (octet pour octet)")
        return
    if check:
        sys.exit("DIVERGENCE : le prompt Swift diffère d'index.html — relancer sync_prompt.py")
    SWIFT.write_text(src[: m.start(1)] + prompt + src[m.end(1) :], encoding="utf-8")
    print("Prompt injecté dans DeductionService.swift depuis index.html")

if __name__ == "__main__":
    main()
