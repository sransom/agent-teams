# Profile: deno

Deno runtime. Detected by `deno.json` or `deno.jsonc` at repo root.

## Commands

```bash
LINT="deno lint"
TEST="deno test --no-lock"
BUILD=""                     # Deno typically doesn't build; if bundling is needed, check deno.json tasks
TYPECHECK="deno check **/*.ts"
```

Prefer Deno tasks if defined: `deno task lint`, `deno task test`.

## Test runner

Built into Deno. Test files: `*_test.ts` colocated with source. Run single file: `deno test --no-lock path/to/file_test.ts`.

## File conventions

- Source: `*.ts` (often flat or under `src/`)
- Tests: `*_test.ts` colocated (Deno convention — not `.test.ts`)
- Import specifiers: URLs or JSR (`jsr:@std/testing`) — don't assume npm
- No `node_modules/`; don't run `npm install` on a Deno repo

## Commit conventions

- No husky; hooks vary. Check for `.githooks/` or `.lefthook.yml`.
- Default to `git commit -m "..."` without special env vars unless hooks clearly need bypassing.
