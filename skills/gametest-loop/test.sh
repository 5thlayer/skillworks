#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# The loop on fixture repos whose gradlew starts a fake game-test server, as libworks' plugin starts the
# real one: what it captures, how it reads each run, when it skips or refuses Gradle, and what it refuses.
# It runs no Gradle and no Minecraft.
#
#   skills/gametest-loop/test.sh
set -uo pipefail

loop="$(cd "$(dirname "$0")" && pwd)/gametest-loop.sh"
tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'pkill -f "$tmp/" 2> /dev/null; rm -rf "$tmp"' EXIT
failed=0

# The fake server: the n-th start (counted in $tmp/starts) prints and exits as line n of $tmp/results says:
# "pass", "fail <test>...", "crash" or "hang".
cat > "$tmp/java" << EOF
#!/usr/bin/env bash
n=\$(( \$(cat "$tmp/starts" 2> /dev/null || echo 0) + 1 )); echo \$n > "$tmp/starts"
read -ra r <<< "\$(sed -n "\${n}p" "$tmp/results")"
sleep 0.5
case \${r[0]:-pass} in
    pass) echo "All 3 required tests passed :)"; exit 0 ;;
    fail) echo "\$(( \${#r[@]} - 1 )) required tests failed :("
          for t in "\${r[@]:1}"; do echo "   - mod:\$t: Expected true"; done; exit \$(( \${#r[@]} - 1 )) ;;
    crash) echo "Exception in thread main"; exit 1 ;;
    hang) sleep 30 ;;
esac
EOF
chmod +x "$tmp/java"

mkrepo() { # <dir>: a mod repo whose gradlew runs the fake server as runGameTestServer does
    local d=$1
    mkdir -p "$d/src/main" "$d/run/gametest"; git -C "$d" init -q; echo "plugins {}" > "$d/build.gradle"
    cat > "$d/gradlew" << EOF
#!/bin/sh
echo "\$*" >> "$tmp/gradle-calls"
[ -f "$tmp/compile-error" ] && { echo "* What went wrong:"; echo "Compilation failed"; exit 1; }
cd "$d/run/gametest" && "$tmp/java" -Dfml.modFolders=mod%%$d/build/classes/java/main -cp "$d/a.jar:$d/b.jar" \
    net.neoforged.devlaunch.Main "@$d/build/moddev/gameTestServerRunProgramArgs.txt"
EOF
    touch -t 202601010000 "$d/src/main/A.java" "$d/build.gradle"
}

check() { # <name> <exit code> <expected substring> [args...]: run the loop in $mod with $results
    local name=$1 status=$2 want=$3; shift 3
    local got code=0
    printf '%s\n' "${results[@]}" > "$tmp/results"; rm -f "$tmp/starts" "$tmp/gradle-calls"
    got="$(cd "$mod/src" && GAMETEST_LOOP_TIMEOUT=3 "$loop" "$@" 2>&1)" || code=$?
    if [[ $got$'\n' == *"$want"* && $code == "$status" ]]; then
        echo "ok   $name"
    else
        echo "FAIL $name: wanted exit $status and \"$want\", got exit $code and:"; sed 's/^/     /' <<< "$got"; failed=1
    fi
}

mod="$tmp/mod"; mkrepo "$mod"

results=(pass pass pass pass)
check "runs Gradle once, then the server directly" 0 "3 of 3 direct runs passed" 3
check "Gradle runs without a daemon" 0 "" 1
grep -qx -- "--no-daemon --console=plain runGameTestServer" "$tmp/gradle-calls" && [[ $(wc -l < "$tmp/gradle-calls") == 1 ]] \
    && echo "ok   gradle: called once, with --no-daemon" || { echo "FAIL gradle calls:"; cat "$tmp/gradle-calls"; failed=1; }
check "captures the server's command line, one argument a line" 0 "" 1
grep -qx "@$mod/build/moddev/gameTestServerRunProgramArgs.txt" "$mod/build/gametest-loop/server.cmd" \
    && echo "ok   capture: the program-args argument" || { echo "FAIL capture:"; cat "$mod/build/gametest-loop/server.cmd"; failed=1; }
check "--classpath prints the captured classpath" 0 "$mod/a.jar:$mod/b.jar"$'\n' --classpath

results=(pass pass "fail solar_a solar_b" pass "fail solar_a")
check "reports the Gradle run" 1 "gradle: passed" 4
check "names a run's failed tests" 1 "run 2/4: 2 failed: mod:solar_a, mod:solar_b" 4
check "counts each failed test across the runs" 1 "  mod:solar_a: 2 of 4 (run 2, 4)" 4

results=("fail solar_a" pass)
check "reads a failing Gradle run" 0 "gradle: 1 failed: mod:solar_a" 1

results=(pass crash hang pass)
check "reads a run with no summary as a crash" 1 "run 1/3: crashed, exit 1" 3
check "stops a hung run at the timeout" 1 "run 2/3: timed out after 3s" 3
check "goes on after a hung run" 1 "1 of 3 direct runs passed" 3

results=(pass pass)
check "--reuse skips Gradle" 0 "2 of 2 direct runs passed" --reuse 2
[[ ! -f $tmp/gradle-calls ]] && echo "ok   --reuse: no Gradle call" || { echo "FAIL --reuse called Gradle"; failed=1; }
touch "$mod/src/main/A.java"
check "--reuse refuses sources newer than the capture" 2 "src/main/A.java changed since the capture" --reuse

touch "$tmp/compile-error"
check "refuses when Gradle starts no server" 2 "Compilation failed" 1
rm "$tmp/compile-error"
check "--reuse refuses with no capture" 2 "no capture in" --reuse

echo hang > "$tmp/results"; rm -f "$tmp/starts"
(cd "$mod/run/gametest" && exec "$tmp/java" "@$mod/build/moddev/gameTestServerRunProgramArgs.txt") &
sleep 0.2
check "refuses while a server of the checkout runs" 2 "is already running" 1
kill %1 2> /dev/null; wait 2> /dev/null

bare="$tmp/bare"; mkdir -p "$bare"; git -C "$bare" init -q
got="$(cd "$bare" && "$loop" 2>&1)"; code=$?
[[ $code == 2 && $got == *"is not a mod repo"* ]] && echo "ok   refuses a repo that is not a mod repo" \
    || { echo "FAIL not a mod repo: exit $code: $got"; failed=1; }

exit $failed
