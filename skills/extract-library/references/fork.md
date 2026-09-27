# Fork: a Library from an upstream mod

Beltworks forked Rearth's SimpleBelts ("Simple Conveyor Belts") at branch `26.1.2`, commit `92a97c3`. A fork keeps upstream's history: `git blame` against the fork point is how each file's licence is decided, and upstream's changelog stays readable. So it doesn't start from `gh repo create --template`; it adopts the template into the fork.

1. **Clone.** Write down the fork point: upstream's branch and commit. Then:
   ```bash
   gh repo create 5thlayer/<mod_id> --public
   git clone <upstream url> ~/minecraft_mods/<mod_id>
   cd ~/minecraft_mods/<mod_id>
   git remote rename origin upstream
   git remote add origin https://github.com/5thlayer/<mod_id>.git
   git checkout -b main <fork point commit>
   git push -u origin main
   ```
   A plain `git push` from upstream's branch would publish that branch's name (Beltworks forked `26.1.2`), not `main`. Done when `git remote -v` shows both and `origin/main` is the fork point.

2. **Licence and NOTICE.** Read upstream's licence and every credit it carries (textures often have their own). Then:
   - `LICENSE` points each kind of file at its licence. Beltworks' says: its own code is MIT, assets are CC BY 4.0, a file carrying upstream's work is "CC-BY-4.0 AND MIT", and the Gradle wrapper is Apache-2.0. Upstream's licence decides these for your fork; don't assume Beltworks'.
   - `NOTICE` credits upstream by name and author, names the fork point (branch and commit), and quotes upstream's own credits word for word.
   - `LICENSES/` holds each licence's text; `REUSE.toml` annotates the files, with later matches winning: own files, then upstream-carrying files, then assets, then the wrapper.
   - Java files get SPDX headers from their lineage: `git blame -C -M <fork point>..` tells a file that still carries upstream lines from one that doesn't.
   - An ADR records the decision, as Beltworks' `docs/adr/0001-code-mit-assets-cc-by.md`. Since libworks' semver ADR is 0001, a new fork's licence ADR is 0002.

   Done when `reuse lint` passes and the user has approved `LICENSE` and `NOTICE`.

3. **Rename.** Replace upstream's names with those from `SKILL.md` step 2 everywhere: the mod id and namespace (every `assets/` and `data/` path, the mixin config `<mod_id>.mixins.json`), the package `io.github._5thlayer.<mod_id>`, `maven_group`, `archives_name`, `mod_name`, `settings.gradle`'s `rootProject.name`, and `neoforge.mods.toml`. `fill-template.sh` doesn't apply: it renames only libworks' `examplelib` placeholders. Upstream's ids in saves are gone unless remapped. Beltworks remapped nothing, and old `belts:` blocks vanished (its changelog and ADR 0009 say so). Ask the user which, and record it. Done when `git grep -i <upstream id>` finds only `NOTICE`, the changelog's upstream section and licence records.

4. **Versions restart at 0.1.0.** Set `mod_version = 0.1.0`. `CHANGELOG.md` opens an `## Unreleased` whose first line says the mod was renamed to <Name>, a mod of its own, with its version restarting at 0.1.0. Upstream's entries move below, under `## Upstream: <upstream name>`. Upstream's `v*` tags stay in the history; the tag prefix from step 2 keeps them from clashing. Done when the rename commit builds.

5. **Adopt the template.** The libworks README describes adopting it in an existing Library: diff libworks against the fork and take its `build.gradle` GameTest wiring (`--tests "${mod_id}:*"`, the report check, the refusal to republish), `scripts/release.sh` with the tag prefix, `scripts/quicklaunch.sh`, `.github/workflows/ci.yml`, `docs/agents/`, `CLAUDE.md`, `ModIdTest`, and ADR 0001. Commit it (`chore: adopt the libworks template`), push, then finish `SKILL.md` step 4 from "Triage labels" on, skipping its carve-only commit. Done when CI is green on `main`.

Then go on to `SKILL.md` step 5. A fork has no Pack copies to port its GameTests from, but upstream's tests, if any, move into the `<mod_id>:*` namespace. The Pack's own tests of the mechanic are the ones step 8 deletes or keeps as Bindings.
