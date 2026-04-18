# agent-teams

Parallel, worktree-isolated agent teams for [Claude Code](https://docs.claude.com/en/docs/claude-code). Ship a feature by spawning a coordinated team — an explorer maps the codebase and splits the work, implementer agents build in parallel in isolated worktrees, a judge gates merges, reviewers report findings, and the orchestrator integrates and pushes.

Built on top of Claude Code subagents and the [beads](https://github.com/steveyegge/beads) issue tracker.

---

## Why

One Claude Code session is a single worker. For work that fans out — a migration + API changes + frontend updates, or reviewing a large PR from multiple angles — you want real parallelism with clean boundaries, not a single agent juggling everything.

agent-teams gives you:

- **Isolated worktrees per agent** — no shared-file races, no step-on-toes
- **Dynamic decomposition** — the explorer decides how to split work at runtime based on what the codebase actually looks like
- **Dependency tracking in beads** — `bd ready` drives sequencing; resumable across sessions
- **Model routing** — cheap models for mechanical work (haiku), smart models for judgment (sonnet), optional Codex delegation for ~3x savings on implementation
- **Two commands** — `/build-team` to design a workflow, `/spawn` to run one

---

## Install

```bash
git clone https://github.com/sransom/agent-teams.git
cd agent-teams
./install.sh
```

The installer will:
1. Check for `claude` (required), `bd` (required for orchestration), `codex` (optional)
2. Ask before copying each of: 5 agents, 5 formulas, 2 commands into `~/.claude/`
3. Back up anything it would overwrite (`.bak.{timestamp}` suffix)
4. Optionally append a model-routing block to `~/.claude/CLAUDE.md`

To remove: `./uninstall.sh`. It asks before deleting modified files and cleans its CLAUDE.md block.

### Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) installed
- [beads plugin](https://github.com/steveyegge/beads) — `claude plugin install beads`
- Git with worktree support (every modern version)
- Optional: [Codex CLI](https://github.com/openai/codex) for cheaper implementer runs

---

## Quick start

### Spawn a team on a feature

```
/spawn
```

Interactive picker: pick a formula, answer a few questions (team name, feature description, base branch), confirm, and go.

Shortcuts:

```bash
/spawn my-auth-refactor                                 # full-team, team=arg
/spawn --formula lite-team                              # pick formula, prompt for vars
/spawn --from-plan ~/plans/migrate-auth.md              # infer feature + plan from file
/spawn --var implementer_model=gpt-4o-mini              # ~3x cheaper (needs codex CLI)
/spawn --resume                                         # pick from teams in flight
/spawn --list                                           # just show formulas, exit
/spawn --dry-run                                        # pour, show DAG, don't dispatch
```

### Design your own team

```
/build-team
```

Wizard walks you through:

1. **Name + description**
2. **Roles** — start from a template (clone `full-team`, `lite-team`, or `code-review`) or pick roles one at a time. Your existing agents in `~/.claude/agents/` show up alongside the built-ins.
3. **DAG** — numbered picks for what each step waits for. Detects "this step probably needs `all-children`" and defaults accordingly.
4. **Variables** — pre-seeded with `team`, `feature`, `repo`; add your own.
5. **Review + save** — plain-English summary, then raw JSON. Edit any part without restarting.

Output: a `.formula.json` in `~/.claude/formulas/` that `/spawn` can run.

---

## What ships

### Agents (`~/.claude/agents/`)

| Agent          | Model  | Role                                           |
|----------------|--------|------------------------------------------------|
| explorer       | haiku  | Read-only map + arm decomposition              |
| implementer    | sonnet | Execute a plan in a worktree (Claude or Codex) |
| judge          | sonnet | Pass/fail gate on implementer output           |
| test-writer    | haiku  | Write colocated tests                          |
| code-reviewer  | sonnet | P1/P2/P3 report on a diff                      |

Model names are family aliases (`haiku` / `sonnet` / `opus`) so they track Claude Code's latest defaults. Pin to a snapshot (e.g. `claude-sonnet-4-6`) if you want reproducibility.

### Formulas (`~/.claude/formulas/`)

| Formula       | What it does                                                                                                  |
|---------------|---------------------------------------------------------------------------------------------------------------|
| full-team     | Ship end-to-end: explorer → implementer arms → judge → test + review → integrate                              |
| lite-team     | Same as full-team, minus test-writer. For prototypes.                                                         |
| code-review   | Parallel specialist reviewers. Triage picks reviewers per file type; aggregate dedupes findings.              |
| implement-arm | Child formula bonded by the explorer. One implementer, one slice of a feature.                                |
| review-arm    | Child formula bonded by triage. One specialist reviewer.                                                      |

---

## The `full-team` DAG

```
                  ┌──────────┐
                  │ explorer │   (haiku — maps codebase, bonds arms)
                  └────┬─────┘
                       │ bonds N implement-arms dynamically
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌─────────┐    ┌─────────┐    ┌─────────┐
   │  arm 1  │    │  arm 2  │... │  arm N  │   (sonnet or gpt-4o-mini)
   └────┬────┘    └────┬────┘    └────┬────┘
        └──────────────┼──────────────┘
                       ▼
                  ┌─────────┐
                  │  judge  │   (sonnet — waits: all-children)
                  └────┬────┘
               PASS    │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌─────────┐    ┌──────────┐   ┌───────────────┐
   │  tests  │    │  review  │   │ codex-review  │   (parallel)
   └────┬────┘    └────┬─────┘   └───────┬───────┘
        └──────────────┼─────────────────┘
                       ▼
                 ┌───────────┐
                 │ integrate │   (orchestrator — merge, fix P1s, push)
                 └───────────┘
```

Judge FAIL → reopen failing arm(s), retry (max 3). Escalates to the user after.

---

## Cost lever

The implementer step defaults to Sonnet. You can switch it to Codex (gpt-4o-mini) for ~3x cost savings at similar quality:

```bash
/spawn --var implementer_model=gpt-4o-mini
```

This requires the [Codex CLI](https://github.com/openai/codex) installed. The implementer agent auto-detects the model type and delegates to `codex exec` when a `gpt-*` model is requested, falling back to native Claude tools if Codex isn't available.

---

## Docs

- [`docs/architecture.md`](docs/architecture.md) — how the DAG, beads tracking, and worktree isolation fit together
- [`docs/model-routing.md`](docs/model-routing.md) — which models for which roles and why
- [`docs/writing-formulas.md`](docs/writing-formulas.md) — create custom formulas by hand or with `/build-team`
- [`docs/writing-agents.md`](docs/writing-agents.md) — define custom agents that plug into formulas

---

## Resuming an interrupted session

Agents crash. Laptops close. `/spawn --resume` picks up where you left off — it reads open beads issues, groups them by team name, and lets you pick which team to continue:

```
Resuming — which team?

  [1] auth-refactor  (3 open, 2 in-progress)
  [2] docs-refresh   (1 blocked)

>
```

No re-pouring, no lost work. beads is the source of truth for what's done and what's still owed.

---

## License

MIT. See [LICENSE](LICENSE).
