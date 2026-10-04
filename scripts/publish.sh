#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# Where a skillworks change stands on its way to the installed plugin, and the steps that carry it
# there. The marketplace is this repo's main on GitHub, so a commit reaches sessions only once it is
# pushed, the local marketplace clone is updated, and the plugin is updated from it.
#
#   scripts/publish.sh            report the checkout, origin/main and the installed plugin; exit 1
#                                 when something is not yet published or installed
#   scripts/publish.sh --publish  check, push main, update the marketplace and the plugin
#
# Every push must raise .claude-plugin/plugin.json's version above origin/main's: the plugin is
# installed by version, so an unbumped push never reaches the installed plugin.
set -euo pipefail

publish=
[[ ${1:-} == --publish ]] && publish=1

plugin=skillworks@skillworks marketplace=skillworks
installed_json="${SKILLWORKS_INSTALLED:-$HOME/.claude/plugins/installed_plugins.json}"

fail() { echo "publish: $*" >&2; exit 1; }

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

version_at() { # <rev>: plugin.json's version at that commit
    git show "$1:.claude-plugin/plugin.json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])'
}
installed() { # the installed plugin's "<version> <sha>", or nothing
    [[ -f $installed_json ]] || return 0
    python3 - "$installed_json" "$plugin" << 'EOF'
import json, sys
for e in json.load(open(sys.argv[1])).get("plugins", {}).get(sys.argv[2], []):
    if e.get("scope") == "user":
        print(e.get("version", "?"), e.get("gitCommitSha", "?"))
EOF
}
newer() { # <a> <b>: a is a higher version than b
    [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1) == "$1" ]]
}

git fetch -q origin main
head="$(git rev-parse HEAD)" origin="$(git rev-parse origin/main)"
read -r inst_version inst_sha <<< "$(installed)" || true
ahead="$(git rev-list --count origin/main..HEAD)" behind="$(git rev-list --count HEAD..origin/main)"

echo "checkout:   $(version_at HEAD) ${head:0:7} on $(git branch --show-current), $ahead ahead of origin"
echo "origin:     $(version_at origin/main) ${origin:0:7}"
echo "installed:  ${inst_version:-none} ${inst_sha:0:7}"

todo=()
[[ -n $(git status --porcelain) ]] && todo+=("uncommitted changes in the checkout")
(( behind > 0 )) && todo+=("the checkout is $behind behind origin/main; pull first")
if (( ahead > 0 )); then
    todo+=("$ahead commit(s) not pushed")
    newer "$(version_at HEAD)" "$(version_at origin/main)" \
        || todo+=("plugin.json's version $(version_at HEAD) is not above origin's $(version_at origin/main); bump it")
fi
[[ ${inst_sha:-} != "$origin" ]] && todo+=("the installed plugin is not origin/main's")

if [[ -z $publish ]]; then
    if (( ${#todo[@]} == 0 )); then echo "published and installed."; exit 0; fi
    printf '  - %s\n' "${todo[@]}"
    exit 1
fi

[[ $(git branch --show-current) == main ]] || fail "not on main."
[[ -z $(git status --porcelain) ]] || fail "uncommitted changes; commit them first."
(( behind == 0 )) || fail "the checkout is behind origin/main; pull first."
if (( ahead > 0 )); then
    newer "$(version_at HEAD)" "$(version_at origin/main)" \
        || fail "plugin.json's version $(version_at HEAD) is not above origin's $(version_at origin/main); bump it in its own commit or the last one."
    claude plugin validate . > /dev/null || fail "claude plugin validate . fails."
    for t in skills/*/test.sh; do
        [[ -e $t ]] || continue
        "$t" > /dev/null || fail "$t fails; run it for the details."
    done
    git push -q origin main
    echo "pushed ${head:0:7} to origin/main."
fi

claude plugin marketplace update "$marketplace"
claude plugin update "$plugin"

read -r inst_version inst_sha <<< "$(installed)" || true
[[ ${inst_sha:-} == "$head" ]] || fail "the installed plugin is ${inst_sha:-none}, not ${head:0:7}; see the update's output above."
echo "installed $inst_version (${head:0:7}); restart Claude Code sessions to load it."
