---
name: quicklaunch
description: Launch the dev client of the mod repo you're in (libworks, Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks, Fieldworks), or a packwiz modpack's CurseForge profile (the FactoryWorks Showcase, Mechanical Mastery Plus, any other) with the local builds of the mods, straight into its most recent save. Use only when the user asks for it — "quicklaunch", "quick launch", "launch the game", "open the client" — never on your own initiative to check a change, since it opens a window on the user's screen.
---

# Quick launch

Run:

```bash
QUICKLAUNCH_LOG=<scratchpad>/launch.log ${CLAUDE_SKILL_DIR}/quicklaunch.sh [--in <pack or mod>] [save name]
```

It opens the most recent save unless given one, and a new game's menu when there is none. Pass nothing else: the user is at the display and wants the window.

It launches only the folder it is given (docs/adr/0001): the working directory must itself be a packwiz pack or a mod build with the `-PquickPlay` hook, and any other folder is refused, with the candidates listed. At the repo root it launches the repo's one candidate, and refuses several. `--in <query>` names a target from anywhere in the checkout. It is matched fuzzily against each candidate's path, pack name and mod id, and a tie is refused. A mod build inside a pack's folder is that pack's companion mod. It is no target, only swapped into the pack.

Pick the target this way:

- When the user names one ("launch Reborn"), pass their words as `--in`.
- Otherwise run it from the session's working directory, without `--in`.
- If that is refused, pass `--in <candidate's path>` only when every file the session changed sits under that one candidate. Otherwise ask the user which candidate, and list them as the refusal did.

For a mod build, a Gradle build whose client run takes `-PquickPlay=<save>` (libworks' convention plugin, `io.github.5thlayer.libworks.module`, adds it to every build that applies it), the script runs `./gradlew runClient` detached and waits for the client's sound engine. Its saves are in `run/saves`.

For a packwiz pack it runs `launch_pack.py` instead, which plays the pack's CurseForge profile offline on CurseForge's Java, on the Forge or NeoForge the profile names. The profile is the CurseForge instance named as `pack.toml` names the pack; `QUICKLAUNCH_INSTANCE` names another folder. Before each launch it copies the checkout's configs and `kubejs/` into the profile, and puts each mod's local build in place of the pack's jar when it is at the pack's version or later. A local build is `<mod id>/build/libs` beside the main checkout (from a worktree too), or a mod build inside the pack's repo, matched by the mod id its jar declares. So a mod's change shows in the pack once its checkout is built. The saves are the profile's. Minecraft before 1.20 has no quick play, so there it opens to the menu and says which save to pick. The launcher refuses while the profile's game is running, or when the pack was never imported into CurseForge, and says so.

Gradle runs with `--no-daemon`, so the game leaves no idle daemon behind once it closes. Never stop daemons yourself, with `./gradlew --stop` or otherwise: every checkout of a Gradle version shares them, and another session may be building with one.

It refuses in these cases:

- a client of that checkout is already running;
- the named save isn't there;
- a mod checkout has no Java (JAVA_HOME is unset and mise has none pinned there). It prints the `mise use` line that pins one, which is the user's to run;
- the folder is not a target, or the repo root has several;
- `--in` matches nothing, or ties.

In a pack, the launcher's own refusals are reported the same way. Report its last line, which names what launched and which save, in one line. If it exits non-zero, report its error and don't retry: a running client is the user's to close, never yours to kill.

`${CLAUDE_SKILL_DIR}/quicklaunch.sh --dry-run` prints what it would launch and launches nothing. `${CLAUDE_SKILL_DIR}/test.sh` checks its choices on fixture repos.
