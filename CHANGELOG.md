# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-18

First public-release polish pass on `sransom/agent-teams`. Establishes the
parallel, worktree-isolated team workflow on top of Claude Code subagents and
the beads issue tracker.

### Added

- Initial agent-teams scaffold — 5 agents, 5 formulas, 2 commands.
- Examples directory: local-models formula, custom agent, and a reviewer registry.
- Stack profiles — make agent-teams stack-agnostic. Ships `nextjs-ts`, `node-ts`,
  `deno`, `go`, `rust`, `python`, `swift-ios`, and `generic` profiles. `/spawn`
  auto-detects the repo's stack from marker files.
- Plan-first team — adds the `plan-checker` agent and checkbox/progress-log
  tracking for multi-milestone work.
- Plan discovery + template-aware scaffolding in the `/spawn` wizard.
- ASCII banner + team DAG at the top of the README.
- `--local` flag on `install.sh` for repo-scoped install (writes to `./.claude/`
  and `./.beads/formulas/`, with a version stamp at `.claude/agent-teams.version`).
- Beads issue tracking initialized in the repo (`bd init`).

### Changed

- Renamed `mol-plan-first-team` to `mol-plan-driven-team`.
- Renamed shipped formulas to `mol-*.formula.json` so `bd mol bond` can resolve
  them.
- Install formulas to `~/.beads/formulas/` (beads' actual search path) instead
  of `~/.claude/formulas/`.
- Clarified that the explorer is read-only — the orchestrator executes bond
  commands. Documented the `bd ready` gotcha for bonded arms.

### Fixed

- Wire `waits_for: all-children` as real `bd` deps after bonding.
- `mol-plan-first-team`: drop `judge.needs=[explore]` (conflicted with
  `waits_for: all-children`).
- Six friction points from the first live orchestration run captured from the
  transcript.
- Three additional friction points from a follow-up live run.

### Docs

- README, install scripts, and four supplementary doc pages (`architecture.md`,
  `model-routing.md`, `writing-formulas.md`, `writing-agents.md`).
- Findings from the live Next.js test run.
- Findings from the final-phase E2E test (test-writer install, codex model
  fallback).

[Unreleased]: https://github.com/sransom/agent-teams/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sransom/agent-teams/releases/tag/v0.1.0
