---
name: release-train
description: Release train for Groundworks, Beltworks, Craftworks and the PlanetaryFactory Pack. Use when a change in one must reach another — releasing Groundworks, Beltworks or Craftworks, moving the Groundworks that Beltworks nests, or syncing the Pack to a new Beltworks or Craftworks.
---

# Release train

The cars run in one order: Groundworks → Beltworks → Craftworks → Pack. Beltworks nests Groundworks, and the Pack loads only the Beltworks jar it pins, with the Groundworks inside it. Craftworks depends on neither: the Pack pins its jar directly, so it waits on no car ahead of it and only the Pack waits on it. A change reaches the Pack only once every car it depends on is released to `~/.m2`, where a version is final.

| Car | Checkout | Releases with | Its rules |
|---|---|---|---|
| Groundworks | `~/minecraft_mods/groundworks` | `scripts/release.sh <version>` | `docs/agents/releases.md`, ADR 0001 |
| Beltworks | `~/minecraft_mods/beltworks` | `scripts/release.sh --no-upload <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md` |
| Craftworks | `~/minecraft_mods/craftworks` | `scripts/release.sh <version>` | `docs/agents/releases.md` |
| Pack | `~/curseforge/Instances/PlanetaryFactory` | `scripts/sync-local-jars.py <mod>=<version>` | `CLAUDE.md`, "local jar" |

Craftworks is the mod; "Personal Assembler" stays the name of its in-game feature. Its releases are tagged `v<version>` and publish `io.github.5thlayer:craftworks` to `~/.m2`. Until the Pack's `data/pack/local-jars.json` has a `craftworks` row, the Pack doesn't load it. Adding that row is the Pack's change, made when the Pack switches off its own `core/assembler/`.

## Ownership

Each checkout has one owner: the session whose working directory it is (`list_sessions` shows each `cwd`). Commit and release only in your own checkout; the push is step 4's. For a change in another car, message its owner with exactly what you need and wait for its reply. When no session owns that checkout, ask the user.

## Steps

1. **Status.** Run `${CLAUDE_SKILL_DIR}/status.sh`. Done when you can say, for every car: its `mod_version`, its newest version in `~/.m2`, its unpushed commits and tags, and any uncommitted files; which Groundworks Beltworks nests; and the Pack's pin and `--check` result. Before building on a car that has uncommitted files or unpushed work you didn't make, ask its owner.
2. **Plan.** Name each car that moves and its next version. Below 1.0, a breaking Groundworks change bumps the minor, and an addition or a fix bumps the patch (Groundworks ADR 0001).
   - A Groundworks patch needs only Beltworks' `prefer` in `build.gradle`.
   - A Groundworks minor needs Beltworks' range moved in both `build.gradle` (`strictly`) and `neoforge.mods.toml` (`versionRange`), and the Pack reads the new range from Beltworks' jar.
   - A Beltworks release that only changes the Groundworks it nests is a patch.
   - A Craftworks release moves only itself and the Pack's pin; it never waits on Groundworks or Beltworks.
   Done when the user has approved every car's version.
3. **Run the cars in order.** Each owner releases its own car, only after the car before it is in `~/.m2`:
   - Groundworks: a line under `## Unreleased` in `CHANGELOG.md`, then `scripts/release.sh`.
   - Beltworks: `prefer` (and the range for a minor), a changelog line naming the Groundworks it now nests, then `scripts/release.sh --no-upload <version>`. Without `--no-upload` it would also upload the jar to Modrinth and CurseForge, publicly and for good, before the user's word and before the Pack's `--check` passes on the new pin. The published jar's `META-INF/jarjar/metadata.json` names that Groundworks.
   - Craftworks: a line under `## Unreleased` in `CHANGELOG.md`, then `scripts/release.sh`.
   - Pack: `scripts/sync-local-jars.py` with a `<mod>=<version>` for each car that moved (`beltworks=…`, `craftworks=…`), then the Pack's tests, which run `--check`.
   Done when `status.sh` shows every planned version in `~/.m2` and the Pack's `--check` passes on the new pin.
4. **Push.** The session the user tells to push pushes every car itself, in train order, with its new tags: `git -C <checkout> push origin main <tags>`. A push publishes commits the owners already made, so it needs no owner's word, only the user's. Push exactly the commits and tags `status.sh` listed; if `git log origin/main..HEAD` shows any more, ask the user first. Then, if Beltworks moved, upload it from its checkout: `scripts/upload.py <version>`. Like the push, an upload is public and final (neither site lets a version be replaced), so it needs the user's word; it takes its tokens from 1Password by itself. A site that fails is retried alone with `scripts/upload.py --site <modrinth|curseforge> <version>`. Then tell each owner its car is pushed. Done when `status.sh` shows no unpushed commits or tags, and a moved Beltworks' upload output names both sites as uploaded or as already having the version.
