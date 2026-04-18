# Profile: go

Go module. Detected by `go.mod` at repo root.

## Commands

```bash
LINT="go vet ./..."          # or golangci-lint run if .golangci.yml present
TEST="go test ./..."
BUILD="go build ./..."
TYPECHECK=""                 # Go compiles and type-checks as one step; build covers it
```

If `.golangci.yml` or `.golangci.yaml` exists, prefer `golangci-lint run` over `go vet`.

## Test conventions

- Test files: `*_test.go` colocated with source (Go convention)
- Run specific package: `go test ./path/to/package`
- Run specific test: `go test -run TestName ./path/to/package`

## File conventions

- Source: `*.go`, typically organized into packages under subdirectories
- `internal/` directory is a compiler-enforced visibility boundary
- `cmd/{binary}/main.go` for executables

## Commit conventions

- No husky. `git commit -m "..."` directly.
- If `pre-commit` framework is set up (`.pre-commit-config.yaml`), `SKIP=all git commit` bypasses.
