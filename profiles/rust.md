# Profile: rust

Rust + Cargo. Detected by `Cargo.toml` at repo root.

## Commands

```bash
LINT="cargo clippy --all-targets --all-features -- -D warnings"
TEST="cargo test"
BUILD="cargo build"
TYPECHECK="cargo check"
```

For large repos, scope to the changed crate: `cargo test -p {crate-name}`.

## Test conventions

- Unit tests: `#[cfg(test)] mod tests { ... }` inside source files
- Integration tests: `tests/*.rs` at crate root
- Doc tests: triple-slash examples in public API docs

## File conventions

- Source: `src/*.rs`, `src/**/*.rs`
- Crate root: `src/lib.rs` or `src/main.rs`
- Workspaces: multiple `Cargo.toml` files under one root with a top-level `[workspace]`

## Commit conventions

- No husky. `git commit -m "..."` directly.
- If `.pre-commit-config.yaml` present, `SKIP=all git commit` bypasses.
- Format before committing: `cargo fmt`.
