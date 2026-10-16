---
name: iterate
description: Refine a feature after its own tests pass, checking each change against that feature alone, until the user says it is done; then run the whole test suite before the merge.
disable-model-invocation: true
---

# Iterate

The feature is built and its own tests are green. The user now refines it, often by looking at it in the dev client, a round at a time. Each round checks the feature alone; the whole suite runs once, at the exit.

## Each round

1. Make the change the user asks for.
2. Check it: `sh ./gradlew build` for the compile and the JUnit tests, then the feature's own game tests alone, through the `gametest-loop` skill (`--tests '<modid>:<prefix>*' 1`, the prefix the feature's tests share). A change only the user can judge, such as a pose, a texture or a timing, needs the compile alone; the user relaunches the client, or asks for `quicklaunch`.
3. Report what changed and what the check covered. Commit the change once the user accepts it.

Iterating ends only when the user says it is done.

## Exit

1. Run the whole suite once: `sh ./gradlew build` and `sh ./gradlew runGameTestServer`. If it goes red, fix it and run the whole suite again, until it is green.
2. Review what changed the Module's behaviour since the last review, with the checkout's `/code-review`, and commit.
3. Go on to the merge or push the checkout's `CLAUDE.md` describes, on the user's word.
