---
name: release-train
description: Release train for Groundworks, Beltworks, Wireworks, Craftworks and the FactoryWorks Pack, run by one conductor session. Use when a change in one must reach another — releasing Groundworks, Beltworks, Wireworks or Craftworks, moving the Groundworks that Beltworks or Wireworks nests, or syncing the Pack to a new Beltworks, Wireworks or Craftworks.
---

# Release train

The cars run in one order: Groundworks → Beltworks → Wireworks → Craftworks → Pack. Beltworks and Wireworks each nest Groundworks; Craftworks requires it without nesting it, at least its `gradle.properties`' `groundworks_version`; and the Pack pins a Groundworks jar of its own. The game loads one Groundworks, the highest any jar offers, and every jar's range must accept it, which `release-status` checks. Wireworks waits on Groundworks alone, never on Beltworks; it follows Beltworks only so the train has one order. FactoryWorks ADR-0115 un-nests Groundworks from Beltworks and Wireworks too; until their `build.gradle` drops its `jarJar`, the nesting below holds. A change reaches the Pack only once every car it depends on is released to `~/.m2` and, for a car the Pack pins from CurseForge, listed there: a version is final in both places.

| Car | Checkout | Releases with | Its rules |
|---|---|---|---|
| Groundworks | `~/minecraft_mods/groundworks` | `scripts/release.sh <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md`, ADR 0001 |
| Beltworks | `~/minecraft_mods/beltworks` | `scripts/release.sh <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md` |
| Wireworks | `~/minecraft_mods/wireworks` | `scripts/release.sh <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md` |
| Craftworks | `~/minecraft_mods/craftworks` | `scripts/release.sh <version>`, then `scripts/upload.py <version>` at step 4 | `docs/agents/releases.md` |
| Pack | `$PACK_CHECKOUT`, else the checkout `$CURSEFORGE_ROOT/Instances/FactoryWorks` links to, else `~/MC/factoryworks` | `scripts/sync-local-jars.py <mod>=<version>` | `CLAUDE.md`, "local jar" |

Craftworks is the mod; "Personal Assembler" stays the name of its in-game feature. Its releases are tagged `v<version>` and publish `io.github.5thlayer:craftworks` to `~/.m2`.

## The conductor

One session runs a train: the **conductor**. The user names it, or it is the session the user asked to release; it tells each session working in a car's checkout (`list_sessions` shows each `cwd`) that it is conducting. The conductor does all of the train's work in every checkout, and only that work: versions, changelog lines, Groundworks ranges, `release.sh`, pushes, uploads and the Pack's sync. Feature work stays with the sessions in those checkouts.

A session whose change must reach another car commits it, tells the conductor what is ready and in which commit, and then commits nothing more on that checkout's `main` until the conductor says the car is done. The conductor works from the commits `release-status` listed and pushes those exact commits; anything that lands after is a later train's.

## Steps

1. **Status.** Use the `release-status` skill. Done when you can say, for every car, what it reports, and you know which session is behind any uncommitted files or unpushed commits you didn't make: ask it whether they ride this train.
2. **Plan.** Name each car that moves and its next version. Below 1.0, a breaking Groundworks change bumps the minor, and an addition or a fix bumps the patch (Groundworks ADR 0001).
   - A car's least accepted Groundworks is the one it nests or compiles against, so whenever that rises the lower bound rises with it.
   - A Groundworks patch moves, in each car that takes it, Beltworks' and Wireworks' `prefer` and the lower bound of the `groundworksRange` def in their `build.gradle`, which feeds `strictly` and `neoforge.mods.toml`'s `versionRange`, and Craftworks' `groundworks_version`.
   - A Groundworks minor also moves the upper bounds: `groundworksRange` in Beltworks and Wireworks, together, since the Pack loads one Groundworks for both and reads the range from their jars; and Craftworks' cap below the next minor, the `0.6` in its `neoforge.mods.toml` `versionRange`.
   - A Beltworks or Wireworks release that only changes the Groundworks it nests is a patch.
   - A Craftworks release moves itself and the Pack's pin. When its `groundworks_version` rises, the Groundworks it names must be released first.
   Done when `release-status`'s check of the newest cars in `~/.m2`, with the planned ones counted, would load a Groundworks every car accepts, and the user has approved every car's version.
3. **Release the Libraries in order.** The conductor releases each car, only after the car before it is in `~/.m2`, with `scripts/release.sh <version>`, which stops after the tag. Its `--upload` would also upload the jar to Modrinth and CurseForge, publicly and for good, before the user's word, so the train never passes it. A Library's gate is its own: `release.sh` runs its build and GameTests against the cars before it.
   - Groundworks: a line under `## Unreleased` in `CHANGELOG.md`, then the release.
   - Beltworks: `prefer` and the range's lower bound (and its upper for a minor), a changelog line naming the Groundworks it now nests, then the release. The published jar's `META-INF/jarjar/metadata.json` names that Groundworks.
   - Wireworks: the same as Beltworks. Its tags are `wireworks-v<version>`.
   - Craftworks: `groundworks_version` if it moves, a line under `## Unreleased` in `CHANGELOG.md`, then the release.
   Done when `release-status` shows every planned version in `~/.m2`.
4. **Push and upload the Libraries.** On the user's one word, the conductor does this for every Library that moved, in train order.
   - Push the release commit and its tag: `git -C <checkout> push origin <release commit>:main <tag>`. A commit that landed after it stays unpushed, its session's to push.
   - Upload from its checkout: `scripts/upload.py <version>`. It takes its tokens from 1Password by itself, through `op`; on a machine where `op` has no account, `fresh-machine` has the setup. A site that fails is retried alone with `scripts/upload.py --site <modrinth|curseforge> <version>`. Read each Library's `gradle.properties`: `upload.py` uploads to the sites whose `modrinth_project_id` and `curseforge_project_id` it names, and a Library naming neither has nothing to upload.

   Neither site lets a version be replaced, and the Pack can't check a pin before the upload (step 5), so a problem the Pack finds afterwards is fixed with the next patch, never by replacing this one. Done when `release-status` shows each release commit and tag on origin, and each upload's output names both sites as uploaded or as already having the version.
5. **Move the Pack.** The conductor runs `scripts/sync-local-jars.py` with a `<mod>=<version>` for each pinned car that moved (`groundworks=…`, `beltworks=…`, `wireworks=…`, `craftworks=…`), then the Pack's tests, which run `--check`, and commits. A Pack checkout older than `dcee50b` (factoryworks#625) resets the manifest to HEAD when `scripts/pack-check.sh` fails, wiping an uncommitted sync, so on one, commit or stage the sync before running the tests. For a row with a `curseforge` id the sync writes the pin from CurseForge's file listing, so it fails ("lists no <jar> -- upload … first, or wait for CurseForge to approve it") until CurseForge lists the version, which waits on CurseForge's review as well as the upload. Wait for the listing rather than retrying in a loop; if a failed sync left `mods/` or the pin half-changed, the conductor restores them before the next try. Then it pushes the sync commit: the user's word from step 4 covers it once `--check` passes, and if `--check` fails, stop and ask. Tell each session it froze that its car is done. Done when the Pack's `--check` passes on the new pin, `release-status` shows the Pack loading a Groundworks every jar accepts, and the sync commit is on origin.
