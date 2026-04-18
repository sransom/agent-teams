# Architecture

How agent-teams orchestrates a parallel team of Claude Code subagents across isolated git worktrees, coordinated by beads.

---

## Three primitives

agent-teams is built from three boring, well-understood primitives:

1. **Claude Code subagents** — each agent is an `.md` file in `~/.claude/agents/` with a name, a model, and a prompt. The orchestrator spawns them with the `Agent` tool.
2. **beads issues** — each task is a beads issue with `needs` / `blocks` relationships. `bd ready` returns issues with no blockers. beads persists across sessions.
3. **Git worktrees** — each agent works in its own worktree (`../{repo}-{team}-{role}`). Different branches, no shared filesystem state, no races.

The orchestrator's job is to pour a formula into beads, dispatch agents against `bd ready`, and merge when all issues close.

---

## Anatomy of a run

```
User: /spawn my-auth-refactor
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ Orchestrator (you, the Claude Code lead)                        │
│                                                                 │
│ 1. Pick formula, collect vars, pour molecule                    │
│ 2. bd graph → see the DAG                                       │
│ 3. bd ready → dispatch unblocked agents                         │
│ 4. When arms close, bd ready unblocks the next step             │
│ 5. Integrate, push, clean up                                    │
└─────────────────────────────────────────────────────────────────┘
        │                        │                        │
        ▼                        ▼                        ▼
┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│  explorer    │        │ implementer  │        │   judge      │
│  (haiku)     │        │   (sonnet)   │        │   (sonnet)   │
│              │        │              │        │              │
│ worktree:    │        │ worktree:    │        │ reads all    │
│ {team}-      │        │ {team}-      │        │ arm worktrees│
│ explorer     │        │ impl-{arm}   │        │ for review   │
└──────────────┘        └──────────────┘        └──────────────┘
```

Each box is a subagent spawned by `Agent({ subagent_type: "..." })`. Each worktree is a separate checkout. beads tracks what's done and what's next.

---

## How decomposition works

The explorer is a special agent. It does two things in sequence:

**Part 1: Explore.** Reads the feature description (and optional plan file), greps the codebase, finds files that need to change, identifies patterns to follow.

**Part 2: Decompose.** Decides how to split the work into implementer arms. The rules:

- **Parallel arms** when file boundaries don't overlap *and* arm B doesn't depend on arm A's output.
- **Sequential arms** (`bd dep add B A`) when arm B imports or queries something arm A produces (e.g. a migration creates a table that the API queries).
- **Single arm** when the feature is small (≤5 files, one concern).

For each arm, the explorer calls `bd mol bond implement-arm {parent}` with file boundaries, lint command, and notes. This bonds a child formula into the parent's DAG — a molecule bonded inside another molecule.

After bonding, the explorer closes its own issue. beads now contains an expanded graph where the judge step depends on `all-children` — which includes the dynamically bonded implementer arms.

---

## Why `waits_for: all-children`

Most workflow engines require a static DAG. agent-teams needs dynamic fanout: the explorer doesn't know at pour time how many arms there will be, because that depends on what it finds.

`waits_for: all-children` is the beads idiom for "wait until everything bonded under the parent is closed." The judge can't run until every implementer arm the explorer created is done.

This is why formulas that use the explorer pattern always have the gating step (judge, aggregate) set to `waits_for: all-children`.

---

## Model routing

Labels on beads issues encode which model each step should use:

```json
"labels": ["agent:explorer", "model:haiku"]
```

The orchestrator reads the `model:` label when spawning the agent. If a label is absent, it falls back to the agent's frontmatter `model` field. If that's absent too, it falls back to `sonnet`.

See [model-routing.md](model-routing.md) for the reasoning behind each default.

---

## Integration

When `test`, `review`, and `codex-review` all close, the orchestrator's `integrate` issue becomes ready. The orchestrator:

1. Creates an `integration/{team}` branch off `base_branch`
2. Merges each `agent/{team}/impl-{arm}` branch into it (resolving conflicts by hand, not discarding)
3. Merges `agent/{team}/test-writer` if present
4. Fixes P1 findings from both reviewers
5. Pushes `integration/{team}` to origin
6. Checks out `base_branch`, merges integration, pushes
7. Deletes local branches and worktrees
8. Closes remaining beads issues

The single final push is by design: all per-agent commits use `HUSKY=0` to skip hooks in the worktree, and the final integration push runs hooks once against the merged state.

---

## Resumability

Every step's state lives in beads, not in memory. If Claude Code exits:

- Open issues are still open
- Worktrees still exist (tracked by `bd worktree list`)
- `bd ready` still tells you what's next

`/spawn --resume` uses this. It doesn't re-pour — it reads open issues, groups by team name, and dispatches from `bd ready`. The lead reconstructs context from issue titles and worktree layout, not from prior session state.

---

## What's intentionally not here

- **No shared agent memory** — each agent starts with a spawn prompt. The orchestrator relays findings between them (e.g. judge failures back to implementer) rather than giving them common state.
- **No sub-session branching** — this isn't [git-rebase-interactive](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History). If a run goes off-track, you stop it, close the bad issues, and re-pour.
- **No automatic retry loops outside the judge** — the judge has a 3-attempt retry for failed implementer arms, but other steps (tests, reviews, integrate) escalate to the user on failure. Retry logic gets costly fast.
