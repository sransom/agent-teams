# /spawn

Pick an existing formula from `~/.beads/formulas/` and run it — worktree-isolated, beads-tracked.

Explorer maps the codebase, decomposes work into implementer arms with non-overlapping file boundaries, bonds them in beads. `bd ready` drives all sequencing. Judge gates merges. Code-reviewer reports findings. Orchestrator integrates.

---

## Shortcuts

```bash
/spawn                                                      # interactive picker
/spawn {team-name}                                          # full-team, team=arg
/spawn --formula {name}                                     # pick formula by name
/spawn --formula mol-code-review 123                        # formula + first positional var
/spawn --var feature="auth migration" --var base_branch=main  # var passthrough
/spawn --from-plan ~/plans/my-plan.md                       # feature + plan from file
/spawn --resume                                             # pick from active teams in beads
/spawn --resume {team-name}                                 # resume specific team
/spawn --list                                               # show available formulas, exit
/spawn --dry-run ...                                        # pour + show DAG, don't dispatch
```

**Var passthrough.** Any `--var key=value` flag pre-fills that variable and skips the prompt for it. The wizard only asks for vars that weren't provided.

**`--from-plan <file>`.** Reads the plan file. Auto-sets `plan` to the file's path and (optionally) `feature` to the first H1 heading in the file. The user still confirms and can override.

**`--list`.** Shows all available formulas (from `~/.beads/formulas/*.formula.json`) with name + description, then exits. Does not pour or dispatch. Combine with no other flags.

**`--dry-run`.** Runs Steps 1–3 (pick formula, collect vars, pour, `bd graph`, `bd ready`) but stops before dispatching any agents. Useful for validating a new custom formula without burning tokens. Leaves the beads issues in place — the user can continue by running `/spawn --resume {team}`, or tear down with `bd list --status=open | grep {team} | bd close ...`. Print the teardown command at the end of the dry run.

---

## Instructions for Claude (the lead)

### Step 0 — Prerequisites

Check:
```bash
bd --version                      # beads must be available
ls ~/.beads/formulas/*.json      # at least one formula must exist
```

If `bd` is missing: tell the user to install the beads plugin and stop.
If no formulas exist: suggest running `/build-team` first and stop.

Set beads context to the current repo if not already set:
```bash
bd set_context "$(pwd)"
```

### Step 1 — Pick a formula

If `--formula <name>` was passed, jump straight to that formula. Otherwise:

```bash
ls ~/.beads/formulas/*.formula.json
```

For each file, read the `formula` and `description` fields and show:

```
Available formulas:

  [1] full-team       — Cost-optimized worktree team with test-writer + review
  [2] lite-team       — Fast team for prototypes (no test-writer)
  [3] code-review     — Parallel specialist reviewers for a PR
  [4] {custom}        — {description}

Which one? >
```

### Step 2 — Collect variables

Read the selected formula's `vars`. For each variable, resolve its value in this order (first match wins):

1. **`--var key=value` passthrough** from the invocation
2. **Positional arg** — `/spawn {team}` or `/spawn --formula mol-code-review 123` maps positionals onto the formula's vars in declaration order (skipping any already set by `--var`)
3. **`--from-plan <file>` inference** — sets `plan` to the file path; if `feature` is still unset, uses the first H1 (`# ...`) heading as the feature name. User confirms.
4. **Auto-detect**:
   - `repo` → `basename "$(pwd)"`
   - `base_branch` → `git branch --show-current`
5. **Prompt** — only for required vars still unset after the above

One question at a time. Skip optional vars unless the user asks to set them.

Before the confirm step, show all resolved values and let the user override any one with a single prompt ("which var to change?"). This lets auto-detected values (especially `base_branch`) be corrected without restarting.

### Step 3 — Confirm + pour

Show the config:

```
Config:
  formula: full-team
  team: auth-refactor
  feature: migrate session tokens to argon2id
  repo: my-app
  base_branch: main
  plan: /tmp/auth-plan.md

Proceed? [y/n]
>
```

On `y`, pour the molecule:

```bash
bd mol pour <formula-name> \
  --var team=<team> \
  --var feature="<feature>" \
  --var repo=<repo> \
  --var base_branch=<base_branch> \
  --var plan="<plan-or-empty>"
```

Show the resulting DAG:
```bash
bd graph
bd ready       # first tasks to dispatch
```

### Step 4 — Resume (if `--resume` was passed)

Skip Steps 1–3 entirely. Goal: find the active team, reconstruct its state from beads, and dispatch whatever's in `bd ready`.

**Pick a team to resume.** Extract team names from open issue titles. Your issue titles follow the convention `[{team}] {step-id}: {feature}`, so:

```bash
bd list --status=open --json | jq -r '.[].title' | grep -oE '^\[[^]]+\]' | sort -u | tr -d '[]'
```

Cases:
- **Zero open teams** → "Nothing to resume. `bd list` is empty."
- **One open team** → skip the picker, resume it.
- **Multiple open teams** → show picker with counts:

  ```
  Resuming — which team?

    [1] auth-refactor  (3 open, 2 in-progress)
    [2] docs-refresh   (1 blocked)
    [3] eval-migrate   (5 open)

  >
  ```

**`/spawn --resume {team-name}`** skips the picker and goes straight to that team. If the name isn't in the extracted list, show an error and fall back to the picker.

**Reconstruct context:**

```bash
bd list --status=in_progress  | grep {team}   # claimed but not closed
bd ready                      | grep {team}   # unblocked
bd blocked                    | grep {team}   # waiting
bd worktree list              | grep {team}   # existing worktrees
```

Do NOT re-pour. Proceed directly to Step 5 (orchestrate) using `bd ready` as the dispatch queue.

### Step 5 — Orchestrate

Walk the formula's step DAG. For each ready task:

1. **Create the worktree** (if it's a task that needs one):
   ```bash
   bd worktree create {team}-{step-id} --branch agent/{team}/{step-id}
   ```

2. **Dispatch the agent**. Read the `labels` for model routing:
   - `agent:<name>` → which subagent to spawn
   - `model:<id>` → which model to use

   Fall back to the agent's frontmatter `model` field if no `model:` label is present.

3. **Judge retry loop** (max 3 attempts): on `VERDICT: FAIL`, reopen the failing arm (`bd reopen {id}`), relay findings verbatim, re-dispatch. Escalate to the user after attempt 3.

4. **Parallel dispatch**: if multiple tasks in `bd ready` share the same `needs` set, spawn them in a **single message** so they run in parallel.

#### Read-only agents cannot close their own beads issues or bond children

Some agents (explorer, code-reviewer) ship without the `Bash` tool — they're read-only by design. They cannot run `bd close`, `bd mol bond`, or any shell commands. When the orchestrator dispatches a read-only agent:

1. **Expect a report, not side effects.** The agent returns structured output describing what should happen next (e.g. the explorer returns a `DECOMPOSITION:` block with one `bond_command` per arm).
2. **Execute the commands yourself.** Parse the agent's output for `bd mol bond ...` commands (explorer) or bond/dep/close commands (reviewer with follow-ups) and run them from the project root.
3. **Close the agent's beads issue yourself** after executing its recommended actions: `bd close {agent-issue-id}`.

Agents with `Bash` in their tools (implementer, judge, test-writer) can handle their own beads operations and should close their own issues.

#### CRITICAL: `bd ready` does not surface bonded arms

Once the explorer bonds implementer arms under the root epic, those arms do **not** appear in `bd ready` until the root epic closes (which happens last). `bd ready` will only show the root epic itself and any non-bonded steps.

This means the orchestrator must:

1. **Track arm IDs from the bond output.** Each `bd mol bond mol-implement-arm ...` prints "Spawned: N issues". Capture the resulting arm task IDs — either from the output or by running `bd list --parent {root-epic-id}` after bonding.
2. **Dispatch arms by ID directly**, not by polling `bd ready`. Use `bd show {arm-id}` to confirm status before dispatch.
3. **Poll arm closure**: after dispatching, check each arm's status with `bd show {arm-id}` until all are `closed`. Do not rely on `bd ready` to signal completion.

#### CRITICAL: enforce `waits_for: all-children` yourself

`bd ready` returns the judge (or any step with `waits_for: all-children`) as ready **immediately** — beads does NOT block it until bonded children exist and close. That's an orchestrator responsibility.

When the formula declares `waits_for: all-children` on a step, you must:

1. **Do not claim that step from `bd ready` directly.** Skip it and pick another ready task.
2. Dispatch the upstream decomposing step (explorer / triage). Parse its report for `bd mol bond` commands and run them yourself (explorer is read-only, cannot bond).
3. After bonding, dispatch each arm by ID. Poll `bd show {arm-id}` until all arms are closed.
4. Only then claim and dispatch the gated step.

Getting this wrong means dispatching the judge before any arms have been built — the judge will have nothing to judge and will either PASS vacuously or FAIL on missing work. Both are wrong outcomes.

#### Bond target for dynamic arms

When the explorer (or triage) bonds child molecules, target them at the **root epic**, not at the gated step:

```bash
bd mol bond mol-implement-arm {ROOT_EPIC_ID} \
  --var team=... --var arm=... --var feature=... ...
```

beads blocks `mol-*` prefixed formula names for bond resolution. If you renamed a formula without the prefix, `bd mol bond` will fail with "not found (not an issue ID or formula name)". Our shipped formulas all use the `mol-` prefix in their filenames for this reason.

### Step 6 — Integration

When the `integrate` task (or the last orchestrator-labeled step) becomes ready:

```bash
# 1. Build integration branch
git checkout -b integration/{team}
git merge agent/{team}/impl-{arm}      # repeat per arm
git merge agent/{team}/test-writer     # if present

# 2. Fix P1 findings from reviewers
# (apply fixes, commit)

# 3. Push
git push origin integration/{team}

# 4. Merge back to base branch
git checkout {base_branch}
git merge integration/{team} --no-edit
git push origin {base_branch}

# 5. Clean up
bd worktree list               # see what exists
bd worktree remove {name}      # repeat per worktree
git branch -D agent/{team}/* integration/{team}

# 6. Close remaining issues
bd list --status=open | grep {team}
bd close {id1} {id2} ...
```

Final report:

```
✓ {team} shipped
  formula: {formula-name}
  arms: {N}
  judge iterations: {N}
  base branch: {base_branch} (pushed)
```

---

## Model routing

When dispatching an agent, select the model in this order:
1. `model:<id>` label on the beads issue
2. `model` field in the agent's frontmatter
3. Default fallback: `sonnet`

Model names use family aliases so they track the latest Claude Code default:
- `haiku` — fast, read-only, deterministic tasks
- `sonnet` — judgment, review, complex implementation
- `opus` — orchestrator (lead only)
- `gpt-4o-mini` / `gpt-5.4-mini` — Codex CLI (implementer alternative, ~3x cheaper)

To pin to a specific snapshot (e.g. for reproducibility across Claude Code releases), use the full ID like `claude-sonnet-4-6`. Both forms work.

---

## Dispatch rules

**Parallel** when ALL are true:
- Tasks share the same `needs` set (both unblocked at the same time)
- File boundaries don't overlap
- Results don't block each other

**Sequential** when:
- Task B's `needs` includes Task A
- Task B reads files Task A produces

Always spawn parallel tasks in a single message with multiple Agent tool calls.

---

## Rules

- Never push until the `integrate` step — worktree commits only
- Never skip hooks on the integration commit — only on per-agent commits (`HUSKY=0` or repo equivalent)
- Resolve conflicts manually during integration — do not discard work
- Close beads issues only when the work is actually done
