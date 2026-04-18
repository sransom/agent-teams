# Writing plans for agent teams

An agent team (mol-full-team, mol-lite-team, mol-plan-driven-team) decomposes a plan file into parallel arms. The quality of the plan directly determines the quality of the decomposition. This doc covers:

- Where plan files live
- How to hand a plan to `/spawn`
- What makes a plan decomposable
- The checkbox + progress-log convention for multi-milestone work
- When to use `mol-plan-driven-team` (with plan-checker) vs `mol-full-team`

---

## Where plan files live

A plan is a plain markdown file. Conventions (pick what fits):

- **`~/.claude/plans/{name}.md`** — personal, not tied to a specific repo. Good for exploration and cross-repo work.
- **`{repo}/docs/plans/{name}.md`** — committed to the repo. Good for features tied to a product, so the plan ships with the code.
- **`{repo}/PLAN.md`** — top-level, used for a single active plan. Simple.
- **`/tmp/plan-*.md`** — disposable, for one-off runs.

agent-teams doesn't care where the file lives — you just pass the path.

---

## How to hand a plan to `/spawn`

### Recommended: `--from-plan`

```bash
/spawn --from-plan ~/.claude/plans/auth-refactor.md
```

This:
- Sets the `plan` formula var to the file's absolute path
- Reads the first `# H1` heading and suggests it as the `feature` var (user confirms)
- Uses the rest of the vars from the wizard or defaults

### Explicit `--var plan=...`

```bash
/spawn --formula mol-full-team \
  --var team=auth-refactor \
  --var feature="Rotate session tokens to argon2id" \
  --var plan=~/plans/auth.md \
  --var base_branch=main
```

Same effect, more verbose. Useful in scripts.

### In the wizard

Run `/spawn` bare and when it asks for the `plan` var, paste the path. You can also type an inline description instead — the explorer handles "path to file OR prose description" transparently.

---

## What the team does with the plan

1. **`/spawn`** reads the plan file once (for `--from-plan` inference) and passes the **path** in the formula vars (not the content — the agents read it themselves).
2. **Explorer** is the first agent to open the file. It reads the plan, inspects the codebase, and decides how to split the work into arms.
3. **Per-arm notes** distilled by the explorer go into each implementer's spawn prompt. Arm implementers do NOT re-read the whole plan — they get only the slice relevant to them.
4. **Judge** refers back to the plan to verify fidelity. It fails arms that drifted from what the plan asked for.
5. **Code reviewer + codex reviewer** use the plan as a spec baseline for finding deviations.
6. **Integrate** (in `mol-plan-driven-team`) ticks checkboxes for what got done and appends a progress log.

---

## What makes a plan decomposable

### Good

- **Clear problem statement.** One or two sentences on what's being built and why.
- **Concrete milestones as checkboxes:**

  ```markdown
  - [ ] Add `argon2id` dependency and verify it lints
  - [ ] Rewrite `hashPassword()` to use argon2id (keeps old-hash fallback)
  - [ ] Add migration that flags users with old hashes
  - [ ] Update login flow to rehash on successful old-hash verify
  ```

- **File paths and function signatures spelled out.** `src/auth/hash.ts` — function `hashPassword(plain: string): Promise<string>`.
- **Explicit out-of-scope list.** "Don't touch the session store. Don't migrate historical hashes — leave those for a followup."
- **Interfaces between parallel-able pieces.** If the work splits naturally, say so: "The migration can be built in parallel with the handler rewrite; they converge at the rehash-on-login step."

### Bad

- "Improve auth" — no detail the explorer can decompose.
- "Rewrite the payments flow" with no list of what's currently wrong or what the new flow should do.
- A stream-of-consciousness brainstorm with TODOs and questions still open.
- Commands/idioms from the wrong stack (says "run `npm test`" in a Go repo).

If your plan is closer to "bad" — use `mol-plan-driven-team`. Its plan-checker agent will either refine it or tell you what's missing before you burn implementer tokens.

---

## Checkbox convention for progress tracking

Multi-session or long-running work benefits from a visible checklist. Use GitHub-flavored checkbox syntax:

```markdown
## Milestones

- [ ] Week 1 — core hash migration
  - [ ] Add argon2id dep
  - [ ] Rewrite hashPassword()
  - [ ] Unit tests for new hash path
- [ ] Week 2 — login flow
  - [ ] Update /login handler
  - [ ] Rehash on successful old-hash verify
  - [ ] Integration test
- [ ] Week 3 — observability
  - [ ] Add metric: hash_algo{version} counter
  - [ ] Dashboard panel
```

Each `/spawn` run ticks the boxes it actually completes (the integrate step handles this when the formula supports it — currently `mol-plan-driven-team`). After three weeks of runs, the plan file tells the story of what shipped.

GitHub renders these as clickable checkboxes in PR descriptions and markdown previews — useful for status-at-a-glance.

### Progress log

The integrate step appends a short log entry per team run, at the bottom of the plan file under `## Progress log`:

```markdown
## Progress log

### 2026-04-15 — team `hash-migration` (arms: deps, impl)
- [x] Add argon2id dep
- [x] Rewrite hashPassword()
- [x] Unit tests for new hash path
- Commits: abc1234, def5678
- Reviewer findings: 1 P2 (documented)

### 2026-04-18 — team `login-rehash` (arms: handler, test)
- [x] Update /login handler
- [x] Rehash on successful old-hash verify
- [x] Integration test
- Commits: 9ab01cd
```

This gives you a complete audit trail in the plan file itself — no external project-management tool required.

---

## When to use `mol-plan-driven-team`

Use it when:

- The plan is long (>100 lines, multiple milestones)
- You're not sure the plan is concrete enough — want a second pair of eyes before burning implementer tokens
- You want checkbox tracking and progress logs
- The plan has gaps you know about but haven't written yet (plan-checker will flag them)

Use regular `mol-full-team` or `mol-lite-team` when:

- The plan is tight and you've already reviewed it
- You just want to ship a small feature quickly
- The plan isn't really a multi-milestone doc — it's a one-arm task description

### Command

```bash
/spawn --formula mol-plan-driven-team --from-plan ~/plans/big-feature.md
```

The plan-check step runs first (sonnet, ~$0.10) and returns one of:

- `PLAN_VERDICT: PASS` — plan is good as-is, proceed.
- `PLAN_VERDICT: REFINED` — plan-checker wrote a `.refined.md` sidecar with mechanical additions (converted prose to checkboxes, added inferred signatures). Orchestrator either uses the refined version (`--var use_refined_plan=true`) or stops for you to review.
- `PLAN_VERDICT: NEEDS_REVISION` — plan has gaps that require your decisions. Orchestrator stops, shows you what's missing.

---

## Multi-session / multi-run plans

For plans that span several `/spawn` runs:

1. Keep the plan file in a stable location (`{repo}/docs/plans/{name}.md` is good — it gets committed).
2. Use checkboxes so you can see progress across runs.
3. Commit the plan to the integration branch in each run so the progress log is versioned.
4. For the Nth run, pass the same `plan` path — each run only ticks the milestones it actually completes.

The explorer sees the current checkbox state and uses it to scope: it won't re-propose arms for milestones that are already `- [x]`.

### Tip: resumption after a partial run

If a `/spawn` run fails mid-way, the checkboxes won't be ticked for the incomplete parts. Use `/spawn --resume {team}` to pick up from where beads left off — the integration step will only tick boxes for work that actually merged.

---

## Related

- [`profiles/README.md`](../profiles/README.md) — stack profiles that agents use for lint/test/build commands
- [`commands/spawn.md`](../commands/spawn.md) — full orchestrator flow including plan-update logic
- [`docs/writing-formulas.md`](writing-formulas.md) — create your own formulas with custom plan handling
