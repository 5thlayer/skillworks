---
name: quicklaunch
description: Launch Minecraft for the checkout you're in, straight into its most recent save — a mod repo (libworks, Groundworks, Beltworks, Craftworks) opens its dev client, the FactoryWorks Pack installs its jar and opens the pack. Use only when the user asks for it — "quicklaunch", "quick launch", "launch the game", "open the client", "install the jar and launch" — never on your own initiative to check a change, since it opens a window on the user's screen.
---

# Quick launch

From anywhere in the checkout, run:

```bash
QUICKLAUNCH_LOG=<scratchpad>/launch.log ${CLAUDE_SKILL_DIR}/quicklaunch.sh [save name]
```

It opens the most recent save unless given one, and a new game's menu when there is none. Pass nothing else: the user is at the display and wants the window.

The script works out which checkout it is in:

- **A mod repo**, a Gradle build whose client run takes `-PquickPlay=<save>` (libworks' `build.gradle` has it), runs `./gradlew runClient` detached and waits for the client's sound engine. Its saves are in `run/saves`.
- **The Pack**, where `scripts/launch.py` sits beside `data/pack/local-jars.json`, runs `:factoryworks_core:installToPack`, then `scripts/launch.py` detached, and checks the log's `launching as` line. Its saves are in `saves/`. It launches as the player in `PF_PLAYER_NAME` and `PF_PLAYER_UUID`, or else in the Pack's `player.env` (those two lines), which it refuses to read unless git ignores it. Without a player it refuses, since a fresh player makes the save's opening quests and starting kit fire again. If it refuses for that, ask the user for their name and UUID rather than guessing.

It refuses when a client of that checkout is already running, when the named save isn't there, and in any other repo. Report its last line in one line: what launched and which save. If it exits non-zero, report its error and don't retry: a running client is the user's to close.

`${CLAUDE_SKILL_DIR}/quicklaunch.sh --dry-run` prints what it would launch and launches nothing. `${CLAUDE_SKILL_DIR}/test.sh` checks its choices on fixture repos.
