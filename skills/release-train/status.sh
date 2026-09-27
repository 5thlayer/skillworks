#!/usr/bin/env bash
# The release train's state: each car's version, what ~/.m2 holds, what isn't pushed, the Groundworks
# Beltworks nests, and whether the Pack's mods/ matches its pins. It changes nothing but fetches.
set -uo pipefail

m2="${MAVEN_REPO_LOCAL:-$HOME/.m2/repository}/io/github/5thlayer"
gw="$HOME/minecraft_mods/groundworks"
bw="$HOME/minecraft_mods/beltworks"
cw="$HOME/minecraft_mods/craftworks"
pack="$HOME/curseforge/Instances/PlanetaryFactory"

car() { # <name> <checkout> [artifact]
    local name=$1 dir=$2 artifact=${3:-}
    git -C "$dir" fetch -q origin 2> /dev/null || echo "  (fetch failed: origin is as last seen)"
    echo "== $name  $dir"
    echo "  $(git -C "$dir" status -sb | head -1 | sed 's/^## //')"
    if [[ -n $artifact && ! -f $dir/gradle.properties ]]; then
        echo "  no gradle.properties yet: nothing to release"
    elif [[ -n $artifact ]]; then
        echo "  mod_version $(sed -n 's/^mod_version *= *//p' "$dir/gradle.properties")"
        echo "  ~/.m2: $(ls "$m2/$artifact" 2> /dev/null | grep -E '^[0-9]' | sort -V | tr '\n' ' ')"
    fi
    local dirty; dirty=$(git -C "$dir" status --porcelain --untracked-files=no | wc -l | tr -d ' ')
    [[ $dirty == 0 ]] || echo "  uncommitted: $dirty tracked files"
    git -C "$dir" log --format='  unpushed commit: %h %s  (%ar)' '@{u}..HEAD'
    comm -23 <(git -C "$dir" tag -l | sort) \
             <(git -C "$dir" ls-remote -q --tags origin | sed -n 's|.*refs/tags/\([^^]*\)$|\1|p' | sort) \
        | sed 's/^/  unpushed tag: /'
}

car Groundworks "$gw" groundworks

car Beltworks "$bw" beltworks
echo "  nests Groundworks: $(grep -E "^\s*(strictly|prefer) " "$bw/build.gradle" | tr -s ' ' | tr '\n' ' ')"
# build.gradle keeps the range in one def, which both strictly and neoforge.mods.toml read.
range=$(sed -n "s/^def groundworksRange *= *'\(.*\)'.*/\1/p" "$bw/build.gradle")
[[ -n $range ]] && echo "  groundworksRange: $range"
echo "  neoforge.mods.toml requires: $(awk '/modId *= *"groundworks"/{on=1} on && /versionRange/{print $3; exit}' \
    "$bw/src/main/resources/META-INF/neoforge.mods.toml")"

# Craftworks' artifact is its archives_name; until it has one, assume craftworks.
cw_artifact=$(sed -n 's/^archives_name *= *//p' "$cw/gradle.properties" 2> /dev/null)
car Craftworks "$cw" "${cw_artifact:-craftworks}"

car Pack "$pack"
echo "  pin: $(python3 -c 'import json,sys; print(", ".join(f"{r["mod"]} {r["version"]}" for r in json.load(open(sys.argv[1]))["jars"]))' \
    "$pack/data/pack/local-jars.json")"
python3 "$pack/scripts/sync-local-jars.py" --check 2>&1 | sed 's/^/  --check: /'
