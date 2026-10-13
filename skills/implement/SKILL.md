---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Read each ticket's labels first (`docs/agents/triage-labels.md`). A ticket without `ready-for-agent` is not yet work: tell the user what it lacks (an open investigation, no seam, no acceptance criterion), offer a timebox, and start only on their word.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work.

Commit your work to the current branch.
