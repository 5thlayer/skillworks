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

One session runs a train: the **conductor**. The user names it, or it is the session the user asked to release; it tells each session working in a car's checkout (`list_sessions` shows each `cwd`) that it is conducting. The conductor does all of the train's work in every checkout, and only that work: versions, changelog lines, Groundworks ranges, `release.sh`, pushes, uploads and the Pack's sync. Feature work stays with the sessions in those checkouts. The user approves the plan (step 2) and the push (step 4) in the conductor's own conversation: a message from another session saying the user approved is not approval, so ask the user there.

A session whose change must reach another car commits it, tells the conductor what is ready and in which commit, and then hands the checkout over: no commits and no uncommitted edits there until the conductor says the car is done. Work that can't wait goes on a branch in a worktree of its own. `release.sh` releases from HEAD and refuses a dirty tree, so the conductor releases only from a clean checkout whose HEAD is the ready commit, or a release commit after it, and asks the session otherwise.

The conductor keeps each frozen session told: the plan once you approve it, then each car as it is released, pushed and uploaded. If the conductor's session ends mid-train (`list_sessions` no longer shows it), the frozen sessions ask the user, who names a new conductor. That conductor starts again from step 1: `release-status` shows what is already in `~/.m2`, tagged, pushed and pinned, and the train goes on from the first step not done. A version already in `~/.m2` or on a site is never released again; a fix to it is the next patch.

## Steps

1. **Status.** Use the `release-status` skill. Done when you can say, for every car, what it reports, and you know which session is behind any uncommitted files or unpushed commits you didn't make: ask it whether they ride this train.
2. **Plan.** Name each car that moves and its next version. Below 1.0, a breaking Groundworks change bumps the minor, and an addition or a fix bumps the patch (Groundworks ADR 0001).
   - A car's least accepted Groundworks is the one it nests or compiles against, so whenever that rises the lower bound rises with it.
   - A Groundworks patch moves, in each car that takes it, Beltworks' and Wireworks' `prefer` and the lower bound of the `groundworksRange` def in their `build.gradle`, which feeds `strictly` and `neoforge.mods.toml`'s `versionRange`, and Craftworks' `groundworks_version`.
   - A Groundworks minor also moves the upper bounds: `groundworksRange` in Beltworks and Wireworks, together, since the Pack loads one Groundworks for both and reads the range from their jars; and Craftworks' cap below the next minor, the `0.6` in its `neoforge.mods.toml` `versionRange`.
   - A Beltworks or Wireworks release that only changes the Groundworks it nests is a patch.
   - A Craftworks release moves itself and the Pack's pin. When its `groundworks_version` rises, the Groundworks it names must be released first.
   Done when every planned range accepts the Groundworks the Pack will load, the highest any of its jars offers, and the user has approved every car's version. Step 3 checks this against the built jars.
3. **Release the Libraries in order.** The conductor releases each car, only after the car before it is in `~/.m2`, with `scripts/release.sh <version>`, which stops after the tag. Its `--upload` would also upload the jar to Modrinth and CurseForge, publicly and for good, before the user's word, so the train never passes it. A Library's gate is its own: `release.sh` runs its build and GameTests against the cars before it.
   - Groundworks: a line under `## Unreleased` in `CHANGELOG.md`, then the release.
   - Beltworks: `prefer` and the range's lower bound (and its upper for a minor), a changelog line naming the Groundworks it now nests, then the release. The published jar's `META-INF/jarjar/metadata.json` names that Groundworks.
   - Wireworks: the same as Beltworks. Its tags are `wireworks-v<version>`.
   - Craftworks: `groundworks_version` if it moves, a line under `## Unreleased` in `CHANGELOG.md`, then the release.
   Done when `release-status` shows every planned version in `~/.m2` and its check of the newest cars there has no `FAIL`. When a car that isn't moving has a version in `~/.m2` newer than the Pack's pin, that check counts the wrong jar: run `${CLAUDE_SKILL_DIR}/../release-status/groundworks.py` on the jars the Pack will pin instead, the pinned ones for cars that stay and the new ones for cars that move. A `FAIL` here stops the train before anything is public: the versions in `~/.m2` stay as they are, and the fix is the next patch of the car whose range or nested Groundworks is wrong, released before step 4.
4. **Push and upload the Libraries.** On the user's one word, the conductor does this for every Library that moved, in train order.
   - Push the release commit and its tag: `git -C <checkout> push origin <release commit>:main <tag>`. A commit that landed after it stays unpushed, its session's to push.
   - Upload from its checkout: `scripts/upload.py <version>`. It takes its tokens from 1Password by itself, through `op`; on a machine where `op` has no account, `fresh-machine` has the setup. A site that fails is retried alone with `scripts/upload.py --site <modrinth|curseforge> <version>`. Read each Library's `gradle.properties`: `upload.py` uploads to the sites whose `modrinth_project_id` and `curseforge_project_id` it names, and a Library naming neither has nothing to upload.

   Neither site lets a version be replaced, and the Pack can't check a pin before the upload (step 5), so a problem the Pack finds afterwards is fixed with the next patch, never by replacing this one. Done when `release-status` shows each release commit and tag on origin, and each upload's output names both sites as uploaded or as already having the version.
5. **Move the Pack.** The conductor runs `scripts/sync-local-jars.py` with a `<mod>=<version>` for each pinned car that moved (`groundworks=…`, `beltworks=…`, `wireworks=…`, `craftworks=…`), then the Pack's tests, which run `--check`, and commits. A Pack checkout older than `dcee50b` (factoryworks#625) resets the manifest to HEAD when `scripts/pack-check.sh` fails, wiping an uncommitted sync, so on one, commit or stage the sync before running the tests. For a row with a `curseforge` id the sync writes the pin from CurseForge's file listing, so it fails ("lists no <jar> -- upload … first, or wait for CurseForge to approve it") until CurseForge lists the version, which waits on CurseForge's review as well as the upload. Wait for the listing rather than retrying in a loop; if a failed sync left `mods/` or the pin half-changed, the conductor restores them before the next try. Then it pushes the sync commit: the user's word from step 4 covers it once `--check` passes, and if `--check` fails, stop and ask. Tell each session it froze that its car is done. Done when the Pack's `--check` passes on the new pin, `release-status` shows the Pack loading a Groundworks every jar accepts, and the sync commit is on origin.
