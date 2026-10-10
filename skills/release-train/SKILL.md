---
name: release-train
description: Release train for Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks and the FactoryWorks Pack, run by one conductor session. Use when a change in one must reach another — releasing any of them, moving the Groundworks the others nest or require, or moving the Pack to new versions.
---

# Release train

A train is run by one session, the conductor, under the `conductor` skill: load it first. This skill is the train's own steps.

The cars run in one order: Groundworks → Beltworks → Pipeworks → Wireworks → Craftworks → Pack. Beltworks and Wireworks each nest Groundworks; Craftworks requires it without nesting it, at least its `gradle.properties`' `groundworks_version`; and the Pack pins a Groundworks jar of its own. The game loads one Groundworks, the highest any jar offers, and every jar's range must accept it, which `release-status` checks. Pipeworks doesn't use Groundworks. The Modules wait on Groundworks alone, never on each other; they follow one order only so the train has one.

| Car | Checkout | Releases with | Its rules |
|---|---|---|---|
| Groundworks | `~/minecraft_mods/groundworks` | `scripts/release.sh <version>`; tags `v<version>` | `docs/agents/releases.md`, ADR 0001 |
| Beltworks | `~/minecraft_mods/beltworks` | `scripts/release.sh <version>`; tags `beltworks-v<version>` | `docs/agents/releases.md` |
| Pipeworks | `~/minecraft_mods/pipeworks` | `scripts/release.sh <version>`; tags `pipeworks-v<version>` | `docs/agents/releases.md` |
| Wireworks | `~/minecraft_mods/wireworks` | `scripts/release.sh <version>`; tags `wireworks-v<version>` | `docs/agents/releases.md` |
| Craftworks | `~/minecraft_mods/craftworks` | `scripts/release.sh <version>`; tags `v<version>` | `docs/agents/releases.md` |
| Pack | `$PACK_CHECKOUT`, else the checkout `$CURSEFORGE_ROOT/Instances/FactoryWorks` links to, else `~/MC/factoryworks` | `scripts/sync-local-jars.py <mod>=<version>` | `CLAUDE.md`, "local jar"; `docs/pack/packwiz-workflow.md` |

Every car's `release.sh` stops after its tag; its `--upload` would upload publicly, for good, before the user's word, so the train never passes it, and uploads at step 5 with `scripts/upload.py <version>` from the car's checkout. Craftworks is the mod; "Personal Assembler" stays the name of its in-game feature.

FactoryWorks Core is no car: the Pack's ADR-0128 took its source out of the Pack's repo (it is at the Pack's commit `fb05f50`), and its mechanics are being ported into the Modules. The Pack still loads Core's last release, whose `factoryworks_core` jar in `mods/` requires Groundworks in a range of its own that no release can move: `release-status` checks it with the other jars. FactoryWorks ADR-0115 reshapes the train further as its tickets land, and this skill changes with each.

## Steps

1. **Status.** Use the `release-status` skill. Done when you can say, for every car, what it reports, and you know which session is behind any uncommitted files or unpushed commits you didn't make: ask it whether they ride this train.
2. **Plan.** Name each car that moves and its next version, and tell the sessions in those checkouts (`conductor`). Below 1.0, a breaking change bumps the minor, and an addition or a fix bumps the patch (libworks ADR 0001). A car whose `## Unreleased` is empty, or holds nothing a player or pack author would notice, doesn't move: its other commits are pushed without a release.
   - A car's least accepted Groundworks is the one it nests or compiles against, so whenever that rises the lower bound rises with it.
   - A Groundworks patch moves, in each car that takes it, Beltworks' and Wireworks' `prefer` and the lower bound of the `groundworksRange` def in their `build.gradle`, which feeds `strictly` and `neoforge.mods.toml`'s `versionRange`, and Craftworks' `groundworks_version`.
   - A Groundworks minor also moves the upper bounds: `groundworksRange` in Beltworks and Wireworks, together, since the Pack loads one Groundworks for both; and Craftworks' cap below the next minor, the `0.6` in its `neoforge.mods.toml` `versionRange`. Core's jar caps it too and can't move, so a Groundworks minor waits until the Pack stops loading Core.
   - A Beltworks or Wireworks release that only changes the Groundworks it nests is a patch.
   Done when every planned range accepts the Groundworks the Pack will load, the highest any of its jars offers, and the user has approved every car's version. Step 3 checks this against the built jars.
3. **Release the Libraries.** The conductor releases each moving Library in order, from a clean checkout at its ready commit (`conductor`), after the car before it is in `~/.m2`: a line under `## Unreleased` in `CHANGELOG.md` and any range change from step 2, then `scripts/release.sh <version>`. A Library's gate is its own: `release.sh` runs its build and GameTests against the cars before it. For Beltworks and Wireworks, the published jar's `META-INF/jarjar/metadata.json` names the Groundworks it nests.
   Done when `release-status` shows every planned version in `~/.m2` and its check of the newest cars there has no `FAIL`. When a car that isn't moving has a version in `~/.m2` newer than the Pack's pin, that check counts the wrong jar: run `${CLAUDE_SKILL_DIR}/../release-status/groundworks.py` on the jars the Pack will pin instead. A `FAIL` stops the train while nothing is public: the versions in `~/.m2` stay, and the fix is the next patch of the car that is wrong.
4. **Take the Libraries into the Pack.** From a clean Pack checkout, the conductor runs `scripts/sync-local-jars.py` with a `<mod>=<version>` for each pinned car that moved (`groundworks=…`, `beltworks=…`, `pipeworks=…`, `wireworks=…`, `craftworks=…`). It installs and pins from `~/.m2` at once; a row whose CurseForge file isn't listed yet prints a line starting `pending ` and waits for step 6. Then the Pack's tests, which run `--check` (passing with rows pending), and a commit. A failure here stops the train while nothing is public, as at step 3.
   Done when the Pack's tests pass on the new pins and the sync is committed.
5. **Push and upload.** On the user's one word (`conductor`), in train order: each Library's release commit and tag, `git -C <checkout> push origin <release commit>:main <tag>`, then `scripts/upload.py <version>` from its checkout; then the Pack's commit from step 4. `upload.py` uploads to the sites whose `modrinth_project_id` and `curseforge_project_id` the car's `gradle.properties` names, takes its tokens from 1Password through `op` (`fresh-machine` sets that up), and retries one site with `--site <modrinth|curseforge>`. Neither site lets a version be replaced, so a problem found later is the next patch.
   Done when `release-status` shows each release commit and tag on origin, and each upload's output names both sites as uploaded or as already having the version.
6. **Fill in the Pack's CurseForge references.** CurseForge lists an upload only after its review, which can take hours: come back to it rather than waiting in a loop. Once it lists them, the conductor runs a plain `scripts/sync-local-jars.py` in the Pack, which fills in every pending reference. The conductor then runs `scripts/sync-local-jars.py --check --strict`, commits and pushes; the user's word from step 5 covers it once `--strict` passes. The Pack is never exported while a row is pending: `--check --strict` is the gate, since the Pack has no export script to run it.
   Done when no `pending ` line remains, `--check --strict` passes, and the commit is on origin.
7. **Finish.** Tell each session the conductor froze that its checkout is its own again (`conductor`).
