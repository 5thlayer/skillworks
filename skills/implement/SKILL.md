---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Read each ticket's labels first (`docs/agents/triage-labels.md`). A ticket without `ready-for-agent` is not yet work: tell the user what it lacks (an open investigation, no seam, no acceptance criterion), offer a timebox, and start only on their word.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the work's own tests together at the end: its game tests share a name prefix, so one `gametest-loop` selector runs them all. The whole suite runs at the end of iterating.

Once done, use /code-review to review the work.

Commit your work to the current branch.

Then iterate: follow `${CLAUDE_SKILL_DIR}/../iterate/SKILL.md` from its first round, as if the user had typed `/iterate`.
