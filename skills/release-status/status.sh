#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# The release train's state, for Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks, Core and the
# Pack: each car's version, what ~/.m2 holds, what isn't pushed, the Groundworks
# each car nests or requires, whether the Pack's mods/ matches its pins and loads a Groundworks every
# jar accepts, the same for the newest cars in ~/.m2, and the release tooling against libworks' template.
# It changes nothing but fetches.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

m2="${MAVEN_REPO_LOCAL:-$HOME/.m2/repository}/io/github/5thlayer"
gw="$HOME/minecraft_mods/groundworks"
bw="$HOME/minecraft_mods/beltworks"
ww="$HOME/minecraft_mods/wireworks"
pw="$HOME/minecraft_mods/pipeworks"
cw="$HOME/minecraft_mods/craftworks"
# The Pack's checkout: PACK_CHECKOUT, else the one CurseForge's instance links to, else ~/MC/factoryworks.
pack=
for p in "${PACK_CHECKOUT:-}" "${CURSEFORGE_ROOT:-$HOME/curseforge}/Instances/FactoryWorks" "$HOME/MC/factoryworks"; do
    [[ -n $p && -f $p/data/pack/local-jars.json ]] && { pack="$(cd "$p" && pwd -P)"; break; }
done

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

nests_groundworks() { # <checkout>
    local dir=$1 range
    echo "  nests Groundworks: $(grep -E "^\s*(strictly|prefer) " "$dir/build.gradle" | tr -s ' ' | tr '\n' ' ')"
    # build.gradle keeps the range in one def, which both strictly and neoforge.mods.toml read.
    range=$(sed -n "s/^def groundworksRange *= *'\(.*\)'.*/\1/p" "$dir/build.gradle")
    [[ -n $range ]] && echo "  groundworksRange: $range"
    echo "  neoforge.mods.toml requires: $(awk '/modId *= *"groundworks"/{on=1} on && /versionRange/{print $3; exit}' \
        "$dir/src/main/resources/META-INF/neoforge.mods.toml")"
}

car Beltworks "$bw" beltworks
nests_groundworks "$bw"

car Pipeworks "$pw" pipeworks

car Wireworks "$ww" wireworks
nests_groundworks "$ww"

# Craftworks' artifact is its archives_name; until it has one, assume craftworks.
cw_artifact=$(sed -n 's/^archives_name *= *//p' "$cw/gradle.properties" 2> /dev/null)
car Craftworks "$cw" "${cw_artifact:-craftworks}"
echo "  requires Groundworks: >= $(sed -n 's/^groundworks_version *= *//p' "$cw/gradle.properties"), unnested"

# Release tooling that drifts from libworks' template misses its fixes, as a release.sh kept --no-upload's.
echo "== release tooling against libworks' template (template-drift)"
"$here/../template-drift/drift.sh" --release-tooling "$gw" "$bw" "$pw" "$ww" "$cw" ${pack:+"$pack"} | sed 's/^/  /'

# The Groundworks the Pack would load were it to take the newest Groundworks, Beltworks, Wireworks and
# Craftworks in ~/.m2: a FAIL is a car to release, or a pin that can't move alone.
newest() { # <artifact>: its newest jar in ~/.m2
    local v; v=$(ls "$m2/$1" 2> /dev/null | grep -E '^[0-9]' | sort -V | tail -1)
    [[ -n $v ]] && echo "$m2/$1/$v/$1-$v.jar"
}
echo "== Groundworks, were the Pack to take the newest cars in ~/.m2"
jars=("$(newest groundworks)" "$(newest beltworks)" "$(newest pipeworks)" "$(newest wireworks)" "$(newest "${cw_artifact:-craftworks}")")
python3 "$here/groundworks.py" $(for j in "${jars[@]}"; do [[ -f $j ]] && echo "$j"; done)

if [[ -z $pack ]]; then
    echo "== Pack  not found: set PACK_CHECKOUT to its checkout"
    exit 0
fi
car Pack "$pack"
# Core is released from the Pack's checkout, with core-v tags and its own maven group.
core_group=$(sed -n 's/^maven_group *= *//p' "$pack/gradle.properties")
core_id=$(sed -n 's/^mod_id *= *//p' "$pack/gradle.properties")
echo "  Core: mod_version $(sed -n 's/^mod_version *= *//p' "$pack/gradle.properties"), newest tag $(git -C "$pack" tag -l 'core-v*' | sort -V | tail -1), ~/.m2: $(ls "${MAVEN_REPO_LOCAL:-$HOME/.m2/repository}/${core_group//.//}/$core_id" 2> /dev/null | grep -E '^[0-9]' | sort -V | tr '\n' ' ')"
echo "  pin: $(python3 -c 'import json,sys; print(", ".join(f"{r["mod"]} {r["version"]}" for r in json.load(open(sys.argv[1]))["jars"]))' \
    "$pack/data/pack/local-jars.json")"
python3 "$pack/scripts/sync-local-jars.py" --check 2>&1 | sed 's/^/  --check: /'
python3 "$here/groundworks.py" $(ls "$pack"/mods/*.jar | grep -v -- '-sources\.jar$')
