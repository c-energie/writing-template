# Setting up the toolchain

Three repositories make one pipeline. This is the order to set them up, what each one
needs from the others, and the parts that are genuinely fiddly.

```
analysis-template ──figures/tables──> THIS REPO ──ingest──> doc-publish ──> corpus / wiki / site
                                    (= $DOC_REPO)              │
                                          └────── Overleaf ────┴──> the PDF
```

**`DOC_REPO` is the only joint.** Both Python repositories locate this one through that
environment variable and nothing else. Get it right once per machine and the rest follows.

> Already have a document? Skip to [Adapting an existing document](#adapting-an-existing-document)
> first, then come back here. Starting from scratch is the easier path but the rarer one.

## The one command to remember

```bash
doc-publish doctor
```

Walks every condition in this guide at once and prints, for anything not ready, the
specific thing to do about it. It reads and never writes, so run it whenever you are
unsure. `--json` gives the same findings as structured data.

Its grading: `ok`, `warn` (usable, worth knowing), `--` (an optional feature you have not
configured, which is fine), `FAIL` (must be fixed). Only `FAIL` sets a non-zero exit.

## Setting up with an AI assistant

- **An agent with repository access** (Cursor, Claude Code, Copilot, Codex, Windsurf,
  Aider, Zed) reads [AGENTS.md](AGENTS.md) automatically, or can be pointed at it. Tell it
  to run `doc-publish doctor` and work down the `FAIL` lines.
- **A chat assistant without file access** (ChatGPT, Gemini, a browser tab): paste
  [docs/setup-prompt.md](docs/setup-prompt.md) into it. It will interview you about your
  situation and walk you through setup one step at a time.

Both know the things people get wrong — that your root `.tex` need not be renamed, that a
glossary is optional, that an empty one is worse than none.

---

## Order of setup

Do these in order. Each step assumes the previous one worked.

### 1. The document repository (this one)

```bash
# "Use this template" on GitHub, then:
git clone https://github.com/<you>/<your-document>.git
cd <your-document>
python init.py          # fills in title and author, then deletes itself
make                    # optional: prove it builds locally
```

You now have a document that compiles. Everything else is optional and additive — you can
stop here and just write, and the two other repositories can be added months later.

### 2. Overleaf (optional, but do it before you have many commits)

See [Working with Overleaf](#working-with-overleaf) below — there are two modes and the
choice affects your daily routine, so it is worth making deliberately.

### 3. The analysis repository (figures and tables)

```bash
# "Use this template" on GitHub for analysis-template, then:
git clone https://github.com/<you>/<your-analysis>.git
cd <your-analysis>
python init.py          # names the project, picks a backend, writes .env
uv sync --extra dev --extra notebooks --extra plotly
```

`init.py` asks for the path to your document repo and writes it to `.env` as `DOC_REPO`.
That file is gitignored, because it is a per-machine path rather than a project setting.

Prove the wiring before you write any analysis of your own:

```bash
# runs on synthetic data; writes a real figure into the document repo
jupyter lab notebooks/example/example_figure.ipynb
```

Then check the document repo — you should have a new PNG under
`Sections/Example/Figures/` and a commented-out `\begin{figure}` block appended to
`Sections/Example/example.tex`. **Commit both in the document repo.** Nothing does that
for you.

### 4. The publishing engine (optional)

Only needed if you want a queryable corpus, a Notion wiki or a website. The PDF does not
need it.

```bash
cd <your-analysis>
uv sync --extra publish          # installs doc-publish as a command
doc-publish doctor               # confirm it can see your document
doc-publish init                 # scaffolds .doc-publish/ into the DOCUMENT repo
doc-publish build                # LaTeX -> corpus
doc-publish check                # says what is still unfinished
```

Two things surprise everyone here:

- **`doc-publish init` writes into the *document* repo, not the analysis one.** The
  publishing state is keyed to that document's labels, so it lives beside them. Commit
  `.doc-publish/` there. It also drops an `AGENTS.md` at the document's root — tool-neutral
  instructions any coding agent reads — which you should edit to taste and commit.
- **`doc-publish check` will fail at first, on purpose.** It reports `prompt.md` as
  unfinished because `.doc-publish/prompt.md` is a template with `[TODO:]` markers in it.
  That file is the one piece of real work: it tells an agent what your document does and
  does not establish. Until it is written, an agent will misrepresent your findings
  confidently. `init` also writes a Claude skill (`.claude/skills/write-agent-prompt/`)
  that walks you through it.

For the site and wiki, see [Publishing](#publishing).

---

## Adapting an existing document

If your thesis already exists — on Overleaf or anywhere else — you are not starting from
this template. You are making your document satisfy the small set of conventions the
tooling relies on. There are four, and only the last is real work.

### What is actually required

| Requirement | Why | If you don't |
|---|---|---|
| A root `.tex` at the repository root | The flattener starts there and follows `\subfile`/`\input`/`\include` | `doc-publish` refuses to run, naming the setting to fix |
| Figures referenced by **bare filename** | `\graphicspath` resolves them; the tooling indexes by name | Figures resolve as `missing` in the manifest |
| Labels mirroring figure filenames | How the tooling knows a figure is already placed | Re-running a notebook appends duplicate blocks |
| Sections in `Sections/<Name>/` | Where the analysis tooling writes | Only matters if you use `analysis-template` |

Everything else adapts to you:

- **Your root file keeps its name.** `main.tex`, `thesis.tex`, `dissertation.tex`,
  `report.tex` and `book.tex` are found automatically. Anything else — set `DOC_MAIN_TEX`
  in your `.env` and leave the file alone.
- **A glossary is optional.** If you have `glossary_terms.tex` it is read; if your
  `\newacronym` entries live in a `.sty` or the preamble they are found there; if you have
  no glossary at all that is fine.
- **Your bibliography stays where it is.** The engine reads your own
  `\addbibresource{...}` or `\bibliography{...}` declarations. No particular directory is
  required.
- **Your settings file keeps its name.** Every `.sty` at the repository root is scanned
  for `\graphicspath` and macro definitions.
- **Your document class is untouched.** `report`, `book`, an institutional `.cls` —
  `\chapter` and `\section` are both understood.

### Migrating in

```bash
# 1. Get the document into git locally (from Overleaf, see below)
git clone https://git.overleaf.com/<project-id> my-thesis
cd my-thesis

# 2. Point the tooling at it and see what it makes of the document as-is
export DOC_REPO=$PWD          # PowerShell: $env:DOC_REPO = $PWD
doc-publish doctor            # what it found, and what it could not
doc-publish build             # the real audit
```

`doctor` tells you what the engine makes of your layout before anything runs: which root
`.tex` it picked, where your glossary and bibliography resolved to, whether every
`\graphicspath` directory exists. If it names your files correctly, the rest usually
follows.

`build` is the audit proper. It exits non-zero and tells you exactly what it could not
resolve — unexpanded macros, figures it could not find, ambiguous filenames. Work down
that list. Nothing is dropped silently; an unresolvable thing becomes an
`[UNRESOLVED: ...]` marker and fails the build, because the silent version reads
plausibly: an unexpanded count macro turns "a family of `\nmodels{}` variants" into "a
family of variants" and the number is simply gone.

The most common finding is a macro of your own that takes arguments. Zero-argument
literals (`\newcommand{\nmodels}{40}`) are expanded for you. For the rest, write a
`macros.py` into `.doc-publish/` — `init` ships a Claude skill
(`.claude/skills/write-macro-adapter/`) for exactly this.

### Restructuring for the analysis tooling

Only if you want generated figures. `analysis-template` writes to
`$DOC_REPO/Sections/<Name>/Figures/`, so your sections need to live there. If your thesis
currently has, say, `chapters/introduction.tex`:

```bash
mkdir -p Sections/Introduction/Figures
git mv chapters/introduction.tex Sections/Introduction/
# then update the \subfile / \input line in your root .tex,
# and add Sections/Introduction/Figures/ to \graphicspath
```

`\graphicspath` **does not recurse** — every directory holding figures needs its own
line, and a missing one produces a "file not found" at build time with no hint why.

You do not have to move everything at once. Move one section, prove a figure lands, then
do the rest.

---

## Working with Overleaf

Overleaf's git bridge makes this repository and the Overleaf project two clones of the
same thing. There are two ways to live with that, and the difference matters because
figures arrive from a *third* place — your analysis repo writes PNGs straight into your
local checkout.

### Mode A — local git is primary, Overleaf compiles

You edit prose locally, push to Overleaf for the PDF and for supervisors to read.

```bash
git remote add overleaf https://git.overleaf.com/<project-id>
git push overleaf main
```

The routine after generating figures:

```bash
# in the analysis repo: run your notebook, then in the document repo
git add Sections/ && git commit -m "Regenerate figures"
git push origin main
git push overleaf main
```

**Simplest, and what the tooling assumes.** The rule is: never edit in the Overleaf web
editor. If you do, the next push is a conflict.

### Mode B — Overleaf is the editor

You write prose in the Overleaf web editor. Sync is genuinely bidirectional and figures
still arrive locally, so ordering matters:

```bash
# ALWAYS pull before generating figures
git pull overleaf master        # note: Overleaf's branch is usually `master`

# now run the notebook in the analysis repo, then
git add Sections/ && git commit -m "Regenerate figures"
git push overleaf master
git push origin main            # keep GitHub in step
```

**The failure mode to know:** generate figures against a stale checkout and you commit
PNGs alongside prose that Overleaf has already moved on from. The merge is usually clean
(figures and prose rarely touch the same lines) but the *caption* you wrote in Overleaf
and the *figure block* the tooling appended locally can end up duplicated. Pull first.

### Either mode

- **Overleaf runs its own toolchain**, so the `Makefile` is for local builds only.
  Anything the document actually needs belongs in the root `.tex` or your `.sty`.
- **`.doc-publish/` is data, not markup.** Overleaf ignores it; the document builds
  identically without it. Commit it anyway — losing `notion_manifest.json` makes the next
  sync create a second copy of your entire wiki.
- **Never commit the built PDF.** It is stale by definition and conflicts on every push.

---

## Publishing

Only relevant if you want more than the PDF.

```bash
doc-publish build      # -> corpus_public.md, corpus_draft.md, labels, figures
doc-publish site       # -> a Quarto site      (needs Quarto installed)
doc-publish serve      # view it locally
doc-publish sync       # -> a Notion wiki      (needs a token)
doc-publish publish    # -> copy into the publish repo; writes files, never commits
```

Three prerequisites nothing can install for you:

- **Quarto is a system dependency.** `winget install Posit.Quarto`, or the equivalent for
  your platform. A Python extra cannot provide it.
- **Notion needs an integration token** (`NOTION_TOKEN`) and a parent page
  (`DOC_NOTION_PARENT`). That means a credential on the machine where your analysis runs —
  use an environment variable and never commit it.
- **The publish repo must be a git repo** (`DOC_PUBLISH_REPO`). `doc-publish publish`
  writes into it and stops, so you can review the result as a diff before it is permanent.

### The one that can bite

**Two corpora, and only one may leave the machine.** `corpus_public.md` has source
comments stripped and feeds every outbound route. `corpus_draft.md` keeps them as
`> [draft note]` — provenance, TODOs, contested numbers, questions to your supervisor —
and is for you alone. `CORPUS_MODE` selects which; the publish path hard-fails under
`draft` and scans its payload for the marker. Keep `build/` gitignored.

Read `doc-publish/docs/publishing.md` before the first push of a public site. Treat that
push as the point of no return.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `DOC_REPO ... does not look like a LaTeX document repo` | No recognised root `.tex`. Set `DOC_MAIN_TEX` to your root filename. |
| `DOC_REPO is not set` | The analysis repo reads `.env` in its own checkout; `doc-publish` searches upward from the working directory. Run `doc-publish config` to see how every setting resolved and from where. |
| Every citation is `[UNRESOLVED: cite ...]` | The engine could not find your `.bib`. Check your `\addbibresource` path resolves from the repository root. |
| A figure is `missing` in `build/figures.json` | The PNG is not under any `\graphicspath` directory. It does not recurse — add the directory explicitly. |
| A figure is `ambiguous` | Two files share a stem. Figure names must be unique document-wide. |
| Re-running a notebook appended a second figure block | The label does not mirror the filename, so the gate could not see the existing reference. |
| `doc-publish check` reports `prompt.md UNFINISHED` | Expected until you write it. See step 4 above. |
| `uv run pytest` fails with "trampoline failed to canonicalize script path" | Use `uv run python -m pytest` instead. |

`doc-publish config` is the fastest way to diagnose anything path-shaped: it prints every
setting, its value, and which source it came from.
