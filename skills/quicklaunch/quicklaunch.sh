#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# Launch the game for the checkout the working directory is in, into its most recent save, unless a
# client is already running:
#   - a packwiz pack (a pack.toml at or above the working directory, or the one folder under the repo
#     root that has one) opens its CurseForge profile, with the local builds of the mods beside the repo,
#     through launch_pack.py, which refuses while that game runs;
#   - a mod repo (a Gradle build whose client run takes -PquickPlay, as libworks' convention plugin's
#     does) opens its dev client.
#
#   quicklaunch.sh [--dry-run] [save name]
#
# The game is detached and its output goes to $QUICKLAUNCH_LOG (default: a temp file, printed).
# Gradle runs with --no-daemon, so no idle daemon outlives the game.
# --dry-run prints what it found and the commands it would run, and launches nothing.
set -euo pipefail

dry=
[[ ${1:-} == --dry-run ]] && { dry=1; shift; }
save="${1:-}"

fail() { echo "quicklaunch: $*" >&2; exit 1; }

start="$(pwd -P)"
root="$(git rev-parse --show-toplevel 2> /dev/null)" || fail "not in a git checkout."
cd "$root"

new_log() { echo "${QUICKLAUNCH_LOG:-$(mktemp -t quicklaunch.XXXXXX.log)}"; }

here="$(dirname "$(readlink -f "$0")")"

is_pack() { [[ -f $1/pack.toml ]] && grep -q '^pack-format = "packwiz:' "$1/pack.toml"; }

# The pack the working directory is in, or the one folder under the repo root with a pack.toml.
pack=
dir="$start"
while :; do
    is_pack "$dir" && { pack="$dir"; break; }
    [[ $dir == "$root" || $dir == / ]] && break
    dir="$(dirname "$dir")"
done
if [[ -z $pack ]]; then
    packs=()
    for dir in "$root"/*/; do is_pack "${dir%/}" && packs+=("${dir%/}"); done
    if ((${#packs[@]} > 1)); then
        fail "$root has several packs; run from inside one: $(printf '%s ' "${packs[@]#"$root"/}" | sed 's/ $//')."
    fi
    ((${#packs[@]} == 1)) && pack="${packs[0]}"
fi

# launch_pack.py finds the pack's profile, picks the save, syncs the profile and refuses a second game.
if [[ -n $pack ]]; then
    run=(python3 "$here/launch_pack.py" --pack "$pack" --beside "$(dirname "$root")")
    if [[ -n $dry ]]; then
        echo "root: $root"
        echo "pack: $pack"
        echo "run: $(printf '%q ' "${run[@]}" ${save:+"$save"} | sed 's/ $//')"
        exec "${run[@]}" --dry-run ${save:+"$save"}
    fi
    log="$(new_log)"
    nohup "${run[@]}" ${save:+"$save"} > "$log" 2>&1 &
    game=$!
    for _ in $(seq 1 300); do
        if grep -aq "Sound engine started" "$log"; then
            echo "$(sed -n 's/^name = "\(.*\)"/\1/p' "$pack/pack.toml") up, $(grep -a -m1 '^save: ' "$log" | sed 's/^save: //'); log: $log"
            exit 0
        fi
        if ! kill -0 "$game" 2> /dev/null; then
            grep -a '^launch: ' "$log" >&2 || tail -20 "$log" >&2
            fail "the pack did not start; log: $log"
        fi
        sleep 1
    done
    fail "the pack is not up after 300s; log: $log"
fi

[[ -f gradlew && -f build.gradle ]] || fail "$root is not a mod repo nor a packwiz pack."
# libworks' convention plugin adds the hook to the client run of every build that applies it.
grep -qE "id ['\"]io\.github\.5thlayer\.libworks\.module['\"]|gradleProperty\(['\"]quickPlay" build.gradle \
    || fail "build.gradle has no -PquickPlay hook on its client run; apply libworks' convention plugin, io.github.5thlayer.libworks.module."
saves=run/saves

if [[ -n $save ]]; then
    [[ -f $saves/$save/level.dat ]] || fail "no save \"$save\" in $saves."
else
    latest="$(ls -t "$saves"/*/level.dat 2> /dev/null | head -1 || true)"
    [[ -n $latest ]] && save="$(basename "$(dirname "$latest")")"
fi

# Gradle needs a Java: JAVA_HOME's, or the `java` on PATH, which under mise is a shim that fails in a
# checkout with no Java pinned. Say how to pin one, rather than let gradlew fail on it in the log.
if [[ -z ${JAVA_HOME:-} ]] && ! java_err="$(java -version 2>&1)"; then
    want="$(grep -ohE 'JavaLanguageVersion\.of\([0-9]+' build.gradle 2> /dev/null | head -1 | grep -oE '[0-9]+$' || true)"
    fail "no Java for $root: $(grep -m1 -iE 'error' <<< "$java_err" || head -1 <<< "$java_err")"$'\n'\
"  pin one in the checkout: (cd $root && mise use java@temurin-${want:-<version>}), or set JAVA_HOME."
fi

# The Gradle daemon a build starts stays up, idle, for three hours after it, and every checkout of the
# same Gradle version shares it, so there is none of ours to stop afterwards without stopping another
# session's: --no-daemon starts none, and the runClient build's JVMs end when the game does.
run=(sh ./gradlew --no-daemon runClient ${save:+"-PquickPlay=$save"})

# A second client of a mod checkout fights the first over run/, and a world opened in both is corrupted.
running="net.neoforged.devlaunch.Main.*@$root/build/moddev/clientRunProgramArgs.txt"

if [[ -n $dry ]]; then
    echo "root: $root"
    echo "save: ${save:-none, to the menu}"
    echo "run: $(printf '%q ' "${run[@]}" | sed 's/ $//')"
    if pgrep -f "$running" > /dev/null; then echo "a client is already running: a real run refuses."; fi
    exit 0
fi

# A client of this checkout may be the user's, mid-game, so it is theirs to close, never ours to kill.
clients="$(pgrep -f "$running" | paste -sd, - || true)"
[[ -n $clients ]] && fail "a client is already running (pid $clients); close the game first."

[[ -z $save ]] && echo "quicklaunch: no save found; launching to the menu." >&2
log="$(new_log)"

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
