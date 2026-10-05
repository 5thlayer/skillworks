#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# groundworks.py on fixture jars: the Groundworks it says the game loads, and which jars refuse it.
#
#   skills/release-status/test.sh
set -uo pipefail

check_py="$(cd "$(dirname "$0")" && pwd)/groundworks.py"
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

exit $failed
