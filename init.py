#!/usr/bin/env python3
"""Fill this template's placeholders in, then delete itself.

GitHub's "Use this template" copies files verbatim — it cannot substitute a title or an
author — so that job lands here. Run once, immediately after creating your repository:

    python init.py

It asks for each answer in turn. To run it unattended, give them as flags instead
(`python init.py --help`): a flag's value is used as-is, and with no terminal on stdin
a left-out --title takes its default and a left-out --author stops the script.

Nothing outside this directory is touched, and the script refuses to run twice.
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# token, prompt, default (None: required), flag
PLACEHOLDERS = [
    ("<<DOCUMENT_TITLE>>", "Document title", "My Document", "--title"),
    ("<<AUTHOR>>", "Author", None, "--author"),
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


def at_terminal():
    """Whether a person can answer a prompt on stdin. isatty() alone is wrong both ways on
    Windows: the NUL device claims to be a TTY, so input() hit EOF and said "Aborted";
    and Git Bash's mintty hands Python a pipe, so a person there would be refused."""
    if sys.stdin is None:
        return False
    if sys.platform != "win32":
        return sys.stdin.isatty()
    import ctypes
    import msvcrt
    from ctypes import wintypes
    try:
        handle = msvcrt.get_osfhandle(sys.stdin.fileno())
    except (OSError, ValueError):
        return False
    kernel32 = ctypes.windll.kernel32
    kernel32.GetConsoleMode.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    if kernel32.GetConsoleMode(handle, ctypes.byref(wintypes.DWORD())):
        return True
    # mintty's end of the pty is a named pipe called msys-<hash>-ptyN-from-master
    # (cygwin-... under Cygwin). FileNameInfo is 2: a DWORD length, then UTF-16.
    kernel32.GetFileInformationByHandleEx.argtypes = [
        wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    info = ctypes.create_string_buffer(4 + 2 * 512)
    if not kernel32.GetFileInformationByHandleEx(handle, 2, info, ctypes.sizeof(info)):
        return False
    length = int.from_bytes(info.raw[:4], "little")
    name = info.raw[4:4 + length].decode("utf-16-le", errors="replace")
    return "-pty" in name and name.endswith("-from-master")


def nonempty(value):
    value = value.strip()
    if not value:
        raise argparse.ArgumentTypeError("Required.")
    return value


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0],
        epilog="Each flag left out is prompted for at a terminal. Without one, a left-out "
               "--title takes its default and a left-out --author stops the script.")
    parser.add_argument("--title", type=nonempty, help="document title (default: My Document)")
    parser.add_argument("--author", type=nonempty, help="author name")
    return parser.parse_args(argv)


def files():
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        if path.name == Path(__file__).name:
            continue
        yield path


def main(argv=None):
    args = parse_args(argv)
    interactive = at_terminal()
    remaining = [p for p, _, _, _ in PLACEHOLDERS
                 if any(p in f.read_text(encoding="utf-8", errors="replace")
                        for f in files())]
    if not remaining:
        print("No placeholders left — this template has already been initialised.")
        return 1

    # Checked before anything is written. Without a terminal there is nobody to ask, and
    # input() would only hit EOF and hide which answer was missing.
    missing = [flag for _, _, default, flag in PLACEHOLDERS
               if default is None and getattr(args, flag[2:]) is None]
    if missing and not interactive:
        sys.exit(f"init.py: no terminal to prompt on; pass {' and '.join(missing)}.")

    print(__doc__.splitlines()[0] + "\n")
    # A flag's value is used as-is and its prompt is not shown.
    values = {}
    for token, label, default, flag in PLACEHOLDERS:
        given = getattr(args, flag[2:])
        values[token] = given or (ask(label, default) if interactive else default)

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
    print("  * To publish beyond the PDF: `doc-publish init` scaffolds .doc-publish/,")
    print("    then rewrite its prompt.md before pointing any agent at this document.")
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
