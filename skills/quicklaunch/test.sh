#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# The launcher's choices, through --dry-run on fixture repos: whether it takes a checkout, the
# save it picks, the command it would run, and what it refuses. It launches nothing, and runs a fake
# `java`, not the machine's, so the result doesn't hang on which Java mise has here.
#
#   skills/quicklaunch/test.sh
set -uo pipefail

launcher="$(cd "$(dirname "$0")" && pwd)/quicklaunch.sh"
tmp="$(cd "$(mktemp -d)" && pwd -P)" # git prints the resolved path: /private/var, not /var
trap 'rm -rf "$tmp"' EXIT
failed=0

# A Java that answers, and mise's shim in a checkout with no Java pinned.
mkdir -p "$tmp/java/bin" "$tmp/nojava/bin"
printf '#!/bin/sh\necho "openjdk version \\"25\\"" >&2\n' > "$tmp/java/bin/java"
printf '#!/bin/sh\necho "mise ERROR No version is set for shim: java" >&2\nexit 1\n' > "$tmp/nojava/bin/java"
chmod +x "$tmp/java/bin/java" "$tmp/nojava/bin/java"

check() { # <name> <0 if it launches, 1 if it refuses> <expected substring> <dir> [args...]
    local name=$1 status=$2 want=$3 dir=$4; shift 4
    local got code=0
    got="$(cd "$dir" && env -u JAVA_HOME PATH="$tmp/java/bin:$PATH" ${ENV:-} "$launcher" --dry-run "$@" 2>&1)" || code=$?
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
printf '%s\n' "java { toolchain.languageVersion = JavaLanguageVersion.of(25) }" \
    "programArguments.addAll providers.gradleProperty('quickPlay')" > "$mod/build.gradle"
touch -t 202601010000 "$mod/run/saves/Old/level.dat"
touch -t 202602010000 "$mod/run/saves/New World/level.dat"

check "mod: takes a Gradle build with the quickPlay hook" 0 "root: $mod" "$mod"
check "mod: runs from the repo root, even from a subdirectory" 0 "root: $mod" "$mod/src"
check "mod: opens the most recent save, its name one argument" 0 "run: sh ./gradlew --no-daemon runClient -PquickPlay=New\\ World"$'\n' "$mod"
check "mod: opens the save it is given" 0 "run: sh ./gradlew --no-daemon runClient -PquickPlay=Old"$'\n' "$mod" Old
check "mod: refuses a save that isn't there" 1 "no save \"Nope\"" "$mod" Nope

bare="$tmp/bare"
mkdir -p "$bare"; git -C "$bare" init -q; touch "$bare/gradlew"; echo "// takes no quickPlay" > "$bare/build.gradle"
check "mod: refuses a build without the quickPlay hook" 1 "no -PquickPlay hook" "$bare"

plugin="$tmp/plugin"
mkdir -p "$plugin/run/saves/World"; git -C "$plugin" init -q; touch "$plugin/gradlew" "$plugin/run/saves/World/level.dat"
printf '%s\n' "plugins {" "    id 'io.github.5thlayer.libworks.module' version '0.1.2'" "}" > "$plugin/build.gradle"
check "mod: takes a build applying libworks' plugin, which carries the hook" 0 \
    "run: sh ./gradlew --no-daemon runClient -PquickPlay=World"$'\n' "$plugin"

nosave="$tmp/nosave"
mkdir -p "$nosave"; git -C "$nosave" init -q; touch "$nosave/gradlew"; cp "$mod/build.gradle" "$nosave/"
check "mod: with no save, launches to the menu" 0 "run: sh ./gradlew --no-daemon runClient"$'\n' "$nosave"

ENV="PATH=$tmp/nojava/bin:$PATH" check "mod: refuses with no Java, and says which to pin" 1 \
    "mise use java@temurin-25)" "$mod"
ENV="PATH=$tmp/nojava/bin:$PATH" check "mod: names mise's error when there is no Java" 1 \
    "No version is set for shim: java" "$mod"
ENV="PATH=$tmp/nojava/bin:$PATH JAVA_HOME=$tmp/java" check "mod: takes JAVA_HOME over the java on PATH" 0 \
    "root: $mod" "$mod"

# The Showcase's own launcher picks the save and refuses a second game; quicklaunch hands it the save.
show="$tmp/showcase"
mkdir -p "$show/scripts"; git -C "$show" init -q; touch "$show/pack.toml"
printf '%s\n' 'import sys' 'print("launcher got", sys.argv[1:])' > "$show/scripts/launch.py"
check "showcase: takes pack.toml beside scripts/launch.py" 0 "root: $show" "$show"
check "showcase: dry-runs its launcher" 0 "launcher got ['--dry-run']"$'\n' "$show"
check "showcase: hands its launcher the save, one argument" 0 "launcher got ['--dry-run', 'New World']"$'\n' "$show" "New World"

none="$tmp/none"
mkdir -p "$none"; git -C "$none" init -q
check "refuses a repo that is neither a mod repo nor the Showcase" 1 "is not a mod repo nor the Showcase" "$none"

exit $failed
