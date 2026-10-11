---
name: quicklaunch
description: Launch the dev client of the mod repo you're in (libworks, Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks, Fieldworks), straight into its most recent save. Use only when the user asks for it — "quicklaunch", "quick launch", "launch the game", "open the client" — never on your own initiative to check a change, since it opens a window on the user's screen.
---

# Quick launch

From anywhere in the checkout, run:

```bash
QUICKLAUNCH_LOG=<scratchpad>/launch.log ${CLAUDE_SKILL_DIR}/quicklaunch.sh [save name]
```

It opens the most recent save unless given one, and a new game's menu when there is none. Pass nothing else: the user is at the display and wants the window.

The checkout must be a mod repo, a Gradle build whose client run takes `-PquickPlay=<save>` (libworks' `build.gradle` has it). The script runs `./gradlew runClient` detached and waits for the client's sound engine. Its saves are in `run/saves`.

Gradle runs with `--no-daemon`, so the game leaves no idle daemon behind once it closes. Never stop daemons yourself, with `./gradlew --stop` or otherwise: every checkout of a Gradle version shares them, and another session may be building with one.

It refuses when a client of that checkout is already running, when the named save isn't there, when a mod checkout has no Java (JAVA_HOME unset and mise has none pinned there; it prints the `mise use` line that pins one, which is the user's to run), and in any other repo. Report its last line in one line: what launched and which save. If it exits non-zero, report its error and don't retry: a running client is the user's to close, never yours to kill.

`${CLAUDE_SKILL_DIR}/quicklaunch.sh --dry-run` prints what it would launch and launches nothing. `${CLAUDE_SKILL_DIR}/test.sh` checks its choices on fixture repos.
