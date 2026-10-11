#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# The release train's state, for Groundworks, Beltworks, Pipeworks, Wireworks and Craftworks: each
# car's version, what ~/.m2 holds, what isn't pushed, the Groundworks each car requires, whether the
# newest cars in ~/.m2 load a Groundworks every one accepts, and the release tooling against
# libworks' template.
# It changes nothing but fetches.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

m2="${MAVEN_REPO_LOCAL:-$HOME/.m2/repository}/io/github/5thlayer"
gw="$HOME/minecraft_mods/groundworks"
bw="$HOME/minecraft_mods/beltworks"
ww="$HOME/minecraft_mods/wireworks"
pw="$HOME/minecraft_mods/pipeworks"
cw="$HOME/minecraft_mods/craftworks"

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

requires_groundworks() { # <checkout>: the range in its libworks { upstream('groundworks') { range = ... } }
    local range
    range=$(awk "/upstream\\(['\"]groundworks['\"]\\)/{on=1} on && /range *=/{gsub(/.*range *= *['\"]|['\"].*/, \"\"); print; exit}" \
        "$1/build.gradle")
    [[ -n $range ]] || range="none named in libworks { upstream('groundworks') }"
    echo "  requires Groundworks: $range"
}

car Beltworks "$bw" beltworks
requires_groundworks "$bw"

car Pipeworks "$pw" pipeworks
requires_groundworks "$pw"

car Wireworks "$ww" wireworks
requires_groundworks "$ww"

# Craftworks' artifact is its archives_name; until it has one, assume craftworks.
cw_artifact=$(sed -n 's/^archives_name *= *//p' "$cw/gradle.properties" 2> /dev/null)
car Craftworks "$cw" "${cw_artifact:-craftworks}"
requires_groundworks "$cw"

# Release tooling that drifts from libworks' template misses its fixes, as a release.sh kept --no-upload's.
echo "== release tooling against libworks' template (template-drift)"
"$here/../template-drift/drift.sh" --release-tooling "$gw" "$bw" "$pw" "$ww" "$cw" | sed 's/^/  /'

# The Groundworks the game would load with the newest Groundworks, Beltworks, Pipeworks, Wireworks and
# Craftworks in ~/.m2: a FAIL is a car still to release.
newest() { # <artifact>: its newest jar in ~/.m2
    local v; v=$(ls "$m2/$1" 2> /dev/null | grep -E '^[0-9]' | sort -V | tail -1)
    [[ -n $v ]] && echo "$m2/$1/$v/$1-$v.jar"
}
echo "== Groundworks, loaded with the newest cars in ~/.m2"
jars=("$(newest groundworks)" "$(newest beltworks)" "$(newest pipeworks)" "$(newest wireworks)" "$(newest "${cw_artifact:-craftworks}")")
python3 "$here/groundworks.py" $(for j in "${jars[@]}"; do [[ -f $j ]] && echo "$j"; done)

