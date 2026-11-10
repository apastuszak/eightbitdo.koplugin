#!/usr/bin/env bash
# Check the plugin and build its installable archives.
#
#   scripts/build.sh          run every check, then create or refresh archives
#   scripts/build.sh --check  run every check without writing anything (CI)
#
# Checks: version consistency, README copies, Lua syntax, both test profiles,
# and that dist/ archives contain exactly the current plugin folder. A released
# versioned archive is never rewritten: if the plugin changed, bump the version.
set -euo pipefail

cd "$(dirname "$0")/.."
PLUGIN=eightbitdo.koplugin
DIST=dist

mode=build
case "${1:-}" in
    --check) mode=check ;;
    "") ;;
    *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

fail() { echo "error: $*" >&2; exit 1; }
step() { echo "==> $*"; }

required="luajit unzip"
[ "$mode" = build ] && required="$required zip"
for tool in $required; do
    command -v "$tool" >/dev/null || fail "$tool is required"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

version=$(sed -n 's/^ *version = "\([^"]*\)".*/\1/p' "$PLUGIN/_meta.lua")
[ -n "$version" ] || fail "no version found in $PLUGIN/_meta.lua"
step "Checking version $version"
grep -qxF "local VERSION = \"$version\"" "$PLUGIN/main.lua" \
    || fail "VERSION in $PLUGIN/main.lua does not match _meta.lua ($version)"
grep -qF "**$version**" README.md || fail "README.md does not name build **$version**"
grep -qF "eightbitdo-$version.koplugin.zip" README.md \
    || fail "README.md does not name eightbitdo-$version.koplugin.zip"
grep -qF "**v$version**" README.md || fail "README.md does not mention **v$version**"
grep -qF "\"v$version\"" tests/run.lua || fail "tests/run.lua does not check Help for v$version"
grep -qF "## [$version]" CHANGELOG.md || fail "CHANGELOG.md has no [$version] section"
cmp -s README.md "$PLUGIN/README.md" || fail "README.md and $PLUGIN/README.md differ"
cmp -s LICENSE "$PLUGIN/LICENSE" || fail "LICENSE and $PLUGIN/LICENSE differ"

step "Checking plugin folder contents"
stray=$(find "$PLUGIN" \( -name '*.luac' -o -name '.*' \) -print)
[ -z "$stray" ] || fail "remove local files from $PLUGIN before packaging: $stray"

step "Checking Lua syntax"
for source in "$PLUGIN"/*.lua; do
    luajit -b "$source" "$tmp/$(basename "$source").luac" || fail "syntax error in $source"
done

step "Running tests"
luajit tests/run.lua
luajit tests/run.lua micro

# Succeeds when the archive is intact, holds only $PLUGIN/, and matches it.
matches_source() {
    local dir
    dir=$(mktemp -d "$tmp/unzip.XXXXXX")
    unzip -tq "$1" >/dev/null 2>&1 || return 1
    unzip -q "$1" -d "$dir" || return 1
    [ "$(ls -A "$dir")" = "$PLUGIN" ] || return 1
    diff -r "$dir/$PLUGIN" "$PLUGIN" >/dev/null
}

latest="$DIST/eightbitdo.koplugin.zip"
versioned="$DIST/eightbitdo-$version.koplugin.zip"
step "Checking archives"
if [ -e "$versioned" ]; then
    matches_source "$versioned" || fail "$versioned is a released archive and no longer \
matches $PLUGIN; bump the version instead of changing a release"
elif [ "$mode" = check ]; then
    fail "$versioned is missing; run scripts/build.sh"
else
    zip -qX -r "$tmp/new.zip" "$PLUGIN" -x '*.luac' -x '*/.*'
    mv "$tmp/new.zip" "$versioned"
    echo "created $versioned"
fi
if [ -e "$latest" ] && matches_source "$latest"; then
    :
elif [ "$mode" = check ]; then
    fail "$latest does not match $PLUGIN; run scripts/build.sh"
else
    cp "$versioned" "$latest"
    echo "updated $latest"
fi
matches_source "$versioned" || fail "$versioned failed verification"
matches_source "$latest" || fail "$latest failed verification"
step "OK: $latest and $versioned match $PLUGIN"
