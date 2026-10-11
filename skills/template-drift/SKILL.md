---
name: template-drift
description: Compare the 5thlayer mods (Groundworks, Beltworks, Wireworks, Craftworks, Pipeworks, Fieldworks, Voidworks, Gearworks) with libworks' template, and carry a template fix out to them. Use when the template changes, when a fix lands in one mod's shared tooling or docs, when asked how far the mods have drifted from libworks, or when release-status reports release tooling that differs.
---

# Template drift

Every Library starts as a copy of 5thlayer/libworks, filled by its `scripts/fill-template.sh`, and its shared files (`publish/upload.env`, `mise.toml`, `.gitignore`, the CI workflow, `docs/agents/`, the Gradle wrapper, `LICENSE`) drift as the template and each mod change apart. The release and upload tasks are no longer files in a mod: the libworks convention plugin carries them, at the version `build.gradle` applies, and the CI calls the plugin's `module-ci.yml` at that version's tag. A fix made in one place and not the others is how Groundworks 0.5.4 went up early: the template's `release.sh` fix was missing from a copy, before the plugin took the script over.

## Check

Run `${CLAUDE_SKILL_DIR}/drift.sh` for every shared file, or `${CLAUDE_SKILL_DIR}/drift.sh --release-tooling` for only what a release reads from the mod, the libworks plugin version and `upload.env`; either can name checkouts to compare. It clones the template's `main` and fills it as `fill-template.sh` fills a new Library, so libworks' own plugin, runtime and tooling tests are left out and the CI is the one a Module gets. It reads each mod's names as the template's example ones, ignores each repo's tag prefix, and prints, per checkout, `same`, or the libworks plugin version `build.gradle` applies when it isn't the template's, and each file that differs, with a count of differing lines, or that is missing.

A difference is either **intended**, one of those below, or **drift**. For anything not on the list, `diff` the file against the template and decide which. Done when every difference is accounted for.

Intended:

- **Beltworks**: `upload.env` names the 1Password items without the template's line that every Library shares Beltworks' items, as their owner. Its issue tracker, labels and `LICENSE` are its own, from Upstream and FactoryWorks. It has no `publishing.md`, since its projects predate the doc.
- **Craftworks**: `upload.env`'s comment says Craftworks where the template says every Library. Its glossary and tracker docs. No `publishing.md`, like Beltworks.
- **Pipeworks**: `publishing.md` names its CurseForge project "5thlayer Pipeworks", since another mod holds Pipeworks there, and its icon and cover in `publish/`.
- **Wireworks, Fieldworks**: a CI job, `textures`, that checks the committed textures against the script that builds them.
- **Voidworks**: it calls itself a Module, not a Library (voidworks#24), in `upload.env`, `publishing.md` and the CI comment.
- **`docs/agents/releases.md`** everywhere: each mod's own changelog sections and history.

A libworks plugin older than the template's is a mod not yet moved to it: `build.gradle`'s version and the CI's `plugin-v` tag move together, as one `build: move to libworks-plugin <version>` commit.

## Carry a fix

A fix to shared tooling or docs lands in the template first, then in each mod that has the file, as its own commit there, with the same wording; a mod's name replaces the example one where the file names it. Then `drift.sh` shows each checkout back to `same` or to only its intended differences. When other sessions work in those checkouts, the change is conducted under the `conductor` skill, which covers handing the checkouts over, the user's approval and pushing exact commits. A fix changes no jar, so it needs no release: its commits are pushed as they are, or ride under the next release commit.
