# Profile: python

Python. Detected by `pyproject.toml`, `setup.py`, or `requirements.txt` at repo root.

## Commands

```bash
LINT="ruff check ."          # modern default; fall back to "flake8 ." if no ruff config
TEST="pytest"
BUILD=""                     # most Python projects don't build; if wheels/sdist are needed, check pyproject.toml
TYPECHECK="mypy ."           # optional; only if mypy is configured
```

Detection order for lint:
1. `ruff.toml` or `[tool.ruff]` in `pyproject.toml` → `ruff check .`
2. `.flake8` or `setup.cfg` with `[flake8]` → `flake8 .`
3. Fallback: `ruff check .` (install on demand if missing)

## Test conventions

- pytest finds `test_*.py` or `*_test.py` in `tests/` or alongside source
- Run specific file: `pytest path/to/test_thing.py`
- Run specific test: `pytest path/to/test_thing.py::test_name`

## File conventions

- Source: `*.py`, usually under `src/{package}/` or top-level `{package}/`
- Virtualenv: `.venv/` (usually gitignored)
- Lock file: `poetry.lock`, `pdm.lock`, `uv.lock`, or `requirements.txt`

## Commit conventions

- If `.pre-commit-config.yaml` present: `SKIP=all git commit` bypasses hooks (pre-commit framework is the Python ecosystem standard)
- No husky unless the repo is polyglot
