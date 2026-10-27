#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 5thlayer
# SPDX-License-Identifier: MIT
#
# Plays a packwiz pack as its checkout stands, in the CurseForge profile it was imported into, with the
# local builds of the mods whose checkouts sit beside the repo: no export, no zip, no copying by hand.
#
#   launch_pack.py --pack <dir with pack.toml> [--dry-run] [--released] [save]
#
# Before each launch it brings the profile up to the checkout and the mod checkouts beside it:
#   - every file index.toml lists outside mods/ (configs, kubejs/) is copied in, so a change to the
#     pack's own files shows without an export;
#   - a mod whose checkout sits beside the repo, ../<mod id>, with a jar in build/libs at the pack's
#     version or later, takes the place of the pack's jar. The pack's jar is set aside in
#     .quicklaunch-local/ and put back on the next run, so --released plays the pack as CurseForge has it.
# It then starts the game the way CurseForge would, from its Install/ folder and bundled Java, on the
# loader the profile names (Forge or NeoForge), offline as the profile's last player, or Dev, into the
# most recent save unless given one, where the Minecraft version has quick play (1.20 and later).
# Singleplayer checks no token. It refuses while a game of the profile is running, since it rewrites mods/.
#
# The profile is the CurseForge instance named as pack.toml names the pack, under the Minecraft root
# CurseForge's settings give; QUICKLAUNCH_INSTANCE names another.
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tomllib
import zipfile
from pathlib import Path

CURSEFORGE_SETTINGS = Path.home() / ".config/CurseForge/storage.json"
SET_ASIDE = ".quicklaunch-local"
# Where the Showcase's own launcher set the pack's jars aside, put back as this one's are.
OLD_SET_ASIDE = (".showcase-local",)
OS_NAME = {"darwin": "osx", "win32": "windows"}.get(sys.platform, "linux")
MODS_TOMLS = ("META-INF/neoforge.mods.toml", "META-INF/mods.toml")


def fail(message):
    sys.exit(f"launch: {message}")


def note(message):
    print(message, file=sys.stderr)


def curseforge_root():
    try:
        settings = json.loads(CURSEFORGE_SETTINGS.read_text())
        return Path(json.loads(settings["minecraft-settings"])["minecraftRoot"])
    except (OSError, KeyError, ValueError):
        fail(f"no Minecraft root in {CURSEFORGE_SETTINGS}; set QUICKLAUNCH_INSTANCE to the profile's folder.")


def profile_name(folder):
    try:
        return json.loads((folder / "minecraftinstance.json").read_text()).get("name")
    except (OSError, ValueError):
        return None


def instance(pack):
    if named := os.environ.get("QUICKLAUNCH_INSTANCE"):
        found = Path(named)
        if not (found / "minecraftinstance.json").is_file():
            fail(f"no CurseForge profile at {found} (QUICKLAUNCH_INSTANCE).")
        return found
    instances = curseforge_root() / "Instances"
    # CurseForge names the folder as the profile was first named; a renamed profile keeps its folder.
    candidates = [instances / pack["name"]] + sorted(instances.glob("*/")) if instances.is_dir() else []
    for folder in candidates:
        if (folder / "minecraftinstance.json").is_file() and pack["name"] in (folder.name, profile_name(folder)):
            return folder
    fail(f"no CurseForge profile \"{pack['name']}\" in {instances}: import the pack into CurseForge once, "
         f"as \"{pack['name']}\", or set QUICKLAUNCH_INSTANCE to its folder.")


def jar_mod(jar):
    """The mod id and version a jar's mods.toml declares, or None for a jar that declares none."""
    try:
        with zipfile.ZipFile(jar) as z:
            names = set(z.namelist())
            toml = next((n for n in MODS_TOMLS if n in names), None)
            if not toml:
                return None
            text = z.read(toml).decode()
            manifest = z.read("META-INF/MANIFEST.MF").decode() if "META-INF/MANIFEST.MF" in names else ""
    except zipfile.BadZipFile:
        return None
    mod = re.search(r'^\s*modId\s*=\s*"([^"]+)"', text, re.M)
    version = re.search(r'^\s*version\s*=\s*"([^"]+)"', text, re.M)
    if not (mod and version):
        return None
    found = version[1]
    if "${" in found:  # ${file.jarVersion}: the manifest has it
        implementation = re.search(r"^Implementation-Version:\s*(\S+)", manifest, re.M)
        if not implementation:
            return None
        found = implementation[1]
    return mod[1], found


def version_key(version):
    return tuple(int(n) for n in re.findall(r"\d+", version))


def local_build(beside, mod):
    """The newest jar the checkout beside the repo, <beside>/<mod>, built, if it builds that mod."""
    libs = beside / mod / "build" / "libs"
    jars = [j for j in libs.glob("*.jar") if not j.name.endswith("-sources.jar")] if libs.is_dir() else []
    for jar in sorted(jars, key=lambda j: j.stat().st_mtime, reverse=True):
        if (found := jar_mod(jar)) and found[0] == mod:
            return jar, found[1]
    return None


def put_back(game):
    """Undo the last run's swaps: its local jars out of mods/, the pack's jars back in."""
    for folder in (SET_ASIDE, *OLD_SET_ASIDE):
        aside = game / folder
        record = aside / "installed.json"
        if record.is_file():
            for name in json.loads(record.read_text()):
                (game / "mods" / name).unlink(missing_ok=True)
            record.unlink()
        if aside.is_dir():
            for jar in aside.glob("*.jar"):
                shutil.move(jar, game / "mods" / jar.name)


def file_hash(path, algorithm):
    return hashlib.new(algorithm, path.read_bytes()).hexdigest()


def sync(pack_dir, pack, game, beside, released, dry):
    if not dry:
        put_back(game)
    index_meta = pack.get("index", {})
    index = tomllib.loads((pack_dir / index_meta.get("file", "index.toml")).read_text())
    default_format = index.get("hash-format", index_meta.get("hash-format", "sha256"))
    copied = 0
    for entry in index.get("files", []):
        path = entry["file"]
        if entry.get("metafile") or path.startswith("mods/"):
            continue
        source, target = pack_dir / path, game / path
        if target.is_file() and file_hash(target, entry.get("hash-format", default_format)) == entry["hash"]:
            continue
        copied += 1
        if not dry:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    note(f"pack files: {copied} copied in" if copied else "pack files: as the checkout has them")
    if released:
        note("mods: as the pack has them (--released)")
        return
    installed = []
    for jar in sorted((game / "mods").glob("*.jar")):
        if not (declared := jar_mod(jar)):
            continue
        mod, version = declared
        if not (local := local_build(beside, mod)) or version_key(local[1]) < version_key(version):
            continue
        name = f"{local[0].stem}-local.jar"
        note(f"mods: {mod} {version} -> local {local[1]} ({local[0].relative_to(beside)})")
        if not dry:
            (game / SET_ASIDE).mkdir(exist_ok=True)
            shutil.move(jar, game / SET_ASIDE / jar.name)
            shutil.copyfile(local[0], game / "mods" / name)
            installed.append(name)
    if installed:
        (game / SET_ASIDE / "installed.json").write_text(json.dumps(installed, indent=2) + "\n")
    elif not dry:
        note("mods: no local build at the pack's version or later")


def player(game, save):
    """The profile's player, whom its saves know, or Dev under the offline UUID.

    Mods put other players in usercache.json (their authors, for skins and credits), so the player is
    the cached one with playerdata in the save, else in any save, else the latest cached.
    """
    try:
        cached = [e for e in json.loads((game / "usercache.json").read_text()) if e["name"] != "Dev"]
    except (OSError, ValueError):
        cached = []
    saves = game / "saves"
    for folder in ([saves / save] if save else []) + [saves / "*"]:
        played = [e for e in cached if any(folder.parent.glob(f"{folder.name}/playerdata/{e['uuid']}.dat"))]
        if played:
            cached = played
            break
    if cached:
        latest = max(cached, key=lambda e: e["expiresOn"])
        return latest["name"], latest["uuid"].replace("-", "")
    digest = bytearray(hashlib.md5(b"OfflinePlayer:Dev").digest())
    digest[6] = (digest[6] & 0x0F) | 0x30
    digest[8] = (digest[8] & 0x3F) | 0x80
    return "Dev", bytes(digest).hex()


def rules_pass(entry):
    for rule in entry.get("rules") or []:
        # Feature-gated arguments (quick play, demo, a custom resolution) stay off: enabling none and
        # letting them through would hand Minecraft its own placeholders as values.
        if "features" in rule:
            return False
        matches = rule.get("os", {}).get("name") in (None, OS_NAME)
        if (rule["action"] == "allow") != matches:
            return False
    return True


def loader_version(game, pack):
    """The version folder CurseForge installed the profile's loader as: forge-43.2.23, neoforge-21.1.1."""
    try:
        named = json.loads((game / "minecraftinstance.json").read_text())["baseModLoader"]["name"]
        if named:
            return named
    except (OSError, ValueError, KeyError, TypeError):
        pass
    versions = pack.get("versions", {})
    for loader in ("neoforge", "forge"):
        if loader in versions:
            return f"{loader}-{versions[loader]}"
    fail(f"the profile names no loader, and pack.toml has neither Forge nor NeoForge: {sorted(versions)}.")


def memory(game):
    """The profile's memory in MB; 0 there means CurseForge's own setting, which applies to every profile."""
    try:
        allocated = int(json.loads((game / "minecraftinstance.json").read_text()).get("allocatedMemory") or 0)
    except (OSError, ValueError, TypeError):
        allocated = 0
    if allocated > 0:
        return allocated
    try:
        settings = json.loads(json.loads(CURSEFORGE_SETTINGS.read_text())["minecraft-settings"])
        if (default := int(settings.get("maxMemoryAllocation") or 0)) > 0:
            return default
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return 6144


def library_jar(libs, lib):
    if path := (lib.get("downloads") or {}).get("artifact", {}).get("path"):
        return libs / path
    group, artifact, ver, *classifier = lib["name"].split(":")
    return libs.joinpath(*group.split("."), artifact, ver,
                         f"{artifact}-{ver}{'-' + classifier[0] if classifier else ''}.jar")


def command(game, pack, save):
    install = game.parent.parent / "Install"
    version = loader_version(game, pack)
    try:
        loader = json.loads((install / f"versions/{version}/{version}.json").read_text())
        mc = json.loads((install / f"versions/{loader['inheritsFrom']}/{loader['inheritsFrom']}.json").read_text())
    except OSError:
        fail(f"CurseForge has not installed {version} in {install}: play the profile once from CurseForge.")
    libs = install / "libraries"
    classpath = []
    for lib in loader["libraries"] + mc["libraries"]:
        if not rules_pass(lib):
            continue
        jar = library_jar(libs, lib)
        if jar.exists() and str(jar) not in classpath:
            classpath.append(str(jar))
    # The loader finds the Minecraft jar itself and leaves it off its module path; on the classpath it
    # is where the launcher's own Minecraft jar would be.
    classpath.append(str(install / f"versions/{version}/{version}.jar"))
    name, uuid = player(game, save)
    subs = {
        "library_directory": str(libs), "classpath_separator": os.pathsep, "version_name": version,
        "natives_directory": str(install / "natives"), "launcher_name": "quicklaunch",
        "launcher_version": "1", "classpath": os.pathsep.join(classpath), "auth_player_name": name,
        "version_type": "release", "game_directory": str(game), "assets_root": str(install / "assets"),
        "assets_index_name": mc["assets"], "auth_uuid": uuid, "auth_access_token": "0", "clientid": "0",
        "auth_xuid": "0", "user_type": "legacy",
    }

    def expand(args):
        out = []
        for arg in args:
            if isinstance(arg, dict):
                if rules_pass(arg):
                    out.extend(arg["value"] if isinstance(arg["value"], list) else [arg["value"]])
            else:
                out.append(arg)
        return [re.sub(r"\$\{(\w+)\}", lambda m: subs.get(m[1], m[0]), a) for a in out]

    java = install / "java" / mc["javaVersion"]["component"] / "bin" / "java"
    jvm = loader.get("arguments", {}).get("jvm", []) + mc["arguments"]["jvm"]
    game_args = mc["arguments"]["game"] + loader.get("arguments", {}).get("game", [])
    cmd = [str(java), f"-Xmx{memory(game)}M", *expand(jvm), loader["mainClass"], *expand(game_args)]
    # Quick play came with Minecraft 1.20; an older one has no flag for it and opens to the menu.
    quick_play = "--quickPlaySingleplayer" in json.dumps(mc["arguments"]["game"])
    if save and quick_play:
        cmd += ["--quickPlaySingleplayer", save]
    return cmd, name, quick_play


def main():
    parser = argparse.ArgumentParser(description="Play a packwiz pack as the checkout stands, with local mod builds.")
    parser.add_argument("--pack", type=Path, default=Path.cwd(), help="the folder with pack.toml")
    parser.add_argument("--beside", type=Path, help="where the mod checkouts are; the pack's repo's parent by default")
    parser.add_argument("--dry-run", action="store_true", help="say what it would copy, swap and run; change nothing")
    parser.add_argument("--released", action="store_true", help="play the pack's own mod jars, no local builds")
    parser.add_argument("save", nargs="?", help="the save to open; the most recent by default")
    args = parser.parse_args()

    pack_dir = args.pack.resolve()
    try:
        pack = tomllib.loads((pack_dir / "pack.toml").read_text())
    except OSError:
        fail(f"no pack.toml in {pack_dir}.")
    if not (beside := args.beside):
        top = subprocess.run(["git", "-C", str(pack_dir), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        beside = Path(top.stdout.strip()).parent if top.returncode == 0 else pack_dir.parent
    beside = beside.resolve()

    game = instance(pack)
    running = subprocess.run(["pgrep", "-f", "--", f"--gameDir {game}"], capture_output=True, text=True).stdout.split()
    if running:
        fail(f"a game of the profile is running (pid {', '.join(running)}); close it first.")
    saves = game / "saves"
    save = args.save
    if save and not (saves / save / "level.dat").is_file():
        fail(f"no save \"{save}\" in {saves}.")
    if not save:
        latest = sorted(saves.glob("*/level.dat"), key=lambda p: p.stat().st_mtime)
        save = latest[-1].parent.name if latest else None

    sync(pack_dir, pack, game, beside, args.released, args.dry_run)
    cmd, name, quick_play = command(game, pack, save)
    note(f"profile: {game}")
    if save and not quick_play:
        note(f"save: none, to the menu (this Minecraft has no quick play; open \"{save}\" from it); player: {name}")
    else:
        note(f"save: {save or 'none, to the menu'}; player: {name}")
    if args.dry_run:
        note("run: " + " ".join(cmd[:2]) + " ... " + " ".join(cmd[-4:]))
        return
    os.chdir(game)
    sys.exit(subprocess.call(cmd))


if __name__ == "__main__":
    main()
