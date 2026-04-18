# /build-team

Interactive wizard to create a new agent team formula from scratch. Produces a `.formula.json` file in `~/.claude/formulas/` that `/spawn` can run.

---

## Instructions for Claude

Walk the user through the wizard **one question at a time**. Do not dump the whole thing at once — wait for each answer before moving to the next step.

### Step 0 — Name

Ask:

```
Formula name? (kebab-case, e.g. docs-refresh, security-audit)
>
```

Validate: lowercase, hyphens only, not already in `~/.claude/formulas/`. If it exists, ask whether to overwrite or pick a different name.

### Step 1 — Describe

Ask:

```
One-sentence description of what this team does?
>
```

This becomes the `description` field in the formula JSON.

### Step 2 — Roles

Most custom formulas are close variants of an existing one. Lead with a clone prompt before offering from-scratch composition:

```
Start from a template, or build from scratch?

  [1] clone full-team    — explorer → implementer arms → judge → test + review → integrate
  [2] clone lite-team    — same as full-team, minus test-writer
  [3] clone code-review  — triage → parallel specialist reviewers → aggregate
  [4] from scratch       — pick roles one at a time

>
```

**Before rendering the catalog**, scan `~/.claude/agents/*.md` and read the frontmatter (`name`, `description`, `model`) of each existing agent. These become "Your agents" — selectable in both the clone flow (for swaps) and the scratch flow (as first-class roles). A user agent with the same `name` as a built-in shadows the built-in (their version wins).

**If the user picks 1, 2, or 3 (clone):** read the source formula, lift its `steps` and `vars` verbatim. Then offer:

```
Template loaded: full-team (6 steps)

  [A] add a step
  [R] replace a step with a different agent  (built-in or one of yours)
  [D] remove a step
  [K] keep as-is, continue to DAG

>
```

On **R**, show the step list numbered, then show the combined catalog (built-ins + user agents) so they can pick a replacement. Common swaps: "replace code-reviewer with my-custom-security-reviewer".

**If the user picks 4 (from scratch):** show the combined catalog:

```
Pick roles (one per step — type the number, or C for custom, or D when done):

  Built-in:
  [1] explorer      — read-only codebase map + arm decomposition (haiku)
  [2] implementer   — executes plans; Claude by default, Codex via implementer_model var (sonnet)
  [3] judge         — pass/fail gate on implementer output (sonnet)
  [4] test-writer   — writes colocated tests (haiku)
  [5] code-reviewer — P1/P2/P3 report on a diff (sonnet)

  Your agents (scanned from ~/.claude/agents/):
  [6] {name} — {one-line description from frontmatter} ({model})
  [7] {name} — ... ({model})
  ...

  [C] define a brand-new custom agent (generates a new .md file)
  [D] done — move on to DAG

>
```

Only show the "Your agents" section if at least one user agent exists. If the user picks an existing agent, no new file is generated — the formula just references the agent by name. For built-in roles, confirm the model:

```
Use default model for {role} ({default-model})? [y/n]
>
```

If `n`, ask which model. Accept any valid Claude model ID or `gpt-4o-mini`/`gpt-5.4-mini` for Codex-delegated roles.

For `C` (custom):
```
Custom role name (kebab-case)? > {name}
One-sentence description? > {desc}
Tools (comma-separated, e.g. Read,Write,Edit,Bash)? > {tools}
Model (haiku | sonnet | opus | gpt-4o-mini | gpt-5.4-mini)? > {model}
```

Generate the agent `.md` file at `~/.claude/agents/{name}.md` with the standard frontmatter (`name`, `model`, `description`, `tools`) and a minimal body instructing the agent to perform its role. Remind the user they can edit it after the wizard finishes.

Track the selected roles as a letter list (a, b, c, …) for Step 3.

### Step 3 — DAG

For each role in order (skipping the first, which always starts with no deps), ask what it waits for by showing numbered options. Include all prior roles, plus two specials: "all previous" and "all-children" (dynamic arms).

**Smart default — `all-children` after a decomposing step.** If the *immediately prior* step is an `explorer` (or any agent whose role description mentions bonding arms / decomposition / triage), mark `all-children` as the default (`[default]`) and expand the inline hint so the user knows what it does. The user can still pick something else.

```
What should `judge` wait for?

  [1] explorer        (prior step)
  [2] all previous    (explorer)
  [3] all-children    [default] — wait for dynamic arms that `explorer` bonds
                       at runtime. Pick this when a prior step creates more
                       work than it starts with (explorer → N implementer
                       arms, triage → N reviewer arms).
  [4] nothing         (runs in parallel with others)

> [enter = 3]
```

When no decomposing step is upstream, no default is highlighted and the user picks explicitly:

```
What should `ship` wait for?

  [1] build
  [2] test
  [3] all previous
  [4] nothing

>
```

For roles with more than one prior step, support multi-select (e.g. `1,2` to depend on two specific steps):

```
What should `integrate` wait for?

  [1] explorer
  [2] judge
  [3] test
  [4] review
  [5] codex-review
  [6] all previous
  [7] all-children
  [8] nothing

> 3,4,5
```

After all roles are answered, render an ASCII DAG for confirmation:

```
DAG preview:

  explorer ─────┐
                ▼
              judge  (waits: all-children)
                │
        ┌───────┼───────┐
        ▼       ▼       ▼
      test   review   codex-review
        └───────┼───────┘
                ▼
            integrate

Proceed? [y/n]
```

If `n`, let the user revise a single role's deps.

### Step 4 — Variables

Pre-seed three variables: `team`, `feature`, `repo` (all required). Then ask:

```
Add more variables? [y/n]
>
```

For each additional variable:
```
Name? > {name}
Description? > {desc}
Required? [y/n] > {required}
Default (empty for none)? > {default}
```

### Step 5 — Review + save

Show a plain-English summary first, then the raw JSON below it. Example:

```
Formula: auth-refactor
Description: Security-focused team for auth changes with an extra OWASP pass.

Steps (DAG):
  explorer ──► judge (waits: all-children)
                 │
          ┌──────┴──────┐
          ▼             ▼
        review       security-audit
          └──────┬──────┘
                 ▼
             integrate

Vars:
  team           (required)  — short kebab-case team name
  feature        (required)  — what is being built
  repo           (required)  — repo directory name
  base_branch    (required)  — branch to merge back into
  plan           (default: "")
  implementer_model (default: sonnet)

Agents used:
  explorer          (built-in, haiku)
  judge             (built-in, sonnet)
  code-reviewer     (built-in, sonnet)
  security-sentinel (your agent, sonnet)

---

Raw JSON:

{
  "formula": "auth-refactor",
  ...
}

---

What would you like to do?

  [s] save to ~/.claude/formulas/auth-refactor.formula.json
  [n] edit name or description
  [r] edit roles (add, remove, or swap a step's agent)
  [d] edit DAG (change what a step waits for)
  [v] edit vars (add, remove, or change defaults)
  [q] quit without saving

>
```

On `s`, write the file and print:

```
✓ Saved: ~/.claude/formulas/auth-refactor.formula.json
Run it with: /spawn auth-refactor
```

On `n`, `r`, `d`, or `v`: jump back into the minimal version of that step — *only* the specific thing the user wants to change, not the whole step over. After the edit, return to the Step 5 summary with the change reflected. Loop until the user picks `s` or `q`.

Example of `d` (edit DAG): ask which step's deps to change, show the numbered options from Step 3 for just that one step, apply the change, redraw the summary.

Do not let the user into a state where the DAG is invalid (e.g. a cycle, or a step with no upstream when removing its only dep). If an edit would break the DAG, reject it with a one-line reason and return to the summary.

---

## Output format

The generated formula must be valid JSON matching this shape:

```json
{
  "formula": "<name>",
  "description": "<one-sentence>",
  "version": 1,
  "type": "convoy",
  "vars": { "<var>": { "description": "...", "required": true|false, "default": "..." } },
  "steps": [
    {
      "id": "<role-id>",
      "title": "[{{team}}] <role-id>: {{feature}}",
      "type": "task",
      "description": "<what this step does>",
      "labels": ["agent:<role>", "model:<model>"],
      "needs": ["<prior-step-id>"],
      "waits_for": "all-children"
    }
  ]
}
```

Omit `needs` if the step has no dependencies. Omit `waits_for` unless it's `all-children`.

---

## Rules

- Never write to the formula file until the user confirms in Step 6
- Never overwrite an existing agent `.md` file without asking
- Keep responses short between wizard steps — one question, wait, next question
- If the user types `quit` or `cancel` at any point, abandon without writing
