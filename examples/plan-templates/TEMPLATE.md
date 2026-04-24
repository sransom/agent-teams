# {{name}}

<!--
  Created: {{date}}
  Feature: {{feature}}

  This is a single-milestone plan template. If your work has multiple
  parallelizable arms with cross-arm dependencies, switch to
  multi-milestone-TEMPLATE.md instead.

  Delete this comment block before committing the plan.
-->

## Problem statement

<!--
  Two to four sentences. Answer:
    1. What is broken / missing / underbuilt today?
    2. Who feels the pain, and how often?
    3. What does "done" look like in one sentence?

  Be concrete. "Login is slow" is weak; "p95 login is 3.2s; target is <800ms"
  is strong. Cite numbers, paths, or commit SHAs where you have them.
-->

## Out of scope

<!--
  List the adjacent things you are NOT doing in this plan, and why.
  This is the most under-used section in agent-driven plans — agents will
  expand scope unless told not to. Be explicit.

  Example:
  - Telemetry / metrics on the new endpoint — separate plan, needs design.
  - Migrating legacy clients — they keep working against the v1 path.
  - Schema changes to the `users` table — this plan only touches the
    handler layer.
-->

- …
- …

## Milestones

<!--
  Single-milestone plans usually have 3-7 checkboxes. Each one should be
  small enough that one implementer agent can finish it in a session, but
  large enough to be a meaningful unit ("Wire the new handler" vs.
  "Add a semicolon").

  Use `- [ ]` so /spawn and the integrate step can track progress.
-->

- [ ] …
- [ ] …
- [ ] …

## Testing

<!--
  What needs tests, where they live, and what level (unit / integration /
  e2e). If you're touching infra or scripts that don't have a test harness,
  describe the manual verification steps the implementer should run before
  closing out.

  Example:
  - Unit tests for `parseToken()` in `src/auth/__tests__/parseToken.test.ts`.
  - Integration test for the full login flow in `tests/integration/login.spec.ts`.
  - Manual: run `./scripts/smoke-test.sh` against a scratch dev instance.
-->

## Progress log

<!-- integrate step appends here -->
