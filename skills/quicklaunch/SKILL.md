---
name: quicklaunch
description: Launch the dev client of the mod repo you're in (libworks, Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks, Fieldworks), or a packwiz modpack's CurseForge profile (the FactoryWorks Showcase, Mechanical Mastery Plus, any other) with the local builds of the mods, straight into its most recent save. Use only when the user asks for it — "quicklaunch", "quick launch", "launch the game", "open the client" — never on your own initiative to check a change, since it opens a window on the user's screen.
---

# Quick launch

From anywhere in the checkout, run:

```bash
QUICKLAUNCH_LOG=<scratchpad>/launch.log ${CLAUDE_SKILL_DIR}/quicklaunch.sh [save name]
```

It opens the most recent save unless given one, and a new game's menu when there is none. Pass nothing else: the user is at the display and wants the window.

In a mod repo, a Gradle build whose client run takes `-PquickPlay=<save>` (libworks' convention plugin, `io.github.5thlayer.libworks.module`, adds it to every build that applies it), the script runs `./gradlew runClient` detached and waits for the client's sound engine. Its saves are in `run/saves`.

In a packwiz pack's checkout it runs `launch_pack.py` instead, which plays the pack's CurseForge profile offline on CurseForge's Java, on the Forge or NeoForge the profile names. The pack is the `pack.toml` at or above the working directory, or the one folder under the repo root with a `pack.toml`; a repo root with several packs is refused, so run it from inside the one wanted. The profile is the CurseForge instance named as `pack.toml` names the pack; `QUICKLAUNCH_INSTANCE` names another folder. Before each launch it copies the checkout's configs and `kubejs/` into the profile, and puts each mod's local build, `../<mod id>/build/libs` beside the repo, in place of the pack's jar when it is at the pack's version or later. So a mod's change shows in the pack once its checkout is built. The saves are the profile's. Minecraft before 1.20 has no quick play, so there it opens to the menu and says which save to pick. The launcher refuses while the profile's game is running, or when the pack was never imported into CurseForge, and says so.

Gradle runs with `--no-daemon`, so the game leaves no idle daemon behind once it closes. Never stop daemons yourself, with `./gradlew --stop` or otherwise: every checkout of a Gradle version shares them, and another session may be building with one.

It refuses when a client of that checkout is already running, when the named save isn't there, when a mod checkout has no Java (JAVA_HOME unset and mise has none pinned there; it prints the `mise use` line that pins one, which is the user's to run), in a repo root with several packs, and in any other repo. In a pack, the launcher's own refusals are reported the same way. Report its last line in one line: what launched and which save. If it exits non-zero, report its error and don't retry: a running client is the user's to close, never yours to kill.

`${CLAUDE_SKILL_DIR}/quicklaunch.sh --dry-run` prints what it would launch and launches nothing. `${CLAUDE_SKILL_DIR}/test.sh` checks its choices on fixture repos.
