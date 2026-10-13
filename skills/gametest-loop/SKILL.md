---
name: gametest-loop
description: Run a 5thlayer mod's game tests many times over, with Gradle only once, to prove them stable or catch a flaky failure. Use when asked to repeat or loop the game tests, or whether a game test is flaky.
---

# Game-test loop

Gradle runs once; every further run starts the game-test server JVM directly. A loop through `./gradlew` holds a Gradle client and daemon for its whole length, and other projects' sessions on this machine wait on those slots.

From anywhere in the mod's checkout, in the background (a run takes about 25–70 s):

```bash
${CLAUDE_SKILL_DIR}/gametest-loop.sh [runs]
```

It builds with `./gradlew --no-daemon writeGameTestServerCommand`, which has libworks' plugin write the server's whole command line to `build/moddev/gameTestServerRunCommand.txt`, then runs the server directly `runs` times (default 10). A plugin older than that task gets `runGameTestServer` instead, which runs the tests once while the script reads the server's command line from `/proc`. `--no-daemon` leaves no daemon of this checkout behind, so there is none to stop afterwards.

It prints a line per run (`passed`, `<n> failed: <tests>`, `crashed`, `timed out`), then how many passed and, for each failed test, the runs it failed in. Report those last lines. The logs are in `build/gametest-loop/`: read a failed run's `run<i>.log` for the assertion. Exit 0 means every run passed, 1 that one did not, 2 a refusal: report the refusal and leave the cause to the user.

## A subset of the tests

To loop only some tests, such as the flaky ones under suspicion, pass a selector, `namespace:pattern`:

```bash
${CLAUDE_SKILL_DIR}/gametest-loop.sh --tests 'gearworks:solar_*' [runs]
```

Every run then reads `build/gametest-loop/gameTestServerRunProgramArgs.txt`, a copy of the build's program arguments with that selector in place of `<modId>:*`. Don't edit the files in `build/moddev` instead: a loop without `--tests` re-reads them every run. With a plugin older than `writeGameTestServerCommand`, the one run through Gradle still runs every test.

## After a change

Edited sources need Gradle: run it again without `--reuse`, and it rebuilds. With nothing changed since the last build, `--reuse [runs]` skips Gradle, with or without `--tests`; it refuses once `src/` or the build files are newer than that build.

To check that a file compiles without Gradle:

```bash
javac -proc:none -d <scratchpad>/classes -cp "$(${CLAUDE_SKILL_DIR}/gametest-loop.sh --classpath)" <files>
```

## Stopping processes

To stop the loop, stop its background task: the script then stops the Gradle build or server it started. Stop a process yourself only once you've proved this session owns it: its parent chain leads to this session's own claude process, or its cwd is this checkout. A matching command line is no proof: another session's server or shell matches the same pattern, and a kill on a pattern match once cut off another Claude session's background work. Daemons are shared by every checkout of their Gradle version, so `./gradlew --stop` stops other sessions' builds: leave daemons to the user.

`${CLAUDE_SKILL_DIR}/test.sh` checks the loop on fixture repos with a fake server.
