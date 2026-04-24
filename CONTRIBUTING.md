# Contributing to agent-teams

Thanks for taking the time to contribute. This is a small project — most PRs
will be focused additions (a new stack profile, a new formula, a new agent) or
small bug fixes. This page covers the four most common contribution paths and
the conventions to follow before opening a PR.

---

## Add a new stack profile

Profiles live in `profiles/{name}.md`. They tell agents how to lint, test,
build, and commit for a given stack.

1. Copy the closest existing profile as a starting point:
   ```bash
   cp profiles/node-ts.md profiles/elixir.md
   ```
2. Update the detection markers (the first paragraph). Pick a file that uniquely
   identifies the stack (`mix.exs` for Elixir, `pyproject.toml` for Python, etc.).
3. Fill in the `Commands` block: `LINT`, `LINT_CHANGED_FILES`, `TEST`, `BUILD`,
   `TYPECHECK` if applicable. Keep them as bash variables — the orchestrator
   reads them as plain strings, not executes them.
4. Add a `Common gotchas` section. This is where the value is — the
   stack-specific traps an agent will hit on its first run.
5. Wire detection into `/spawn`. Edit `commands/spawn.md`'s `Step 0.5 — Detect
   the repo's stack profile` and add a new bullet for your marker file.
6. Add the profile name to the README's "Shipped profiles" list and the
   `install.sh` profile-count comment if it lives there.

Test by running `/spawn --profile {name}` against a scratch repo of that stack
and confirming the injected lint command runs.

---

## Add a new formula

Formulas are JSON files in `formulas/` that describe a team's DAG.

1. Read [`docs/writing-formulas.md`](docs/writing-formulas.md) for the schema.
2. Filename MUST start with `mol-` (e.g. `mol-quickfix-team.formula.json`). The
   `formula` field inside the JSON must match the filename minus the extension.
   `bd mol bond` only resolves formulas with this prefix.
3. Validate JSON before committing:
   ```bash
   python3 -c "import json; json.load(open('formulas/mol-quickfix-team.formula.json'))"
   ```
4. Pour-test in a scratch directory:
   ```bash
   mkdir /tmp/mol-pour-test && cd /tmp/mol-pour-test
   bd init
   bd mol pour ~/projects/agent-teams/formulas/mol-quickfix-team.formula.json \
     --var team=test --var feature="dummy" --var repo=test --var base_branch=main
   bd list
   ```
   The pour should produce one issue per step with the right deps. If `bd
   ready` returns a step you didn't expect, your `needs` / `waits_for` graph is
   wrong.
5. Watch for the `needs + waits_for: all-children` trap — a step that has both
   a non-empty `needs` array AND `waits_for: "all-children"` will deadlock.
   Pick one.

---

## Add a new agent

Agents are `.md` files in `agents/` with YAML frontmatter and a prompt body.

1. Read [`docs/writing-agents.md`](docs/writing-agents.md) for the full schema.
2. Required frontmatter fields: `name`, `model`, `description`, `tools`.
3. Pick the minimum `tools:` list. Read-only agents get `Read, Glob, Grep`.
   Agents that run shell commands add `Bash`. Agents that edit files add
   `Write, Edit`.
4. If the agent participates in formulas, add a `## Team-spawn use` section to
   the body. This is what the orchestrator's spawn prompt is appended to.
   Document what inputs the orchestrator provides (e.g. `ROOT_EPIC_ID`,
   `TEAM`, `STACK_PROFILE`) and what output format is expected.
5. Reference the agent in any formula that uses it via the `agent:{name}` label
   on a step.

---

## Test changes before PR

Before opening a PR, exercise the parts you touched:

- **Dry-run install.** `./install.sh --dry-run` shows what would be copied
  without writing anything. Run it for both global and `--local` modes if your
  change affects the installer.
- **Live E2E against a scratch repo.** For changes to formulas, agents, or
  `/spawn`, run the actual flow against a throwaway repo:
  ```bash
  cd /tmp && git init scratch-test && cd scratch-test
  ~/projects/agent-teams/install.sh --local
  # Then in Claude Code:
  /spawn --formula mol-lite-team
  ```
- **Run CI locally if possible.** If you have [`act`](https://github.com/nektos/act)
  installed, run `act push` to execute the validate workflow against your
  branch. Otherwise CI will tell you on the PR.
- **Lint markdown.** `npx markdownlint <changed-files>` if you have it. Visual
  skim is fine for small changes.

---

## Commit and PR conventions

- **Conventional Commits.** Format: `type(scope): summary`. Types: `feat`,
  `fix`, `docs`, `chore`, `refactor`, `test`. Scope is optional but encouraged
  (`feat(spawn)`, `fix(install)`, `docs(readme)`).
- **One concern per PR.** Don't bundle a new profile with a formula refactor
  and a typo fix. Reviewers can land focused changes faster.
- **Target `main`.** No long-lived feature branches — work in a topic branch,
  open a PR, merge.
- **Update the CHANGELOG.** Add a bullet under `[Unreleased]` in the
  appropriate section (Added / Changed / Fixed / Docs). The release commit will
  promote `[Unreleased]` to a versioned section.
- **Do not push tags.** Releases are cut by the maintainer.

---

## Project layout reference

```
agents/                  # Subagent .md files (frontmatter + prompt)
commands/                # /spawn and /build-team slash commands
docs/                    # Long-form documentation
examples/                # Example custom agents/formulas
formulas/                # mol-*.formula.json team definitions
profiles/                # Stack profile prompt fragments
install.sh, uninstall.sh # Setup scripts
```

When in doubt, read the existing file closest to what you're adding and follow
its structure.
