#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# What quicklaunch launches (ADR 0001): the working directory, when it is itself a packwiz pack or a
# mod build whose client run takes -PquickPlay; at the repo root, the repo's one such target; or the
# target --in names, from anywhere in the checkout. Nothing walks up the tree, so a folder that is
# neither is refused with the candidates listed.
#
#   targets.py --root <git root> --start <working dir> [--in <query>]
#
# Prints the target as `<pack|mod>\t<path>\t<name>\t<path from the root>`, or refuses on stderr.
#
# A mod build inside a pack's folder is that pack's companion mod: no target of its own, only swapped
# into the pack, which launch_pack.py does by the mod id its jar declares.
import argparse
import os
import re
import sys
from pathlib import Path

# Hidden folders hold .git and .claude/worktrees, whose packs are other checkouts', not this one's.
PRUNE = {"build", "run", "node_modules"}
# libworks' convention plugin adds the hook to the client run of every build that applies it.
HOOK = re.compile(r"""id ['"]io\.github\.5thlayer\.libworks\.module['"]|gradleProperty\(['"]quickPlay""")


def fail(message):
    sys.exit(f"quicklaunch: {message}")


def read(path):
    try:
        return path.read_text()
    except (OSError, UnicodeDecodeError):
        return ""


def is_pack(folder):
    return re.search(r'^pack-format = "packwiz:', read(folder / "pack.toml"), re.M) is not None


def is_build(folder):
    return (folder / "gradlew").is_file() and (folder / "build.gradle").is_file()


def has_hook(folder):
    return HOOK.search(read(folder / "build.gradle")) is not None


def walk(root):
    """Every folder in the checkout, parents before their children, but hidden ones and build output."""
    for here, dirs, _ in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d not in PRUNE)
        yield Path(here)


class Target:
    def __init__(self, kind, path, root):
        self.kind, self.path = kind, path
        self.rel = "." if path == root else path.relative_to(root).as_posix()
        if kind == "pack":
            named = re.search(r'^name = "(.*)"', read(path / "pack.toml"), re.M)
            self.name = named[1] if named else path.name
        else:
            named = re.search(r"^\s*mod_id\s*=\s*(\S+)", read(path / "gradle.properties"), re.M)
            self.name = named[1] if named else path.name
        # What --in matches: the path, its last folder (the root's own name for the root), the name.
        self.keys = [self.rel, path.name, self.name]

    def __str__(self):
        return f"{self.rel} ({self.name})"


def targets(root):
    found, packs = [], []
    for folder in walk(root):
        if is_pack(folder):
            packs.append(folder)
            found.append(Target("pack", folder, root))
        elif is_build(folder) and has_hook(folder) and not any(folder.is_relative_to(p) for p in packs):
            found.append(Target("mod", folder, root))
    return found


def listing(found):
    return ", ".join(map(str, found))


def tier(query, key):
    """How closely a key matches: 0 equal, 1 a prefix, 2 a substring, 3 its letters in order; None not at all."""
    key = re.sub(r"[^a-z0-9]", "", key.lower())
    if not key:
        return None
    if key == query:
        return 0
    if key.startswith(query):
        return 1
    if query in key:
        return 2
    letters = iter(key)
    return 3 if all(c in letters for c in query) else None


def match(query, found):
    q = re.sub(r"[^a-z0-9]", "", query.lower())
    if not q:
        fail(f"--in \"{query}\" has nothing to match; name a pack or mod: {listing(found)}.")
    scored = []
    for target in found:
        tiers = [t for key in target.keys if (t := tier(q, key)) is not None]
        if tiers:
            scored.append((min(tiers), target))
    if not scored:
        fail(f"nothing here matches \"{query}\": {listing(found) or 'the checkout has no pack nor mod build'}.")
    best = min(t for t, _ in scored)
    top = [target for t, target in scored if t == best]
    if len(top) > 1:
        fail(f"\"{query}\" matches several, equally: {listing(top)}; name one more closely.")
    return top[0]


def resolve(root, start, query):
    found = targets(root)
    if query is not None:
        return match(query, found)
    for target in found:
        if target.path == start:
            return target
    rel = "." if start == root else start.relative_to(root).as_posix() if start.is_relative_to(root) else str(start)
    pack = next((t for t in reversed(found) if t.kind == "pack" and start.is_relative_to(t.path)), None)
    if pack and is_build(start) and has_hook(start):
        fail(f"{rel} is {pack.name}'s companion mod, swapped into the pack rather than launched on its own; "
             f"launch the pack with --in {pack.rel}.")
    if is_build(start):
        fail("build.gradle has no -PquickPlay hook on its client run; apply libworks' convention plugin, "
             "io.github.5thlayer.libworks.module.")
    if start == root:
        if not found:
            fail(f"{root} is not a mod repo nor a packwiz pack.")
        if len(found) == 1:
            return found[0]
        fail(f"{root} has several targets; name one with --in: {listing(found)}.")
    if not found:
        fail(f"{rel} is not a pack nor a mod build, and {root} has none.")
    fail(f"{rel} is not a pack nor a mod build with the -PquickPlay hook; "
         f"run from one, or name one with --in: {listing(found)}.")


def main():
    parser = argparse.ArgumentParser(description="Say what quicklaunch launches.")
    parser.add_argument("--root", type=Path, required=True, help="the checkout's git root")
    parser.add_argument("--start", type=Path, required=True, help="the working directory")
    parser.add_argument("--in", dest="query", help="a pack or mod to match fuzzily by path, pack name or mod id")
    args = parser.parse_args()
    target = resolve(args.root.resolve(), args.start.resolve(), args.query)
    print("\t".join((target.kind, str(target.path), target.name, target.rel)))


if __name__ == "__main__":
    main()
