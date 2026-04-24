# Writing formulas

A formula is a JSON file that describes a workflow: its steps, their dependencies, and the variables the user provides at spawn time. `/spawn` pours a formula into beads issues; `/build-team` generates one interactively.

This doc covers both the interactive and by-hand paths.

---

## The easy way: `/build-team`

If you don't want to hand-edit JSON, skip this doc and run `/build-team`. It walks you through:

1. Name + description
2. Pick roles — clone a template (`full-team` / `lite-team` / `code-review`) or compose from primitives
3. Define the DAG with numbered picks for each step's dependencies
4. Declare variables
5. Review + save

The output is a formula in `~/.beads/formulas/` that `/spawn` can run.

Keep reading if you want to understand or hand-edit the JSON.

---

## Where formulas live

beads searches three locations, in order:

1. `.beads/formulas/` — project-level, checked first. Commit these to a repo when a formula is specific to that codebase.
2. `~/.beads/formulas/` — user-level, where agent-teams installs its 5 formulas. Your personal formulas go here too.
3. `$GT_ROOT/.beads/formulas/` — orchestrator-level, only if `GT_ROOT` is set.

`bd formula list` (from inside a repo with `bd init` run) shows what's visible from your current location.

---

## Anatomy of a formula

Here's `lite-team`, annotated:

```json
{
  "formula": "lite-team",
  "description": "Same parallel agent team as full-team, minus the test-writer step...",
  "version": 1,
  "type": "convoy",

  "vars": {
    "team":        { "description": "Short kebab-case team name", "required": true },
    "feature":     { "description": "What is being built", "required": true },
    "repo":        { "description": "Repo directory name", "required": true },
    "base_branch": { "description": "The branch to merge integration/{team} back into", "required": true },
    "plan":        { "description": "Path to a plan file or description", "default": "" },
    "implementer_model": { "description": "Model for implementer arms", "default": "sonnet" }
  },

  "steps": [
    {
      "id": "explore",
      "title": "[{{team}}] explore + decompose: {{feature}}",
      "type": "task",
      "description": "Map the codebase for {{feature}}. Decompose into implementer arms...",
      "labels": ["agent:explorer", "model:haiku"]
    },
    {
      "id": "judge",
      "title": "[{{team}}] judge: verify all implementations",
      "type": "task",
      "description": "Judge all implementer arms (attempt 1 of 3)...",
      "labels": ["agent:judge", "model:sonnet"],
      "waits_for": "all-children",
      "needs": []
    },
    {
      "id": "review",
      "title": "[{{team}}] code-review: integration/{{team}} branch",
      "type": "task",
      "description": "Run code review on integration/{{team}} branch...",
      "labels": ["agent:code-reviewer", "model:sonnet"],
      "needs": ["judge"]
    }
  ]
}
```

---

## Field reference

### Top-level

| Field         | Required | Purpose                                                         |
|---------------|----------|-----------------------------------------------------------------|
| `formula`     | yes      | The name. Must match the filename (without `.formula.json`)    |
| `description` | yes      | One-liner shown in `/spawn`'s picker                            |
| `version`     | yes      | Always `1` for now                                              |
| `type`        | yes      | Always `"convoy"` — beads' term for a multi-step workflow       |
| `vars`        | yes      | Variables the user provides at spawn time                       |
| `steps`       | yes      | The DAG — ordered list of tasks with `needs` relationships      |

### Vars

Each key is a var name (used as `{{name}}` in step templates). Each value is an object:

| Field         | Purpose                                                                      |
|---------------|------------------------------------------------------------------------------|
| `description` | Prompt text shown in `/spawn`                                                |
| `required`    | `true` if the user must provide a value (no default)                         |
| `default`     | Default value if not provided                                                |
| `enum`        | Optional list of allowed values (for constrained picks)                      |

### Steps

Each step is an object:

| Field         | Required | Purpose                                                         |
|---------------|----------|-----------------------------------------------------------------|
| `id`          | yes      | Short unique identifier, used in `needs` references             |
| `title`       | yes      | Displayed in `bd list`. Supports `{{var}}` interpolation        |
| `type`        | yes      | Always `"task"` for now                                         |
| `description` | yes      | The spawn prompt the orchestrator uses when dispatching         |
| `labels`      | yes      | Tags: `agent:name`, `model:name`, `arm:name`, etc.              |
| `needs`       | no       | Step IDs this depends on. Empty / absent = no deps              |
| `waits_for`   | no       | `"all-children"` for dynamic fanout                             |

---

## The `all-children` pattern

When one of your steps bonds additional issues at runtime (like the explorer bonding implementer arms), the step that gates on them needs `waits_for: "all-children"` — not a static `needs` list, because the arms don't exist at pour time.

```json
{
  "id": "judge",
  "needs": [],
  "waits_for": "all-children"
}
```

This tells the orchestrator: "don't become ready until every issue that was bonded under the parent molecule is closed, including any that got bonded after the pour."

**Important**: `waits_for` is metadata, not a beads-enforced blocker. `bd mol bond` attaches children but does NOT auto-wire blocking deps from each child to this step. The orchestrator (`/spawn`) is responsible for running `bd dep add {gated-step} {arm}` after every bond — default dep type `blocks` is what makes `bd ready` actually gate the step. See `commands/spawn.md` "wire `waits_for: all-children` as real beads deps after bonding."

Rule of thumb: if a step upstream uses `bd mol bond` in its spawn prompt, the next gating step needs `all-children` — AND the orchestrator must `bd dep add` each bonded arm to it before moving on.

---

## Variable interpolation

Any `{{var}}` reference in `title`, `description`, or `labels` gets replaced at pour time:

```json
"title": "[{{team}}] implement-{{arm}}: {{feature}}"
```

Becomes:

```
[auth-refactor] implement-migration: add argon2id session tokens
```

Variables used inside `labels` get interpolated too — that's how `implement-arm` threads the implementer model through:

```json
"labels": ["agent:implementer", "model:{{implementer_model}}", "arm:{{arm}}"]
```

---

## Writing a custom formula from scratch

Minimal 2-step example:

```json
{
  "formula": "plan-and-ship",
  "description": "Write a plan, then execute it. No parallel arms, no tests.",
  "version": 1,
  "type": "convoy",
  "vars": {
    "team":        { "description": "Team name", "required": true },
    "feature":     { "description": "What to build", "required": true },
    "repo":        { "description": "Repo directory", "required": true },
    "base_branch": { "description": "Branch to merge back into", "required": true }
  },
  "steps": [
    {
      "id": "plan",
      "title": "[{{team}}] plan: {{feature}}",
      "type": "task",
      "description": "Write an implementation plan for {{feature}}. Output to /tmp/{{team}}-plan.md.",
      "labels": ["agent:explorer", "model:sonnet"]
    },
    {
      "id": "build",
      "title": "[{{team}}] build: {{feature}}",
      "type": "task",
      "description": "Read /tmp/{{team}}-plan.md and implement it in worktree {{team}}-build.",
      "labels": ["agent:implementer", "model:sonnet"],
      "needs": ["plan"]
    }
  ]
}
```

Save as `~/.beads/formulas/mol-plan-and-ship.formula.json` and run `/spawn --formula mol-plan-and-ship`.

Don't forget the `mol-` filename prefix. beads' `bd mol bond` command only resolves formula names that start with `mol-` (the bond example in this doc's sibling formulas depends on this). You can keep the `formula` field inside the JSON short or prefixed — `bd` doesn't care — but the filename must have the prefix.

---

## Child formulas

Some formulas are never run directly — they're bonded as children by a parent step. `implement-arm` and `review-arm` are examples.

Convention: mark them in the description ("Not meant to be invoked directly — use full-team or lite-team") so they don't confuse users browsing `/spawn`'s picker.

Structurally they're identical to top-level formulas. The only difference is they're typically single-step and designed to be parameterized by a parent at bond time.

---

## Testing a new formula

Use `--dry-run` to pour without dispatching:

```bash
/spawn --formula mol-my-new-formula --dry-run
```

This pours the molecule, runs `bd graph` to show the DAG, and stops. If the graph looks wrong (wrong dependencies, missing `all-children`), fix the JSON and re-run. Tear down with:

```bash
bd list --status=open | grep {team} | awk '{print $1}' | xargs bd close
```

Once the graph is correct, drop `--dry-run` and let it run.
