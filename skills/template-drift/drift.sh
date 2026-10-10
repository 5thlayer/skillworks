#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# Each mod's shared files against libworks' template, 5thlayer/libworks on GitHub: the tooling, docs and
# config every Library starts from, with the mod's names read as the template's example ones (examplelib,
# ExampleLib, Example Library), whether the mod renamed them or not. Per-mod files (build, changelog, glossary, README, ADRs) are left out.
# The template's own text is read the same way, since it may name a mod: Groundworks, as an example.
#
#   drift.sh [--release-tooling] [mod checkout...]
#
# --release-tooling compares only what a release runs: release.sh, upload.py, its tests, upload.env.
# With no checkout, it takes Groundworks, Beltworks, Wireworks, Craftworks, Pipeworks and Voidworks.
# It prints, per checkout, "same" or each file that differs (with its line count) or is missing.
# LIBWORKS points it at a local template checkout instead of a fresh clone.
set -uo pipefail

release_only=
[[ ${1:-} == --release-tooling ]] && { release_only=1; shift; }

if [[ -n ${LIBWORKS:-} ]]; then
    template=$LIBWORKS
else
    template="$(mktemp -d)"
    trap 'rm -rf "$template"' EXIT
    git clone -q --depth 1 https://github.com/5thlayer/libworks.git "$template" 2> /dev/null \
        || { echo "drift: could not clone 5thlayer/libworks" >&2; exit 2; }
fi

release_tooling=(scripts/release.sh scripts/upload.py scripts/tests/standin.py scripts/tests/test_upload.py publish/upload.env)
if [[ -n $release_only ]]; then
    files=("${release_tooling[@]}")
else
    mapfile -t files < <(git -C "$template" ls-files | grep -vE '^(src/|docs/adr/|CHANGELOG\.md|CONTEXT\.md|GLOSSARY\.md|README\.md|CLAUDE\.md|build\.gradle|gradle\.properties|settings\.gradle|REUSE\.toml|scripts/fill-template\.sh)')
fi

checkouts=("$@")
if (( ${#checkouts[@]} == 0 )); then
    for m in groundworks beltworks wireworks craftworks pipeworks voidworks; do checkouts+=("$HOME/minecraft_mods/$m"); done
fi

property() { sed -n "s/^$2 *= *//p" "$1/gradle.properties" 2> /dev/null | head -1; }
for dir in "${checkouts[@]}"; do
    [[ -d $dir ]] || continue
    artifact="$(property "$dir" archives_name)" name="$(property "$dir" mod_name)"
    class="$(sed -n 's/^\(.\)/\U\1/p' <<< "${artifact:-examplelib}")"
    report=()
    for f in "${files[@]}"; do
        [[ -f $template/$f ]] || continue
        if [[ ! -f $dir/$f ]]; then report+=("missing $f"); continue; fi
        if [[ $f == *.jar ]]; then cmp -s "$template/$f" "$dir/$f" || report+=("$f differs"); continue; fi
        # The display name first, since it is often the class name too; and each repo's tag prefix is its own.
        # Both sides read the mod's names as the example ones, so a mod the template names matches itself.
        as_example=("${name:+s/$name \([0-9]\)/Example Library \1/g; s/= $name\$/= Example Library/;} ${artifact:+s/$artifact/examplelib/g; s/$class/ExampleLib/g}")
        n=$(diff -I '^tag=' <(sed "${as_example[0]}" "$template/$f") <(sed "${as_example[0]}" "$dir/$f") | grep -c '^[<>]')
        (( n > 0 )) && report+=("$f: $n lines differ")
    done
    echo "== $(basename "$dir")"
    if (( ${#report[@]} == 0 )); then echo "  same"; else printf '  %s\n' "${report[@]}"; fi
done
