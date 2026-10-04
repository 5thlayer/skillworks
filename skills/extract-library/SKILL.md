---
name: extract-library
description: Extract a Library out of the FactoryWorks Pack, or fork one from an upstream mod, under FactoryWorks ADR-0090. Use when a Pack mechanic (such as core/energy/'s pole network) should become a 5thlayer mod of its own, when forking an upstream mod into a Library the way Beltworks forked SimpleBelts, when starting a repo from 5thlayer/libworks, or when renaming a Library.
---

# Extract a Library

A **Library** is a 5thlayer mod the Pack consumes as a local jar pinned in `data/pack/local-jars.json`. A **Binding** is the Pack's code configuring a Library for Factorio's rules, with the GameTests asserting that configuration; it stays in the Pack. The terms are in this repo's `CONTEXT.md`, the rules in the Pack's `docs/adr/0090-extracting-a-library.md`. How a Library is built, released and versioned is 5thlayer/libworks'; read its `README.md` and `docs/agents/releases.md` before step 4.

There are two starting branches, which meet at step 5:

- **Carve**: the mechanic is Pack code. Groundworks came out of `core/placement/`, Craftworks out of `core/assembler/`. Read `references/carve.md`.
- **Fork**: the mechanic is an upstream mod 5thlayer takes over. Beltworks forked SimpleBelts. Read `references/fork.md`.

To rename a Library that already exists, skip the steps and read `references/rename.md`.

| Checkout | Where |
|---|---|
| Pack | `$CURSEFORGE_ROOT/Instances/FactoryWorks`, default root `~/curseforge` (remote `5thlayer/factoryworks`) |
| libworks | `~/minecraft_mods/libworks` (template `5thlayer/libworks`) |
| The new Library | `~/minecraft_mods/<mod_id>` |

The Pack's checkout usually belongs to another session. Keep `release-train`'s ownership rule: commit only in your own checkout, and for a change in the Pack message its owner (`list_sessions` shows each `cwd`) or, if no session owns it, ask the user.

## Steps

1. **Gate.** ADR-0090 extracts a mechanic only if all five hold, otherwise it stays in `factoryworks_core`:
   1. it makes sense without Factorio's rules;
   2. few Pack classes depend on it;
   3. its tests move without the Pack's corpus;
   4. it works standalone, in a game with no Pack;
   5. it gives the modding community a mechanic no other mod has.

   For a carve, count 2 and 3 rather than guess: `grep -rl` the mechanic's package across the rest of `mod/src/main/java`, and list its JVM tests' and GameTests' imports from outside it. Name what would become Bindings (the Pack's numbers, tiers, tags and refusals). Done when the user has read your answer for each criterion, with its evidence, and agreed the mechanic passes. One failing criterion ends the skill.

2. **Name.** Fix every name before the first commit; renaming Groundworks (from `placementpreview`) after its first commit cost a round of churn in both repos. Choose and have the user approve:
   - the mod id, which is also the GameTest namespace, the artifact and the repo: `5thlayer/<mod_id>`;
   - the class name and display name `fill-template.sh` takes;
   - the package `io.github._5thlayer.<mod_id>` (group `io.github.5thlayer` stays);
   - the tag prefix. The default is `<mod_id>-v<version>`, as Beltworks' `beltworks-v0.3.8`. It keeps the tags distinct across repos, and for a fork it avoids upstream's `v*` tags, which the fork's history carries. libworks' `scripts/release.sh` hardcodes `tag="v$version"`, so the default means editing that line and the two `v<version>` mentions in `docs/agents/releases.md` at step 4. Groundworks and Craftworks predate the default and keep `v*`.

   Done when every name above is written down and approved.

3. **Branch.** Follow `references/carve.md` or `references/fork.md` to its end; each runs step 4 at the point it says. Done when the Library's repo is set up, its code and JVM tests are in it, and CI is green on `main`.

4. **Repo setup.** Both branches pass through this; each reference says where.
   - Create: `gh repo create 5thlayer/<mod_id> --template 5thlayer/libworks --public --clone`, in `~/minecraft_mods`. Public unless the user says otherwise: criterion 5 means the Library is for the modding community.
   - Fill: `scripts/fill-template.sh <mod_id> <ClassName> "<Display Name>" ["<one-line description>"]`. It `git mv`s the `examplelib` paths, replaces `examplelib`, `ExampleLib` and `Example Library` in every tracked file, and deletes itself. It commits nothing.
   - Tags: apply the prefix from step 2 to `scripts/release.sh` and `docs/agents/releases.md`.
   - Triage labels: libworks carries only GitHub's defaults, and no script creates the four that `docs/agents/triage-labels.md` names. Create them with the colours the other Libraries use:
     ```bash
     gh label create needs-triage --color d93f0b -R 5thlayer/<mod_id>
     gh label create needs-info --color fbca04 -R 5thlayer/<mod_id>
     gh label create ready-for-agent --color 0e8a16 -R 5thlayer/<mod_id>
     gh label create ready-for-human --color 1d76db -R 5thlayer/<mod_id>
     ```
     `wontfix` is a GitHub default.
   - Agent docs: `CLAUDE.md` and `docs/agents/` come from the template. `CLAUDE.md` opens with a section, between `<!-- template-only: … -->` and `<!-- /template-only -->`, telling an agent the checkout is the template and not a Library; in a Library that's false, so delete it, markers and the blank line before them included:
     ```bash
     perl -0pi -e 's/\n<!-- template-only:.*?<!-- \/template-only -->\n//s' CLAUDE.md
     ! grep -rn template-only CLAUDE.md docs
     ```
     Do the same whenever a Library later copies a `CLAUDE.md` change back from libworks. Then read both and correct any line that doesn't hold for this Library. The README pitch is the Library's own.
   - Carve only: commit `chore: fill the libworks template` once `sh ./gradlew build runGameTestServer` passes, and push. A fork commits its adoption of the template in `references/fork.md` step 5.
   - First issues: file the extraction's work in the new repo, labelled, one per step that moves something: the code and JVM tests (#1), the GameTests, the first release. The Pack's side stays on the Pack's issue (such as factoryworks#476), which links them.

   Done when `gh run list -R 5thlayer/<mod_id>` shows the latest `main` run green. The template's CI builds, runs the GameTests and runs `reuse lint`, and it must be green before the first release.

5. **Port the GameTests.** Move each GameTest that asserts the mechanic itself into the Library's `gametest/` package, registered in `<ClassName>GameTests.registerTests` and run by `--tests "<mod_id>:*"`. Replace the Pack's numbers with the Library's defaults or with test-local configuration. A GameTest that asserts the Pack's settings (a tier's Factorio number, a Pack tag, a Pack refusal) is a Binding test: it stays in the Pack under the `factoryworks:*` selector (#448), since a Library's own run can't see the Pack's settings. Done when the Library's `runGameTestServer` passes and every GameTest of the mechanic is listed as either moved or Binding.

6. **Record the domain.** Write `CONTEXT.md` with the Library's terms. Keep libworks' ADR 0001 (semver below 1.0) as the Library's 0001, then number from 0002:
   - Copy each Pack ADR the Library inherits, unchanged apart from renumbering, under a note like the one heading Craftworks' imported ADRs. (Craftworks predates libworks, so its imports start at 0001; a Library from the template starts them at 0002.)
     > **Imported from FactoryWorks ADR-00NN**, unchanged apart from renumbering. <Library> began as FactoryWorks' `core/<package>/`. Issue numbers (`#n`) and ADRs cited as FactoryWorks refer to 5thlayer/factoryworks. [ADR-00MM](…) records where <Library> departs from this decision; the glossary in `CONTEXT.md` has the current terms.
   - Then one ADR of the Library's own recording where it departs from those, as Craftworks' ADR 0006.

   Done when every Pack ADR that governs the moved code is either imported or named as staying with the Binding.

7. **First release.** A line under `## Unreleased` in `CHANGELOG.md`, then `scripts/release.sh 0.1.0`. It refuses a dirty tree, and it builds, runs the GameTests, commits `chore: release 0.1.0`, publishes to `~/.m2` and tags. It pushes nothing: push `main` and the tag with the user's word. Done when `~/.m2/repository/io/github/5thlayer/<mod_id>/0.1.0/` holds the jar and the tag is on `origin`.

8. **Switch the Pack.** This is one commit in the Pack, made by the Pack's owner, which you message with this list. The Pack's build must read `local-jars.json` without naming a Library, which is factoryworks#475: while `gh issue view 475 -R 5thlayer/factoryworks --json state` says open, it comes first. Before the release, the owner can try the switch against your checkout with `-PsiblingBuilds=<mod_id>`, once the row below is in the Pack's tree (`settings.gradle` refuses a name with no row); a green run under it proves nothing about the pinned jar.
   - Add a row to `data/pack/local-jars.json`: `{"mod": "<mod_id>", "group": "io.github.5thlayer", "artifact": "<mod_id>", "version": "0.1.0", "pattern": "<mod_id>-*.jar"}`, with `"nests": [...]` if the Library jar-in-jars another.
   - `scripts/sync-local-jars.py <mod_id>=0.1.0`, which installs the jar, refreshes the manifest and rebuilds.
   - Rewrite the Pack's imports to `io.github._5thlayer.<mod_id>`. Keep the Bindings.
   - Delete the Pack's copies of the code and of every test that moved (ADR-0090's tests rule). The Pack's belt GameTests ran beside Beltworks' own until #438 deleted them; don't repeat that.
   - Update the Pack's `CLAUDE.md` where it describes the mechanic.

   Done when the Pack's `./gradlew :factoryworks_core:build`, `runGameTestServer` and `tests/pack/test_local_jars.py` pass on that commit.

9. **Add a `release-train` car.** In this repo (5thlayer/skillworks): add the Library's row to the car table in `skills/release-train/SKILL.md` and a sentence for what it waits on; add a `car <Name> "$HOME/minecraft_mods/<mod_id>" <mod_id>` line to `skills/release-train/status.sh`; name the Library in `skills/release-train/SKILL.md`'s description and in `README.md`'s row for `release-train`. Done when `status.sh` prints the new car with `0.1.0` in `~/.m2`.
