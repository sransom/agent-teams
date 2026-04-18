# Writing agents

An agent is an `.md` file in `~/.claude/agents/` with YAML frontmatter and a prompt body. Formulas reference agents by name via the `agent:{name}` label on a step.

agent-teams ships with 5 built-in agents (explorer, implementer, judge, test-writer, code-reviewer). This doc covers how to write your own and plug them into formulas.

---

## Frontmatter

```markdown
---
name: security-reviewer
model: sonnet
description: >
  Security-focused code review. Flags OWASP Top 10 issues, hardcoded secrets,
  auth bypass, SQL injection. Report-only.
tools: Read, Glob, Grep, Bash
---
```

| Field         | Required | Purpose                                                      |
|---------------|----------|--------------------------------------------------------------|
| `name`        | yes      | Agent ID used in formula `agent:{name}` labels               |
| `model`       | yes      | `haiku`, `sonnet`, `opus`, or a full ID like `claude-sonnet-4-6` |
| `description` | yes      | What the agent does + when to invoke it                      |
| `tools`       | yes      | Comma-separated list: `Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `Agent` |

The `description` is what Claude Code sees when deciding which agent to invoke from a general request. Make it specific — list trigger phrases if you want it invoked for certain verbs.

---

## Tool selection

Pick the minimum set. Fewer tools = safer and faster.

| Need                              | Tools                               |
|-----------------------------------|-------------------------------------|
| Read-only exploration             | `Read, Glob, Grep`                  |
| Run shell commands, no file edits | `Read, Glob, Grep, Bash`            |
| Edit existing files               | `Read, Write, Edit, Glob, Grep`     |
| Full-stack implementer            | `Read, Write, Edit, Bash, Glob, Grep` |

If you want an agent that can spawn subagents, add `Agent`. Most agents don't need it — only the orchestrator does.

---

## Body

Write the prompt as if you're onboarding a new contractor:

- **What they are** — one-line role
- **What's in scope** — the tasks they handle
- **What's out of scope** — tasks they should decline or delegate
- **Workflow** — the steps they follow
- **Output format** — how they report results back

Example from the code-reviewer:

```markdown
# Code Reviewer

Report-only. You do not write or modify files under any circumstances.

## Workflow

1. Read the diff in the worktree specified in your spawn prompt
2. For each changed file, walk the review checklist below
3. Classify each finding as P1 (blocks merge), P2 (should fix), or P3 (nit)
4. End your response with a single-line verdict:
   `Done: code-reviewer — [PASS|BLOCK] — [N issues: X P1, Y P2, Z P3]`
```

Be concrete about output format. The orchestrator parses the last line — if an agent doesn't produce the expected format, the orchestrator has to guess, which introduces bugs.

---

## Conventions that play well with agent-teams

### Respect the worktree

The orchestrator spawns your agent with a `worktree_path` in its prompt. All file operations should be relative to that path. Don't `cd` elsewhere unless you're intentionally working outside the worktree (unusual).

### Commit with `HUSKY=0`

The integration step runs hooks once against the merged result. Per-agent commits should skip hooks so parallel arms don't fight over lock files or slow each other down:

```bash
HUSKY=0 git add -A && HUSKY=0 git commit -m "feat: add X"
```

For non-Node projects, use the equivalent (`--no-verify` is the generic flag).

### Never push

The orchestrator owns the single final push after integration. Pushing from an arm means the orchestrator can't safely rebase, and it partially ships work before reviewers see it.

### Close your beads issue

When done, your agent prompt will have a beads issue ID. Close it:

```bash
bd close {issue-id}
```

This unblocks downstream steps via `bd ready`.

### Produce parseable output

The orchestrator reads your final message to decide what happens next:

- Judge agents: start with `VERDICT: PASS` or `VERDICT: FAIL`
- Reviewers: end with `Done: {agent} — [N findings]`
- Implementers: end with `Done: implementer — N files changed`

Structured output makes the orchestrator's life easier.

---

## Using your agent in a formula

Reference the agent by `name` in a step's `labels`:

```json
{
  "id": "security-audit",
  "title": "[{{team}}] security-audit: integration/{{team}}",
  "type": "task",
  "description": "Run security review on integration/{{team}} branch...",
  "labels": ["agent:security-reviewer", "model:sonnet"],
  "needs": ["judge"]
}
```

The orchestrator reads `agent:security-reviewer` and spawns your agent as the subagent_type.

`/build-team` discovers your agents automatically — when you pick "from scratch" or "replace a step", the wizard shows built-in agents alongside your own under "Your agents".

---

## Shadowing built-ins

If you write an agent with the same `name` as a built-in (e.g. your own `code-reviewer.md`), yours wins. The built-in file still exists on disk but Claude Code uses whichever one it finds first — user agents take precedence.

Useful for:
- Customizing review rules for your codebase (e.g. adding proto-file-specific checks)
- Adding organization-specific lint or compliance gates to the judge
- Adjusting test-writer conventions for your test runner

If you later want the built-in back, delete your override or rename it.

---

## Example: a custom reviewer

```markdown
---
name: proto-reviewer
model: sonnet
description: >
  Protocol buffer schema reviewer. Checks .proto files for backwards-compat
  violations (removed fields, renamed fields with reused tags), field number
  reservations, and naming conventions. Report-only.
tools: Read, Glob, Grep, Bash
---

# Proto Reviewer

Report-only. You do not modify files.

## Workflow

1. Find all changed .proto files:
   `git diff {base_branch}...HEAD --name-only | grep '\.proto$'`

2. For each file, check:
   - Removed fields → P1 (breaks existing consumers)
   - Renamed fields with reused tags → P1
   - Unreserved tag numbers after field removal → P2
   - Field naming (snake_case expected) → P3

3. Report per file with line numbers.

4. End with: `Done: proto-reviewer — [PASS|BLOCK] — [N findings]`
```

Drop this into `~/.claude/agents/proto-reviewer.md`. Then reference it in a formula:

```json
{
  "id": "proto-review",
  "description": "Review proto schema changes on integration/{{team}} branch.",
  "labels": ["agent:proto-reviewer", "model:sonnet"],
  "needs": ["judge"]
}
```

`/build-team` will pick it up automatically next time you run the wizard.
