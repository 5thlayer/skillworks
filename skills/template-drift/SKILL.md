---
name: template-drift
description: Compare the 5thlayer mods (Groundworks, Beltworks, Wireworks, Craftworks, Pipeworks) and the Pack's release.sh with libworks' template, and carry a template fix out to them. Use when the template changes, when a fix lands in one mod's shared tooling or docs, when asked how far the mods have drifted from libworks, or when release-status reports release tooling that differs.
---

# Template drift

Every Library starts as a copy of 5thlayer/libworks, and its shared files (`scripts/release.sh`, `scripts/upload.py` and its tests, `publish/upload.env`, `mise.toml`, the CI workflow, `docs/agents/`) drift as the template and each mod change apart. A fix made in one place and not the others is how Groundworks 0.5.4 went up early: the template's `release.sh` fix was missing from a copy.

## Check

Run `${CLAUDE_SKILL_DIR}/drift.sh` for every shared file, or `${CLAUDE_SKILL_DIR}/drift.sh --release-tooling` for only what a release runs; either can name checkouts to compare. It clones the template's `main`, reads each mod's names as the template's example ones, ignores each repo's tag prefix, and prints, per checkout, `same` or each file that differs, with a count of differing lines, or that is missing.

A difference is either **intended**, one of those below, or **drift**. For anything not on the list, `diff` the file against the template and decide which. Done when every difference is accounted for.

Intended:

- **Beltworks**: `upload.py` and its tests check the NOTICE crediting Rearth and malcolmriley, the CC BY text, and the nested Groundworks' licence. `release.sh` refuses a build under `-PsiblingBuilds`. `upload.env` names the 1Password items without the template's comment, as their owner. Its CI, issue tracker, labels, `LICENSE` and game-test platform are its own, from Upstream and the Pack. It has no `publishing.md`, since its projects predate the doc.
- **Craftworks**: "Mod" for "Library" in `release.sh`'s and `upload.env`'s comments. Its own CI step that builds Groundworks, its glossary and tracker docs. No `publishing.md`, like Beltworks.
- **Wireworks, Craftworks, Beltworks**: a CI step that builds the tagged Groundworks into the runner's `~/.m2`. A game-test platform sized for their tests.
- **`docs/agents/releases.md`** everywhere: each mod's own changelog sections and history.
- **The Pack**: its `release.sh` releases FactoryWorks Core with its own tag and changelog; only the argument handling and the upload default must match the template's.

## Carry a fix

A fix to shared tooling or docs lands in the template first, then in each mod that has the file, as its own commit there, with the same wording; a mod's name replaces the example one where the file names it. Then `drift.sh` shows each mod back to `same` or its intended difference. When other sessions work in those checkouts, the change is conducted under the `conductor` skill, which covers handing the checkouts over, the user's approval and pushing exact commits. A fix changes no jar, so it needs no release: its commits are pushed as they are, or ride under the next release commit.
