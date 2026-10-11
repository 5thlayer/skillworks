#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# Warns when a checkout's latest release tag isn't on origin/main's history, as when main is rewritten
# after the tag: anything counting from the tag, such as a changelog's `git log <tag>..HEAD`, counts
# the wrong range. It names the commit on origin/main with the tag's tree, if one has it. The tag is
# public, so it is never moved: count from that commit instead.
#
#   tag-on-main.sh <checkout>
set -uo pipefail
dir=$1

tag=$(git -C "$dir" tag -l --sort=-creatordate | head -1)
[[ -n $tag ]] || exit 0
git -C "$dir" rev-parse -q --verify origin/main > /dev/null || exit 0
git -C "$dir" merge-base --is-ancestor "$tag" origin/main && exit 0

tree=$(git -C "$dir" rev-parse "$tag^{tree}")
same=$(git -C "$dir" log --format='%h %T' origin/main | awk -v t="$tree" '$2 == t { print $1; exit }')
if [[ -n $same ]]; then
    echo "  warning: tag $tag is not on origin/main's history; origin/main's $same has its tree, so count from $same"
else
    echo "  warning: tag $tag is not on origin/main's history, and no commit there has its tree"
fi
