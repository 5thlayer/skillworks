---
name: fresh-machine
description: Bootstrap the FactoryWorks Pack on a machine with an empty ~/.m2 and no jars in mods/ — a fresh clone, a new computer, a wiped Gradle or maven cache. Use when the user asks to set up the Pack, get its mods, or rebuild the local jars from source.
---

# Fresh machine

A **bootstrap** puts every jar the Pack's manifest names on disk, byte for byte the jar it names, and makes the checkout CurseForge's FactoryWorks profile. A jar that cannot be reproduced is the user's call: the pin never moves silently. Commands run from the Pack checkout, which is the working directory's repo.

## Steps

1. **Tools.** Install through mise and keep them out of the user's global config (`mise exec <tool>@<version> -- …`):
   - Java 25 builds the Libraries, which `bootstrap.py` does from source. The Pack itself builds nothing: its ADR-0128 took Core and its Gradle build out.
   - packwiz at `PACKWIZ_SHA` in `scripts/pack-check.sh`: `go install github.com/packwiz/packwiz@<sha>`, then move the binary to `~/go/bin` (mise's Go sets `GOBIN` inside its own install). `sync-local-jars.py` calls `packwiz` by name, so `~/go/bin` goes on `PATH` for it.
   - `uv` for the Python checks.
   - The 1Password CLI (`op`), for the Libraries' `scripts/upload.py` and its `--dry-run`, which take the site tokens through `op run`. With no account it fails "No accounts configured": the user turns on the desktop app's Settings → Developer → "Integrate with 1Password CLI", or runs `op account add` with their account's sign-in address (Settings → Accounts in the app). Under the app integration `op whoami` reports "not signed in" while `op run` works, so test with `upload.py --dry-run`.
   Done when each runs, and a Library's `upload.py --dry-run` gets past 1Password.

2. **CurseForge.** When CurseForge's root is not `~/curseforge`, `CURSEFORGE_ROOT` is exported in the user's shell rc. In CurseForge, the user creates a custom profile named `FactoryWorks` on the Minecraft and NeoForge versions `pack.toml` names. It lands in `Instances/FactoryWorks (1)` once the link exists, which `bootstrap.py instance` adopts. Done when the profile exists and CurseForge is quit: it rewrites its instance list while running.

3. **Bootstrap.** `mise exec java@<25> -- scripts/bootstrap.py`: it links `Instances/FactoryWorks` to the checkout, adopts the profile, downloads the CurseForge jars and puts every `local-jars.json` row into `~/.m2` from its `source`. It stops on a jar that differs from its recorded hash; report that to the user, who moves the pin or copies the jar from another machine. Done when it prints `next: scripts/sync-local-jars.py`.

4. **Sync.** `PATH=~/go/bin:$PATH scripts/sync-local-jars.py`, then `--check`. Done when `--check` prints `OK`.

5. **Verify.** Run `uv run --with pytest pytest tests/`; then the user presses Play in CurseForge, and `scripts/check-launch.sh` reads the log. The adopted profile lists no mods until the user presses refresh in the profile's mod list. Its "Update all" offers CurseForge's newer files: the manifest's pins decide versions, so updating there makes `pack-check.sh` report them. After a pin moves, compare the tracked `config/` with HEAD: a mod that moves a setting between its config files writes its default in the new place. If the run moved a pin, also run `scripts/jar-registry-extract.py`. Done when each passes, or each failure is reported to the user with whether `main` fails it too.
