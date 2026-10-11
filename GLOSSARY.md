# Document repo

The LaTeX side of a document project: the hand-written prose, with figures and tables generated into it by a separate analysis repo.

## Language

### Repos and layouts

**Document repo**:
This repo: the LaTeX document the analysis repo writes figures and tables into, and the analysis repo locates through `DOC_REPO`.
_Avoid_: writing repo (in prose; `writing-hosts-analysis` is a fixed value, not prose), LaTeX repo, thesis repo

**Analysis repo**:
The companion Python repo, made from `analysis-template`, whose notebooks generate this repo's figures and tables.
_Avoid_: code repo, Python repo, companion repo

**Layout**:
How the document repo and the analysis repo sit relative to each other on disk and in git.
_Avoid_: setup, mode, structure

**Nested layout**:
A layout where one repo is the host and the other is a nested repo inside it: `writing-hosts-analysis` here, `analysis-hosts-writing` from the analysis side.
_Avoid_: embedded layout, monorepo

**Host repo**:
In a nested layout, the outer repo you open and work from; it gitignores the nested repo.
_Avoid_: parent repo, outer repo

**Nested repo**:
In a nested layout, a separate repo with its own remote that lives in a gitignored subdirectory of the host repo.
_Avoid_: submodule, child repo, inner repo
