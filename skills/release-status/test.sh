#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# groundworks.py on fixture jars: the Groundworks it says the game loads, and which jars refuse it.
# tag-on-main.sh on fixture repos: whether it warns of a latest tag off origin/main's history.
#
#   skills/release-status/test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
check_py="$here/groundworks.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failed=0

jar() { # <file> <range or -> [nested version]: a mod jar requiring Groundworks in <range>, nesting one
    python3 - "$tmp/$1" "$2" "${3:-}" << 'PY'
import json, sys, zipfile
path, rng, nested = sys.argv[1:]
with zipfile.ZipFile(path, "w") as z:
    toml = 'modLoader = "javafml"\n[[mods]]\nmodId = "x"\n'
    if rng != "-":
        toml += f'[[dependencies.x]]\nmodId = "groundworks"\ntype = "required"\nversionRange = "{rng}"\n'
    z.writestr("META-INF/neoforge.mods.toml", toml)
    if nested:
        z.writestr("META-INF/jarjar/metadata.json", json.dumps({"jars": [{
            "identifier": {"group": "io.github.5thlayer", "artifact": "groundworks"},
            "version": {"range": rng, "artifactVersion": nested}, "path": f"META-INF/jarjar/groundworks-{nested}.jar"}]}))
PY
}

check() { # <name> <exit status> <expected substring> <jar>...
    local name=$1 status=$2 want=$3; shift 3
    local got code=0
    got="$(cd "$tmp" && python3 "$check_py" "$@" 2>&1)" || code=$?
    if [[ $got == *"$want"* && $code == "$status" ]]; then
        echo "ok   $name"
    else
        echo "FAIL $name: wanted exit $status and \"$want\", got exit $code and:"; sed 's/^/     /' <<< "$got"; failed=1
    fi
}

jar belt.jar "[0.5,0.6)" 0.5.1
jar wire.jar "[0.5.2,0.6)" 0.5.2
jar craft.jar "[0.5.4,)"
jar craft-capped.jar "[0.5.4,0.6)"
jar plain.jar -
jar groundworks-0.5.4.jar -
jar groundworks-0.6.0.jar -

check "loads the highest nested Groundworks" 0 "loaded: 0.5.2 (nested in wire.jar" belt.jar wire.jar
check "fails a jar whose lower bound is above it" 1 "FAIL craft.jar accepts [0.5.4,), not 0.5.2" belt.jar wire.jar craft.jar
check "a Groundworks jar of its own counts, and wins" 0 "loaded: 0.5.4 (groundworks-0.5.4.jar" belt.jar wire.jar craft.jar groundworks-0.5.4.jar
check "fails a jar whose upper bound is below it" 1 "FAIL belt.jar accepts [0.5,0.6), not 0.6.0" belt.jar groundworks-0.6.0.jar
check "an open upper bound takes a new minor" 0 "ok   craft.jar accepts [0.5.4,)" craft.jar groundworks-0.6.0.jar
check "a capped range refuses it" 1 "FAIL craft-capped.jar" craft-capped.jar groundworks-0.6.0.jar
check "fails when nothing offers a Groundworks a jar requires" 1 "none offered" craft.jar
check "says nothing for jars without Groundworks" 0 "" plain.jar

# A repo whose latest tag is at <commit>, with origin/main at <main>.
repo() { # <dir>
    git init -q "$tmp/$1" && cd "$tmp/$1" || exit 2
    git config user.email t@t && git config user.name t
    echo a > f && git add f && GIT_COMMITTER_DATE=2026-01-02T00:00Z git commit -qm one
}
tag_check() { # <name> <expected output, or "" for none> <dir>
    local got; got="$("$here/tag-on-main.sh" "$tmp/$3")"
    if [[ ( -z $2 && -z $got ) || ( -n $2 && $got == *"$2"* ) ]]; then
        echo "ok   $1"
    else
        echo "FAIL $1: wanted \"$2\", got \"$got\""; failed=1
    fi
}

(repo untagged; git update-ref refs/remotes/origin/main HEAD)
tag_check "says nothing without a tag" "" untagged

(repo onmain; git tag v0.1.0; git update-ref refs/remotes/origin/main HEAD)
tag_check "says nothing for a tag on origin/main" "" onmain

(repo rewritten; git tag v0.1.0; GIT_COMMITTER_DATE=2026-01-03T00:00Z git commit -q --amend -m rewritten
 git update-ref refs/remotes/origin/main HEAD)
same=$(git -C "$tmp/rewritten" rev-parse --short origin/main)
tag_check "names the commit with a rewritten tag's tree" "tag v0.1.0 is not on origin/main's history; origin/main's $same has its tree" rewritten

(repo diverged; git update-ref refs/remotes/origin/main HEAD; echo b > f
 GIT_COMMITTER_DATE=2026-01-03T00:00Z git commit -qam two; git tag x-v0.2.0; git checkout -q origin/main 2> /dev/null)
tag_check "warns with no commit of its tree" "tag x-v0.2.0 is not on origin/main's history, and no commit there has its tree" diverged

(repo older; git checkout -q -b stray; echo b > f
 GIT_COMMITTER_DATE=2026-01-01T00:00Z git commit -qam stray; git tag v0.0.1; git checkout -q -; echo c > f
 GIT_COMMITTER_DATE=2026-01-04T00:00Z git commit -qam three; git update-ref refs/remotes/origin/main HEAD; git tag v0.2.0)
tag_check "checks only the latest tag" "" older

exit $failed
