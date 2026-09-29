#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# Launch the game for the checkout the working directory is in, into its most recent save, unless a
# client is already running:
#   - a mod repo (a Gradle build whose client run takes -PquickPlay) opens its dev client;
#   - the Pack (scripts/launch.py beside data/pack/local-jars.json) installs its jar and opens the pack.
#
#   quicklaunch.sh [--dry-run] [save name]
#
# The game is detached and its output goes to $QUICKLAUNCH_LOG (default: a temp file, printed).
# --dry-run prints what it found and the commands it would run, and launches nothing.
set -euo pipefail

dry=
[[ ${1:-} == --dry-run ]] && { dry=1; shift; }
save="${1:-}"

fail() { echo "quicklaunch: $*" >&2; exit 1; }

root="$(git rev-parse --show-toplevel 2> /dev/null)" || fail "not in a git checkout."
cd "$root"

if [[ -f scripts/launch.py && -f data/pack/local-jars.json ]]; then
    mode=pack saves=saves
elif [[ -f gradlew && -f build.gradle ]]; then
    grep -qE "gradleProperty\(['\"]quickPlay" build.gradle \
        || fail "build.gradle has no -PquickPlay hook on its client run; see libworks' build.gradle."
    mode=mod saves=run/saves
else
    fail "$root is neither a mod repo nor the Pack."
fi

if [[ -n $save ]]; then
    [[ -f $saves/$save/level.dat ]] || fail "no save \"$save\" in $saves."
else
    latest="$(ls -t "$saves"/*/level.dat 2> /dev/null | head -1 || true)"
    [[ -n $latest ]] && save="$(basename "$(dirname "$latest")")"
fi

# The Pack's saves know one player; a fresh name or UUID makes FTB Quests complete its opening chapter
# and grant the starting kit again. So the player is the user's, from the environment or the Pack's
# gitignored player.env, and never a guess.
from_env() { # <key>: its value in player.env, as a shell would read a plain KEY=value line
    tr -d '\r' < player.env \
        | sed -nE "s/^[[:space:]]*(export[[:space:]]+)?$1[[:space:]]*=[[:space:]]*//p" | head -1 \
        | sed -E "s/[[:space:]]+\$//; s/^\"(.*)\"\$/\1/; s/^'(.*)'\$/\1/"
}
if [[ $mode == pack ]]; then
    if [[ -f player.env ]]; then
        git check-ignore -q player.env \
            || fail "$root/player.env is not gitignored; add it to .gitignore before it holds your player."
        name="${PF_PLAYER_NAME:-$(from_env PF_PLAYER_NAME)}" uuid="${PF_PLAYER_UUID:-$(from_env PF_PLAYER_UUID)}"
    else
        name="${PF_PLAYER_NAME:-}" uuid="${PF_PLAYER_UUID:-}"
    fi
    [[ -n $name && -n $uuid ]] \
        || fail "no player: write PF_PLAYER_NAME=<name> and PF_PLAYER_UUID=<uuid> to $root/player.env, gitignored."
fi

if [[ $mode == pack ]]; then
    run=(python3 scripts/launch.py ${save:+--quickPlaySingleplayer "$save"})
else
    run=(sh ./gradlew runClient ${save:+"-PquickPlay=$save"})
fi

# A second client of a mod checkout fights the first over run/, and a world opened in both is
# corrupted. Under the Pack, swapping the jar under a live client breaks class loading, and looks like
# a code bug; the game runs on CurseForge's bundled Java, not the JDK Gradle uses, so match that only.
if [[ $mode == pack ]]; then
    running="curseforge/Install/java/java-runtime-epsilon/Contents/Home/bin/java"
else
    running="net.neoforged.devlaunch.Main.*@$root/build/moddev/clientRunProgramArgs.txt"
fi

if [[ -n $dry ]]; then
    echo "mode: $mode"
    echo "root: $root"
    echo "save: ${save:-none, to the menu}"
    if [[ $mode == pack ]]; then
        echo "player: $name $uuid"
        echo "run: ./gradlew :factoryworks_core:installToPack -q"
    fi
    echo "run: $(printf '%q ' "${run[@]}" | sed 's/ $//')"
    if pgrep -f "$running" > /dev/null; then echo "a client is already running: a real run refuses."; fi
    exit 0
fi

pgrep -f "$running" > /dev/null && fail "a client is already running; close the game first."

[[ -z $save ]] && echo "quicklaunch: no save found; launching to the menu." >&2
log="${QUICKLAUNCH_LOG:-$(mktemp -t quicklaunch).log}"

if [[ $mode == pack ]]; then
    ./gradlew :factoryworks_core:installToPack -q
    PF_PLAYER_NAME=$name PF_PLAYER_UUID=$uuid nohup "${run[@]}" > "$log" 2>&1 &
    launcher=$!
    player=
    for _ in $(seq 1 30); do
        player="$(grep -m1 -o 'launching as [^ ]*' "$log" 2> /dev/null || true)"
        [[ -n $player ]] && break
        kill -0 "$launcher" 2> /dev/null || { tail -20 "$log" >&2; fail "the pack did not start; log: $log"; }
        sleep 1
    done
    [[ -n $player ]] || fail "no 'launching as' line after 30s; log: $log"
    [[ $player == "launching as $name" ]] || fail "expected $name, got '${player#launching as }'"
    echo "jar installed; ${save:+opening \"$save\" }$player; log: $log"
else
    nohup "${run[@]}" > "$log" 2>&1 &
    gradle=$!
    up=
    for _ in $(seq 1 300); do
        grep -aq "Sound engine started" "$log" && { up=1; break; }
        if ! kill -0 "$gradle" 2> /dev/null; then
            grep -a -A5 "What went wrong" "$log" >&2 || tail -20 "$log" >&2
            fail "the client did not start; log: $log"
        fi
        sleep 1
    done
    [[ -n $up ]] || fail "the client is not up after 300s; log: $log"
    echo "client up${save:+, opening \"$save\"}; log: $log"
fi
