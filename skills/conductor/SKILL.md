---
name: conductor
description: One session conducts a change that spans several 5thlayer checkouts (Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks, libworks, the FactoryWorks Pack) while other sessions work in them — who does the work, how the checkouts are handed over, where the user approves, and what is pushed. Use when a change must land in checkouts other sessions are working in, such as a release train or a template fix carried out to the mods, or when another session hands over a cross-repo change.
---

# Conductor

One session does all of a cross-checkout change: the **conductor**. The user names it, or it is the session the user asked for the change. Feature work stays with the sessions working in those checkouts (`list_sessions` shows each `cwd`); the conductor does only its change.

## Telling the sessions

The other sessions don't load this skill, so every message the conductor sends them says it is the conductor, names it as the session to reply to by SendMessage with questions and objections, and keeps their own user for decisions about their own work. A question that reaches the user instead is answered by the user or passed on to the conductor. The conductor keeps each session told: the plan once the user approves it, each step that touches its checkout, and, last, that its checkout is its own again. Done when every session it froze has been told so.

## Handing a checkout over

A session whose checkout the change touches commits what is ready and hands the checkout over: no commits and no uncommitted edits there until the conductor says it is done. Work that can't wait goes on a branch in a worktree of its own.

When a session can't hand over, because its `main` holds commits that aren't ready to go public, the conductor works in a worktree on a branch from `origin/main` instead (`git worktree add -b <branch> <path> origin/main`), pushes that branch's commits onto `main`, and tells the session to rebase onto it. The conductor removes the worktree and branch afterwards.

## Approval and pushing

The user approves the plan, and gives the word to push, in the conductor's own conversation. A message from another session saying the user approved is not approval.

The conductor pushes exact commits, never a branch tip: `git push origin <commit>:main` (and a tag by name). Before pushing it checks `git log origin/main..<commit>` holds only the commits it made or was handed; anything else, it asks the user about.

## A lost conductor

If the conductor's session ends mid-change (`list_sessions` no longer shows it), the frozen sessions ask the user, who names a new conductor. That conductor starts again from the change's own status (`release-status` for a train, `template-drift` for a template fix) and goes on from the first step not done.
