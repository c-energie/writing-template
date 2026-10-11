#!/bin/sh
# setup-nested.sh — host this document repo's analysis repo inside it, as a nested repo.
#
#   sh setup-nested.sh                  create one from analysis-template (needs gh)
#   sh setup-nested.sh --from <src>     adopt one that already exists (anything git clone takes)
#   sh setup-nested.sh                  with layout.toml present: restore it on a fresh clone
#
#   options: [--dir DIR] [--owner O] [--name N] [--public] [--backend plotly|matplotlib]
#            [-- INIT_ARGS...]          passed through to the analysis repo's init.py
#
# Strict POSIX sh, so it runs under dash and under Git Bash on Windows without being a
# second language here: AGENTS.md allows this file and init.py, and nothing else. It is
# kept LF by .gitattributes, because a CRLF copy fails in sh with "$'\r': not found".
#
# The nested repo is a separate repo with its own remote. This script records that in
# layout.toml and gitignores the directory; the host never tracks a file inside it.
# It never writes DOC_REPO: the analysis repo derives that from layout.toml
# (c-energie/analysis-template#11), and until it does SETUP.md gives .env as the stopgap.
#
# GH names the gh command (default gh), so the test can make gh missing on a machine
# that has one. Nothing else reads the environment.

set -u

GH=${GH:-gh}
LAYOUT=writing-hosts-analysis
TEMPLATE=c-energie/analysis-template

# The host is wherever this script sits, not wherever it was run from: run from another
# directory, a cwd-based root would nest the analysis repo in the wrong place.
ROOT=$(cd "$(dirname "$0")" && pwd) || exit 1
LAYOUT_FILE=$ROOT/layout.toml
GITIGNORE=$ROOT/.gitignore

say() { printf '%s\n' "$*"; }
die() { printf 'setup-nested.sh: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,9s/^# \{0,1\}//p' "$0"
}

# Single-quotes each argument, so a printed rerun command can be pasted back as-is.
quote() {
    out=
    for arg do
        out="$out '$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")'"
    done
    printf '%s' "${out# }"
}

# The value of a string key in a TOML file, or nothing. Handles what this script writes
# and a hand-written basic or literal string; tr strips the CR a Windows checkout adds.
toml_get() {
    tr -d '\r' < "$2" | sed -n \
        -e "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\(.*\)\"[[:space:]]*\(#.*\)\{0,1\}\$/\1/p" \
        -e "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*'\([^']*\)'[[:space:]]*\(#.*\)\{0,1\}\$/\1/p" \
        | head -n 1 | sed 's/\\"/"/g; s/\\\\/\\/g'
}

toml_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

is_empty_dir() {
    [ -d "$1" ] && [ -z "$(ls -A "$1")" ]
}

# ---- arguments --------------------------------------------------------------------------

FROM='' DIR='' OWNER='' NAME='' PUBLIC='' BACKEND=plotly
CREATE_FLAGS=

value() {
    [ $# -ge 2 ] || die "$1 needs a value"
}

while [ $# -gt 0 ]; do
    case $1 in
        --from)    value "$@"; FROM=$2; shift 2 ;;
        --dir)     value "$@"; DIR=$2; shift 2 ;;
        --owner)   value "$@"; OWNER=$2; CREATE_FLAGS="$CREATE_FLAGS --owner"; shift 2 ;;
        --name)    value "$@"; NAME=$2; CREATE_FLAGS="$CREATE_FLAGS --name"; shift 2 ;;
        --public)  PUBLIC=1; CREATE_FLAGS="$CREATE_FLAGS --public"; shift ;;
        --backend) value "$@"; BACKEND=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --)        shift; break ;;
        *)         die "unknown argument: $1 (see --help)" ;;
    esac
done
# What is left in "$@" goes to init.py.

case $BACKEND in
    plotly|matplotlib) ;;
    *) die "--backend takes plotly or matplotlib, not $BACKEND" ;;
esac

if [ -n "$FROM" ] && [ -n "$CREATE_FLAGS" ]; then
    die "${CREATE_FLAGS# } only apply when creating a repo, not with --from"
fi

if [ -n "$NAME" ]; then
    case $NAME in
        *[!A-Za-z0-9._-]*) die "--name may hold only letters, digits, '.', '_' and '-'" ;;
    esac
fi

# nested_dir is relative to the root and stays inside it: an absolute path or a '..'
# would put the "nested" repo outside the host, where the .gitignore line means nothing.
check_dir() {
    case $1 in
        ''|.|/*|*\\*|*:*) die "the nested directory must be a relative path inside this repo, not '$1'" ;;
    esac
    case /$1/ in
        */../*|*/./*|*/.git/*) die "the nested directory may not contain '.', '..' or '.git': '$1'" ;;
    esac
}

# ---- what to do -------------------------------------------------------------------------
# Everything that can refuse does so here, before anything is created or written.

[ -e "$ROOT/.git" ] || die "$ROOT is not the root of a git checkout"
command -v git >/dev/null 2>&1 || die "git is not installed"
command -v uv >/dev/null 2>&1 || die "uv is not installed: https://docs.astral.sh/uv/"

if [ -f "$LAYOUT_FILE" ]; then
    recorded=$(toml_get layout "$LAYOUT_FILE")
    [ "$recorded" = "$LAYOUT" ] ||
        die "layout.toml records layout '$recorded', not '$LAYOUT'; this script only sets up '$LAYOUT'"
    L_DIR=$(toml_get nested_dir "$LAYOUT_FILE"); L_DIR=${L_DIR%/}
    L_REMOTE=$(toml_get nested_remote "$LAYOUT_FILE")
    [ -n "$L_DIR" ] || die "layout.toml has no nested_dir"
    DIR=${DIR%/}
    if [ -n "$DIR" ] && [ "$DIR" != "$L_DIR" ]; then
        die "layout.toml already names nested_dir '$L_DIR'; refusing to set up a second one at '$DIR'"
    fi
    DIR=$L_DIR
    check_dir "$DIR"

    if [ -e "$ROOT/$DIR" ] && ! is_empty_dir "$ROOT/$DIR"; then
        # A rerun after a failed init.py or uv sync lands here, so say what is left.
        say "$DIR already exists; nothing to do."
        if [ -f "$ROOT/$DIR/init.py" ]; then
            say "Its init.py has not run yet:"
            say "  cd $(quote "$DIR") && uv run --no-project python init.py --backend $BACKEND"
        fi
        if [ ! -d "$ROOT/$DIR/.venv" ]; then
            say "It has no .venv yet:"
            say "  cd $(quote "$DIR") && uv sync --extra dev --extra notebooks --extra $BACKEND"
        fi
        exit 0
    fi

    if [ -n "$FROM" ]; then
        MODE=adopt
    elif [ -n "$CREATE_FLAGS" ]; then
        die "layout.toml already records the nested repo, so${CREATE_FLAGS} do not apply: run with no arguments to restore it, or use --from <src>"
    else
        [ -n "$L_REMOTE" ] || die "layout.toml has no nested_remote to restore $DIR from; use --from <src>"
        MODE=restore
        FROM=$L_REMOTE
    fi
else
    base=$(basename "$ROOT")
    if [ -n "$FROM" ]; then
        MODE=adopt
        DIR=${DIR:-$base-analysis}
    else
        MODE=create
        NAME=${NAME:-$base-analysis}
        DIR=${DIR:-$NAME}
    fi
    DIR=${DIR%/}
    check_dir "$DIR"
    if [ -e "$ROOT/$DIR" ] && ! is_empty_dir "$ROOT/$DIR"; then
        die "$DIR already exists and is not empty; choose another --dir"
    fi
fi

if [ "$MODE" = create ]; then
    command -v "$GH" >/dev/null 2>&1 ||
        die "creating a repo needs the GitHub CLI (gh), which is not installed. Install it and run 'gh auth login', or adopt an existing repo with --from <url>."
    "$GH" auth status >/dev/null 2>&1 ||
        die "gh is not signed in. Run 'gh auth login', or adopt an existing repo with --from <url>."
    if [ -z "$OWNER" ]; then
        # The owner of this repo's own origin, so the pair sit side by side on GitHub;
        # an origin elsewhere (Overleaf, say) says nothing about a GitHub owner.
        origin=$(git -C "$ROOT" remote get-url origin 2>/dev/null) || origin=
        case $origin in
            *github.com[:/]*/*) rest=${origin#*github.com[:/]}; OWNER=${rest%%/*} ;;
        esac
    fi
    if [ -z "$OWNER" ]; then
        OWNER=$("$GH" api user --jq .login 2>/dev/null) || OWNER=
        [ -n "$OWNER" ] || die "could not work out a GitHub owner; pass --owner"
    fi
    if "$GH" repo view "$OWNER/$NAME" >/dev/null 2>&1; then
        die "$OWNER/$NAME already exists on GitHub; adopt it with --from https://github.com/$OWNER/$NAME.git"
    fi
fi

# ---- clone ------------------------------------------------------------------------------

# An empty directory left by an earlier attempt is replaced rather than refused.
if is_empty_dir "$ROOT/$DIR"; then
    rmdir "$ROOT/$DIR" || exit 1
fi
mkdir -p "$(dirname "$ROOT/$DIR")" || exit 1

case $MODE in
    create)
        visibility=--private
        [ -z "$PUBLIC" ] || visibility=--public
        say "Creating $OWNER/$NAME from $TEMPLATE ..."
        # gh clones into ./<name>, so it runs in a scratch directory and the clone is moved
        # to DIR, which need not share the repo's name. --clone rather than a separate git
        # clone, because a repo made from a template is filled in asynchronously and gh
        # waits for it.
        stage=$ROOT/.setup-nested.$$
        mkdir "$stage" || exit 1
        if ! (cd "$stage" && "$GH" repo create "$OWNER/$NAME" --template "$TEMPLATE" "$visibility" --clone); then
            rm -rf "$stage"
            die "gh repo create failed. If $OWNER/$NAME now exists on GitHub, adopt it with: sh setup-nested.sh --from https://github.com/$OWNER/$NAME.git"
        fi
        mv "$stage/$NAME" "$ROOT/$DIR" ||
            die "created $OWNER/$NAME but could not move its clone from $stage to $DIR"
        rmdir "$stage" || die "moved the clone into $DIR but could not remove $stage; delete it, then rerun"
        ;;
    adopt|restore)
        say "Cloning $FROM into $DIR ..."
        git clone -- "$FROM" "$ROOT/$DIR" || die "git clone failed; nothing was changed here"
        ;;
esac

# ---- record the layout ------------------------------------------------------------------
# From here the nested repo exists, and on GitHub too when it was just created, so there is
# no rollback: a failure says which step to rerun, and rerunning this script finds the
# directory and reports what is left.

REMOTE=$(git -C "$ROOT/$DIR" remote get-url origin 2>/dev/null) || REMOTE=$FROM

# Step 1: gitignore the nested repo, once.
entry=/$DIR/
if ! { [ -f "$GITIGNORE" ] && tr -d '\r' < "$GITIGNORE" | grep -qxF "$entry"; }; then
    # shellcheck disable=SC2094 # tail reads the last byte before anything is appended
    {
        # A file with no final newline would glue the entry onto its last line.
        if [ -s "$GITIGNORE" ] && [ -n "$(tail -c 1 "$GITIGNORE")" ]; then
            printf '\n'
        fi
        printf '\n# The nested analysis repo (layout.toml). Its own repo: commit there, not here.\n%s\n' "$entry"
    } >> "$GITIGNORE" || die "step 1 failed: could not add $entry to .gitignore; add it by hand, then rerun"
fi

# Step 2: layout.toml. An existing one keeps its other lines and gets the new remote; it is
# only rewritten when that changes something.
if [ -f "$LAYOUT_FILE" ]; then
    new=$LAYOUT_FILE.tmp.$$
    V="nested_remote = \"$(toml_escape "$REMOTE")\"" awk '
        /^[ \t]*nested_remote[ \t]*=/ { if (!done) print ENVIRON["V"]; done = 1; next }
        { print }
        END { if (!done) print ENVIRON["V"] }
    ' "$LAYOUT_FILE" > "$new" || die "step 2 failed: could not write layout.toml"
    if cmp -s "$new" "$LAYOUT_FILE"; then
        rm -f "$new"
    else
        mv "$new" "$LAYOUT_FILE" || die "step 2 failed: could not write layout.toml"
    fi
else
    {
        say "# Written by setup-nested.sh. This document repo hosts its analysis repo in nested_dir:"
        say "# a separate repo with its own remote, gitignored here. Commit there, never here."
        say "# On a fresh clone, \`sh setup-nested.sh\` restores nested_dir from nested_remote."
        say "layout = \"$LAYOUT\""
        say "nested_dir = \"$(toml_escape "$DIR")\""
        say "nested_remote = \"$(toml_escape "$REMOTE")\""
    } > "$LAYOUT_FILE" || die "step 2 failed: could not write layout.toml"
fi

case $REMOTE in
    *://*|*@*:*) ;;
    *) say "Note: nested_remote is a local path ($REMOTE). A clone of this repo on another" \
           "machine cannot restore from it: give $DIR a hosted origin and put that URL in" \
           "layout.toml." ;;
esac

# ---- set up the nested repo -------------------------------------------------------------

doc_path=$ROOT
if command -v cygpath >/dev/null 2>&1; then
    doc_path=$(cygpath -m "$ROOT")   # Git Bash: the C:/... form Python on Windows reads
fi

init_cmd="uv run --no-project python init.py --backend $BACKEND${1+ $(quote "$@")}"
sync_cmd="uv sync --extra dev --extra notebooks --extra $BACKEND"

# Step 3: init.py, in the analysis repo's own uv env and attached to the terminal, since it
# asks questions. No --doc-repo: see the header. If it asks for the document repo anyway,
# the answer is printed here.
if [ -f "$ROOT/$DIR/init.py" ]; then
    say "Running $DIR/init.py. If it asks for the document repo, it is: $doc_path"
    if ! (cd "$ROOT/$DIR" && uv run --no-project python init.py --backend "$BACKEND" "$@"); then
        die "step 3 failed: init.py in $DIR. Rerun it, then step 4:
  cd $(quote "$DIR") && $init_cmd
  cd $(quote "$DIR") && $sync_cmd"
    fi
fi

# Step 4: the analysis repo's venv.
if ! (cd "$ROOT/$DIR" && uv sync --extra dev --extra notebooks --extra "$BACKEND"); then
    die "step 4 failed: uv sync in $DIR. Rerun it:
  cd $(quote "$DIR") && $sync_cmd"
fi

cat <<EOF

Done: $DIR is a nested repo, with its own remote ($REMOTE).

Commit here, in the document repo:
  git add layout.toml .gitignore && git commit -m "Host the analysis repo in $DIR"

Commit in $DIR separately, from inside it; nothing in it is tracked here:
  cd $(quote "$DIR") && git status

Until the analysis repo reads DOC_REPO from layout.toml, set it in $DIR/.env:
  DOC_REPO=$doc_path
EOF
