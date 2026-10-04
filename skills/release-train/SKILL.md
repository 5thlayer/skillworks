---
name: release-train
description: Release train for Groundworks, Beltworks, Wireworks, Craftworks and the FactoryWorks Pack. Use when a change in one must reach another — releasing Groundworks, Beltworks, Wireworks or Craftworks, moving the Groundworks that Beltworks or Wireworks nests, or syncing the Pack to a new Beltworks, Wireworks or Craftworks.
---

# Release train

The cars run in one order: Groundworks → Beltworks → Wireworks → Craftworks → Pack. Beltworks and Wireworks each nest Groundworks, in the same range, and the Pack loads only the Beltworks and Wireworks jars it pins, with the Groundworks inside them. Wireworks waits on Groundworks alone, never on Beltworks; it follows Beltworks only so the train has one order. Craftworks depends on neither: the Pack pins its jar directly, so it waits on no car ahead of it and only the Pack waits on it. A change reaches the Pack only once every car it depends on is released to `~/.m2` and, for a car the Pack pins from CurseForge, listed there: a version is final in both places.

| Car | Checkout | Releases with | Its rules |
|---|---|---|---|
| Groundworks | `~/minecraft_mods/groundworks` | `scripts/release.sh --no-upload <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md`, ADR 0001 |
| Beltworks | `~/minecraft_mods/beltworks` | `scripts/release.sh --no-upload <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md` |
| Wireworks | `~/minecraft_mods/wireworks` | `scripts/release.sh --no-upload <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md` |
| Craftworks | `~/minecraft_mods/craftworks` | `scripts/release.sh --no-upload <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md` |
| Pack | `$CURSEFORGE_ROOT/Instances/FactoryWorks` (default root `~/curseforge`) | `scripts/sync-local-jars.py <mod>=<version>` | `CLAUDE.md`, "local jar" |

Craftworks is the mod; "Personal Assembler" stays the name of its in-game feature. Its releases are tagged `v<version>` and publish `io.github.5thlayer:craftworks` to `~/.m2`.

## Ownership

Each checkout has one owner: the session whose working directory it is (`list_sessions` shows each `cwd`). Commit and release only in your own checkout; pushing and uploading are steps 4 and 5's. For a change in another car, message its owner with exactly what you need and wait for its reply. When no session owns that checkout, ask the user.

## Steps

1. **Status.** Run `${CLAUDE_SKILL_DIR}/status.sh`. Done when you can say, for every car: its `mod_version`, its newest version in `~/.m2`, its unpushed commits and tags, and any uncommitted files; which Groundworks Beltworks and Wireworks nest; and the Pack's pin and `--check` result. Before building on a car that has uncommitted files or unpushed work you didn't make, ask its owner.
2. **Plan.** Name each car that moves and its next version. Below 1.0, a breaking Groundworks change bumps the minor, and an addition or a fix bumps the patch (Groundworks ADR 0001).
   - A Groundworks patch needs only the `prefer` in Beltworks' and Wireworks' `build.gradle`.
   - A Groundworks minor needs the `groundworksRange` def moved in both Beltworks' and Wireworks' `build.gradle`, which feeds `strictly` and `neoforge.mods.toml`'s `versionRange`; the Pack reads the new range from their jars. Both must move together, since the Pack loads one Groundworks for both.
   - A Beltworks or Wireworks release that only changes the Groundworks it nests is a patch.
   - A Craftworks release moves only itself and the Pack's pin; it never waits on Groundworks or Beltworks.
   Done when the user has approved every car's version.
3. **Release the Libraries in order.** Each owner releases its own car, only after the car before it is in `~/.m2`, with `scripts/release.sh --no-upload <version>`. Without `--no-upload` the script also uploads the jar to Modrinth and CurseForge, publicly and for good, before the user's word. A Library's gate is its own: `release.sh` runs its build and GameTests against the cars before it.
   - Groundworks: a line under `## Unreleased` in `CHANGELOG.md`, then the release.
   - Beltworks: `prefer` (and the range for a minor), a changelog line naming the Groundworks it now nests, then the release. The published jar's `META-INF/jarjar/metadata.json` names that Groundworks.
   - Wireworks: the same as Beltworks. Its tags are `wireworks-v<version>`.
   - Craftworks: a line under `## Unreleased` in `CHANGELOG.md`, then the release.
   Done when `status.sh` shows every planned version in `~/.m2`.
4. **Push and upload the Libraries.** The session the user tells to push does this for every Library that moved, in train order, on that one word: a push and an upload each publish what the owners already made, so they need no owner's word, only the user's.
   - Push with its new tags: `git -C <checkout> push origin main <tags>`. Push exactly the commits and tags `status.sh` listed; if `git log origin/main..HEAD` shows any more, ask the user first.
   - Upload from its checkout: `scripts/upload.py <version>`. It takes its tokens from 1Password by itself, through `op`; on a machine where `op` has no account, `fresh-machine` has the setup. A site that fails is retried alone with `scripts/upload.py --site <modrinth|curseforge> <version>`. A Library whose `gradle.properties` names no Modrinth or CurseForge project (Wireworks, for now) has nothing to upload.

   Neither site lets a version be replaced, and the Pack can't check a pin before the upload (step 5), so a problem the Pack finds afterwards is fixed with the next patch, never by replacing this one. Done when `status.sh` shows no unpushed commits or tags on the Libraries, and each upload's output names both sites as uploaded or as already having the version.
5. **Move the Pack.** The Pack's owner runs `scripts/sync-local-jars.py` with a `<mod>=<version>` for each pinned car that moved (`beltworks=…`, `wireworks=…`, `craftworks=…`; Groundworks rides inside Beltworks and Wireworks), then the Pack's tests, which run `--check`, and commits. For a row with a `curseforge` id the sync writes the pin from CurseForge's file listing, so it fails ("lists no <jar> -- upload … first, or wait for CurseForge to approve it") until CurseForge lists the version, which waits on CurseForge's review as well as the upload. Wait for the listing rather than retrying in a loop; if a failed sync left `mods/` or the pin half-changed, the Pack's owner restores them before the next try. Then the session told to push pushes the Pack: the user's word from step 4 covers it once `--check` passes, and if `--check` fails, stop and ask. Tell each owner its car is pushed. Done when the Pack's `--check` passes on the new pin and `status.sh` shows nothing unpushed.
