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
check "mod: refuses a subdirectory, naming the candidates" 1 "src is not a pack nor a mod build with the -PquickPlay hook; run from one, or name one with --in: . (mod)." "$mod/src"
check "mod: --in takes it from a subdirectory" 0 "mod: $mod"$'\n' "$mod/src" --in mod
check "mod: --in takes a save after it" 0 "run: sh ./gradlew --no-daemon runClient -PquickPlay=Old"$'\n' "$mod/src" --in mod Old
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

# A packwiz pack plays its CurseForge profile through launch_pack.py; the fixture profile sits in a fake
# CurseForge root, its Install/ holding one loader on a Minecraft with quick play and one on one without.
cf="$tmp/cf"
mkdir -p "$cf/Install/versions/neoforge-1" "$cf/Install/versions/forge-1" "$cf/Install/versions/mc" "$cf/Install/versions/old"
for v in neoforge-1:mc forge-1:old; do
    printf '{"inheritsFrom": "%s", "mainClass": "Main", "libraries": [], "arguments": {"jvm": [], "game": []}}\n' \
        "${v#*:}" > "$cf/Install/versions/${v%%:*}/${v%%:*}.json"
done
quick='{"rules": [{"action": "allow", "features": {"is_quick_play_singleplayer": true}}], "value": ["--quickPlaySingleplayer", "${quickPlaySingleplayer}"]}'
printf '{"libraries": [], "assets": "1", "javaVersion": {"component": "j"}, "arguments": {"jvm": [], "game": ["--a", %s]}}\n' \
    "$quick" > "$cf/Install/versions/mc/mc.json"
printf '{"libraries": [], "assets": "1", "javaVersion": {"component": "j"}, "arguments": {"jvm": [], "game": ["--a"]}}\n' \
    > "$cf/Install/versions/old/old.json"
profile() { # <folder> <loader version>
    mkdir -p "$cf/Instances/$1/saves/Old" "$cf/Instances/$1/saves/New World" "$cf/Instances/$1/mods"
    printf '{"name": "%s", "allocatedMemory": 4096, "baseModLoader": {"name": "%s"}}\n' "$1" "$2" > "$cf/Instances/$1/minecraftinstance.json"
    touch -t 202601010000 "$cf/Instances/$1/saves/Old/level.dat"
    touch -t 202602010000 "$cf/Instances/$1/saves/New World/level.dat"
}
packwiz() { # <dir> <name>
    mkdir -p "$1/config"; echo "a = 1" > "$1/config/a.toml"
    printf 'name = "%s"\npack-format = "packwiz:1.1.0"\n[index]\nfile = "index.toml"\nhash-format = "sha256"\n' "$2" > "$1/pack.toml"
    printf 'hash-format = "sha256"\n[[files]]\nfile = "config/a.toml"\nhash = "%s"\n' \
        "$(sha256sum "$1/config/a.toml" | cut -d' ' -f1)" > "$1/index.toml"
}
profile New neoforge-1
profile Old forge-1

show="$tmp/showcase"
mkdir -p "$show/scripts"; git -C "$show" init -q; packwiz "$show" New
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: takes a packwiz pack.toml at the repo root" 0 "pack: $show"$'\n' "$show"
check "pack: refuses a subdirectory" 1 "scripts is not a pack nor a mod build" "$show/scripts"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: --in takes it from a subdirectory" 0 "pack: $show"$'\n' "$show/scripts" --in new
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: copies the pack's files into the profile" 0 "pack files: 1 copied in" "$show"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: opens the most recent save, on the profile's memory" 0 \
    "-Xmx4096M ... Main --a --quickPlaySingleplayer New World"$'\n' "$show"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: opens the save it is given, one argument" 0 \
    "--quickPlaySingleplayer Old"$'\n' "$show" Old
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: refuses a save that isn't there" 1 "no save \"Nope\"" "$show" Nope
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/Nope" check "pack: refuses with no CurseForge profile" 1 "no CurseForge profile" "$show"

# Mods put their authors in usercache.json; the player is the one the save has playerdata for.
printf '[{"name": "Author", "uuid": "aaaaaaaa-0000-0000-0000-000000000000", "expiresOn": "2026-12-02"},
 {"name": "Me", "uuid": "bbbbbbbb-0000-0000-0000-000000000000", "expiresOn": "2026-12-01"}]\n' > "$cf/Instances/New/usercache.json"
mkdir -p "$cf/Instances/New/saves/New World/playerdata"
touch "$cf/Instances/New/saves/New World/playerdata/bbbbbbbb-0000-0000-0000-000000000000.dat"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: plays as the player the save knows, not a mod's author" 0 "player: Me"$'\n' "$show"
rm "$cf/Instances/New/usercache.json"

# A profile with no memory of its own takes CurseForge's setting.
mkdir -p "$tmp/home/.config/CurseForge"
printf '{"minecraft-settings": "{\\"maxMemoryAllocation\\": 3072}"}\n' > "$tmp/home/.config/CurseForge/storage.json"
sed -i.bak 's/"allocatedMemory": 4096/"allocatedMemory": 0/' "$cf/Instances/New/minecraftinstance.json"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New HOME=$tmp/home" check "pack: takes CurseForge's memory when the profile has none" 0 "-Xmx3072M" "$show"
mv "$cf/Instances/New/minecraftinstance.json.bak" "$cf/Instances/New/minecraftinstance.json"

multi="$tmp/multi"
mkdir -p "$multi/A/sub" "$multi/docs"; git -C "$multi" init -q; packwiz "$multi/A" Old
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/Old" check "pack: takes the one folder under the repo root with a pack" 0 "pack: $multi/A"$'\n' "$multi"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/Old" check "pack: on a Minecraft without quick play, opens to the menu" 0 \
    "save: none, to the menu (this Minecraft has no quick play" "$multi/A"
check "pack: refuses a folder that is neither, even inside a pack" 1 "A/sub is not a pack nor a mod build" "$multi/A/sub"
check "pack: refuses a folder that is neither, naming the candidates" 1 "name one with --in: A (Old)." "$multi/docs"

# A second pack, with its companion mod inside it: the mod is no target, only swapped into the pack.
packwiz "$multi/B" New
mkdir -p "$multi/B/mod/build/libs"; touch "$multi/B/mod/gradlew"; cp "$mod/build.gradle" "$multi/B/mod/"
echo "mod_id = companion" > "$multi/B/mod/gradle.properties"
check "pack: refuses a repo root with several targets, naming them" 1 "several targets; name one with --in: A (Old), B (New)." "$multi"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: takes the pack it is run in" 0 "pack: $multi/B"$'\n' "$multi/B"
check "pack: refuses its companion mod, naming the pack" 1 \
    "B/mod is New's companion mod, swapped into the pack rather than launched on its own; launch the pack with --in B." "$multi/B/mod"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: --in matches the path" 0 "pack: $multi/B"$'\n' "$multi/docs" --in b
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/Old" check "pack: --in matches the pack's name" 0 "pack: $multi/A"$'\n' "$multi/B/mod" --in OLD
twin="$tmp/twin"
mkdir -p "$twin"; git -C "$twin" init -q; packwiz "$twin/P1" "Mastery Plus"; packwiz "$twin/R1" "Mastery Reborn"
check "pack: --in refuses a tie" 1 "\"mastery\" matches several, equally: P1 (Mastery Plus), R1 (Mastery Reborn); name one more closely." "$twin" --in mastery
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: --in takes the closer match over a looser one" 0 "pack: $twin/R1"$'\n' "$twin" --in "mastery reborn"
check "pack: --in refuses a query nothing matches" 1 "nothing here matches \"zzz\": A (Old), B (New)." "$multi" --in zzz
check "pack: --in finds no companion mod, which is no target" 1 "nothing here matches \"companion\"" "$multi" --in companion

# A jar declaring a mod id and version, as Gradle builds one.
jar() { # <path> <mod id> <version>
    python3 -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("META-INF/neoforge.mods.toml", f"[[mods]]\nmodId = \"{sys.argv[2]}\"\nversion = \"{sys.argv[3]}\"\n")' "$@"
}
jar "$cf/Instances/New/mods/companion-1.0.jar" companion 1.0
jar "$multi/B/mod/build/libs/companion-1.1.jar" companion 1.1
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: swaps in a mod built inside its repo, by its mod id" 0 \
    "mods: companion 1.0 -> local 1.1 (B/mod/build/libs/companion-1.1.jar)" "$multi/B"

# From a worktree, the mod checkouts are beside the main checkout, not beside the worktree.
main="$tmp/main"
mkdir -p "$main"; git -C "$main" init -q; packwiz "$main/P" New
git -C "$main" add -A; git -C "$main" -c user.name=t -c user.email=t@t commit -qm pack
git -C "$main" worktree add -q --detach "$main/.claude/worktrees/wt"
mkdir -p "$tmp/beside/build/libs"; jar "$tmp/beside/build/libs/beside-1.2.jar" beside 1.2
jar "$cf/Instances/New/mods/beside-1.0.jar" beside 1.0
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: from a worktree, swaps in the mod beside the main checkout" 0 \
    "mods: beside 1.0 -> local 1.2 (beside/build/libs/beside-1.2.jar)" "$main/.claude/worktrees/wt/P"
ENV="QUICKLAUNCH_INSTANCE=$cf/Instances/New" check "pack: the main checkout's root skips its worktrees' packs" 0 \
    "pack: $main/P"$'\n' "$main"
rm "$cf/Instances/New/mods/"*.jar

none="$tmp/none"
mkdir -p "$none"; git -C "$none" init -q
check "refuses a repo that is neither a mod repo nor a pack" 1 "is not a mod repo nor a packwiz pack" "$none"

exit $failed
