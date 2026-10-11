---
name: release-train
description: Release train for Groundworks, Beltworks, Pipeworks, Wireworks and Craftworks, run by one conductor session. Use when a change in one must reach another — releasing several of them together, or moving the Groundworks the others require.
---

# Release train

A train is run by one session, the conductor, under the `conductor` skill: load it first. This skill is the train's own steps.

The cars run in one order: Groundworks → Beltworks → Pipeworks → Wireworks → Craftworks. Beltworks, Wireworks and Craftworks each require Groundworks without nesting it: Beltworks and Wireworks in their `groundworksRange`, Craftworks at least its `gradle.properties`' `groundworks_version`. Older Beltworks and Wireworks jars nest a copy, and the game loads the highest any jar offers, and every jar's range must accept it, which `release-status` checks. Pipeworks doesn't use Groundworks. The Modules wait on Groundworks alone, never on each other; they follow one order only so the train has one.

| Car | Checkout | Releases with | Its rules |
|---|---|---|---|
| Groundworks | `~/minecraft_mods/groundworks` | `scripts/release.sh <version>`; tags `v<version>` | `docs/agents/releases.md`, ADR 0001 |
| Beltworks | `~/minecraft_mods/beltworks` | `scripts/release.sh <version>`; tags `beltworks-v<version>` | `docs/agents/releases.md` |
| Pipeworks | `~/minecraft_mods/pipeworks` | `scripts/release.sh <version>`; tags `pipeworks-v<version>` | `docs/agents/releases.md` |
| Wireworks | `~/minecraft_mods/wireworks` | `scripts/release.sh <version>`; tags `wireworks-v<version>` | `docs/agents/releases.md` |
| Craftworks | `~/minecraft_mods/craftworks` | `scripts/release.sh <version>`; tags `v<version>` | `docs/agents/releases.md` |

Every car's `release.sh` stops after its tag; its `--upload` would upload publicly, for good, before the user's word, so the train never passes it, and uploads at step 4 with `scripts/upload.py <version>` from the car's checkout. Craftworks is the mod; "Personal Assembler" stays the name of its in-game feature.

## Steps

1. **Status.** Use the `release-status` skill. Done when you can say, for every car, what it reports, and you know which session is behind any uncommitted files or unpushed commits you didn't make: ask it whether they ride this train.
2. **Plan.** Name each car that moves and its next version, and tell the sessions in those checkouts (`conductor`). Below 1.0, a breaking change bumps the minor, and an addition or a fix bumps the patch (libworks ADR 0001). A car whose `## Unreleased` is empty, or holds nothing a player or pack author would notice, doesn't move: its other commits are pushed without a release.
   - A car's least accepted Groundworks is the one it compiles against, so whenever that rises the lower bound rises with it.
   - A Groundworks patch moves, in each car that takes it, Beltworks' and Wireworks' `prefer` and the lower bound of the `groundworksRange` def in their `build.gradle`, which feeds `strictly` and `neoforge.mods.toml`'s `versionRange`, and Craftworks' `groundworks_version`.
   - A Groundworks minor also moves the upper bounds: `groundworksRange` in Beltworks and Wireworks, together, since the game loads one Groundworks for both; and Craftworks' cap below the next minor, the `0.6` in its `neoforge.mods.toml` `versionRange`.
   - A Beltworks or Wireworks release that only moves the Groundworks it requires is a patch.
   Done when every planned range accepts the Groundworks the newest cars will load together, the highest any of them offers, and the user has approved every car's version. Step 3 checks this against the built jars.
3. **Release the Libraries.** The conductor releases each moving Library in order, from a clean checkout at its ready commit (`conductor`), after the car before it is in `~/.m2`: a line under `## Unreleased` in `CHANGELOG.md` and any range change from step 2, then `scripts/release.sh <version>`. A Library's gate is its own: `release.sh` runs its build and GameTests against the cars before it.
   Done when `release-status` shows every planned version in `~/.m2` and its check of the newest cars there has no `FAIL`. A `FAIL` stops the train while nothing is public: the versions in `~/.m2` stay, and the fix is the next patch of the car that is wrong.
4. **Push and upload.** On the user's one word (`conductor`), in train order: each Library's release commit and tag, `git -C <checkout> push origin <release commit>:main <tag>`, then `scripts/upload.py <version>` from its checkout. `upload.py` uploads to the sites whose `modrinth_project_id` and `curseforge_project_id` the car's `gradle.properties` names, takes its tokens from 1Password through `op run`, and retries one site with `--site <modrinth|curseforge>`. Neither site lets a version be replaced, so a problem found later is the next patch.
   If `op` fails "No accounts configured", the user turns on the 1Password desktop app's Settings → Developer → "Integrate with 1Password CLI", or runs `op account add`. Under the app integration `op whoami` reports "not signed in" while `op run` works, so test with `upload.py --dry-run`.
   Done when `release-status` shows each release commit and tag on origin, and each upload's output names both sites as uploaded or as already having the version.
5. **Finish.** Tell each session the conductor froze that its checkout is its own again (`conductor`).
