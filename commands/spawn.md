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
/spawn --status                                             # peek at all active teams (no dispatch)
/spawn --status {team-name}                                 # peek at one team
/spawn --list                                               # show available formulas, exit
/spawn --dry-run ...                                        # pour + show DAG, don't dispatch
/spawn --profile go                                         # override stack detection
/spawn --profile none                                       # skip profile injection entirely
/spawn --foreground                                         # disable background dispatch (legacy)
```

**Background by default.** Explorer, implementer, test-writer, and reviewer steps are dispatched with `run_in_background: true` so the main session stays free for the user. Judge and integrate stay foreground because they are decision gates the orchestrator must observe directly. Use `--foreground` to revert to the legacy "wait on every step" mode (slower for the user but easier to debug a stuck team).

**Var passthrough.** Any `--var key=value` flag pre-fills that variable and skips the prompt for it. The wizard only asks for vars that weren't provided.

**`--from-plan <file>`.** Reads the plan file. Auto-sets `plan` to the file's path and (optionally) `feature` to the first H1 heading in the file. The user still confirms and can override.

**`--list`.** Shows all available formulas (from `~/.beads/formulas/*.formula.json`) with name + description, then exits. Does not pour or dispatch. Combine with no other flags.

**`--dry-run`.** Runs Steps 1–3 (pick formula, collect vars, pour, `bd graph`, `bd ready`) but stops before dispatching any agents. Useful for validating a new custom formula without burning tokens. Leaves the beads issues in place — the user can continue by running `/spawn --resume {team}`, or tear down with `bd list --status=open | grep {team} | bd close ...`. Print the teardown command at the end of the dry run.

**`--status [team-name]`.** User-facing peek at what's running. Does NOT dispatch, claim, or close anything. With no team name, lists every team that has any open beads issue and a one-line summary per team. With a team name, prints the per-step status and any background `Agent` IDs the orchestrator captured. See "Status command" below for the exact output shape. Safe to run mid-team — meant for the user to check progress without interrupting the orchestrator.

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

### Step 0.5 — Detect the repo's stack profile

Before dispatching agents, figure out which stack profile to inject into their spawn prompts. This is what makes the orchestration stack-agnostic.

**Detection order — first match wins:**

| Marker file                             | Profile       |
|-----------------------------------------|---------------|
| `package.json` contains `"next"` dep    | `nextjs-ts`   |
| `package.json` (no `next`)              | `node-ts`     |
| `deno.json` / `deno.jsonc`              | `deno`        |
| `go.mod`                                | `go`          |
| `Cargo.toml`                            | `rust`        |
| `pyproject.toml` / `setup.py`           | `python`      |
| `Package.swift` / `*.xcodeproj`         | `swift-ios`   |
| (none match)                            | `generic`     |

Read the matched profile from `~/.claude/agent-teams-profiles/{name}.md`. If the profile file is missing, fall back to `generic.md`. If `generic.md` is also missing, proceed with no injected profile — the explorer will set lint/test defaults per arm.

**Override:** `--profile <name>` skips detection. `--profile none` injects nothing.

Report the decision to the user:

```
Stack profile: nextjs-ts (detected via package.json → next dep)
   Lint:   npm run lint
   Test:   npx vitest run <files>
   Build:  npm run build
```

**How the profile is used:** when spawning the explorer, implementer, judge, and test-writer, append the profile's full contents to the spawn prompt under a section header `## Stack profile` — so the agent sees both its normal instructions AND the stack-specific commands/conventions. The profile is a prompt fragment, not a script.

The `{{lint_cmd_default}}` variable in `mol-full-team` and `mol-lite-team` formulas should be set from the profile's LINT command at pour time (via `--var lint_cmd_default=...`). If you're pouring manually, copy the value from the profile.

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
5. **For `plan` specifically** — run plan discovery (see "Plan discovery" below) instead of a bare prompt
6. **Prompt** — only for remaining required vars still unset

One question at a time. Skip optional vars unless the user asks to set them.

Before the confirm step, show all resolved values and let the user override any one with a single prompt ("which var to change?"). This lets auto-detected values (especially `base_branch`) be corrected without restarting.

#### Plan discovery

When the selected formula has a `plan` var that's still unset after steps 1-4, don't just ask "enter a plan path" — **scan for existing plans and offer a picker.**

**Scan roots (2 levels deep, ignore `*.refined.md` sidecars):**

```bash
find ./PLAN.md ./docs/plans ./plans ~/.claude/plans \
     -maxdepth 3 -name "*.md" \
     ! -name "*.refined.md" ! -name "TEMPLATE.md" ! -name "_template.md" ! -iname "*template*" \
     2>/dev/null
```

For each file, read the first `# H1` heading as a one-line description hint.

**Picker (when ≥1 plan file found):**

```
Found 3 plan files:

  [1] docs/plans/todos-v2.md          — todos v2 — filtering, editing, persistence
  [2] docs/plans/auth-refactor.md     — Rotate session tokens to argon2id
  [3] ~/.claude/plans/big-rewrite.md  — Migrate payments flow to Stripe
  [n] enter a path manually
  [c] create a new plan

>
```

- Numeric pick → set `plan` to that path, done.
- `n` → free-text prompt for a path.
- `c` → run **"Create a new plan"** flow (below).

**When no plan files are found:** ask directly — "No plans discovered. Enter a path, or `c` to create one."

**Formula-aware nudge** — if the user picked `mol-full-team` or `mol-lite-team` and a plan was discovered with ≥3 `- [ ]` checkboxes, offer to switch:

```
Heads up: docs/plans/todos-v2.md has 9 checkbox milestones.
Switch to mol-plan-driven-team for plan verification + checkbox tracking? [y/N]
```

Trigger threshold: `grep -c '^- \[ \]' {plan}` ≥ 3. Silent otherwise.

#### Create a new plan

Triggered from the plan picker's `c` option, or when no plans exist and the user wants to start one.

1. **Ask for a name** (kebab-case, validated):

   ```
   Plan name (kebab-case, e.g. auth-refactor): >
   ```

2. **Decide where to put it** — use the first of these that exists; if none, ask:
   - `./docs/plans/` → `./docs/plans/{name}.md`
   - `./plans/` → `./plans/{name}.md`
   - `~/.claude/plans/` → `~/.claude/plans/{name}.md`
   - fallback: ask "Where should this live? [1] docs/plans/ (create dir)  [2] plans/ (create dir)  [3] ~/.claude/plans/  [4] ./PLAN.md"

3. **Look for a template** in the chosen directory first, then walk up to the repo root:

   ```bash
   # In the chosen plans dir, then each parent until repo root or home:
   ls TEMPLATE.md _template.md .template.md *template*.md 2>/dev/null
   ```

   If multiple match, prefer this order: `TEMPLATE.md`, `_template.md`, `.template.md`, first `*template*.md` alphabetically.

4. **If template found** — copy it to `{name}.md` and substitute placeholders:
   - `{{name}}` → the kebab-case name
   - `{{feature}}` → the `feature` var (or name, if feature isn't set yet)
   - `{{date}}` → today's date (`YYYY-MM-DD`)

   Report: `Copied template from {template-path} → {new-plan-path}`.

5. **If no template found** — scaffold with this skeleton:

   ```markdown
   # {name}

   ## Problem statement

   <!-- One or two sentences: what you're building and why. -->

   ## Out of scope

   - …

   ## Milestones

   - [ ] …
   - [ ] …

   ## Testing

   <!-- What needs tests, where they live. -->

   ## Progress log

   <!-- integrate step appends here -->
   ```

6. **Stop the wizard** — the plan is empty. Don't continue with a placeholder plan. Output:

   ```
   Created {path}.

   Fill it in, then re-run:
     /spawn --formula {formula} --from-plan {path}
   ```

   Exit cleanly — do NOT pour the molecule.

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

#### Background vs. foreground per step type

| Step type           | Default mode  | Why                                                              |
|---------------------|---------------|------------------------------------------------------------------|
| explorer            | **background** | Read-only; orchestrator parses output after completion notify    |
| implementer arms    | **background** | Long-running; main session should stay free for the user         |
| test-writer         | **background** | Long-running; failure surfaces in next dispatch cycle            |
| code-reviewer       | **background** | Read-only; report parsed after completion                        |
| codex-reviewer      | **background** | Same as code-reviewer                                            |
| **judge**           | **foreground** | Verdict drives retry loop — orchestrator must read it inline     |
| **integrate**       | **foreground** | Touches `main`, pushes, deletes branches — must not run blind    |

`--foreground` on the `/spawn` invocation flips every step to foreground (legacy behavior). `--foreground` is the right choice when debugging a stuck team or when the user wants to watch every dispatch happen synchronously.

When a step runs in background, the `Agent` tool returns an `agentId` immediately and the orchestrator gets a completion notification later. The orchestrator MUST:

1. **Capture the `agentId`** in a per-team map (`{team-name}: {step-id: agentId}`) so `--status` and resume can find it later.
2. **Not block on the notification** — continue dispatching other ready tasks (parallel arms), or yield to the user, until completion arrives.
3. **On completion notification**, re-enter the orchestration loop: parse the agent's output (for read-only agents whose side effects you must execute), then check if any further steps are now unblocked.
4. **On no-completion-after-N-minutes**, do NOT poll aggressively — use `ScheduleWakeup` (delay 600–1200s) to check `bd list --status=in_progress` and see if the agent's beads issue is still claimed. Aggressive polling burns the prompt cache.

#### Failure surfacing in background mode

Foreground errors land directly in the conversation. Background errors do not — the agent finishes and reports its result, but the orchestrator is busy elsewhere. To catch failures:

- **On completion notification**, always inspect the agent's final message for an explicit "Done:" or "FAILED:" line. Implementers conventionally end with `Done: implementer — N files changed.` — if that line is missing OR the message describes an unhandled exception, treat it as a failure.
- **For implementer arms**, also check `bd show {arm-task-id} --json | jq -r '.status'`. If still `in_progress` after the agent reported done, the agent forgot to close its own beads issue — the orchestrator closes it.
- **For judge FAIL verdicts** (always foreground, so this is straightforward): reopen the failing arm, relay findings, re-dispatch the arm in background, schedule a wakeup to re-judge.

If the orchestrator is yielding to the user when a failure notification arrives, surface a one-line alert: `⚠ {team}/{step-id} failed — {summary}. Run /spawn --resume {team} to continue.` Do not silently retry without telling the user.

#### Per-task dispatch

For each ready task:

1. **Create the worktree** (if it's a task that needs one):

   ```bash
   # When branching off the default base (main, develop, etc.):
   bd worktree create {team}-{step-id} --branch agent/{team}/{step-id}

   # When branching off a non-default base (e.g. test-writer and reviewers
   # need integration/{team} as their base, NOT main), use raw git — bd worktree
   # has no --from flag:
   git worktree add -b agent/{team}/{step-id} \
     /path/to/{team}-{step-id} \
     integration/{team}

   # Either way, silence the "0755 permissions" warning beads emits:
   chmod 700 /path/to/{team}-{step-id}/.beads 2>/dev/null || true
   ```

   **Rule of thumb:** implementer arms branch off the default base. Test-writer and code-review branch off `integration/{team}` (they need the merged arm code to test against / review).

2. **Dispatch the agent**. Read the `labels` for model routing:
   - `agent:<name>` → which subagent to spawn
   - `model:<id>` → which model to use

   Fall back to the agent's frontmatter `model` field if no `model:` label is present. Apply the foreground/background table above for `run_in_background`.

3. **Judge retry loop** (max 3 attempts, foreground): on `VERDICT: FAIL`, reopen the failing arm (`bd reopen {id}`), relay findings verbatim, re-dispatch the arm in background, then schedule a wakeup (1200s) to re-judge once the arm closes. Escalate to the user after attempt 3.

4. **Parallel dispatch**: if multiple tasks in `bd ready` share the same `needs` set, spawn them in a **single message** so they run in parallel. With background dispatch, a single message with N `Agent` calls returns N `agentId`s and the main session is freed immediately.

#### Scope bd queries to your root epic

`bd ready` surfaces work from ALL open teams in the repo's beads database, including stale tasks from prior runs. Every `/spawn` invocation should capture the root epic ID at pour time and use it as the single source of truth for what's "your" work.

```bash
# At pour time, capture the root ID
ROOT_EPIC_ID=$(bd mol pour <formula> --var team=<team> ... | grep -oE 'agent-teams[^ ]*-mol-[a-z0-9]+' | head -1)

# Then, instead of `bd ready`, list your epic's children
bd show "$ROOT_EPIC_ID" | awk '/↳/ {print $2}'    # all child IDs
bd show "$ROOT_EPIC_ID" --json | jq -r '.children[] | select(.status=="open") | .id'
```

Always filter by root epic before claiming work. Never dispatch a task just because `bd ready` surfaced it — confirm it belongs to your team first.

#### Dispatch pattern for a single task

**Background dispatch (default for explorer / implementer / test-writer / reviewers):**

```bash
ID={task-id}
bd update "$ID" --claim --status in_progress
```

```
# Then call Agent with run_in_background: true. Pseudocode:
Agent(
  description="...",
  subagent_type="<from agent: label>",
  model="<from model: label or frontmatter>",
  prompt="<full prompt with worktree, beads ID, files, etc.>",
  run_in_background=true,
)
# → returns agentId immediately. Capture it; do NOT block.
# → on completion notification, parse output, then:
#     bd close "$ID" --reason "..."   (for Bash-equipped agents that may have already self-closed — check first)
#     execute any commands the agent reported (bond_command, etc.)
#     re-evaluate the orchestration loop for newly-ready work
```

**Foreground dispatch (judge + integrate):**

```bash
ID={task-id}
bd update "$ID" --claim --status in_progress
# Agent(... run_in_background=false) — orchestrator waits for the verdict
# On agent success:
bd close "$ID" --reason "{one-line summary}"
# On agent failure: bd update "$ID" --status open and surface the error inline
```

For read-only agents (explorer, code-reviewer) the orchestrator closes the agent's beads issue on its behalf after executing the recommended commands. With background dispatch, this happens in the completion-notification handler, not inline.

**Yielding to the user.** After dispatching all currently-ready background tasks in a single message, the orchestrator's user-facing reply should be a one-line summary of what was kicked off and what the user can do next:

```
Dispatched: {team}/explorer (background, agentId={short-id}). I'll continue when it returns.
You can run /spawn --status {team} to peek at progress, or keep working — I'll surface failures here.
```

This frees the main window without leaving the user wondering whether anything is happening.

#### Read-only agents cannot close their own beads issues or bond children

Some agents (explorer, code-reviewer) ship without the `Bash` tool — they're read-only by design. They cannot run `bd close`, `bd mol bond`, or any shell commands. When the orchestrator dispatches a read-only agent:

1. **Expect a report, not side effects.** The agent returns structured output describing what should happen next (e.g. the explorer returns a `DECOMPOSITION:` block with one `bond_command` per arm).
2. **Execute the commands yourself.** Parse the agent's output for `bd mol bond ...` commands (explorer) or bond/dep/close commands (reviewer with follow-ups) and run them from the project root.
3. **Close the agent's beads issue yourself** after executing its recommended actions: `bd close {agent-issue-id}`.

Agents with `Bash` in their tools (implementer, judge, test-writer) can handle their own beads operations and should close their own issues.

**With background dispatch:** the orchestrator does NOT see the agent's report until the completion notification fires. Treat the notification as the trigger to: (a) parse the report, (b) execute any recommended commands, (c) close the agent's beads issue. If the explorer returned `DECOMPOSITION:` with bond commands, run those bonds in the notification handler — only then is the team ready to move to the implement step.

#### CRITICAL: `bd ready` does not surface bonded arms

Once the explorer bonds implementer arms under the root epic, those arms do **not** appear in `bd ready` until the root epic closes (which happens last). `bd ready` will only show the root epic itself and any non-bonded steps.

This means the orchestrator must:

1. **Track arm IDs from the bond output.** Each `bd mol bond mol-implement-arm ...` prints "Spawned: N issues". Capture the resulting arm task IDs — either from the output or by running `bd list --parent {root-epic-id}` after bonding.
2. **Dispatch arms by ID directly**, not by polling `bd ready`. Use `bd show {arm-id}` to confirm status before dispatch.
3. **Poll arm closure**: after dispatching, check each arm's status with `bd show {arm-id}` until all are `closed`. Do not rely on `bd ready` to signal completion. With background dispatch, prefer the agent completion notification over polling — the notification fires when the agent itself finishes, which is the same moment its beads issue should close. Only fall back to `bd show` polling (via `ScheduleWakeup` at 600–1200s intervals) if a notification was missed or the agent's runtime is unbounded.

#### CRITICAL: wire `waits_for: all-children` as real beads deps after bonding

`waits_for: all-children` in a formula is **just a declaration** — `bd mol pour` and `bd mol bond` do NOT create deps from bonded children to the gated step automatically. Without explicit wiring, `bd ready` returns the gated step (e.g. the judge) as ready immediately, before any arms have been built.

**Fix: after every `bd mol bond` run, wire each new arm's root issue to each gated step with `bd dep add`.**

```bash
# 1. After the explorer's bonds execute, capture the new arm root IDs:
#    Either from each `bd mol bond` output ("Spawned: N issues") or by listing
#    the root epic's children.
ARM_IDS=$(bd show "$ROOT_EPIC_ID" --json | jq -r \
  '.children[] | select(.title | test("implement-")) | .id')

# 2. Read the formula to find every step with waits_for: all-children.
#    These are the gated steps that must block on the new arms.
GATED_STEP_IDS=$(bd show "$ROOT_EPIC_ID" --json | jq -r \
  '.children[] | select(.title | test("judge|integrate")) | .id')
# Better: match by the formula's step IDs directly — judge, integrate, etc.

# 3. Wire every gated step as blocked-by every arm (default --type is "blocks"):
for gated in $GATED_STEP_IDS; do
  for arm in $ARM_IDS; do
    bd dep add "$gated" "$arm"
  done
done
```

Now `bd ready` correctly gates those steps. When the last arm closes, the gated step becomes ready automatically — no polling, no "skip bd ready" special case.

**Why we didn't do this before:** earlier docs said "the orchestrator enforces this manually." That's extra work on every run and easy to get wrong. Explicit `bd dep add` calls are the real fix. Source: beads `docs/MOLECULES.md` "Christmas Ornament" pattern — `bd mol bond` attaches children; it does not wire blocking deps. The formula's `waits_for` field is metadata for the orchestrator to know *which* deps to add, not a beads-enforced blocker on its own.

**Apply the same pattern** to any other dynamic children (e.g. `mol-review-arm` bonded by the triage step for `mol-code-review` — wire each review arm to the aggregate step).

#### CRITICAL: sweep ghost proto beads after bonding

Each `bd mol bond mol-<formula> <parent>` call prints `Spawned: 2 issues` because it creates **both**:

1. **A proto bead** — title is the bare formula name (e.g. exactly `mol-implement-arm`, no team prefix, no description). This is the cooked formula instance.
2. **The actual child step** (the one we want — e.g. `[<team>] implement-<arm>: <feature>`).

The proto inherits the parent molecule's `liquid` phase, so it persists in the database. Nothing closes it automatically — the formula has no `cleanup` step, the bond doesn't auto-archive, and no agent owns it. Result: ghost protos accumulate across teams. After several `/spawn` runs `bd list --status=open` is cluttered with N copies of `mol-implement-arm`.

**Fix: after the bond batch for a team is complete, sweep:**

```bash
# Close every open proto whose title is exactly a known formula name.
# Run this once per team, after all bonds for that team have completed.
bd list --status=open --json \
  | jq -r '.[] | select(.title == "mol-implement-arm" or .title == "mol-review-arm") | .id' \
  | xargs -I{} bd close {} --reason "ghost proto post-bond"
```

Add this to your post-bond cleanup right after the dep-wiring step. It's idempotent — safe to run even if there are no ghosts.

**Do NOT use `--ephemeral` on bond to fix this.** That flag also marks the actual child arm as ephemeral (excluded from Dolt sync), which loses the audit trail of the implementer's work. The sweep above is the right shape.

#### Bond target for dynamic arms

When the explorer (or triage) bonds child molecules, target them at the **root epic**, not at the gated step:

```bash
bd mol bond mol-implement-arm {ROOT_EPIC_ID} \
  --var team=... --var arm=... --var feature=... ...
```

beads blocks `mol-*` prefixed formula names for bond resolution. If you renamed a formula without the prefix, `bd mol bond` will fail with "not found (not an issue ID or formula name)". Our shipped formulas all use the `mol-` prefix in their filenames for this reason.

#### Pass exact bond vars to the explorer

Variable names drift between what the explorer emits and what `mol-implement-arm.formula.json` accepts (e.g. `files_owned` vs. `files`). This costs 1-2 failed bond attempts per run.

Before dispatching the explorer, extract the authoritative var list from the child formula:

```bash
BOND_VARS=$(jq -r '.vars | to_entries | map(
  "\(.key)" + (if .value.required then " (required)" else " (optional, default: \(.value.default // "none"))" end)
) | join("\n  - ")' ~/.beads/formulas/mol-implement-arm.formula.json)
```

Include this in the explorer's spawn prompt as:

```
Root epic ID:       {ROOT_EPIC_ID}
Team:               {TEAM}
Feature:            {FEATURE}
Repo:               {REPO}
Implementer model:  {IMPLEMENTER_MODEL}

Bond vars for mol-implement-arm (use EXACTLY these names in every bond_command):
  - {BOND_VARS output}
```

The explorer then produces bond commands whose `--var` names match the formula verbatim, with every required var present. No more silent renames.

#### Seed dependent arms from their upstream

When arm B has a beads dep on arm A (`bd dep add B A`) because B consumes files A creates, **merge A's branch into B's worktree before dispatching B**. Otherwise B's lint or typecheck fails on missing imports (the file A creates doesn't exist in B's worktree until merge time) — regardless of stack (TS, Go, Rust, Python all hit this differently but for the same reason).

```bash
# After A closes, before claiming B:
cd /path/to/{team}-impl-{arm-b}
git merge agent/{team}/impl-{arm-a} --no-edit
```

If the merge produces conflicts, that's a real dependency conflict between the arms — stop and re-plan the decomposition. Don't dispatch B on a dirty merge state.

### Step 6 — Integration

When the `integrate` task (or the last orchestrator-labeled step) becomes ready:

```bash
# 1. Build integration branch
git checkout -b integration/{team}
git merge agent/{team}/impl-{arm}      # repeat per arm
git merge agent/{team}/test-writer     # if present

# 2. If test-writer added a test runner, the integration branch now has the
#    updated dep manifest but not the installed deps. Install once per stack:
#    - JS/TS: npm install / pnpm install / yarn
#    - Python: pip install -e . / poetry install / uv sync
#    - Rust: cargo fetch (or just let cargo build pull them)
#    - Go: go mod download
#    Use the stack profile's convention; skip for stacks with no separate install step.

# 3. Verify build + tests pass on integration branch using the profile's commands.
#
#    LINT MUST BE SCOPED TO CHANGED FILES — don't lint the whole repo.
#    Many projects have vendor dirs (node_modules/**, vendor/**, .venv/**)
#    that are not excluded by default linter config and produce hundreds
#    of phantom errors. Lint only what this team changed:
#
CHANGED_FILES=$(git diff --name-only {base_branch}...integration/{team} | \
  grep -E '\.(ts|tsx|js|jsx|py|go|rs|swift)$' || true)

if [ -n "$CHANGED_FILES" ]; then
  # Stack-specific — pick one:
  # JS/TS:    echo "$CHANGED_FILES" | xargs -r pnpm exec eslint --no-error-on-unmatched-pattern
  # Python:   echo "$CHANGED_FILES" | xargs -r ruff check
  # Go:       go vet ./...                        # go scopes by package, not file
  # Rust:     cargo clippy --package $PKG         # rust scopes by crate
  echo "$CHANGED_FILES" | xargs -r ${LINT_CMD_CHANGED_FILES}
fi

# BUILD and TEST run at project scope — they need full context.
${BUILD_CMD} && ${TEST_CMD}

# 4. Fix P1 findings from reviewers
# (apply fixes, commit)

# 5. If the formula has a plan-update step OR this was mol-plan-driven-team:
#    update the plan file to reflect what shipped. See "Plan update" below.

# 6. Push
git push origin integration/{team}

# 7. Merge back to base branch
git checkout {base_branch}
git merge integration/{team} --no-edit
git push origin {base_branch}

# 8. Clean up
bd worktree list               # see what exists
bd worktree remove {name}      # repeat per worktree
git branch -D agent/{team}/* integration/{team}

# 9. Close remaining issues
bd list --status=open | grep {team}
bd close {id1} {id2} ...
```

#### Plan update (mol-plan-driven-team and similar)

When the formula has a `plan-update` step — or when a `plan` var was passed and the plan file uses `- [ ]` checkbox milestones — tick off the checkboxes that got done before pushing integration.

**Identifying what shipped.** Read the arm reports (each implementer returns `Done: implementer — N files changed. <summary>`). Read `git diff {base_branch}...integration/{team}`. Match changed files + behaviors back to milestones in the plan.

**Ticking the boxes.** In-place edit on the plan file:

```bash
PLAN="{plan-var-value-or-refined-sidecar}"
# Tick a specific milestone:
sed -i '' 's/- \[ \] Add in-memory todos store/- [x] Add in-memory todos store/' "$PLAN"
```

Only tick milestones that are **actually complete** in the merged diff. If a milestone is partially done (e.g. "Add auth with rotation" where only the base auth shipped), leave it unchecked and note the partial work in the progress log.

**Progress log.** Append a section to the plan file:

```markdown
## Progress log

### 2026-04-18 — team `todos` (arms: api, ui)
- [x] In-memory todos store + REST API (arm: api) — commits 5e4f8d0
- [x] /todos page UI (arm: ui) — commits 27eb536, b2db714
- Test coverage: 16 unit tests for store (arm: test-writer) — commit 8df8a46
- Reviewer findings: 2 P1, 4 P2 (not yet resolved — tracked separately)
```

**Commit the plan update** on the integration branch so it's part of what ships:

```bash
git add "$PLAN"
git commit -m "docs(plan): tick {team} milestones"
```

**What if the plan lives outside the repo** (e.g. `~/.claude/plans/foo.md`)? Still tick the boxes in place, but don't commit — just report to the user that the file was updated.

**What if the plan is unchanged-format prose** (no checkboxes)? Skip the tick step. Still append the progress log if the user explicitly asked for tracking.

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

## Status command

`/spawn --status [{team}]` is the user-facing peek. It does NOT dispatch, claim, close, or modify anything. It exists so the user can check on a team that's running in the background without interrupting the orchestrator.

**No team name** — list every team that has any open beads issue:

```bash
TEAMS=$(bd list --status=open --json | jq -r '.[].title' | grep -oE '^\[[^]]+\]' | sort -u | tr -d '[]')
for t in $TEAMS; do
  OPEN=$(bd list --status=open --json | jq -r --arg t "[$t]" '[.[] | select(.title | contains($t))] | length')
  IN_PROGRESS=$(bd list --status=in_progress --json | jq -r --arg t "[$t]" '[.[] | select(.title | contains($t))] | length')
  BLOCKED=$(bd blocked --json 2>/dev/null | jq -r --arg t "[$t]" '[.[] | select(.title | contains($t))] | length')
  echo "  $t — $OPEN open, $IN_PROGRESS in_progress, $BLOCKED blocked"
done
```

Output shape:

```
Active teams:

  pyannote-sidecar   — 4 open, 2 in_progress, 0 blocked
  enroll-ui          — 5 open, 2 in_progress, 1 blocked

Run /spawn --status {team} for per-step detail, or /spawn --resume {team} to continue.
```

**With a team name** — print per-step status, recent activity, and (if the orchestrator captured them) live `agentId`s:

```bash
TEAM={team}
echo "Team: $TEAM"
echo ""
echo "Steps:"
bd list --status=open --json | jq -r --arg t "[$TEAM]" \
  '.[] | select(.title | contains($t)) | "  ○ \(.id) \(.title) [\(.status)]"'
bd list --status=in_progress --json | jq -r --arg t "[$TEAM]" \
  '.[] | select(.title | contains($t)) | "  ◐ \(.id) \(.title) [in_progress]"'
echo ""
echo "Worktrees:"
git worktree list --porcelain | awk '/^worktree / {print $2}' | grep -E "/${TEAM}-[^/]+$" || echo "  (none)"
echo ""
echo "Branches:"
git branch --list "agent/${TEAM}/*" "integration/${TEAM}" | sed 's/^/  /' || echo "  (none)"
```

If the orchestrator has been tracking background `agentId`s in its scratch state, append a "Background agents" block with the captured IDs and what step each is running. If not, omit that block — don't fabricate it.

**Read-only.** `--status` never writes to beads, never touches git, never dispatches an agent. Safe to run at any time, including while a team is mid-flight.

---

## Abandoning a team run

`/spawn --abandon {team} [--force]` is the escape hatch for a team run that broke mid-way and the user wants to clean up beads state, worktrees, and branches **without shipping anything**. This is destructive — nothing is preserved beyond what's already been pushed to a remote.

```bash
/spawn --abandon {team}            # interactive, with confirmation prompt
/spawn --abandon {team} --force    # skip the prompt, still honors safety rules
```

`--force` skips the confirmation prompt **only**. It does NOT bypass the safety rules below — those always apply. The only way past a safety trip is to fix the underlying condition (push the branch back to local-only, or merge the integration branch).

### When to use it

- Explorer crashed before bonding arms; beads has a half-built epic.
- An implementer's worktree is in a bad state and you'd rather start over than salvage.
- You changed your mind about the feature and want the team's scaffolding gone before it confuses the next run.
- A judge retry loop hit attempt 3 and you want to reset rather than escalate.

If the team **already shipped** (integration branch pushed, base branch merged), do NOT use `--abandon`. That work is done; just close any leftover beads issues by hand.

### Step 1 — Discover everything that belongs to the team

Run these in order. Capture the results into local variables for the preview step:

```bash
TEAM={team}
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
# If the user passed --base or the team was poured against a non-default base,
# use that instead. The default base only matters for the Rule 2 check below.

# 1. Open beads issues whose title contains [{team}]
ISSUES=$(bd list --status=open --json | jq -r \
  --arg t "[$TEAM]" '.[] | select(.title | contains($t)) | .id')

# 2. Worktrees named {team}-* (path basename match)
WORKTREES=$(git worktree list --porcelain | awk '/^worktree / {print $2}' | \
  grep -E "/${TEAM}-[^/]+$" || true)

# 3. Local branches: agent/{team}/* and integration/{team}
AGENT_BRANCHES=$(git branch --list "agent/${TEAM}/*" | sed 's/^[* ] *//')
INTEGRATION_BRANCH=$(git branch --list "integration/${TEAM}" | sed 's/^[* ] *//')
ALL_BRANCHES=$(printf '%s\n%s\n' "$AGENT_BRANCHES" "$INTEGRATION_BRANCH" | grep -v '^$' || true)
```

Discovery order matters: issues first (cheapest, most visible), then worktrees, then branches. If any step errors out (e.g. `bd` is unavailable), abort with a clear message — partial discovery is worse than none.

### Step 2 — Run the safety rules (BOTH must pass)

Both rules below run **before any preview is shown** and **before any destructive op**. If either trips, abort the entire abandon — do not touch beads, worktrees, or branches. Print which rule fired, exactly which branch or commit tripped it, and the specific resolution.

#### Rule 1 — No remote-tracked branches

NEVER delete a branch that's been pushed to a remote. Pushed work is intentional and may be referenced by PRs, other clones, or backups. Check both branch families:

```bash
REMOTE_AGENT=$(git branch -r | grep -E "origin/agent/${TEAM}/" || true)
REMOTE_INTEGRATION=$(git branch -r | grep -E "origin/integration/${TEAM}$" || true)

if [ -n "$REMOTE_AGENT$REMOTE_INTEGRATION" ]; then
  echo "ABORT: --abandon refuses to touch branches that exist on a remote."
  echo "Tripped by:"
  echo "$REMOTE_AGENT$REMOTE_INTEGRATION"
  echo ""
  echo "Resolution: delete the remote branch first, then re-run --abandon:"
  echo "  git push origin --delete <branch>"
  exit 1
fi
```

#### Rule 2 — Integration branch has no unmerged commits

NEVER delete `integration/{team}` if it has commits not on `{base_branch}`. Those commits are real work that hasn't been integrated; abandoning would silently destroy them.

```bash
if [ -n "$INTEGRATION_BRANCH" ]; then
  UNMERGED=$(git log "${BASE_BRANCH}..integration/${TEAM}" --oneline 2>/dev/null || true)
  if [ -n "$UNMERGED" ]; then
    echo "ABORT: integration/${TEAM} has commits not on ${BASE_BRANCH}:"
    echo "$UNMERGED"
    echo ""
    echo "Resolution (pick one):"
    echo "  - Merge integration/${TEAM} to ${BASE_BRANCH} first, then re-run --abandon."
    echo "  - If the work is truly abandoned, discard the branch manually:"
    echo "      git branch -D integration/${TEAM}"
    echo "    then re-run --abandon to clean up the rest."
    exit 1
  fi
fi
```

**All-or-nothing.** A safety trip aborts the whole flow — no partial cleanup, no "skip the offending item and keep going." The user must fix the tripped condition or manually undo it before `/spawn --abandon` will proceed. Rationale: abandon is destructive; a tripped rule means the user may not have full context, so bail hard and make them look.

### Step 3 — Preview

Once both safety rules pass, print a preview summarizing exactly what will happen:

```
/spawn --abandon {team} will:
  - close N open beads issues
  - remove M worktrees:
      /path/to/{team}-explorer
      /path/to/{team}-impl-foo
      /path/to/{team}-impl-bar
  - delete K branches:
      agent/{team}/explorer
      agent/{team}/impl-foo
      agent/{team}/impl-bar
      integration/{team}

Proceed? [y/N]
```

Counts come from the lists captured in Step 1. Always show full paths for worktrees and full names for branches — never just counts. Empty lists print `(none)` rather than being omitted; the user should see exactly what was discovered.

When `--force` is passed, **skip the prompt** and proceed straight to Step 4. The preview is still printed for the run log, but no input is solicited.

### Step 4 — Execute the cleanup

On a `y` (or `--force`), run the destructive ops in this order. Order matters: closing issues first means a mid-flight error still leaves beads in a clean state; removing worktrees before deleting their branches avoids the "branch is checked out" error.

```bash
# 1. Close every open beads issue belonging to the team
for id in $ISSUES; do
  bd close "$id" --reason "abandoned by /spawn --abandon"
done

# 2. Remove every worktree (force, since the user already confirmed)
for wt in $WORKTREES; do
  git worktree remove --force "$wt"
done

# 3. Delete every agent branch, then integration/{team}
for b in $AGENT_BRANCHES; do
  git branch -D "$b"
done
if [ -n "$INTEGRATION_BRANCH" ]; then
  git branch -D "integration/${TEAM}"
fi
```

If any individual command fails (e.g. a worktree is locked, a branch is somehow already gone), log the error and continue — by this point the user has confirmed the cleanup is what they want, and partial completion is better than a half-aborted state. Report any per-item errors in the final summary.

### Step 5 — Summary

Print a concise final summary:

```
Abandoned: N issues closed, M worktrees removed, K branches deleted.
```

If anything failed in Step 4, append a `Warnings:` block listing each failure. Exit zero if the discovery + safety + preview phases all succeeded, regardless of per-item Step 4 errors — the abandon as a whole completed.

### Anything not cleaned up

`--abandon` deliberately does NOT touch:

- `~/.claude/plans/` files (plans are user content)
- The repo's `{base_branch}` (never modified by abandon)
- Pushed remote branches (Rule 1)
- Beads issues whose titles don't contain `[{team}]`
- Other teams' worktrees or branches

If the user wants any of those cleaned up, they do it by hand. `--abandon` is intentionally narrow.

---

## Rules

- Never push until the `integrate` step — worktree commits only
- Never skip hooks on the integration commit — only on per-agent commits (`HUSKY=0` or repo equivalent)
- Resolve conflicts manually during integration — do not discard work
- Close beads issues only when the work is actually done
- Default to background dispatch for explorer / implementer / test-writer / reviewer; keep judge + integrate foreground (the table in Step 5 is authoritative)
- Capture background `agentId`s in per-team scratch state so `--status` and resume can find them
- Surface background failures to the user as a one-line alert when they fire — do not silently retry without telling the user
