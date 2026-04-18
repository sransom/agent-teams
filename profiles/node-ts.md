# Profile: node-ts

Node.js + TypeScript (not Next). Detected by `package.json` WITHOUT `"next"` as a dependency. Covers Express, Fastify, Hono, tRPC, plain Node CLIs, library packages.

## Commands

```bash
LINT="npm run lint"           # fallback: npx eslint .
LINT_CHANGED_FILES="npx eslint --no-error-on-unmatched-pattern"  # pass files as args
TEST="npm test"
BUILD="npm run build"         # if a build script exists
TYPECHECK="npx tsc --noEmit"
```

Detect the package manager from lockfiles: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, otherwise npm.

**Lint scope**: at integration time, prefer scoping eslint to changed files (`LINT_CHANGED_FILES`) instead of the whole repo. Repo-wide lint often hits vendor/generated paths not excluded by `.eslintignore` and produces noise that masks real findings. Pipe `git diff --name-only {base}...integration/{team}` into xargs.

## Test runner detection

- `vitest.config.*` → Vitest
- `jest.config.*` → Jest
- `.mocharc.*` → Mocha
- None → install Vitest as the default

## File conventions

- Source: `src/**/*.ts`
- Tests: `*.test.ts` colocated OR `test/**/*.test.ts` / `tests/**/*.test.ts`
- Build output: `dist/` or `build/` (usually gitignored)

## Commit conventions

- `HUSKY=0 git commit -m "..."` to skip husky hooks
- Some repos use lefthook — set `LEFTHOOK=0` if `.lefthook.yml` exists
