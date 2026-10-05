---
name: release-status
description: Read-only status of the release train for Groundworks, Beltworks, Wireworks, Craftworks and the FactoryWorks Pack — each car's version, what ~/.m2 holds, what isn't pushed, which Groundworks the Pack loads and whether every jar accepts it, and release.sh drift. Use when the user asks where a release stands, what's unreleased or unpushed, or whether the Pack can take a new version, and as release-train's first step.
---

# Release status

Run `${CLAUDE_SKILL_DIR}/status.sh`. It fetches and changes nothing else. Report what it shows; it neither releases nor pushes.

It prints, in train order:

- **Each car** (Groundworks, Beltworks, Wireworks, Craftworks, then the Pack): its branch against origin, `mod_version`, the versions in `~/.m2`, uncommitted tracked files, and unpushed commits and tags. For Beltworks and Wireworks, the Groundworks they nest (`prefer`, `groundworksRange`). For Craftworks, the least Groundworks it requires.
- **release.sh against libworks' template**, ignoring comments and the tag line: `same`, or how many lines differ. The known differences are Beltworks' `-PsiblingBuilds` refusal, Craftworks' upload without the "names no project" check, and the Pack's own script, which releases FactoryWorks Core. Any other difference is drift: compare it with the template, which carries the fixes.
- **Groundworks, were the Pack to take the newest cars in `~/.m2`**: the Groundworks the game would load, the highest version among the newest Groundworks jar and the copies nested in the newest Beltworks and Wireworks, and whether each car's `neoforge.mods.toml` range accepts it.
- **The Pack**: found through `PACK_CHECKOUT`, then `$CURSEFORGE_ROOT/Instances/FactoryWorks`, then `~/MC/factoryworks`. Its pins, `scripts/sync-local-jars.py --check`, and the same Groundworks check over the jars in its `mods/`, which is what the game loads.

A `FAIL` line names a jar whose range refuses the Groundworks that would load. In the newest-cars check, that means a car still to release, or a pin that can't move without another one moving too. In the Pack's check, it means the Pack as it stands won't start. Either way, name the jar, its range and the loaded Groundworks.

Unpushed commits and uncommitted files you didn't make belong to the session working in that checkout (`list_sessions` shows each `cwd`). Report them as theirs.
