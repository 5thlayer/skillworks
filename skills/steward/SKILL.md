---
name: steward
description: Drive a 5thlayer mod's open pull request to green, handle its review and merge it. Use when asked to steward, babysit or land a PR in libworks or a Module, or to get one green and merged.
---

# Stewarding a PR

The checkout's `CLAUDE.md` wins wherever it says otherwise: on pushing, branches, the merge strategy and which changes skip review. Read it first. The `pr` skill writes the PR's body; this one starts once the PR is open.

Being asked to steward a PR is the user's word for its pushes, its rebases onto `main` and its merge, as the template's `CLAUDE.md` says. A checkout whose `CLAUDE.md` does not say so still pushes and merges only on the user's word: there, propose each push and the merge instead.

## Before any push

- Run both of CI's checks locally and push only if they pass: `sh ./gradlew build` and `sh ./gradlew runGameTestServer`, and any further check `CLAUDE.md` names CI running.
- Commits follow `CLAUDE.md`'s conventional-commit rules.
- A change players or a Consumer notices adds its line under `## Unreleased` in `CHANGELOG.md`.

## Branches

- A branch Claude created is kept current by rebasing onto `main` and pushing with `--force-with-lease`. Commits already on `main` drop out in the rebase.
- Never rewrite a branch someone else created.

## CI

- A failing game test is a real failure, never a flake: root-cause it. `gametest-loop` shows whether it fails every time.

## Review

- The review is the checkout's own `/code-review` project skill, never the built-in one of the same name.
- Fix every finding, optional nits included, in the next push.

## Merging

- Merge with the strategy `CLAUDE.md` names, or with **rebase** when it names none, so `main` stays linear.
- Merge without asking once:
  1. CI is green on the current head, and there is no conflict;
  2. `/code-review` at medium effort or higher has run on that head and every finding it raised is fixed (a fix is a new head: review again), unless `CLAUDE.md` lets the PR's changes skip review;
  3. no human review thread is open or requesting changes.
- Otherwise the PR waits for the user.

## Never

- Bump `mod_version`, tag, publish or upload from a PR: releases follow `docs/agents/releases.md`, on the user's word.
