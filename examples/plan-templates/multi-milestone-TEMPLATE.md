# {{name}}

<!--
  Created: {{date}}
  Feature: {{feature}}

  This is a multi-milestone plan template designed for the
  `mol-plan-driven-team` formula. Use it when:
    - The work splits into 2+ independent arms that can run in parallel.
    - You want each arm to own a non-overlapping set of files.
    - The team lead will merge arm branches into one integration branch
      and run a single quality gate at the end.

  If you only have one arm, use TEMPLATE.md instead — this template's
  Arms section will feel like overhead.

  Delete this comment block before committing the plan.
-->

## Problem statement

<!--
  Three to six sentences. Answer:
    1. Current state — what exists today, with concrete pointers
       (file paths, commit SHAs, ticket IDs).
    2. Pain — who feels it, how often, what does it cost?
    3. Desired state — what does "done" look like? One sentence.
    4. Why now — what changed that makes this the right time?

  Be specific. Multi-arm plans live or die on whether the problem
  statement is sharp enough that an arm boundary feels obvious.
-->

## Out of scope

<!--
  Multi-arm plans drift. List what is explicitly NOT in scope and why.
  Mention deferred items, future plans, and adjacent gaps you are
  consciously leaving alone.

  Example:
  - Database migrations — separate plan, owned by the data team.
  - Mobile clients — they keep using the v1 API; v2 ships server-side only.
  - Observability dashboards — follow-up issue, not blocking v0.1.
-->

- …
- …

## Stack notes

<!--
  Pin the agent's environment so they don't guess. Cover:
    - Languages / runtimes / version constraints.
    - Test framework and where tests live.
    - Lint / format conventions (ESLint config? prettier? gofmt? black?).
    - Existing libraries the agent should reuse vs. avoid.
    - Build system, CI assumptions, secrets handling.

  Example:
  - TypeScript 5.4, Node 22 LTS. Tests live in `**/__tests__/*.test.ts`,
    run via `pnpm test`.
  - Use the existing `Result<T, E>` type from `src/lib/result.ts` for
    error returns; do NOT introduce a new error library.
  - Lint via `pnpm lint`. Pre-commit hook runs the full suite — do NOT
    bypass with `--no-verify` unless instructed.
-->

## Arms

<!--
  This is the section that distinguishes a multi-milestone plan from a
  single-milestone one. List each arm explicitly. For every arm specify:
    - Which agent role owns it (typically one implementer per arm).
    - The files / directories it owns. **No two arms may own the same
      file.** Overlap = merge conflicts during integration.
    - Cross-arm dependencies, if any. Prefer NONE — if Arm B can't start
      until Arm A is half-done, the team lead should sequence them and
      the plan should say so.

  Example:

  ### Arm A — backend handler
  **Files owned:** `src/api/handlers/auth.ts`, `src/api/handlers/__tests__/auth.test.ts`
  **Depends on:** none
  **Owner:** implementer-a

  ### Arm B — frontend client
  **Files owned:** `web/src/lib/auth-client.ts`, `web/src/lib/__tests__/auth-client.test.ts`
  **Depends on:** Arm A's response shape (documented in Stack notes above)
  **Owner:** implementer-b

  ### Cross-arm dependencies
  - Arms A and B share no files but share a contract: the response shape
    pinned in Stack notes. If that shape changes mid-flight, both arms
    must coordinate.
-->

### Arm A — …

**Files owned:** …
**Depends on:** none
**Owner:** …

### Arm B — …

**Files owned:** …
**Depends on:** …
**Owner:** …

### Cross-arm dependencies

- …

## Milestones

<!--
  Multi-milestone plans use nested checkboxes. Each top-level milestone
  is a phase or arm; each sub-item is a concrete deliverable an
  implementer can finish in one session.

  Aim for 3-5 sub-items per milestone. Fewer = milestone is too coarse;
  more = it should probably be split.

  Use `- [ ]` so /spawn and the integrate step can track progress.
-->

- [ ] **Milestone 1 — Arm A: …**
  - [ ] …
  - [ ] …
  - [ ] …

- [ ] **Milestone 2 — Arm B: …**
  - [ ] …
  - [ ] …
  - [ ] …

- [ ] **Milestone 3 — Integration**
  - [ ] Merge arm branches into `integration/{{name}}`.
  - [ ] Resolve any conflicts.
  - [ ] Run full quality gate (lint, tests, build).
  - [ ] Open PR against the base branch.

## Testing

<!--
  For multi-arm work, list testing per arm AND for the integration step.
  Per-arm tests catch regressions inside an arm; integration tests catch
  contract drift between arms.

  Example:
  - **Arm A:** unit tests in `src/api/handlers/__tests__/auth.test.ts`.
  - **Arm B:** unit tests in `web/src/lib/__tests__/auth-client.test.ts`.
  - **Integration:** end-to-end test in `tests/e2e/auth.spec.ts` that
    exercises the full A↔B contract.
  - **Manual:** run `./scripts/smoke-test.sh` against the integration
    branch before merging to main.
-->

## Progress log

<!-- integrate step appends here -->
