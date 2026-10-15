# Skillworks

Claude Code skills that act across the 5thlayer repos, as a plugin marketplace.

```bash
claude plugin marketplace add 5thlayer/skillworks
claude plugin install skillworks@skillworks
```

| Skill | Use it to |
|---|---|
| `all-done` | debrief the session's feature: what's done, tested and unclear, and a numbered list to check in game |
| `quicklaunch` | open the dev client of the mod you're in, into its most recent save |
| `gametest-loop` | run a mod's game tests many times over, with Gradle only once, to catch a flaky test |
| `conductor` | run a change across several checkouts while other sessions work in them: hand-over, approval, exact pushes |
| `release-status` | see where the release train stands: versions, unpushed work, the Groundworks the mods load together, and release tooling drift |
| `template-drift` | compare the mods' shared tooling and docs with libworks' template, and carry a template fix out to them |
| `release-train` | release Groundworks, then Beltworks, Pipeworks, Wireworks, Craftworks and Fieldworks, moving the Groundworks the others require, and last the Showcase pack |
| `steward` | drive a mod's open PR to green, through its review, and merge it once CI and `/code-review` are clean |
| `implement` | implement a ticket, once its triage label says it's ready for an agent |
| `diagnosing-bugs` | diagnose a hard bug or regression through a feedback loop that goes red on it |

`implement` and `diagnosing-bugs` are Matt Pocock's ([mattpocock/skills](https://github.com/mattpocock/skills), MIT), each with a line of ours.

The terms the skills share are in [CONTEXT.md](CONTEXT.md).

## Publishing a change

The marketplace is this repo's `main` on GitHub, so a commit reaches sessions only after three steps: push `main`, update the local marketplace clone, and update the installed plugin. `scripts/publish.sh` does all three:

```bash
scripts/publish.sh            # where the checkout, origin/main and the installed plugin stand
scripts/publish.sh --publish  # check, push main, update the marketplace and the plugin
```

Every push must raise the version in `.claude-plugin/plugin.json` above origin's, because the plugin is installed by version. `--publish` refuses an unbumped push, uncommitted changes, any branch other than `main`, and a failing `claude plugin validate` or `skills/*/test.sh`. Sessions load the new version when they restart. `scripts/test.sh` runs it against a fixture origin with a fake `claude`.
