---
name: release-status
description: Read-only status of the release train for Groundworks, Beltworks, Pipeworks, Wireworks and Craftworks — each car's version, what ~/.m2 holds, what isn't pushed, which Groundworks the newest cars load together and whether each accepts it, and release tooling that drifts from libworks' template. Use when the user asks where a release stands, what's unreleased or unpushed, or whether the mods accept a new Groundworks, and as release-train's first step.
---

# Release status

Run `${CLAUDE_SKILL_DIR}/status.sh`. It fetches and changes nothing else. Report what it shows; it neither releases nor pushes.

It prints, in train order:

- **Each car** (Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks): its branch against origin, `mod_version`, the versions in `~/.m2`, uncommitted tracked files, and unpushed commits and tags. For every car but Groundworks, the Groundworks range it requires, from `upstream('groundworks') { range }` in its `build.gradle`.
- **Release tooling against libworks' template**, from the `template-drift` skill's script: per checkout, `same`, or the libworks plugin version `build.gradle` applies when it isn't the template's (the plugin carries the release and upload tasks), and `upload.env` when it differs. That skill lists the intended differences; any other is drift, which the conductor fixes from the template before releasing with it.
- **Groundworks, loaded with the newest cars in `~/.m2`**: the Groundworks the game would load, the highest version among the newest Groundworks jar and any copy nested in a newest car, and whether each car's `neoforge.mods.toml` range accepts it.

A `FAIL` line names a jar whose range refuses the Groundworks that would load: a car still to release. Name the jar, its range and the loaded Groundworks.

Unpushed commits and uncommitted files you didn't make belong to the session working in that checkout (`list_sessions` shows each `cwd`). Report them as theirs.
