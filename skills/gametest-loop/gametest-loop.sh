#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# Run the game tests of the mod repo the working directory is in many times over, with Gradle only once.
# One build compiles the mod and yields the game-test server JVM's command line; every run then starts
# that JVM directly, so the loop holds no Gradle client, daemon or slot that other checkouts' builds need.
# The command line comes from libworks' plugin, whose writeGameTestServerCommand task writes it to
# build/moddev; with a plugin older than that task, runGameTestServer runs the tests once and the command
# line is captured from /proc while the server runs.
#
#   gametest-loop.sh [runs]          build through Gradle, then run the server directly [runs] times
#                                    (default 10)
#   gametest-loop.sh --reuse [runs]  skip Gradle: loop the last command line, refused once the sources
#                                    are newer than it
#   gametest-loop.sh --classpath     print the server's classpath, for a javac check without Gradle
#
# Each run's log is build/gametest-loop/run<i>.log. The server exits with its number of failed required
# tests. Exit 0 when every run passed, 1 when any run failed, crashed or timed out, 2 on a refusal.
# GAMETEST_LOOP_TIMEOUT caps a direct run (default 600s).
set -euo pipefail

fail() { echo "gametest-loop: $*" >&2; exit 2; }

mode=loop
case ${1:-} in
    --reuse) mode=reuse; shift ;;
    --classpath) mode=classpath; shift ;;
esac
runs="${1:-10}"
[[ $runs =~ ^[1-9][0-9]*$ ]] || fail "runs must be a positive number, not \"$runs\"."
per_run="${GAMETEST_LOOP_TIMEOUT:-600}"

root="$(git rev-parse --show-toplevel 2> /dev/null)" || fail "not in a git checkout."
cd "$root"
[[ -f gradlew && -f build.gradle ]] || fail "$root is not a mod repo."

state="$root/build/gametest-loop"
cmd_file="$state/server.cmd" gradle_log="$state/gradle.log"
written="$root/build/moddev/gameTestServerRunCommand.txt"
# The server's identity: libworks' plugin passes it this checkout's own program-args file, and runs it in
# run/gametest. Both together pick out this checkout's server, never the shell that searches for it.
args_arg="@$root/build/moddev/gameTestServerRunProgramArgs.txt"
server_cwd="$root/run/gametest"

servers() { # this checkout's running game-test servers, one pid a line
    local pid
    for pid in $(pgrep -f gameTestServerRunProgramArgs || true); do
        [[ $(readlink "/proc/$pid/cwd" 2> /dev/null) == "$server_cwd" ]] || continue
        tr '\0' '\n' < "/proc/$pid/cmdline" 2> /dev/null | grep -qxF -- "$args_arg" && echo "$pid"
    done
    return 0
}

if [[ $mode == classpath ]]; then
    [[ -f $cmd_file ]] || fail "no command line in $state; run without --classpath first."
    grep -A1 -xE -- '-cp|-classpath|--class-path' "$cmd_file" | tail -1
    exit 0
fi

# A second server in run/gametest fights the first over its world.
running="$(servers | paste -sd, -)"
[[ -n $running ]] && fail "a game-test server of $root is already running (pid $running); let it finish first."

mkdir -p "$state"

if [[ $mode == reuse ]]; then
    [[ -f $cmd_file ]] || fail "no command line in $state; run without --reuse first."
    newer="$(find src build.gradle gradle.properties settings.gradle -newer "$cmd_file" -type f 2> /dev/null | head -1 || true)"
    [[ -z $newer ]] || fail "$newer changed since the build; run without --reuse to rebuild through Gradle."
fi

# Stopped, it stops what it started: its Gradle build or server, and this checkout's server, which
# none ran when it started. Nothing else, however alike.
pids=()
trap 'kill "${pids[@]}" $(servers) 2> /dev/null; exit 130' INT TERM

classify() { # <log> <exit code>: "passed", "<n> failed: <tests>", "timed out" or "crashed, exit <n>"
    local log=$1 code=$2 tests
    if [[ $code == 124 ]]; then echo "timed out after ${per_run}s"
    elif grep -aqE 'All [0-9]+ required tests passed' "$log"; then echo passed
    elif grep -aqE '[0-9]+ required tests failed' "$log"; then
        tests="$(grep -aoE '^ +- [a-z0-9_.-]+:[^:]+' "$log" | sed -E 's/^ +- //' | sort -u | paste -sd, - | sed 's/,/, /g')"
        echo "$(grep -aoE '[0-9]+ required tests failed' "$log" | tail -1 | grep -oE '^[0-9]+') failed: ${tests:-?}"
    else echo "crashed, exit $code"
    fi
}

gradle() { # <task>: start it in the background, where a stop reaches it
    # --no-daemon: the build's JVMs end with it, so no daemon of ours stays behind to be stopped, and
    # the shared daemons of other checkouts are never touched.
    sh ./gradlew --no-daemon --console=plain "$1" > "$gradle_log" 2>&1 < /dev/null &
    pids=("$!")
}
gradle_failed() { # <what>
    grep -a -A5 "What went wrong" "$gradle_log" >&2 || tail -20 "$gradle_log" >&2
    fail "$1; log: $gradle_log"
}

if [[ $mode == loop ]]; then
    rm -f "$cmd_file" "$written"
    echo "gradle: building; log: $gradle_log"
    gradle writeGameTestServerCommand
    code=0; wait "${pids[0]}" || code=$?
    pids=()
    if [[ $code == 0 && -f $written ]]; then
        cp "$written" "$cmd_file"
        echo "gradle: built; the plugin wrote the server's command line"
    elif grep -aq "'writeGameTestServerCommand' not found" "$gradle_log"; then
        echo "gradle: the plugin writes no command line; running the tests once to capture it"
        gradle runGameTestServer
        while kill -0 "${pids[0]}" 2> /dev/null; do
            if [[ ! -f $cmd_file ]]; then
                pid="$(servers | head -1)"
                if [[ -n $pid ]]; then
                    tr '\0' '\n' < "/proc/$pid/cmdline" > "$cmd_file.tmp" && mv "$cmd_file.tmp" "$cmd_file"
                fi
            fi
            sleep 0.2
        done
        code=0; wait "${pids[0]}" || code=$?
        pids=()
        [[ -f $cmd_file ]] || gradle_failed "Gradle started no game-test server to capture"
        echo "gradle: $(classify "$gradle_log" "$code")"
    else
        gradle_failed "the build failed"
    fi
fi

mapfile -t cmd < "$cmd_file"
# Where ModDevGradle runs the server, and the report's folder, both of which its Gradle task makes first.
mkdir -p "$server_cwd" "$root/build/reports"
cd "$server_cwd"
passed=0
declare -A failed_in=()
for i in $(seq 1 "$runs"); do
    log="$state/run$i.log"
    start=$SECONDS
    timeout "$per_run" "${cmd[@]}" > "$log" 2>&1 < /dev/null &
    pids=("$!")
    code=0; wait "${pids[0]}" || code=$?
    pids=()
    result="$(classify "$log" "$code")"
    echo "run $i/$runs: $result ($((SECONDS - start))s)"
    if [[ $result == passed ]]; then
        passed=$((passed + 1))
    elif [[ $result == *" failed: "* ]]; then
        IFS=, read -ra tests <<< "${result#*: }"
        for t in "${tests[@]}"; do t="${t# }"; failed_in[$t]="${failed_in[$t]:+${failed_in[$t]} }$i"; done
    else
        failed_in["($result)"]="${failed_in["($result)"]:+${failed_in["($result)"]} }$i"
    fi
done

echo "$passed of $runs direct runs passed; logs: $state"
for t in "${!failed_in[@]}"; do
    n="$(wc -w <<< "${failed_in[$t]}")"
    echo "  $t: $n of $runs (run ${failed_in[$t]// /, })"
done | sort
[[ $passed == "$runs" ]]
