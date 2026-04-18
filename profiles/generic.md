# Profile: generic

Fallback used when no other profile matches or when the orchestrator can't determine the stack. Also the explicit choice for polyglot monorepos or unusual setups.

## Commands

No hardcoded commands. The orchestrator (and the explorer during decomposition) should:

1. Read the repo root for clues: `README.md`, `Makefile`, `justfile`, `Taskfile.yml`, `.github/workflows/`
2. If a `Makefile` or `justfile` exists, prefer its targets (`make lint`, `just test`)
3. If CI workflows exist, extract the commands they run as a hint
4. Ask the user if the plan file doesn't specify

## Fallback rules

- LINT: try `make lint` → `just lint` → pass `""` (no lint step, document in arm notes)
- TEST: try `make test` → `just test` → pass `""`
- BUILD: try `make build` → `just build` → pass `""`

## File conventions

- Source locations and test conventions vary by project. The explorer is responsible for figuring out what's typical and communicating it to implementer arms via the `files` and `patterns` fields.

## Commit conventions

- Default to `git commit -m "..."` with no special env vars
- If `.pre-commit-config.yaml` is present, try `SKIP=all git commit` to bypass
- If `.husky/` directory is present, try `HUSKY=0`
- If `.lefthook.yml` is present, try `LEFTHOOK=0`
