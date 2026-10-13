#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# The loop on a fixture repo whose gradlew stands in for libworks' plugin, a current one that writes the
# game-test server's command line or an older one that only runs the server, and whose server is fake:
# where it gets the command line, how it reads each run, when it skips or refuses Gradle, which tests
# --tests selects, and what it refuses. It runs no Gradle and no Minecraft.
#
#   skills/gametest-loop/test.sh
set -uo pipefail

loop="$(cd "$(dirname "$0")" && pwd)/gametest-loop.sh"
tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'pkill -f "$tmp/" 2> /dev/null; rm -rf "$tmp"' EXIT
failed=0

# The fake server: the n-th start (counted in $tmp/starts) prints and exits as line n of $tmp/results says:
# "pass", "fail <test>...", "crash" or "hang", in lines prefixed as NeoForge's server logs them. Each start adds its @-file to $tmp/argfiles and the
# selector that file passes to $tmp/selectors, and the CPUs it may run on to $tmp/cpus.
cat > "$tmp/java" << EOF
#!/usr/bin/env bash
n=\$(( \$(cat "$tmp/starts" 2> /dev/null || echo 0) + 1 )); echo \$n > "$tmp/starts"
sed -n 's/^Cpus_allowed_list:\s*//p' /proc/\$\$/status >> "$tmp/cpus"
for a in "\$@"; do case \$a in @*)
    echo "\${a#@}" >> "$tmp/argfiles"; sed -n '/^--tests\$/{n;p}' "\${a#@}" >> "$tmp/selectors" 2> /dev/null ;;
esac; done
read -ra r <<< "\$(sed -n "\${n}p" "$tmp/results")"
log="[19:47:47] [Server thread"  # each line as NeoForge's server logs it
sleep 0.5
case \${r[0]:-pass} in
    pass) echo "\$log/INFO] [minecraft/GameTestServer]: All 3 required tests passed :)"; exit 0 ;;
    fail) echo "\$log/ERROR] [minecraft/GameTestServer]: \$(( \${#r[@]} - 1 )) required tests failed :("
          for t in "\${r[@]:1}"; do echo "\$log/ERROR] [minecraft/GameTestServer]:    - mod:\$t: Expected true"; done; exit \$(( \${#r[@]} - 1 )) ;;
    crash) echo "Exception in thread main"; exit 1 ;;
    hang) sleep 30 ;;
esac
EOF
chmod +x "$tmp/java"

# The fixture: its gradlew's writeGameTestServerCommand writes the command line, unless $tmp/old-plugin
# exists, and both write the program-args file as ModDevGradle does; its runGameTestServer starts the
# server from run/gametest.
mod="$tmp/mod"
mkdir -p "$mod/src/main"; git -C "$mod" init -q; echo "plugins {}" > "$mod/build.gradle"
cat > "$mod/gradlew" << EOF
#!/bin/sh
echo "\$*" >> "$tmp/gradle-calls"
sed -n 's/^Cpus_allowed_list:\s*//p' /proc/\$\$/status > "$tmp/gradle-cpus"
[ -f "$tmp/compile-error" ] && { echo "* What went wrong:"; echo "Compilation failed"; exit 1; }
set -- "$tmp/java" -Dfml.modFolders=mod%%$mod/build/classes/java/main -cp "$mod/a.jar:$mod/b.jar" \
    net.neoforged.devlaunch.Main "@$mod/build/moddev/gameTestServerRunProgramArgs.txt" "\$@"
args="$mod/build/moddev/gameTestServerRunProgramArgs.txt"
mkdir -p "$mod/build/moddev"
printf '# Main Class\nnet.neoforged.fml.startup.GameTestServer\n\n# User Supplied Program Arguments\n--tests\nmod:*\n--report\n%s' \
    "$mod/build/reports/gametest.xml" > "\$args"
case "\$*" in
    *writeGameTestServerCommand)
        [ -f "$tmp/old-plugin" ] && { echo "* What went wrong:"; echo "Task 'writeGameTestServerCommand' not found in root project 'mod'."; exit 1; }
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
    printf '%s\n' "${results[@]}" > "$tmp/results"; rm -f "$tmp/starts" "$tmp/gradle-calls" "$tmp/argfiles" "$tmp/selectors" "$tmp/cpus" "$tmp/gradle-cpus"
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
selected() { # <name> <the selector each server start was passed, one a line>
    if [[ $(cat "$tmp/selectors" 2> /dev/null) == "$2" ]]; then echo "ok   $1"
    else echo "FAIL $1: the servers were passed:"; sed 's/^/     /' "$tmp/selectors" 2> /dev/null; failed=1
    fi
}
build_args="$mod/build/moddev/gameTestServerRunProgramArgs.txt"

results=(pass pass pass)
check "takes the command line the plugin writes, and runs every run directly" 0 "3 of 3 direct runs passed" 3
selected "runs the build's selector" "mod:*"$'\n'"mod:*"$'\n'"mod:*"
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
results=(pass pass)
check "--tests: builds, then runs the selector" 0 "tests: mod:solar_*" --tests 'mod:solar_*' 2
selected "--tests: the selector reaches every run" "mod:solar_*"$'\n'"mod:solar_*"
[[ $(sort -u "$tmp/argfiles") == "$mod/build/gametest-loop/gameTestServerRunProgramArgs.txt" ]] \
    && grep -qx "mod:\*" "$build_args" && grep -qx -- "--report" "$mod/build/gametest-loop/gameTestServerRunProgramArgs.txt" \
    && echo "ok   --tests: runs a copy of the program-args file, and leaves the build's alone" \
    || { echo "FAIL --tests copy:"; cat "$tmp/argfiles" "$build_args"; failed=1; }
check "--tests after the count, with --reuse" 0 "1 of 1 direct runs passed" --reuse 1 --tests mod:solar_a
calls "--reuse --tests: no Gradle call" ""
selected "--reuse --tests: the selector reaches the run" "mod:solar_a"
check "--reuse without --tests: the build's selector again" 0 "1 of 1 direct runs passed" --reuse 1
selected "--reuse without --tests: the build's selector reaches the run" "mod:*"
own_cpus="$(sed -n 's/^Cpus_allowed_list:\s*//p' /proc/$$/status)"
results=(pass pass)
check "--cpus: builds, then pins the runs" 0 "cpus: 0" --cpus 0 2
[[ $(cat "$tmp/cpus") == "0"$'\n'"0" ]] && echo "ok   --cpus: every run is pinned to those CPUs" \
    || { echo "FAIL --cpus: the servers ran on:"; cat "$tmp/cpus"; failed=1; }
[[ $(cat "$tmp/gradle-cpus") == "$own_cpus" ]] && echo "ok   --cpus: Gradle is not pinned" \
    || { echo "FAIL --cpus: Gradle ran on $(cat "$tmp/gradle-cpus"), not $own_cpus"; failed=1; }
results=(pass)
check "--cpus with --reuse and --tests" 0 "1 of 1 direct runs passed" --reuse --cpus 0 --tests mod:solar_a 1
[[ $(cat "$tmp/cpus") == "0" ]] && echo "ok   --cpus with --reuse: the run is pinned" \
    || { echo "FAIL --cpus with --reuse: the server ran on:"; cat "$tmp/cpus"; failed=1; }
check "--cpus refuses a list taskset can't read" 2 "--cpus takes a CPU list" --cpus all
check "--cpus refuses a missing list" 2 "--cpus needs a CPU list" --cpus
check "--tests refuses a selector without a namespace" 2 "--tests takes namespace:pattern" --tests 'solar_*'
check "--tests refuses a selector with a space" 2 "--tests takes namespace:pattern" --tests 'mod:solar a'
check "--tests refuses a missing selector" 2 "--tests needs a selector" --tests

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
results=(pass pass pass)
check "an older plugin with --tests: one Gradle run, then the selector" 0 "2 of 2 direct runs passed" --tests 'mod:solar_*' 2
selected "an older plugin with --tests: Gradle runs every test, each direct run the selector" \
    "mod:*"$'\n'"mod:solar_*"$'\n'"mod:solar_*"
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
(cd "$mod/run/gametest" && exec "$tmp/java" "@$mod/build/gametest-loop/gameTestServerRunProgramArgs.txt") &
sleep 0.2
check "refuses while a server of the checkout runs a selector" 2 "is already running" 1
kill %1 2> /dev/null; wait 2> /dev/null

bare="$tmp/bare"; mkdir -p "$bare"; git -C "$bare" init -q
got="$(cd "$bare" && "$loop" 2>&1)"; code=$?
[[ $code == 2 && $got == *"is not a mod repo"* ]] && echo "ok   refuses a repo that is not a mod repo" \
    || { echo "FAIL not a mod repo: exit $code: $got"; failed=1; }

exit $failed
