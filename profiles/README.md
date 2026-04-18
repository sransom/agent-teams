# Profiles

Stack-specific conventions that agent-teams uses to make its generic orchestration fit real codebases. Each profile is a short markdown file answering the same questions: how to detect the stack, what the lint/test/build commands are, what the skip-hooks flag is, where source files live.

`/spawn` detects the stack automatically at runtime (by scanning for marker files like `package.json`, `Cargo.toml`, `go.mod`) and injects the matching profile into agent spawn prompts. Agents read lint/test commands from the profile instead of hardcoding `npm run lint`.

If detection fails or comes up ambiguous, agents fall back to the `generic` profile and the explorer sets sensible defaults per arm after inspecting the repo.

## Shipped profiles

| Profile     | Detects                         | Lint                 | Test              |
|-------------|---------------------------------|----------------------|-------------------|
| nextjs-ts   | `package.json` + `next` dep     | `npm run lint`       | `vitest` / `jest` |
| node-ts     | `package.json` (non-Next)       | `npm run lint`       | `vitest` / `jest` |
| deno        | `deno.json` / `deno.jsonc`      | `deno lint`          | `deno test`       |
| go          | `go.mod`                        | `go vet ./...`       | `go test ./...`   |
| rust        | `Cargo.toml`                    | `cargo clippy`       | `cargo test`      |
| python      | `pyproject.toml` / `setup.py`   | `ruff check`         | `pytest`          |
| swift-ios   | `*.xcodeproj` / `Package.swift` | `swiftlint`          | `xcodebuild test` |
| generic     | (fallback)                      | _read from repo_     | _read from repo_  |

## Writing your own profile

Drop a new `.md` file into this directory following the format used by the shipped profiles. Install with `./install.sh` or copy manually to `~/.claude/agent-teams-profiles/`. Force its use with `/spawn --profile my-profile`.

A profile is a prompt fragment. Agents (explorer, implementer, judge, test-writer) receive its content appended to their spawn prompt at dispatch time — the orchestrator handles injection. Keep profiles focused on commands and conventions, not architecture advice.
