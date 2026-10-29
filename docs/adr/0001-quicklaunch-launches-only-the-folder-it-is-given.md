---
status: accepted
---

# quicklaunch launches only the folder it is given

In a monorepo such as mechanical-mastery-plus, quicklaunch walked up from the working directory looking for a `pack.toml` and treated only the git root as a mod build. Run from `MMR26.1.2/mod/`, Reborn's companion mod, it launched the 1.19.2 pack. So quicklaunch no longer walks up. The working directory must itself be a pack or a mod build with the `-PquickPlay` hook, and any other folder is refused, with the candidates listed. The repo root is the one exception: there it scans the repo, launches the one candidate it finds, and refuses when it finds several. A target elsewhere is named with `--in <query>`. That works from anywhere in the checkout, and the script matches the query fuzzily against each candidate's path, pack name and mod id. A tie is refused, and the last line names what launched.

## Considered options

- **Nearest pack or mod build up the tree wins.** Rejected: from a folder that is neither, such as Reborn's `docs/` before it had a `pack.toml`, the walk still ends in a pack nobody meant.
- **A mapping file of names to paths.** Rejected for a fuzzy match over what the scan finds, which needs nothing kept in step with the folders.
- **The agent matches the user's words and passes an exact path.** Rejected: the script must work from a terminal, without the skill.

## Consequences

- Once a pack has a `pack.toml`, its companion mod in the same repo is no longer a target. It is only swapped into the pack, like a Module built beside the repo. A mod build found inside the pack's repo is matched by the mod id its jar declares.
- "Beside the repo" means beside the main checkout. From a worktree, the parent of the git root is `.claude/worktrees/`, where no mod checkouts are.
- Without a target named by the user, the agent passes `--in` only when the working directory resolves or when every file the session changed sits under one candidate. Otherwise it asks.
- Single-mod repos and the Showcase are their own root and their only candidate, so they launch as before.
