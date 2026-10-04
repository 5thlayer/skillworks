#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# publish.sh on a fixture: a clone of a local bare origin, and a fake `claude` that installs whatever
# origin/main holds. It touches neither GitHub nor the real plugin.
#
#   scripts/test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
failed=0

mkdir -p "$tmp/bin"
cat > "$tmp/bin/claude" << 'EOF'
#!/usr/bin/env bash
# plugin validate|marketplace update: pass. plugin update: install origin/main of $FAKE_ORIGIN.
echo "claude $*" >> "$FAKE_CALLS"
[[ "$1 $2" == "plugin update" ]] || exit 0
sha="$(git -C "$FAKE_ORIGIN" rev-parse main)"
version="$(git -C "$FAKE_ORIGIN" show main:.claude-plugin/plugin.json | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')"
printf '{"plugins":{"skillworks@skillworks":[{"scope":"user","version":"%s","gitCommitSha":"%s"}]}}' \
    "$version" "$sha" > "$SKILLWORKS_INSTALLED"
EOF
chmod +x "$tmp/bin/claude"

git init -q --bare -b main "$tmp/origin.git"
work="$tmp/work"
git clone -q "$tmp/origin.git" "$work" 2> /dev/null
mkdir -p "$work/.claude-plugin" "$work/scripts"
cp "$here/publish.sh" "$work/scripts/"
bump() { printf '{"name":"skillworks","version":"%s"}\n' "$1" > "$work/.claude-plugin/plugin.json"; }
commit() { git -C "$work" add -A && git -C "$work" -c user.name=t -c user.email=t@t commit -qm "$1"; }
bump 0.1.0; commit init; git -C "$work" push -q origin main

export FAKE_ORIGIN="$tmp/origin.git" FAKE_CALLS="$tmp/calls" SKILLWORKS_INSTALLED="$tmp/installed.json"
export PATH="$tmp/bin:$PATH"

check() { # <name> <exit status> <expected substring> [args...]
    local name=$1 status=$2 want=$3; shift 3
    local got code=0
    : > "$FAKE_CALLS"
    got="$("$work/scripts/publish.sh" "$@" 2>&1)" || code=$?
    if [[ $got == *"$want"* && $code == "$status" ]]; then
        echo "ok   $name"
    else
        echo "FAIL $name: wanted exit $status and \"$want\", got exit $code and:"; sed 's/^/     /' <<< "$got"; failed=1
    fi
}

check "reports a plugin that isn't installed" 1 "the installed plugin is not origin/main's"
check "installs origin/main with nothing to push" 0 "installed 0.1.0" --publish
check "reports when all is published and installed" 0 "published and installed."

echo change > "$work/README.md"
check "reports uncommitted changes" 1 "uncommitted changes in the checkout"
check "refuses to publish uncommitted changes" 1 "uncommitted changes; commit them first." --publish
commit change
check "reports an unpushed commit" 1 "1 commit(s) not pushed"
check "reports a push without a version bump" 1 "version 0.1.0 is not above origin's 0.1.0"
check "refuses to push without a version bump" 1 "bump it" --publish
[[ $(git -C "$tmp/origin.git" rev-parse main) != $(git -C "$work" rev-parse HEAD) ]] \
    && echo "ok   pushes nothing it refuses" || { echo "FAIL pushed despite refusing"; failed=1; }

bump 0.1.1; commit bump
check "pushes, then updates the marketplace and the plugin" 0 "installed 0.1.1" --publish
if [[ $(cat "$FAKE_CALLS") == $'claude plugin validate .\nclaude plugin marketplace update skillworks\nclaude plugin update skillworks@skillworks' ]]; then
    echo "ok   validates, then updates the marketplace before the plugin"
else
    echo "FAIL calls were:"; sed 's/^/     /' "$FAKE_CALLS"; failed=1
fi
check "is in sync after publishing" 0 "published and installed."

mkdir -p "$work/skills/broken"
printf '#!/bin/sh\nexit 1\n' > "$work/skills/broken/test.sh"; chmod +x "$work/skills/broken/test.sh"
bump 0.1.2; commit broken
check "refuses to push when a skill's tests fail" 1 "skills/broken/test.sh fails" --publish

git -C "$work" checkout -q -b side
check "refuses to publish off main" 1 "not on main." --publish

exit $failed
