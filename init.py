#!/usr/bin/env python3
"""Fill this template's placeholders in, then delete itself.

GitHub's "Use this template" copies files verbatim — it cannot substitute a title or an
author — so that job lands here. Run once, immediately after creating your repository:

    python init.py

Nothing outside this directory is touched, and the script refuses to run twice.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

PLACEHOLDERS = [
    ("<<DOCUMENT_TITLE>>", "Document title", "My Document"),
    ("<<AUTHOR>>", "Author", None),
]

# Everything text-like, minus the places a false positive would be invisible.
SUFFIXES = {".tex", ".sty", ".cls", ".bib", ".md", ".py", ".json", ".toml", ".yml"}
SKIP_DIRS = {".git", ".github"}


def ask(prompt, default):
    suffix = f" [{default}]" if default else ""
    while True:
        answer = input(f"  {prompt}{suffix}: ").strip()
        if answer:
            return answer
        if default:
            return default
        print("    Required.")


def files():
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        if path.name == Path(__file__).name:
            continue
        yield path


def main():
    remaining = [p for p, _, _ in PLACEHOLDERS
                 if any(p in f.read_text(encoding="utf-8", errors="replace")
                        for f in files())]
    if not remaining:
        print("No placeholders left — this template has already been initialised.")
        return 1

    print(__doc__.splitlines()[0] + "\n")
    values = {token: ask(label, default) for token, label, default in PLACEHOLDERS}

    changed = 0
    for path in files():
        text = original = path.read_text(encoding="utf-8")
        for token, value in values.items():
            text = text.replace(token, value)
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed += 1
            print(f"    {path.relative_to(ROOT)}")

    print(f"\nRewrote {changed} file(s).")

    # A LaTeX class is a licensing decision, not a substitution, so it is a prompt
    # rather than a placeholder — see README.md.
    print("\nNext:")
    print("  * main.tex uses the standard `report` class. To use an institutional one,")
    print("    drop its .cls beside main.tex and edit the \\documentclass line.")
    print("  * Rewrite .doc-publish/prompt.md before pointing any agent at this.")
    print("  * Replace the Example section with your own, and update \\graphicspath")
    print("    in document_settings.sty when you add a section that holds figures.")

    Path(__file__).unlink()
    print("\nDeleted init.py.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (EOFError, KeyboardInterrupt):
        print("\nAborted; nothing was changed.", file=sys.stderr)
        sys.exit(1)
