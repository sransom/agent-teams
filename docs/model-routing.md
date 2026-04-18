# Model routing

Which models for which roles, and why.

---

## TL;DR

| Role          | Default | Alternatives                      | Why                                |
|---------------|---------|-----------------------------------|------------------------------------|
| Orchestrator  | opus    | sonnet                            | Runs the whole workflow; needs it  |
| Explorer      | haiku   | sonnet                            | Read-only, fast, no reasoning      |
| Implementer   | sonnet  | gpt-4o-mini (via Codex), haiku    | Judgment when plans are ambiguous  |
| Judge         | sonnet  | opus (for high-stakes work)       | Pass/fail gate; needs real review  |
| Test-writer   | haiku   | sonnet                            | Mechanical, deterministic          |
| Code-reviewer | sonnet  | opus (for critical reviews)       | Judgment on trade-offs             |

Family aliases (`haiku` / `sonnet` / `opus`) auto-track Claude Code's current default for each family. Pin to a specific snapshot (e.g. `claude-sonnet-4-6`) for reproducibility.

---

## Why these defaults

### Orchestrator → opus

The orchestrator (you, the Claude Code lead running `/spawn`) coordinates everything. It reads formula DAGs, dispatches agents, handles judge failures, resolves merge conflicts, reports findings. The cost of a mistake here is high — it ripples into every agent. Use opus.

### Explorer → haiku

The explorer is read-only. It runs Glob, Grep, Read, decides file boundaries, bonds arms in beads. No code generation, no judgment calls that require deep reasoning. Haiku is fast and cheap, and the "explore + decompose" task happens at the start of every run — the savings add up.

### Implementer → sonnet (or Codex gpt-4o-mini)

Implementation needs real reasoning. Spec ambiguities come up constantly — "does this function need to handle null?", "is this the right place to add the new field?". A too-cheap model will produce output that compiles but does the wrong thing.

**The Codex alternative.** If you install the [Codex CLI](https://github.com/openai/codex) and pass `--var implementer_model=gpt-4o-mini`, the implementer agent delegates to `codex exec` instead of using Claude tools directly. This costs roughly 1/3 of Sonnet for implementation tasks. Quality is comparable for well-specified plans — the caveat is that Codex has no context from the rest of the Claude Code session, so your plan has to be complete enough to stand alone.

Rule of thumb: **if your plan is a tight spec with clear file boundaries and interfaces, Codex is fine. If the implementer needs to make design calls, stick with Sonnet.**

### Judge → sonnet

The judge is a pass/fail gate. It reads the plan, reads the diff, runs lint, runs tests, and verdicts. A false PASS means broken code merges; a false FAIL triggers another (expensive) implementer retry. Sonnet strikes the right balance — it's not Opus-expensive but it's smart enough to catch real problems.

For high-stakes work (migrations that can corrupt data, auth changes, money-handling code), consider `--var judge_model=opus` or editing the formula.

### Test-writer → haiku

Writing unit tests is mechanical. Read the source, identify the exported surface, write tests for happy path + edge cases. Haiku handles this well and is ~5x cheaper than Sonnet. The test-writer also iterates on test failures — again, mechanical work.

### Code-reviewer → sonnet

Reviews involve judgment on trade-offs. "Is this abstraction premature?" "Is this error handling too defensive or not enough?" These aren't mechanical questions. Sonnet is the floor for useful review output.

The `full-team` formula runs two reviewers in parallel: the Claude code-reviewer (sonnet, for judgment + security) and a Codex reviewer (gpt-4o-mini, for mechanical correctness — wrong field names, missing null checks, off-by-one). They catch different classes of bugs. Codex is optional; the formula skips it gracefully if the CLI isn't installed.

---

## Family aliases vs pinned versions

Claude Code accepts short model names in agent frontmatter:

```yaml
model: sonnet   # resolves to the current Claude Code default Sonnet
model: haiku    # resolves to the current Claude Code default Haiku
model: opus     # resolves to the current Claude Code default Opus
```

**Trade-off:** aliases track upstream updates automatically (good — you get improvements for free), but you lose snapshot reproducibility. If Anthropic ships a new Sonnet that regresses your judge's behavior, you can't easily pin back without editing files.

For most users, aliases are the right call. For CI pipelines or production workflows where you want to fix behavior across releases, pin the exact snapshot:

```yaml
model: claude-sonnet-4-6
```

Both forms work everywhere — agent frontmatter, formula labels, `--var {role}_model=...` overrides.

---

## Overriding per-run

Any var named `{role}_model` can be overridden at spawn time:

```bash
/spawn --var implementer_model=gpt-4o-mini        # cheaper implementation
/spawn --var judge_model=opus                     # higher-stakes judge
```

The formula has to declare the var for this to work. `full-team` and `lite-team` declare `implementer_model`; other per-role overrides require editing the formula.

---

## Cost anatomy of a `full-team` run

Rough costs for a 6-file feature, one team run, no retries (illustrative; prices as of writing):

| Step           | Model       | Approx tokens | Cost             |
|----------------|-------------|---------------|------------------|
| Explorer       | haiku       | 8k in / 2k out| ~$0.01           |
| Implementer ×N | sonnet      | 20k in / 5k out (per arm) | $0.15/arm |
| Judge          | sonnet      | 15k in / 2k out| ~$0.08          |
| Test-writer    | haiku       | 10k in / 3k out| ~$0.015         |
| Code-reviewer  | sonnet      | 12k in / 2k out| ~$0.07          |
| Codex reviewer | gpt-4o-mini | similar       | ~$0.02           |
| **Orchestrator overhead** | opus | varies         | $0.50–2.00      |

Switching the implementer to Codex (`gpt-4o-mini`) saves ~60% of the implementer cost, typically the biggest line item. For a 3-arm team that's $0.30 saved per run.

If you run 10 features a week, that's $3/week or ~$150/year in saved implementer tokens alone. Not life-changing, but worth it if your plans are tight enough for Codex to handle.
