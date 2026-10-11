#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# drift.sh on a fixture template and mods: the template filled as a new Library, the example names
# read as a mod's own, the tag prefix ignored, and a changed or missing file and an older plugin reported.
#
#   skills/template-drift/test.sh
set -uo pipefail

drift="$(cd "$(dirname "$0")" && pwd)/drift.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failed=0

lib="$tmp/libworks"
mkdir -p "$lib/scripts/tests" "$lib/publish" "$lib/plugin" "$lib/.github/workflows"
git -C "$lib" init -q
# A stand-in for libworks' fill-template.sh: libworks' own tooling goes, the build and CI pin the
# plugin, and the example names become the ones given.
cat > "$lib/scripts/fill-template.sh" <<'FILL'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
git rm -rq plugin scripts/tests
printf "plugins {\n    id 'io.github.5thlayer.libworks.module' version '0.2.0'\n}\n" > build.gradle
printf 'uses: module-ci.yml@plugin-v0.2.0\n' > .github/workflows/ci.yml
git grep -lI -e examplelib -e ExampleLib -e 'Example Library' -- . ':!scripts/fill-template.sh' | while read -r f; do
    sed -i -e "s|examplelib|$1|g" -e "s|ExampleLib|$2|g" -e "s|Example Library|$3|g" "$f"
done
git rm -q scripts/fill-template.sh
FILL
echo 'the plugin' > "$lib/plugin/build.gradle"
echo 'standin' > "$lib/scripts/tests/standin.py"
printf "plugins {\n    id 'io.github.5thlayer.libworks.module'\n}\n" > "$lib/build.gradle"
echo 'uses: ./.github/workflows/module-ci.yml' > "$lib/.github/workflows/ci.yml"
printf 'tag="v$version"\n# tokens for examplelib, ExampleLib\nTOKEN=op://x\n' > "$lib/publish/upload.env"
printf 'mod_name = Example Library\nclass ExampleLib\nsite["Example Library 0.3.9"]\n' > "$lib/guide.md"
echo 'changelog' > "$lib/CHANGELOG.md"
echo 'tools' > "$lib/mise.toml"
echo 'Groundworks and Beltworks require Groundworks.' > "$lib/nest.md"
echo 'the template glossary' > "$lib/GLOSSARY.md"
git -C "$lib" add -A
git -C "$lib" -c user.name=t -c user.email=t@t commit -qm template

mod() { # <dir> <archives_name> <mod_name> <tag prefix> <class> [plugin version]
    local d="$tmp/$1"
    mkdir -p "$d/publish" "$d/.github/workflows"
    printf 'archives_name = %s\nmod_name = %s\n' "$2" "$3" > "$d/gradle.properties"
    printf "plugins {\n    id 'io.github.5thlayer.libworks.module' version '%s'\n}\nits own build\n" "${6:-0.2.0}" > "$d/build.gradle"
    printf 'uses: module-ci.yml@plugin-v%s\n' "${6:-0.2.0}" > "$d/.github/workflows/ci.yml"
    printf 'tag="%sv$version"\n# tokens for %s, %s\nTOKEN=op://x\n' "$4" "$2" "$5" > "$d/publish/upload.env"
    printf 'mod_name = %s\nclass %s\nsite["%s 0.3.9"]\n' "$3" "$5" "$3" > "$d/guide.md"
    echo 'its own changelog' > "$d/CHANGELOG.md"
    echo 'tools' > "$d/mise.toml"
    echo 'Groundworks and Beltworks require Groundworks.' > "$d/nest.md"
    echo 'its own glossary' > "$d/GLOSSARY.md"
}
mod renamed pipeworks Pipeworks pipeworks- Pipeworks
mod kept examplelib "Example Library" "" ExampleLib
mod named groundworks Groundworks "" Groundworks
mod drifted wireworks Wireworks wireworks- Wireworks
echo 'tools, an old fork' > "$tmp/drifted/mise.toml"
rm "$tmp/drifted/publish/upload.env"
mod behind craftworks Craftworks "" Craftworks 0.1.0

check() { # <name> <expected substring> [args...]
    local name=$1 want=$2; shift 2
    local got; got="$(LIBWORKS="$lib" "$drift" "$@" 2>&1)"
    if [[ $got == *"$want"* ]]; then echo "ok   $name"; else echo "FAIL $name: wanted \"$want\" in:"; sed 's/^/     /' <<< "$got"; failed=1; fi
}

refute() { # <name> <unwanted substring> [args...]
    local name=$1 unwanted=$2; shift 2
    local got; got="$(LIBWORKS="$lib" "$drift" "$@" 2>&1)"
    if [[ $got != *"$unwanted"* ]]; then echo "ok   $name"; else echo "FAIL $name: did not want \"$unwanted\" in:"; sed 's/^/     /' <<< "$got"; failed=1; fi
}

check "a mod that renamed the example names is the same" $'== renamed\n  same' "$tmp/renamed"
check "a mod that kept them is the same" $'== kept\n  same' "$tmp/kept"
check "a mod the template names is the same" $'== named\n  same' "$tmp/named"
check "leaves the glossary out" $'== kept\n  same' "$tmp/kept"
check "leaves out libworks' own tooling the fill removes" $'== renamed\n  same' "$tmp/renamed"
check "reports a file that differs" "mise.toml: 2 lines differ" "$tmp/drifted"
check "reports a missing file" "missing publish/upload.env" "$tmp/drifted"
check "reports a plugin older than the template's" "libworks plugin 0.1.0 (template: 0.2.0)" "$tmp/behind"
check "compares the CI the fill pins" ".github/workflows/ci.yml: 2 lines differ" "$tmp/behind"
check "--release-tooling compares upload.env" "missing publish/upload.env" --release-tooling "$tmp/drifted"
check "--release-tooling compares the plugin version" "libworks plugin 0.1.0 (template: 0.2.0)" --release-tooling "$tmp/behind"
refute "--release-tooling leaves the CI out" "ci.yml" --release-tooling "$tmp/behind"
refute "--release-tooling leaves mise.toml out" "mise.toml" --release-tooling "$tmp/drifted"

exit $failed
