# Renaming a Library

ADR-0090 doesn't forbid a rename, but it costs a round of churn in every repo that names the Library: `placementpreview` became Groundworks after its first commit (groundworks `8b1424e`, the Pack's `df83508`, Beltworks' `321be3f`). Before starting, list everything below that exists for this Library, and have the user approve the new names (as in `SKILL.md` step 2).

What a rename touches:

- **The Library's repo.** The mod id, package, class names, `gradle.properties` (`mod_id`, `mod_name`, `archives_name`), `settings.gradle`'s `rootProject.name`, `neoforge.mods.toml`, the `assets/` and `data/` namespaces, the mixin config, `CONTEXT.md`, the README, and the GameTest namespace in `--tests "${mod_id}:*"`. Then the GitHub repo: `gh repo rename <new> -R 5thlayer/<old>` (GitHub redirects the old URL), and move the checkout to `~/minecraft_mods/<new>`.
- **Save ids.** Every block, item and block entity id changes namespace, so existing saves drop them unless remapped. Ask the user which, and record it in the changelog and an ADR.
- **Tags.** Old tags stay, as they name published versions. If the prefix carries the old name, new releases use the new prefix in `scripts/release.sh` and `docs/agents/releases.md`. Versions continue; a rename is a breaking change, so it bumps the minor below 1.0 (the Library's ADR 0001, from libworks).
- **`~/.m2`.** The new artifact starts a new directory; the old one's versions stay final and unpinned.
- **Libraries that nest it.** A Library that jar-in-jars it (Beltworks nests Groundworks) updates its `build.gradle` entry for it, its `neoforge.mods.toml` `modId`, its imports, and its own `local-jars.json` `nests` entry in the Pack. It releases through `release-train`.
- **The Pack.** An import-only commit, as `df83508`: rewrite the imports and the mod id in `neoforge.mods.toml` and `CLAUDE.md`, and nothing else. It lands with the sync that pins the renamed jar: the `local-jars.json` row's `mod`, `artifact` and `pattern` (or the `nests` of the row that carries it), then `scripts/sync-local-jars.py <new>=<version>`. Made by the Pack's owner.
- **The `release-train` car.** Every place `SKILL.md` step 9 adds it.
- **Glossary links.** This repo's `CONTEXT.md`, the Pack's `CONTEXT.md`, `CLAUDE.md` and ADRs that name the Library (write a new ADR or a dated note rather than editing an accepted one's decision), and the READMEs of Libraries that mention it.

Done when `git grep -i <old>` in each repo finds only history (changelogs, ADRs, NOTICE) and `release-train`'s `status.sh` shows the renamed car with the Pack's `--check` passing.
