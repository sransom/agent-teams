# Cost reporting — design doc (proposed, not implemented)

**Status:** draft, proposed for v0.2+. Not shipped in v0.1.0.

## Problem

Today, a user running `/spawn` has no idea what a run cost until they check their Anthropic/OpenAI dashboards after the fact. Team runs fan out across 5–15 agent invocations with different model aliases (haiku, sonnet, opus, gpt-4o-mini). A ballpark total at integrate time would let users decide whether to switch `implementer_model=gpt-4o-mini` next time, run fewer arms, or use a lighter formula.

"Know what this run cost" sounds like a simple feature but decomposes into five distinct design questions. Picking wrong means migrating later. This doc sketches the options and recommends a phased approach.

---

## Design questions

### 1. Where do numbers come from?

Three data sources, in decreasing order of "free":

| Source                                              | Tokens | Dollars | Per-agent | Timing | Requires |
|-----------------------------------------------------|--------|---------|-----------|--------|----------|
| `<usage>` blocks from Agent tool results (Claude)   | yes    | no      | yes       | yes    | nothing  |
| Codex CLI exit output (non-Claude models)           | yes    | no      | yes       | yes    | codex ≥? |
| Anthropic/OpenAI API dashboards post-run            | yes    | yes     | no (sum)  | no     | manual   |

The orchestrator already *sees* `<usage>` blocks when it invokes subagents — they come back in the tool result. The information is there; it's just not captured.

### 2. What do we report?

- **Tokens** are free to report. `45k in, 12k out` per model alias.
- **Dollars** require a price table that goes stale. Pricing changes ~quarterly; we'd need to update the repo or fetch live. Fetching live requires network access from `/spawn`, which it doesn't have today.
- **Time** is free — subtract task `created_at` from `closed_at` in beads.

### 3. Where does the report live?

- **Terminal only** (printed by integrate step) — zero infrastructure, no history.
- **Appended to the plan's Progress log** — ships with the team's audit trail, versioned in git.
- **New `.beads/cost.jsonl` per run** — machine-parseable, enables retrospective tools.

### 4. Push vs pull?

- **Push (orchestrator sums as it goes):** lightweight, works even if the run crashes partway — you still get partial totals. Risk: duplicate accounting if the orchestrator loses track of what it already counted.
- **Pull (integrate queries beads at the end):** simpler to implement, but needs per-issue structured data we don't capture today.

### 5. Per-run, or cross-run rollup?

A single number at the end of one run is useful. "You spent $42 on agent-teams this week" is *more* useful, but requires persistent storage across runs (teams, repos, time).

---

## Recommendation: three tiers

### Tier 1 — v0.2: parsed `<usage>`, tokens only, printed to terminal

Minimal viable reporting. No new dependencies, no pricing table, no persistence.

**How:**
1. The orchestrator already calls `Agent(...)` and gets tool results containing `<usage>total_tokens: N` blocks. Capture these per invocation.
2. At integrate time, group by model alias (from the spawn prompt or the agent's frontmatter).
3. Print a summary before the final "Shipped." message:

```
Run totals:
  sonnet:  45,312 in / 12,087 out   (5 invocations)
  haiku:    8,444 in /  3,201 out   (3 invocations)
  Total:   66,044 tokens across 8 agent invocations, 24m runtime.

  Cost estimate (approximate, check dashboards for actual):
    sonnet: ~$0.32
    haiku:  ~$0.02
    ~$0.34 total
```

**What we don't do at Tier 1:**
- No persisted log
- No per-arm breakdown
- No Codex-side numbers (the CLI output format is different; save for Tier 2)
- No exact pricing — use published per-million prices from the Anthropic docs, rounded to 2 decimals, clearly labeled "approximate"

**Sizing:** ~80 lines added to `commands/spawn.md` Step 6 (integration). No new agents, no new formulas, no new files. Pricing table lives in a new `docs/pricing.md` that's easy to hand-update quarterly.

### Tier 2 — v0.3: structured `.beads/cost.jsonl` + retrospective

Opt-in via `/spawn --log-cost`. Writes one JSONL entry per agent invocation:

```json
{"team":"selfimp","arm":"install-ci","agent":"implementer","model":"sonnet","tokens_in":12300,"tokens_out":4100,"duration_ms":162825,"timestamp":"2026-04-24T22:47:12Z"}
```

Enables:
- `/spawn --cost {team}` — retrospective breakdown
- Aggregate across runs: `jq` one-liners over `.beads/cost.jsonl`
- Codex CLI invocations get their own entries (once we design the exit-output parser)

**Sizing:** ~200 lines added across `commands/spawn.md` + a new `scripts/cost-report.sh`. Requires a schema spec so tool authors know the format.

### Tier 3 — v1.0 maybe: observability

Stream to OpenTelemetry or Prometheus for teams running agent-teams at scale. Only useful if someone asks. Probably never shipped unless an enterprise-y user requests it.

---

## Decision points to resolve before Tier 1 ships

1. **Pricing table source of truth** — hardcode in `docs/pricing.md`, or fetch from a URL at integrate time? Fetch adds network dep + failure mode. Hardcode means quarterly PR.
2. **What happens when model is `gpt-4o-mini` or similar Codex model?** Tier 1 can skip (mark as "not tracked") or parse Codex output. Skipping is fine for v0.2.
3. **Integrate-step verbosity** — always print the report, or only when `--show-cost` is passed? Default-on is useful; default-off is quieter. I'd default on with a `--quiet` escape hatch.
4. **How do we count the orchestrator's own turns?** The `/spawn` lead (Opus) uses tokens too. Tier 1 could attribute them as a separate "orchestrator" bucket, or ignore them. I'd attribute — the orchestrator is often 30-50% of total cost on small runs.

---

## Out of scope forever

- **Billing integration** — agent-teams doesn't hold credentials and shouldn't.
- **Per-user tracking across teammates** — beads is already the source of truth for "who ran what"; cost is just a join.
- **Budgets / kill-switches** — interesting, but scope for a separate "cost guardrails" feature, not this doc.

---

## Next step

If we do Tier 1 in v0.2, open a tracking issue that scopes it to:
- Parse `<usage>` from Agent results in orchestrator
- Group by model alias
- Print summary at integrate time
- Document pricing table in `docs/pricing.md`
- Target: integrate-time output under 10 lines, no new agents, no new formulas
