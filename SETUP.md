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

`init.py` asks for each value. To skip the questions, give them as flags:
`python init.py --title "…" --author "…"`.

You now have a document that compiles. Everything else is optional and additive — you can
stop here and just write, and the two other repositories can be added months later.

### 2. Overleaf (optional, but do it before you have many commits)

See [Working with Overleaf](#working-with-overleaf) below — there are two modes and the
choice affects your daily routine, so it is worth making deliberately.

### 3. The analysis repository (figures and tables)

To keep the analysis repo inside this one instead of beside it, skip this step and see
[The nested layout](#the-nested-layout-the-analysis-repo-inside-this-one).

```bash
# "Use this template" on GitHub for analysis-template, then:
git clone https://github.com/<you>/<your-analysis>.git
cd <your-analysis>
python init.py          # names the project, picks a backend, writes .env
uv sync --extra dev --extra notebooks --extra plotly
```

`init.py` asks for the path to your document repo and writes it to `.env` as `DOC_REPO`.
That file is gitignored, because it is a per-machine path rather than a project setting.
To skip the questions, give the answers as flags: `--distribution`, `--author`,
`--doc-repo` and `--backend` (`python init.py --help` lists them).

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

## The nested layout: the analysis repo inside this one

Step 3 puts the analysis repo beside this one. Instead, this document repo can be the
**host repo** and the analysis repo a **nested repo** inside it, in a gitignored
subdirectory:

```
my-thesis/              <- this repo, the one you open
├── main.tex, Sections/ …
├── layout.toml         <- records the layout; committed
└── my-thesis-analysis/ <- the analysis repo: its own repo and remote, gitignored here
```

**When to choose it.** When the document and its analysis are one package of work, and you
want one directory to open, one editor window and one agent session that sees both. Keep
the two side by side instead if one analysis repo feeds several documents. If you would
rather open the analysis repo and nest the document inside it, that is the reverse layout,
`analysis-hosts-writing`, and `analysis-template` sets it up.

### The one command

From the root of this repo, in a POSIX shell (on Windows, Git Bash, which comes with Git):

```bash
sh setup-nested.sh                       # create a new analysis repo from analysis-template
sh setup-nested.sh --from <url-or-path>  # or adopt one you already have
```

Creating needs `git`, `uv` and the GitHub CLI, signed in (`gh auth login`). It makes
`<owner>/<this repo's name>-analysis`, private, owned by whoever owns this repo's `origin`
on GitHub (else by you), and clones it into a directory of the same name. `--name`,
`--owner`, `--dir` and `--public` change those; `--backend matplotlib` replaces the default
`plotly`. `--python 3.12` (or any `3.x` / `3.x.y`) writes the analysis repo's
`.python-version` before its venv is built: commit it there. Anything after `--` is passed to the analysis repo's `init.py`, which otherwise
asks its questions at the terminal. Adopting needs only `git` and `uv`, and takes anything
`git clone` takes. The source is cloned, never moved or modified.

In order, the script clones the repo, adds `/<dir>/` to `.gitignore`, writes `layout.toml`,
runs the analysis repo's `init.py` if it still has one, and runs `uv sync` there. It
refuses before changing anything if a prerequisite is missing, if the directory exists and
is not empty, or if `layout.toml` already names a different directory.

**Already have a document repo and an analysis repo side by side?** Either run the same
command in the document repo, with `--from` pointing at the analysis repo's GitHub URL — the
old checkout is left where it was; delete it once anything uncommitted in it is pushed, so
you do not keep editing a stale copy — or move the checkout itself into this repo and run
`sh setup-nested.sh --dir <dir>`. That records it as it is, cloning nothing; it needs an
`origin` remote, which becomes `nested_remote`. A `DOC_REPO` in its `.env` from the
side-by-side days still names this repo, which has not moved: leave it for doc-publish.

Once the repo exists there is no rollback, because on GitHub it already does. If `init.py`
or `uv sync` fails, the script prints the command to rerun. Rerunning the script itself is
safe too: it finds the directory, changes nothing, and says what is still to do.

### What to commit where

- **Here:** `layout.toml` and `.gitignore`, once. Nothing from inside the nested
  directory, ever. `git status` here does not show it, and that is the point.
- **There:** everything inside the nested directory, from inside it (`cd <dir>`, then
  `git commit` and `git push` as usual). The changes `init.py` makes are the first
  commit there.
- Figures and tables the analysis repo writes into `Sections/` are this repo's files, as
  in any layout: commit them here.

Agents read the same rule in `AGENTS.md`: if `layout.toml` exists, `nested_dir` is a
separate repo, so commit there, never here.

### On a fresh clone

A clone of this repo arrives without the nested directory, because it is gitignored. Run
`sh setup-nested.sh` with no arguments. It reads `nested_dir` and `nested_remote` from
`layout.toml`, clones the analysis repo back into place and syncs its venv. If you chose
`matplotlib`, pass `--backend matplotlib` again. If the directory is already there, the
script says so and exits.

`nested_remote` is the clone's `origin`. If you adopted from a local path, that path is
what gets recorded, and no other machine can restore from it. Push the analysis repo to
GitHub and put that URL in `layout.toml`.

### `DOC_REPO` in the nested layout

Nothing to set. The analysis repo finds this one as its parent directory, because this
repo's `layout.toml` names it as `nested_dir` (analysis-template's ADR 0002,
[#11](https://github.com/c-energie/analysis-template/issues/11)). `setup-nested.sh` never
writes `DOC_REPO`, and the analysis repo's `init.py` does not ask for it. A `DOC_REPO` in
the environment or in `<dir>/.env` still wins, with a warning when it disagrees.

doc-publish is the exception: it reads only `DOC_REPO`, not `layout.toml`. To publish from
the nested repo, put `DOC_REPO=<absolute path to this repo>` in `<dir>/.env` (gitignored
there): the same directory `layout.toml` names, so nothing disagrees.

### Overleaf

Overleaf only sees tracked files, so the nested directory never reaches it.
`setup-nested.sh` and `layout.toml` sync there and do nothing, like the `Makefile`.

---

## Writing a paper (article or a journal class)

The template ships with `report` because a thesis is the common case. A paper swaps the
`\documentclass` line in `main.tex`, for example to `\documentclass[12pt,a4paper]{article}`.
Anything else that breaks after that swap is listed below.

**What adapts on its own.** `document_settings.sty` checks whether the class defines
`\chapter`, and the front matter in `Preamble/` follows that answer:

| | With chapters (`report`, `book`, a thesis class) | Without (`article`, most journal classes) |
|---|---|---|
| Abstract | Unnumbered chapter, listed in the contents | The class's `abstract` environment. Falls back to an unnumbered section if the class has none |
| Acknowledgements | Unnumbered chapter, listed in the contents | Unnumbered section, not listed |
| Contents, list of figures, list of tables, acronyms | Printed | Not printed |

The last row is a switch, `\ifshowcontents`, in `document_settings.sty`. Its default
follows the class. To override it either way, uncomment `\showcontentstrue` or
`\showcontentsfalse` on the lines below it. A paper that does want a contents page needs
only that one edit.

**What you still do by hand:**

- **The example section opens with `\chapter`.** It demonstrates the `report` default, so
  under `article` it fails with `Undefined control sequence`. Change it to `\section`, or
  delete the example. The same goes for your own sections: they open with `\section`, and
  the `\section`s inside them become `\subsection`s.
- **Acknowledgements come straight after the abstract.** Most journals want them at the
  end. Move the `\subfile{acknowledgements.tex}` line out of `Preamble/preamble.tex` and
  into `main.tex`, after the last section, with the path changed to
  `Preamble/acknowledgements.tex`. That move is not automated, because where they go is
  the journal's decision.
- **A journal class usually brings its own front matter.** Many supply their own
  `\title`, `\author`, `\maketitle`, affiliation and abstract macros, which take the
  place of the template's. Where the class's instructions differ from
  `Preamble/preamble.tex`, follow the class. Treat that file as the default, not as a
  requirement.

None of this touches the tooling's conventions. Bare-filename figures, labels mirroring
filenames, `\graphicspath` and `Sections/<Name>/` work the same under any class.

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
  required. With BibTeX and subfiles, see [Subfiles](#subfiles) for
  standalone builds.
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
# and, beside it, \InputIfFileExists{Sections/Introduction/values.tex}{}{}
```

`\graphicspath` **does not recurse** — every directory holding figures needs its own
line, and a missing one produces a "file not found" at build time with no hint why.

You do not have to move everything at once. Move one section, prove a figure lands, then
do the rest.

### Subfiles

A file pulled in with `\subfile` also compiles on its own. With subfiles more than one
level deep — a chapter file that includes section files — that holds at every level only
if the first two things below are right, and a document converted from `\include` needs
the third. Each costs several failed builds to find.

**Point every subfile at the root.** At any depth, the option in
`\documentclass[...]{subfiles}` is the path to the root `.tex`, never to the file that
includes it. A section file under `Chapters/Ch1/Sec/` takes
`\documentclass[../../../main.tex]{subfiles}`, not `[../ch1.tex]`. Pointing at the parent
still compiles inside the full document, so nothing looks wrong until the section is built
on its own:

```
! LaTeX Error: Option clash for document class subfiles.
```

`\subfile{...}` paths are the other way round: they stay relative to the file doing the
including.

**BibTeX bibliographies in standalone builds.** Only for documents using
`\bibliography{...}`. The template uses biblatex (`\addbibresource`), which does not hit
this, so skip it unless you kept a BibTeX setup. The obvious fixes all fail:

- No bibliography code in subfiles: every citation in a standalone build is undefined.
- An `\ifSubfilesClassLoaded{\bibliography{...}}{}` in each subfile: a chapter file built on
  its own runs its sections' copies too, and BibTeX stops with
  `Illegal, another \bibdata command`.
- One `\AtEndDocument{\ifSubfilesClassLoaded{\bibliography{\subfix{references}}}{}}` in the
  preamble: BibTeX gets `references` instead of `../../references`, and citations are
  undefined again.

What works at every level is no bibliography code in any subfile, and this in a `.sty` at
the repository root, loaded by your root `.tex` after `\usepackage{subfiles}`:

```latex
\edef\thesisbibfile{\subfix{references}}   % resolved while the preamble loads
\AtEndDocument{\ifSubfilesClassLoaded{\bibliography{\thesisbibfile}}{}}
```

The `\edef` is the point. `\subfix` has to expand while the root preamble is loading, when
it knows the path from the file being built back to the root. Left to expand inside
`\AtEndDocument`, it resolves relative to the subfile and gives the wrong path — the third
failure above. `references` is your own `.bib`, relative to the repository root and without
the extension. `\bibliographystyle` stays in your preamble, and the full document keeps
its own `\bibliography{...}`; the hook does nothing there.

**`\subfile` does not start a new page; `\include` does.** A document converted from
`\include` that relied on that break — an `\addcontentsline` between two chapters, say —
needs an explicit `\clearpage` before it. Without one the contents entry gets the page the
previous chapter ended on.

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
