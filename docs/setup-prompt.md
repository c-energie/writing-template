# A prompt for setting this up with any AI assistant

Copy everything below the line into ChatGPT, Gemini, Claude, Copilot Chat, or whatever you
use, and answer its questions. It works with an assistant that has no access to your
files — it will ask you to run commands and paste back what you see.

If your assistant *does* have repository access (Cursor, Claude Code, Codex, Windsurf,
Aider), you do not need this: point it at `AGENTS.md` and `SETUP.md` in this repository
instead, and tell it to run `doc-publish doctor`.

---

You are helping me set up a LaTeX document toolchain. Work through this with me one step
at a time. Ask me to run a command, wait for me to paste the output, then tell me the next
step. Do not give me the whole plan up front — I want to do this incrementally.

## What the toolchain is

Three independent repositories that together let me write a long LaTeX document (a thesis,
report or book) where the prose is the only thing I write by hand:

- **writing-template** — the LaTeX document itself. Pure markup. Goes to Overleaf.
- **analysis-template** — Python. Generates figures and tables *into* the document repo.
- **doc-publish** — turns the finished LaTeX into a queryable corpus, a Notion wiki, or a
  website.

They are joined by exactly one thing: an environment variable `DOC_REPO` pointing at the
document repository. Both Python repositories find the document that way and no other way.

## What you need to establish first

Ask me these before suggesting anything. Ask them one or two at a time, not as a wall of
questions.

1. **Do I already have a document, or am I starting fresh?** If I already have one —
   especially on Overleaf — that changes the whole approach: I am adapting an existing
   thesis, not generating a new one, and I should not be told to start from a template.
2. **Which parts do I actually want?** Just the document? Document plus generated figures?
   Or the full publishing pipeline too? Do not set up things I have not asked for —
   the publishing engine needs a system dependency and credentials, and it is optional.
3. **What operating system and shell?** Commands differ; PowerShell and bash set
   environment variables differently.
4. **If I have an existing document: will I keep editing it in the Overleaf web editor, or
   edit locally and use Overleaf only to compile?** This determines my daily routine and
   the risk of conflicts.

## Hard requirements to check against my document

If I have an existing document, only these actually matter. Everything else adapts to me,
so do not tell me to restructure things unnecessarily.

- There must be a **root `.tex` at the repository root**. `main.tex`, `thesis.tex`,
  `dissertation.tex`, `report.tex` and `book.tex` are found automatically. Any other name
  works too — I set `DOC_MAIN_TEX` to it. **Do not tell me to rename my root file.**
- **Figures must be referenced by bare filename** (`\includegraphics{plot.png}`, not a
  path), resolved by `\graphicspath`. `\graphicspath` does not recurse — every directory
  holding figures needs its own entry.
- **Figure labels must mirror figure filenames**: `plot.png` ↔ `\label{Fig: plot}`.
- Only if I want generated figures: sections need to live in `Sections/<Name>/`, each with
  a `Figures/` subdirectory.

Things that are **not** required, and that you should not ask me to change:

- A glossary file. Optional. Acronyms are found wherever they are declared — a separate
  file, a `.sty`, or the preamble.
- A particular bibliography location. My own `\addbibresource{...}` is read.
- A particular `.sty` filename. Every `.sty` at the repository root is scanned.
- A particular document class. `report`, `book`, or an institutional `.cls` all work, and
  `\chapter` and `\section` are both understood.

## The command that tells you the state

Once `doc-publish` is installed and `DOC_REPO` is set, this reports everything at once:

```
doc-publish doctor
```

It reads and never writes, so it is always safe to run. `doc-publish doctor --json` gives
the same findings as structured data if that is easier for you to work with. **Ask me to
run it and paste the output rather than guessing what my setup looks like.** It reports,
per check: `ok`, `warn` (usable, worth knowing), `--` (an optional feature not configured,
which is fine), or `FAIL` (must be fixed).

Then work down its `FAIL` lines with me, one at a time. Each one prints a specific fix.

## Things people get wrong, that you should steer me away from

- **Do not have me create an empty `glossary_terms.tex`** to satisfy anything. It is not
  required, and an empty one is worse than none.
- **Do not put `DOC_REPO` in my shell profile.** It is wrong the moment I have a second
  document and it fails silently — figures land in the wrong one. It belongs in the
  `.env` file of the checkout that needs it.
- **`doc-publish init` writes into the *document* repository**, not the Python one. That
  surprises people. Its output belongs committed there.
- **A build failure is a failure, not a warning.** If `doc-publish build` exits non-zero,
  do not suggest working around it or editing the generated corpus. Fix the cause. The
  markers it leaves (`[UNRESOLVED: ...]`) exist because the silent version reads
  plausibly and loses real content.
- **Do not have me commit the built PDF.**
- If I mention a Notion token or any credential, remind me to keep it in an environment
  variable and never commit it, but **do not ask me to paste it to you.**

## How to finish

I am done when:

1. `doc-publish doctor` shows no `FAIL` lines.
2. `doc-publish build` exits 0.
3. If I wanted generated figures: a figure written by a notebook has appeared in my
   document repository and I have committed it.

Only if I asked for publishing: `doc-publish check` also passes, which requires me to
have written `.doc-publish/prompt.md` by hand. Tell me that file is the one piece of real
authoring work in the setup, and why — it tells an assistant what my document does and
does not establish, and without it an assistant will answer confidently and wrongly in my
name.

Start by asking me question 1.
