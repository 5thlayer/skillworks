---
name: release-status
description: Read-only status of the release train for Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks and the FactoryWorks Pack — each car's version, what ~/.m2 holds, what isn't pushed, which Groundworks the Pack loads and whether every jar accepts it, and release tooling that drifts from libworks' template. Use when the user asks where a release stands, what's unreleased or unpushed, or whether the Pack can take a new version, and as release-train's first step.
---

# Release status

Run `${CLAUDE_SKILL_DIR}/status.sh`. It fetches and changes nothing else. Report what it shows; it neither releases nor pushes.

It prints, in train order:

- **Each car** (Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks, then the Pack): its branch against origin, `mod_version`, the versions in `~/.m2`, uncommitted tracked files, and unpushed commits and tags. For Beltworks and Wireworks, the Groundworks they nest (`prefer`, `groundworksRange`). For Craftworks, the least Groundworks it requires.
- **Release tooling against libworks' template**, from the `template-drift` skill's script: per checkout, `same` or each of `release.sh`, `upload.py`, its tests and `upload.env` that differs. That skill lists the intended differences; any other is drift, which the conductor fixes from the template before releasing with it.
- **Groundworks, were the Pack to take the newest cars in `~/.m2`**: the Groundworks the game would load, the highest version among the newest Groundworks jar and the copies nested in the newest Beltworks and Wireworks, and whether each car's `neoforge.mods.toml` range accepts it.
- **The Pack**: found through `PACK_CHECKOUT`, then `$CURSEFORGE_ROOT/Instances/FactoryWorks`, then `~/MC/factoryworks`. Its pins, `scripts/sync-local-jars.py --check` (a line starting `pending ` is a CurseForge reference still to fill in, release-train's step 6), and the same Groundworks check over the jars in its `mods/`, which is what the game loads. That includes `factoryworks_core`, FactoryWorks Core's last release, which nothing releases any more (the Pack's ADR-0128).

A `FAIL` line names a jar whose range refuses the Groundworks that would load. In the newest-cars check, that means a car still to release, or a pin that can't move without another one moving too. In the Pack's check, it means the Pack as it stands won't start. Either way, name the jar, its range and the loaded Groundworks.

Unpushed commits and uncommitted files you didn't make belong to the session working in that checkout (`list_sessions` shows each `cwd`). Report them as theirs.
