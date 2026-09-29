---
name: all-done
description: Debrief on the feature this session worked on — what's implemented, what's reviewed and tested, what's unclear, what to check in game, what comes next. Use when the user asks whether the session's work is finished, such as "is all done in this session?" or "all done here?".
---

# All done?

A **debrief** of the feature this session worked on, for a user who will play-test it and reply by number and letter. The debrief is the whole answer: it reports the session as it stands and changes no code.

## Steps

1. **Gather.** Go back through the session for what the user asked, what they decided, and what you assumed where they hadn't. In each checkout the session touched, run `git status` and `git log` for this session's commits and anything unpushed. Done when every file the session changed, committed or not, belongs to an item you can name.
2. **Weigh the evidence.** For each item, find what backs it: a build, test or GameTest whose result was seen this session (in your output or a subagent's report), or a review (`/code-review`, a reviewing subagent, the user reading the diff). A result from before the item's last edit is stale: rerun it when it takes under a few minutes, otherwise call it stale. Done when every item is backed, stale, or untested.
3. **Report**, in the sections below, in this order. Every section appears, with "None." when empty, so the user sees it was considered.

## The report

**Implemented.** One line per item, saying what it does in game terms. Name the checkout when the session touched more than one, and say which items are uncommitted or unpushed.

**Reviewed and tested.** Each backed item with its evidence: the command and its result (`./gradlew runGameTestServer`: 42 passed), or who reviewed it. Then the stale and untested items by name.

**Unclear or unspecified.** Lettered A, B, C: each open question, and each assumption you made in the user's place, phrased as a question the user can settle in a word or a line.

**Test in game.** Numbered 1, 2, 3, one check per number, so the user can reply "1 ok, 3 wrong: …". Each check gives its setup (which save, gamemode, `/give` with the item ID), the action, and the result to expect. Checks sharing a setup sit together. The list covers what the evidence leaves open: visuals, sounds, feel, interplay with other mods in the Pack, and every untested item.

**Next.** What could come next, most valuable first: the lettered questions once answered, follow-ups the work surfaced, and the step that carries the work further, such as a release through `release-train`.
