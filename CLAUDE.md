# Skillworks

A commit reaches the installed plugin only once it's published. Each commit raises the version in `.claude-plugin/plugin.json`. After committing, run `scripts/publish.sh` to see what's unpublished, and offer `scripts/publish.sh --publish`, which pushes `main`: run it once the user says yes.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for 5thlayer/skillworks (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
