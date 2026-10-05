#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
"""Which Groundworks a set of mod jars loads, and whether every jar accepts it.

    groundworks.py <jar>...

Groundworks comes as a jar of its own or nested in another (META-INF/jarjar/metadata.json), and
NeoForge loads one: the highest version offered. Each jar's neoforge.mods.toml names the range it
accepts. Prints that Groundworks and one line per jar that requires it; exits 1 when one refuses it.
"""
import json, re, sys, zipfile
from pathlib import Path


def version(text):
    return tuple(int(p) for p in re.findall(r"\d+", text))


def accepts(rng, v):
    m = re.fullmatch(r"([\[(])([^,\]]*)(?:,([^\])]*))?([\])])", rng.strip())
    if not m:
        return True  # a range NeoForge would refuse to read is the build's to catch
    lo_inc, lo, hi, hi_inc = m.group(1) == "[", m.group(2), m.group(3), m.group(4) == "]"
    if hi is None:  # [a]: exactly a
        return v == version(lo)
    if lo and (v < version(lo) or (v == version(lo) and not lo_inc)):
        return False
    if hi and (v > version(hi) or (v == version(hi) and not hi_inc)):
        return False
    return True


offers, needs = [], []  # (version, where), (jar, range)
for path in map(Path, sys.argv[1:]):
    with zipfile.ZipFile(path) as jar:
        names = set(jar.namelist())
        toml = jar.read("META-INF/neoforge.mods.toml").decode() if "META-INF/neoforge.mods.toml" in names else ""
        if re.match(r"groundworks-\d", path.name):
            offers.append((version(path.stem.split("-")[-1]), 1, path.name))
            continue
        if "META-INF/jarjar/metadata.json" in names:
            for j in json.loads(jar.read("META-INF/jarjar/metadata.json"))["jars"]:
                if j["identifier"]["artifact"] == "groundworks":
                    offers.append((version(j["version"]["artifactVersion"]), 0, f"nested in {path.name}"))
        dep = re.search(r'modId *= *"groundworks"[^\[]*?versionRange *= *"([^"]+)"', toml)
        if dep:
            needs.append((path.name, dep.group(1)))

if not needs and not offers:
    sys.exit(0)
if not offers:
    print("  Groundworks: none offered, but required by " + ", ".join(n for n, _ in needs))
    sys.exit(1)
loaded, _, source = max(offers)  # a jar of its own over a nested copy of the same version
shown = ".".join(map(str, loaded))
print(f"  Groundworks loaded: {shown} ({source}; offered: "
      + ", ".join(f"{'.'.join(map(str, v))} {w}" for v, _, w in sorted(offers)) + ")")
bad = 0
for name, rng in needs:
    ok = accepts(rng, loaded)
    bad |= not ok
    print(f"  {'ok  ' if ok else 'FAIL'} {name} accepts {rng}" + ("" if ok else f", not {shown}"))
sys.exit(bad)
