#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# drift.sh on a fixture template, mods and Pack: the example names read as a mod's own, the tag prefix
# ignored, a changed or missing file reported, and the Pack held to the release tooling alone.
#
#   skills/template-drift/test.sh
set -uo pipefail

drift="$(cd "$(dirname "$0")" && pwd)/drift.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failed=0

lib="$tmp/libworks"
mkdir -p "$lib/scripts/tests" "$lib/publish"
git -C "$lib" init -q
printf 'tag="v$version"\nrun examplelib\n' > "$lib/scripts/release.sh"
printf 'PROPERTIES = """mod_name = Example Library\nclass ExampleLib\nsite["Example Library 0.3.9"]\n' > "$lib/scripts/tests/test_upload.py"
echo 'upload' > "$lib/scripts/upload.py"
echo 'standin' > "$lib/scripts/tests/standin.py"
echo 'TOKEN=op://x' > "$lib/publish/upload.env"
echo 'changelog' > "$lib/CHANGELOG.md"
echo 'tools' > "$lib/mise.toml"
echo 'Groundworks nests in Beltworks.' > "$lib/guide.md"
echo 'the template glossary' > "$lib/GLOSSARY.md"
git -C "$lib" add -A

mod() { # <dir> <archives_name> <mod_name> <tag prefix> <class>
    local d="$tmp/$1"
    mkdir -p "$d/scripts/tests" "$d/publish"
    printf 'archives_name = %s\nmod_name = %s\n' "$2" "$3" > "$d/gradle.properties"
    printf 'tag="%sv$version"\nrun %s\n' "$4" "$2" > "$d/scripts/release.sh"
    printf 'PROPERTIES = """mod_name = %s\nclass %s\nsite["%s 0.3.9"]\n' "$3" "$5" "$3" > "$d/scripts/tests/test_upload.py"
    echo 'upload' > "$d/scripts/upload.py"
    echo 'standin' > "$d/scripts/tests/standin.py"
    echo 'TOKEN=op://x' > "$d/publish/upload.env"
    echo 'its own changelog' > "$d/CHANGELOG.md"
    echo 'tools' > "$d/mise.toml"
    echo 'Groundworks nests in Beltworks.' > "$d/guide.md"
    echo 'its own glossary' > "$d/GLOSSARY.md"
}
mod renamed pipeworks Pipeworks pipeworks- Pipeworks
mod kept examplelib "Example Library" "" ExampleLib
mod named groundworks Groundworks "" Groundworks
mod drifted wireworks Wireworks wireworks- Wireworks
echo 'upload, an old fork' > "$tmp/drifted/scripts/upload.py"
rm "$tmp/drifted/publish/upload.env"

# The Pack: FactoryWorks Core's release tooling, an upload.py of its own and no tests, and no mise.toml.
pack="$tmp/pack"
mkdir -p "$pack/data/pack" "$pack/scripts" "$pack/publish"
echo '{}' > "$pack/data/pack/local-jars.json"
printf 'mod_id=factoryworks_core\nmod_name=FactoryWorks Core\n' > "$pack/gradle.properties"
printf 'tag="core-v$version"\nrun examplelib\n' > "$pack/scripts/release.sh"
echo 'upload, Core'"'"'s own' > "$pack/scripts/upload.py"
echo 'TOKEN=op://x' > "$pack/publish/upload.env"

check() { # <name> <expected substring> [args...]
    local name=$1 want=$2; shift 2
    local got; got="$(LIBWORKS="$lib" "$drift" "$@" 2>&1)"
    if [[ $got == *"$want"* ]]; then echo "ok   $name"; else echo "FAIL $name: wanted \"$want\" in:"; sed 's/^/     /' <<< "$got"; failed=1; fi
}

check "a mod that renamed the example names is the same" $'== renamed\n  same' "$tmp/renamed"
check "a mod that kept them is the same" $'== kept\n  same' "$tmp/kept"
check "a mod the template names is the same" $'== named\n  same' "$tmp/named"
check "leaves the glossary out" $'== kept\n  same' "$tmp/kept"
check "reports a file that differs" "scripts/upload.py: 2 lines differ" "$tmp/drifted"
check "reports a missing file" "missing publish/upload.env" "$tmp/drifted"
check "leaves per-mod files out" $'== renamed\n  same' "$tmp/renamed"
check "--release-tooling compares only what a release runs" "missing publish/upload.env" --release-tooling "$tmp/drifted"
check "compares the Pack's upload.py" "scripts/upload.py: 2 lines differ" "$pack"
check "reports the Pack's missing upload tests" "missing scripts/tests/test_upload.py" "$pack"
check "reports the Pack's missing standin" "missing scripts/tests/standin.py" --release-tooling "$pack"
check "holds the Pack to the release tooling alone" $'== pack\n  scripts/upload.py: 2 lines differ\n  missing scripts/tests/standin.py\n  missing scripts/tests/test_upload.py' "$pack"

exit $failed
