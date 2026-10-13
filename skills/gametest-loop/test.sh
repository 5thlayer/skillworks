#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# The loop on a fixture repo whose gradlew stands in for libworks' plugin, a current one that writes the
# game-test server's command line or an older one that only runs the server, and whose server is fake:
# where it gets the command line, how it reads each run, when it skips or refuses Gradle, and what it
# refuses. It runs no Gradle and no Minecraft.
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

# The fixture: its gradlew's writeGameTestServerCommand writes the command line, unless $tmp/old-plugin
# exists, and its runGameTestServer starts the server from run/gametest.
mod="$tmp/mod"
mkdir -p "$mod/src/main"; git -C "$mod" init -q; echo "plugins {}" > "$mod/build.gradle"
cat > "$mod/gradlew" << EOF
#!/bin/sh
echo "\$*" >> "$tmp/gradle-calls"
[ -f "$tmp/compile-error" ] && { echo "* What went wrong:"; echo "Compilation failed"; exit 1; }
set -- "$tmp/java" -Dfml.modFolders=mod%%$mod/build/classes/java/main -cp "$mod/a.jar:$mod/b.jar" \
    net.neoforged.devlaunch.Main "@$mod/build/moddev/gameTestServerRunProgramArgs.txt" "\$@"
case "\$*" in
    *writeGameTestServerCommand)
        [ -f "$tmp/old-plugin" ] && { echo "* What went wrong:"; echo "Task 'writeGameTestServerCommand' not found in root project 'mod'."; exit 1; }
        mkdir -p "$mod/build/moddev"
        for a in "\$@"; do case "\$a" in -*-daemon|--console=*|write*) ;; *) echo "\$a" ;; esac; done \
            > "$mod/build/moddev/gameTestServerRunCommand.txt" ;;
    *runGameTestServer)
        mkdir -p "$mod/run/gametest"; cd "$mod/run/gametest" && "\$1" "\$2" "\$3" "\$4" "\$5" "\$6" ;;
esac
EOF
touch -t 202601010000 "$mod/src/main/A.java" "$mod/build.gradle"

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
calls() { # <name> <the Gradle calls, one a line>
    if [[ $(cat "$tmp/gradle-calls" 2> /dev/null) == "$2" ]]; then echo "ok   $1"
    else echo "FAIL $1: Gradle was called with:"; sed 's/^/     /' "$tmp/gradle-calls" 2> /dev/null; failed=1
    fi
}

results=(pass pass pass)
check "takes the command line the plugin writes, and runs every run directly" 0 "3 of 3 direct runs passed" 3
calls "the plugin's task: one Gradle build, with no daemon" "--no-daemon --console=plain writeGameTestServerCommand"
check "--classpath prints the server's classpath" 0 "$mod/a.jar:$mod/b.jar"$'\n' --classpath

results=(pass "fail solar_a solar_b" pass "fail solar_a")
check "names a run's failed tests" 1 "run 2/4: 2 failed: mod:solar_a, mod:solar_b" 4
check "counts each failed test across the runs" 1 "  mod:solar_a: 2 of 4 (run 2, 4)" 4

results=(crash hang pass)
check "reads a run with no summary as a crash" 1 "run 1/3: crashed, exit 1" 3
check "stops a hung run at the timeout" 1 "run 2/3: timed out after 3s" 3
check "goes on after a hung run" 1 "1 of 3 direct runs passed" 3

results=(pass pass)
check "--reuse skips Gradle" 0 "2 of 2 direct runs passed" --reuse 2
calls "--reuse: no Gradle call" ""
touch "$mod/src/main/A.java"
check "--reuse refuses sources newer than the build" 2 "src/main/A.java changed since the build" --reuse

touch "$tmp/old-plugin"
results=(pass pass pass)
check "an older plugin: runs the tests through Gradle once, and captures the server" 0 "2 of 2 direct runs passed" 2
calls "an older plugin: its task missing, then the run" \
    "--no-daemon --console=plain writeGameTestServerCommand"$'\n'"--no-daemon --console=plain runGameTestServer"
grep -qx "@$mod/build/moddev/gameTestServerRunProgramArgs.txt" "$mod/build/gametest-loop/server.cmd" \
    && echo "ok   an older plugin: the capture holds the server's arguments" \
    || { echo "FAIL capture:"; cat "$mod/build/gametest-loop/server.cmd"; failed=1; }
check "an older plugin: reports the Gradle run" 0 "gradle: passed" 1
results=("fail solar_a" pass)
check "an older plugin: reads a failing Gradle run" 0 "gradle: 1 failed: mod:solar_a" 1
rm "$tmp/old-plugin"

touch "$tmp/compile-error"
check "refuses when the build fails" 2 "Compilation failed" 1
rm "$tmp/compile-error"
check "--reuse refuses with no command line" 2 "no command line in" --reuse

echo hang > "$tmp/results"; rm -f "$tmp/starts"
(mkdir -p "$mod/run/gametest" && cd "$mod/run/gametest" && exec "$tmp/java" "@$mod/build/moddev/gameTestServerRunProgramArgs.txt") &
sleep 0.2
check "refuses while a server of the checkout runs" 2 "is already running" 1
kill %1 2> /dev/null; wait 2> /dev/null

bare="$tmp/bare"; mkdir -p "$bare"; git -C "$bare" init -q
got="$(cd "$bare" && "$loop" 2>&1)"; code=$?
[[ $code == 2 && $got == *"is not a mod repo"* ]] && echo "ok   refuses a repo that is not a mod repo" \
    || { echo "FAIL not a mod repo: exit $code: $got"; failed=1; }

exit $failed
