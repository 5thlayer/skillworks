#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# Each mod's shared files against libworks' template, 5thlayer/libworks on GitHub, as its
# fill-template.sh leaves a new Module: the docs, config and CI every Module starts from, without the
# plugin, runtime and tooling tests libworks keeps, and with build.gradle and the CI pinned to the
# released libworks plugin. The mod's names are read as the template's example ones (examplelib,
# ExampleLib, Example Module), whether the mod renamed them or not. Per-mod files (build, changelog,
# glossary, README, ADRs) are left out. The template's own text is read the same way, since it may name
# a mod: Groundworks, as an example.
#
#   drift.sh [--release-tooling] [mod checkout...]
#
# It also reports a mod without the template's Works tab: a listener on WorksTab.KEY, a CreativeTabTests
# that calls WorksTabCheck, or the required libworks dependency in neoforge.mods.toml; --release-tooling
# leaves these out, as it does a CLAUDE.md that does not name the steward skill and a steward skill
# of the mod's own.
#
# --release-tooling compares only what a release reads from the mod: the libworks plugin version
# build.gradle applies, which carries the release and upload tasks, and upload.env.
# With no checkout, it takes Groundworks, Beltworks, Wireworks, Craftworks, Pipeworks, Fieldworks, Voidworks and Gearworks.
# NOTICE is compared only as far as the template's runs, the preamble every Module keeps above its own
# credits.
# It prints, per checkout, "same", or the plugin version it applies against the template's, each part
# of the Works tab it lacks, and each file that differs (with its line count) or is missing.
# LIBWORKS points it at a local template checkout, at its last commit, instead of a fresh clone.
set -uo pipefail

release_only=
[[ ${1:-} == --release-tooling ]] && { release_only=1; shift; }

template="$(mktemp -d)"
trap 'rm -rf "$template"' EXIT
git clone -q --depth 1 "${LIBWORKS:-https://github.com/5thlayer/libworks.git}" "$template" 2> /dev/null \
    || { echo "drift: could not clone ${LIBWORKS:-5thlayer/libworks}" >&2; exit 2; }
# Filled under names no mod has, which read back as the example ones below.
(cd "$template" && bash scripts/fill-template.sh drifttemplate DriftTemplate "Drift Template") > /dev/null 2>&1 \
    || { echo "drift: the template's fill-template.sh failed" >&2; exit 2; }
filled='s/Drift Template/Example Module/g; s/drifttemplate/examplelib/g; s/DriftTemplate/ExampleLib/g'

if [[ -n $release_only ]]; then
    files=(publish/upload.env)
else
    mapfile -t files < <(git -C "$template" ls-files | grep -vE '^(src/|docs/adr/|CHANGELOG\.md|CONTEXT\.md|GLOSSARY\.md|README\.md|CLAUDE\.md|build\.gradle|gradle\.properties|settings\.gradle|REUSE\.toml)')
fi

checkouts=("$@")
if (( ${#checkouts[@]} == 0 )); then
    for m in groundworks beltworks wireworks craftworks pipeworks fieldworks voidworks gearworks; do checkouts+=("$HOME/minecraft_mods/$m"); done
fi

property() { sed -n "s/^$2 *= *//p" "$1/gradle.properties" 2> /dev/null | head -1; }
plugin() { sed -n "s/^ *id 'io\.github\.5thlayer\.libworks\.module' version '\([^']*\)'.*/\1/p" "$1/build.gradle" 2> /dev/null | head -1; }
template_plugin="$(plugin "$template")"
for dir in "${checkouts[@]}"; do
    [[ -d $dir ]] || continue
    artifact="$(property "$dir" archives_name)" name="$(property "$dir" mod_name)"
    class="$(sed -n 's/^\(.\)/\U\1/p' <<< "${artifact:-examplelib}")"
    report=()
    version="$(plugin "$dir")"
    if [[ -z $version ]]; then report+=("applies no libworks plugin (template: $template_plugin)")
    elif [[ $version != "$template_plugin" ]]; then report+=("libworks plugin $version (template: $template_plugin)"); fi
    if [[ -z $release_only ]]; then
        grep -rqE 'getTabKey\(\) *[!=]= *WorksTab\.KEY|WorksTab\.KEY *[!=]= *[[:alnum:]_]+\.getTabKey\(\)' "$dir/src/main/java" 2> /dev/null \
            || report+=("no Works tab listener (on WorksTab.KEY)")
        grep -rqE --include=CreativeTabTests.java 'WorksTabCheck\.' "$dir/src" 2> /dev/null \
            || report+=("no CreativeTabTests calling WorksTabCheck")
        # The libworks entry's own lines, up to the next table.
        sed -n '/^ *modId *= *"libworks"/,/^ *\[/p' "$dir/src/main/resources/META-INF/neoforge.mods.toml" 2> /dev/null \
            | grep -qE '^ *type *= *"required"' || report+=("neoforge.mods.toml does not require libworks")
        # The template's CLAUDE.md lets a session steward a PR under skillworks' steward skill, the one source of it.
        grep -qF '`steward` skill' "$dir/CLAUDE.md" 2> /dev/null || report+=("CLAUDE.md does not name the steward skill")
        [[ -e $dir/.claude/skills/steward ]] && report+=("has its own .claude/skills/steward, which hides skillworks' one")
    fi
    for f in "${files[@]}"; do
        [[ -f $template/$f ]] || continue
        if [[ ! -f $dir/$f ]]; then report+=("missing $f"); continue; fi
        if [[ $f == *.jar ]]; then cmp -s "$template/$f" "$dir/$f" || report+=("$f differs"); continue; fi
        # The display name first, since it is often the class name too; and each repo's tag prefix is its own.
        # Both sides read the mod's names as the example ones, so a mod the template names matches itself.
        as_example=("${name:+s/$name \([0-9]\)/Example Module \1/g; s/= $name\$/= Example Module/;} ${artifact:+s/$artifact/examplelib/g; s/$class/ExampleLib/g}")
        lines=; [[ $f == NOTICE ]] && lines=$(wc -l < "$template/$f")
        n=$(diff -I '^tag=' <(sed "$filled" "$template/$f" | sed "${as_example[0]}") <(sed "${as_example[0]}${lines:+;${lines}q}" "$dir/$f") | grep -c '^[<>]')
        (( n > 0 )) && report+=("$f: $n lines differ")
    done
    echo "== $(basename "$dir")"
    if (( ${#report[@]} == 0 )); then echo "  same"; else printf '  %s\n' "${report[@]}"; fi
done
