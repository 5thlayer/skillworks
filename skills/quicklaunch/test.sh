#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# The launcher's choices, through --dry-run on fixture repos: which repo it takes a checkout for, the
# save it picks, the command it would run, and what it refuses. It launches nothing.
#
#   skills/quicklaunch/test.sh
set -uo pipefail

launcher="$(cd "$(dirname "$0")" && pwd)/quicklaunch.sh"
tmp="$(cd "$(mktemp -d)" && pwd -P)" # git prints the resolved path: /private/var, not /var
trap 'rm -rf "$tmp"' EXIT
failed=0

check() { # <name> <0 if it launches, 1 if it refuses> <expected substring> <dir> [args...]
    local name=$1 status=$2 want=$3 dir=$4; shift 4
    local got code=0
    got="$(cd "$dir" && env -u PF_PLAYER_NAME -u PF_PLAYER_UUID ${ENV:-} "$launcher" --dry-run "$@" 2>&1)" || code=$?
    if [[ $got$'\n' == *"$want"* && $code == "$status" ]]; then
        echo "ok   $name"
    else
        echo "FAIL $name: wanted exit $status and \"$want\", got exit $code and:"; sed 's/^/     /' <<< "$got"; failed=1
    fi
}

mod="$tmp/mod"
mkdir -p "$mod/run/saves/Old" "$mod/run/saves/New World" "$mod/src"
git -C "$mod" init -q
touch "$mod/gradlew"
echo "programArguments.addAll providers.gradleProperty('quickPlay')" > "$mod/build.gradle"
touch -t 202601010000 "$mod/run/saves/Old/level.dat"
touch -t 202602010000 "$mod/run/saves/New World/level.dat"

check "mod: takes a Gradle build with the quickPlay hook" 0 "mode: mod" "$mod"
check "mod: runs from the repo root, even from a subdirectory" 0 "root: $mod" "$mod/src"
check "mod: opens the most recent save, its name one argument" 0 "run: sh ./gradlew runClient -PquickPlay=New\\ World"$'\n' "$mod"
check "mod: opens the save it is given" 0 "run: sh ./gradlew runClient -PquickPlay=Old"$'\n' "$mod" Old
check "mod: refuses a save that isn't there" 1 "no save \"Nope\"" "$mod" Nope

bare="$tmp/bare"
mkdir -p "$bare"; git -C "$bare" init -q; touch "$bare/gradlew"; echo "// takes no quickPlay" > "$bare/build.gradle"
check "mod: refuses a build without the quickPlay hook" 1 "no -PquickPlay hook" "$bare"

nosave="$tmp/nosave"
mkdir -p "$nosave"; git -C "$nosave" init -q; touch "$nosave/gradlew"; cp "$mod/build.gradle" "$nosave/"
check "mod: with no save, launches to the menu" 0 "run: sh ./gradlew runClient"$'\n' "$nosave"

pack="$tmp/pack"
mkdir -p "$pack/scripts" "$pack/data/pack" "$pack/saves/World"
git -C "$pack" init -q
touch "$pack/gradlew" "$pack/scripts/launch.py" "$pack/data/pack/local-jars.json" "$pack/saves/World/level.dat"
check "pack: refuses without a player" 1 "player.env" "$pack"
printf 'PF_PLAYER_NAME=someone\nPF_PLAYER_UUID=00000000-0000-0000-0000-000000000001\n' > "$pack/player.env"
check "pack: refuses a player.env git would commit" 1 "not gitignored" "$pack"
echo player.env > "$pack/.gitignore"
check "pack: takes the Pack" 0 "mode: pack" "$pack"
check "pack: reads the player from player.env" 0 "player: someone 00000000-0000-0000-0000-000000000001"$'\n' "$pack"
check "pack: installs the jar first" 0 "run: ./gradlew :planetaryfactory_core:installToPack -q" "$pack"
check "pack: opens the most recent save" 0 "run: python3 scripts/launch.py --quickPlaySingleplayer World"$'\n' "$pack"
ENV="PF_PLAYER_NAME=other" check "pack: the environment overrides player.env, one variable at a time" 0 \
    "player: other 00000000-0000-0000-0000-000000000001"$'\n' "$pack"
printf 'export PF_PLAYER_NAME="someone"\r\nPF_PLAYER_UUID = '"'"'u-1'"'"'  \r\n' > "$pack/player.env"
check "pack: reads export, quotes, spaces and CRLF in player.env" 0 "player: someone u-1"$'\n' "$pack"

none="$tmp/none"
mkdir -p "$none"; git -C "$none" init -q
check "refuses a repo that is neither" 1 "neither a mod repo nor the Pack" "$none"

exit $failed
