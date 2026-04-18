# Profile: nextjs-ts

Next.js (any version) + TypeScript. Detected by `package.json` containing `"next"` in `dependencies` or `devDependencies`.

## Commands

```bash
LINT="npm run lint"          # fallback: pnpm lint, yarn lint
LINT_CHANGED_FILES="npx eslint --no-error-on-unmatched-pattern"   # pass files as args
TEST="npm test"              # if package.json has a "test" script
BUILD="npm run build"
TYPECHECK="npx tsc --noEmit" # optional sanity check
```

Detect the package manager from lockfiles: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, otherwise npm.

**Lint scope**: at integration time, prefer `LINT_CHANGED_FILES` applied to only the files the team changed. Next.js projects commonly have `node_modules/next/dist/docs/**` TypeScript files that aren't in the project's `.eslintignore` and generate hundreds of phantom errors when you run the default `npm run lint` on the whole repo. Scope to changed files:

```bash
git diff --name-only {base}...integration/{team} | \
  grep -E '\.(ts|tsx|js|jsx|mjs)$' | \
  xargs -r npx eslint --no-error-on-unmatched-pattern
```

## Test runner detection

- `vitest.config.*` present → Vitest (`npx vitest run <files>`)
- `jest.config.*` present → Jest (`npx jest <files>`)
- Neither → no test runner installed yet; test-writer should install Vitest and add a `test` script.

## File conventions

- Source: `src/**/*.ts`, `src/**/*.tsx`
- App Router pages: `src/app/**/page.tsx`, `src/app/**/layout.tsx`, `src/app/api/**/route.ts`
- Tests colocated: `*.test.ts` or `*.spec.ts` next to source
- `@/` path alias typically maps to `src/`

## Commit conventions

- Skip hooks with `HUSKY=0 git commit -m "..."` (husky is the common pre-commit manager for this stack)

## Common gotchas

- App Router server components can't import client-only APIs (browser globals, `useState`, etc.). Client components need `"use client"` on the first line.
- `NextResponse` comes from `next/server`, not `next`.
- Server component `fetch` to the app's own API works in production but is fragile in local dev (relative URLs need a base); importing store helpers directly is often simpler for in-memory data.
