#!/bin/sh
# tests/setup-nested.test.sh — setup-nested.sh, and init.py's guard for a nested repo.
#
#   make test-setup        (or: sh tests/setup-nested.test.sh)
#
# No network, and nothing outside a scratch directory: gh and uv are stubs on PATH that
# log their arguments, and the analysis repo is a local git repo. GH names a command that
# does not exist to make gh missing, since a real one is usually installed beside git.
# Strict POSIX sh, so it runs under dash and Git Bash alike.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
WORK=${TMPDIR:-/tmp}/setup-nested-test.$$
trap 'rm -rf "$WORK"' EXIT
trap 'exit 1' INT TERM
mkdir -p "$WORK/bin" || exit 1

FAILS=0
ok()   { printf 'ok    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
check() {   # check DESCRIPTION COMMAND...
    desc=$1; shift
    if "$@"; then ok "$desc"; else fail "$desc"; fi
}

g() { git -c user.name=test -c user.email=test@example.invalid -c init.defaultBranch=main "$@"; }

# Every path and its checksum, .git included: "unchanged" means byte-for-byte.
snapshot() {
    (cd "$1" && find . -print | LC_ALL=C sort | while IFS= read -r f; do
        if [ -f "$f" ]; then cksum < "$f" | sed "s|^|$f |"; else printf '%s\n' "$f"; fi
    done)
}

same() { [ "$1" = "$2" ]; }
fails() { ! "$@"; }
cloned() { [ -e "$1/.git" ] && [ -f "$1/pyproject.toml" ]; }
count_entry() { tr -d '\r' < "$1/.gitignore" | grep -cxF "$2"; }

# ---- stubs ------------------------------------------------------------------------------

cat > "$WORK/bin/uv" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG/uv.log"
exit 0
EOF

# auth status succeeds unless GH_AUTH=fail; repo view finds nothing; repo create clones the
# local stand-in for analysis-template unless GH_CREATE=fail.
cat > "$WORK/bin/gh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG/gh.log"
case "$1 $2" in
    "auth status") [ "${GH_AUTH:-ok}" = ok ] ;;
    "api user")    echo stub-user ;;
    "repo view")   exit 1 ;;
    "repo create") [ "${GH_CREATE:-ok}" = ok ] || exit 1
                   exec git clone -q "$STUB_TEMPLATE" "${3#*/}" ;;
    *)             exit 2 ;;
esac
EOF
chmod +x "$WORK/bin/uv" "$WORK/bin/gh"
PATH=$WORK/bin:$PATH
STUB_LOG=$WORK
STUB_TEMPLATE=$WORK/template
export PATH STUB_LOG STUB_TEMPLATE

# ---- fixtures ---------------------------------------------------------------------------

# A document repo holding only the script, under the name given.
new_host() {
    rm -rf "${WORK:?}/$1"
    mkdir -p "$WORK/$1"
    cp "$REPO/setup-nested.sh" "$WORK/$1/"
    printf 'main.pdf\n' > "$WORK/$1/.gitignore"
    (cd "$WORK/$1" && g init -q && g add . && g commit -q -m host) || exit 1
}

# A local analysis repo, with an init.py so step 3 runs.
new_analysis() {
    mkdir -p "$1"
    printf '[project]\nname = "x"\n' > "$1/pyproject.toml"
    printf 'print("init")\n' > "$1/init.py"
    (cd "$1" && g init -q && g add . && g commit -q -m analysis) || exit 1
}

new_analysis "$WORK/src-analysis"
new_analysis "$WORK/template"

run() {   # run HOST ARGS... — from $WORK, so the root has to come from the script's own path
    host=$1; shift
    : > "$WORK/uv.log"; : > "$WORK/gh.log"
    (cd "$WORK" && sh "$WORK/$host/setup-nested.sh" "$@" < /dev/null > "$WORK/out.log" 2>&1)
}

# ---- adopt ------------------------------------------------------------------------------

H=$WORK/my-thesis
N=$H/my-thesis-analysis
new_host my-thesis
src_before=$(snapshot "$WORK/src-analysis")

check "adopt: --from a local repo exits 0" run my-thesis --from "$WORK/src-analysis"
check "adopt: clones into <name>-analysis" cloned "$N"
check "adopt: gitignores it" same "$(count_entry "$H" /my-thesis-analysis/)" 1
check "adopt: writes layout.toml" grep -qx 'layout = "writing-hosts-analysis"' "$H/layout.toml"
check "adopt: records nested_dir" grep -qx 'nested_dir = "my-thesis-analysis"' "$H/layout.toml"
check "adopt: records nested_remote" grep -q '^nested_remote = ".*src-analysis"$' "$H/layout.toml"
check "adopt: runs init.py with --backend plotly" \
    grep -qx 'run --no-project python init.py --backend plotly' "$WORK/uv.log"
check "adopt: does not pass --doc-repo" fails grep -q -- --doc-repo "$WORK/uv.log"
check "adopt: syncs the venv" \
    grep -qx 'sync --extra dev --extra notebooks --extra plotly' "$WORK/uv.log"
check "adopt: leaves the source untouched" same "$(snapshot "$WORK/src-analysis")" "$src_before"

host_before=$(snapshot "$H")
check "adopt, again: exits 0" run my-thesis --from "$WORK/src-analysis"
check "adopt, again: .gitignore entry still once" same "$(count_entry "$H" /my-thesis-analysis/)" 1
check "adopt, again: changes nothing" same "$(snapshot "$H")" "$host_before"

# ---- restore ----------------------------------------------------------------------------

rm -rf "$N"
check "restore: no arguments exits 0" run my-thesis
check "restore: re-clones from nested_remote" cloned "$N"
check "restore: .gitignore entry still once" same "$(count_entry "$H" /my-thesis-analysis/)" 1

host_before=$(snapshot "$H")
check "restore, present: exits 0" run my-thesis
check "restore, present: changes nothing" same "$(snapshot "$H")" "$host_before"
check "restore, present: runs nothing" test ! -s "$WORK/uv.log"

# ---- create -----------------------------------------------------------------------------

new_host paper
(cd "$WORK/paper" && g remote add origin https://github.com/someone/paper.git)
host_before=$(snapshot "$WORK/paper")

export GH=gh-not-installed-$$
check "create, gh missing: exits non-zero" fails run paper
unset GH
check "create, gh missing: names --from" grep -q -- '--from <url>' "$WORK/out.log"
check "create, gh missing: changes nothing" same "$(snapshot "$WORK/paper")" "$host_before"

export GH_AUTH=fail
check "create, gh signed out: exits non-zero" fails run paper
unset GH_AUTH
check "create, gh signed out: names gh auth login" grep -q 'gh auth login' "$WORK/out.log"
check "create, gh signed out: creates no repo" fails grep -q 'repo create' "$WORK/gh.log"
check "create, gh signed out: changes nothing" same "$(snapshot "$WORK/paper")" "$host_before"

export GH_CREATE=fail
check "create, gh repo create fails: exits non-zero" fails run paper
unset GH_CREATE
check "create, gh repo create fails: changes nothing" same "$(snapshot "$WORK/paper")" "$host_before"

check "create: exits 0" run paper --dir analysis
check "create: owner from origin, private, from the template" grep -qx \
    'repo create someone/paper-analysis --template c-energie/analysis-template --private --clone' \
    "$WORK/gh.log"
check "create: --dir need not match --name" test -f "$WORK/paper/analysis/pyproject.toml"
check "create: no scratch directory left" same "$(ls -A "$WORK/paper" | grep '^\.setup-nested')" ""
check "create: records nested_dir" grep -qx 'nested_dir = "analysis"' "$WORK/paper/layout.toml"

# ---- refusals ---------------------------------------------------------------------------

new_host busy
mkdir "$WORK/busy/taken" && : > "$WORK/busy/taken/file"
host_before=$(snapshot "$WORK/busy")
check "refuse: a non-empty --dir" fails run busy --from "$WORK/src-analysis" --dir taken
check "refuse: a non-empty --dir changes nothing" same "$(snapshot "$WORK/busy")" "$host_before"

new_host other
printf 'layout = "writing-hosts-analysis"\nnested_dir = "elsewhere"\nnested_remote = "%s"\n' \
    "$WORK/src-analysis" > "$WORK/other/layout.toml"
host_before=$(snapshot "$WORK/other")
check "refuse: layout.toml naming a different nested_dir" \
    fails run other --from "$WORK/src-analysis" --dir mine
check "refuse: a different nested_dir changes nothing" same "$(snapshot "$WORK/other")" "$host_before"

# ---- init.py leaves a nested repo alone -------------------------------------------------

python=
for p in python3 python; do
    if "$p" -c 'import sys; sys.exit(sys.version_info[0] != 3)' > /dev/null 2>&1; then
        python=$p; break
    fi
done

# A stamped document repo keeps this test after its init.py has run and deleted itself.
if [ ! -f "$REPO/init.py" ]; then
    printf 'SKIP  init.py guard: init.py has already run and deleted itself\n'
elif [ -z "$python" ]; then
    printf 'SKIP  init.py guard: no Python 3 on PATH\n'
else
    # Spelt in pieces, so nothing that greps this checkout for placeholders finds them here.
    title='<<''DOCUMENT_TITLE>>' author='<<''AUTHOR>>'
    D=$WORK/doc
    mkdir -p "$D/nested-analysis" "$D/unnamed"
    cp "$REPO/init.py" "$D/"
    printf '%s by %s\n' "$title" "$author" > "$D/main.tex"
    printf 'layout = "writing-hosts-analysis"\nnested_dir = "nested-analysis"\n' > "$D/layout.toml"
    for f in nested-analysis/README.md nested-analysis/pyproject.toml nested-analysis/init.py \
             unnamed/notes.md; do
        printf '%s by %s\n' "$title" "$author" > "$D/$f"
    done
    (cd "$D/nested-analysis" && g init -q) && (cd "$D/unnamed" && g init -q)
    nested_before=$(snapshot "$D/nested-analysis")
    unnamed_before=$(snapshot "$D/unnamed")

    check "init.py: runs" sh -c 'cd "$1" && "$2" init.py --title T --author A < /dev/null > /dev/null' \
        sh "$D" "$python"
    check "init.py: fills the document's own placeholders" grep -qx 'T by A' "$D/main.tex"
    check "init.py: leaves layout.toml's nested_dir byte-for-byte" \
        same "$(snapshot "$D/nested-analysis")" "$nested_before"
    check "init.py: leaves any other directory with a .git alone" \
        same "$(snapshot "$D/unnamed")" "$unnamed_before"
fi

# -----------------------------------------------------------------------------------------

if [ "$FAILS" -ne 0 ]; then
    printf '\n%s failed. Output of the last run:\n' "$FAILS"
    cat "$WORK/out.log"
    exit 1
fi
printf '\nAll passed.\n'
