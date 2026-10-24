---
name: release-train
description: Release train for Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks, Fieldworks, Gearworks and Voidworks, ending with the Showcase pack that carries them, run by one conductor session. Use when a change in one must reach another — releasing several of them together, or moving the Groundworks the others require.
---

# Release train

A train is run by one session, the conductor, under the `conductor` skill: load it first. This skill is the train's own steps.

Groundworks goes first, then Beltworks, Pipeworks, Wireworks, Craftworks and Fieldworks in any order (FactoryWorks ADR-0127). Every car builds, releases and uploads through libworks' convention plugin, and every car but Groundworks requires Groundworks without nesting it, in one range in its `build.gradle`: `libworks { upstream('groundworks') { range = '…' } }`, which the build compiles against, `neoforge.mods.toml` reads as `${groundworks_range}`, and CI builds the lower bound's tag for. Older Beltworks and Wireworks jars nest a copy, and the game loads the highest any jar offers, and every jar's range must accept it, which `release-status` checks. Craftworks also takes Pipeworks, optionally and with no upper bound, so it never waits on a Pipeworks release. The mods otherwise wait on Groundworks alone, never on each other. Gearworks and Voidworks require no Groundworks and release whenever they're ready; Gearworks takes Wireworks, optionally and with no upper bound, so it never waits on a Wireworks release either. The Showcase rides last and isn't a car: it takes the cars from CurseForge, not `~/.m2`, and releases through its own scripts (step 5).

| Car | Checkout | Releases with | Its rules |
|---|---|---|---|
| Groundworks | `~/minecraft_mods/groundworks` | `sh ./gradlew release -PreleaseVersion=<version>`; tags `v<version>` | `docs/agents/releases.md`, ADR 0001 |
| Beltworks | `~/minecraft_mods/beltworks` | `sh ./gradlew release -PreleaseVersion=<version>`; tags `beltworks-v<version>` | `docs/agents/releases.md` |
| Pipeworks | `~/minecraft_mods/pipeworks` | `sh ./gradlew release -PreleaseVersion=<version>`; tags `pipeworks-v<version>` | `docs/agents/releases.md` |
| Wireworks | `~/minecraft_mods/wireworks` | `sh ./gradlew release -PreleaseVersion=<version>`; tags `wireworks-v<version>` | `docs/agents/releases.md` |
| Craftworks | `~/minecraft_mods/craftworks` | `sh ./gradlew release -PreleaseVersion=<version>`; tags `v<version>` | `docs/agents/releases.md` |
| Fieldworks | `~/minecraft_mods/fieldworks` | `sh ./gradlew release -PreleaseVersion=<version>`; tags `fieldworks-v<version>` | `docs/agents/releases.md` |
| Gearworks | `~/minecraft_mods/gearworks` | `sh ./gradlew release -PreleaseVersion=<version>`; tags `gearworks-v<version>` | `docs/agents/releases.md` |
| Voidworks | `~/minecraft_mods/voidworks` | `sh ./gradlew release -PreleaseVersion=<version>`; tags `voidworks-v<version>` | `docs/agents/releases.md` |

Every car's `release` stops after its tag; its `-Pupload` would upload publicly, for good, before the user's word, so the train never passes it, and uploads at step 4 with `sh ./gradlew upload -PreleaseVersion=<version>` from the car's checkout. Craftworks is the mod; "Personal Assembler" stays the name of its in-game feature.

## Steps

1. **Status.** Use the `release-status` skill. Done when you can say, for every car, what it reports, and you know which session is behind any uncommitted files or unpushed commits you didn't make: ask it whether they ride this train.
2. **Plan.** Name each car that moves and its next version, and tell the sessions in those checkouts (`conductor`). Below 1.0, a breaking change bumps the minor, and an addition or a fix bumps the patch (libworks ADR 0001). A car whose `## Unreleased` is empty, or holds nothing a player or pack author would notice, doesn't move: its other commits are pushed without a release.
   - A car's least accepted Groundworks is the one it compiles against, so whenever that rises the lower bound rises with it.
   - A Groundworks patch moves, in each car that takes it, the lower bound of its `upstream('groundworks')` range.
   - A Groundworks minor also moves the upper bound, the next minor, in every car together, since the game loads one Groundworks for all of them.
   - A car's release that only moves the Groundworks it requires is a patch.
   Done when every planned range accepts the Groundworks the newest cars will load together, the highest any of them offers, and the user has approved every car's version. Step 3 checks this against the built jars.
3. **Release the Modules.** The conductor releases each moving Module from a clean checkout at its ready commit (`conductor`): Groundworks first, if it moves, and each mod once the Groundworks it requires is in `~/.m2`: a line under `## Unreleased` in `CHANGELOG.md` and any range change from step 2, then `sh ./gradlew release -PreleaseVersion=<version>`. A Module's gate is its own: `release` runs its build and GameTests against the Groundworks in `~/.m2`.
   Done when `release-status` shows every planned version in `~/.m2` and its check of the newest cars there has no `FAIL`. A `FAIL` stops the train while nothing is public: the versions in `~/.m2` stay, and the fix is the next patch of the car that is wrong.
4. **Push and upload.** On the user's one word (`conductor`), Groundworks first: each Module's release commit and tag, `git -C <checkout> push origin <release commit>:main <tag>`, then `sh ./gradlew upload -PreleaseVersion=<version>` from its checkout. `upload` uploads to the sites whose projects the car's `gradle.properties` names, takes its tokens from 1Password through `op run --env-file=publish/upload.env`, and retries one site with `-Psite=<modrinth|curseforge>`. Neither site lets a version be replaced, so a problem found later is the next patch.
   If `op` fails "No accounts configured", the user turns on the 1Password desktop app's Settings → Developer → "Integrate with 1Password CLI", or runs `op account add`. Under the app integration `op whoami` reports "not signed in" while `op run` works, so test with `upload -PreleaseVersion=<version> -PdryRun`.
   Done when `release-status` shows each release commit and tag on origin, and each upload's output names both sites as uploaded or as already having the version.
5. **Showcase.** The pack in `~/minecraft_mods/factoryworks-showcase` takes each car's file from CurseForge, and packwiz sees a file only once CurseForge has approved it, which can take a day: this step may fall to a later session. There, `packwiz update <file>` for each car that moved, by its file in `mods/`: `groundworks`, `beltworks`, `kc00ls-pipeworks`, `wireworks`, `kc00l-craftworks`, `fieldworks`, `kc00ls-gearworks`, `voidworks`. `scripts/changelog.py mods` then lists each as Updated to its new jar; one still on its old jar isn't approved yet. Commit the updates with a line under `## Unreleased` in its `CHANGELOG.md` for what a player gains from the train, and release the pack as its `README.md` ("Releasing") says; its push and `scripts/upload.py` take the user's word as step 4's do.
   Done when the pack's release is on CurseForge and GitHub, or the user knows which car's approval it waits on.
6. **Finish.** Tell each session the conductor froze that its checkout is its own again (`conductor`).
