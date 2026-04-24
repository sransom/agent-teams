#!/usr/bin/env bash
# agent-teams installer
# Copies agents, formulas, and commands with interactive confirmation.
# Idempotent: re-running won't clobber your changes without asking.
#
# Two modes:
#   (default) Global install to ~/.claude/ and ~/.beads/ — available everywhere.
#   --local   Repo-scoped install to ./.claude/ and ./.beads/ — committed with
#             the repo so every team member (and CI) gets the same flow.
#             Repo-local formulas override global by name.

set -euo pipefail

# ---------- setup ----------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse mode flag
SCOPE="global"
for arg in "$@"; do
  case "$arg" in
    --local) SCOPE="local" ;;
    --global) SCOPE="global" ;;
    -h|--help)
      cat <<EOF
Usage: ./install.sh [--local|--global]

  (default)  Install globally to ~/.claude/ and ~/.beads/formulas/
  --local    Install into the current directory's .claude/ and .beads/formulas/
             (run from the repo root where you want agent-teams scoped)
EOF
      exit 0
      ;;
  esac
done

if [ "$SCOPE" = "local" ]; then
  # Must run from a project directory — verify we're somewhere sensible
  if [ "$(pwd)" = "$HOME" ]; then
    printf '%s\n' "✗ --local in \$HOME would pollute your home dir. cd to a project first." >&2
    exit 1
  fi
  CLAUDE_DIR="${CLAUDE_DIR:-$(pwd)/.claude}"
  BEADS_DIR="${BEADS_DIR:-$(pwd)/.beads}"
else
  CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
  BEADS_DIR="${BEADS_DIR:-$HOME/.beads}"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
DIM=$'\033[2m'
RESET=$'\033[0m'

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
err()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; }
head() { printf '\n%s==%s %s\n' "$BLUE" "$RESET" "$*"; }

ask_yn() {
  local prompt="$1" default="${2:-y}" answer
  local hint="[Y/n]"
  [ "$default" = "n" ] && hint="[y/N]"
  printf '%s %s ' "$prompt" "$hint"
  read -r answer || answer=""
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------- prereqs ----------

head "Checking prerequisites"

if ! command -v claude >/dev/null 2>&1; then
  err "Claude Code CLI (\`claude\`) not found on PATH."
  say "   Install from: https://docs.claude.com/en/docs/claude-code"
  exit 1
fi
ok "Claude Code CLI found: $(command -v claude)"

if ! command -v bd >/dev/null 2>&1; then
  warn "beads CLI (\`bd\`) not found."
  say "   agent-teams requires the beads plugin for Claude Code."
  say "   Install with: claude plugin install beads"
  if ! ask_yn "   Continue anyway?" n; then
    exit 1
  fi
else
  ok "beads CLI found: $(bd --version 2>/dev/null | head -1)"
fi

if ! command -v codex >/dev/null 2>&1; then
  warn "Codex CLI (\`codex\`) not found."
  say "   Optional — implementer falls back to Claude if unavailable."
  say "   For ~3x cost savings on implementation, install Codex and set"
  say "   \`implementer_model=gpt-4o-mini\` when running /spawn."
else
  ok "Codex CLI found: $(command -v codex)"
fi

if [ ! -d "$CLAUDE_DIR" ]; then
  warn "$CLAUDE_DIR does not exist."
  if ask_yn "   Create it?" y; then
    mkdir -p "$CLAUDE_DIR"
    ok "Created $CLAUDE_DIR"
  else
    err "Cannot install without $CLAUDE_DIR."
    exit 1
  fi
else
  ok "$CLAUDE_DIR exists"
fi

# ---------- copy files ----------

copy_dir() {
  local src_name="$1" kind="$2" dst_override="${3:-}"
  local src="$REPO_DIR/$src_name"
  local dst="${dst_override:-$CLAUDE_DIR/$src_name}"

  mkdir -p "$dst"

  local count=0 skipped=0 backed_up=0
  local f name target
  for f in "$src"/*; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    target="$dst/$name"

    if [ -e "$target" ]; then
      if cmp -s "$f" "$target"; then
        skipped=$((skipped + 1))
        continue
      fi
      cp "$target" "$target.bak.$TIMESTAMP"
      backed_up=$((backed_up + 1))
    fi

    cp "$f" "$target"
    count=$((count + 1))
  done

  say "   $kind: ${GREEN}$count installed${RESET}, ${DIM}$skipped unchanged${RESET}, ${YELLOW}$backed_up backed up${RESET}"
}

head "Installing files"

if ask_yn "Install 5 agents into $CLAUDE_DIR/agents/?" y; then
  copy_dir agents "Agents"
else
  warn "Skipped agents"
fi

if ask_yn "Install 5 formulas into $BEADS_DIR/formulas/?" y; then
  copy_dir formulas "Formulas" "$BEADS_DIR/formulas"
else
  warn "Skipped formulas"
fi

if ask_yn "Install 2 commands (/build-team, /spawn) into $CLAUDE_DIR/commands/?" y; then
  copy_dir commands "Commands"
else
  warn "Skipped commands"
fi

if ask_yn "Install stack profiles into $CLAUDE_DIR/agent-teams-profiles/?" y; then
  copy_dir profiles "Profiles" "$CLAUDE_DIR/agent-teams-profiles"
else
  warn "Skipped profiles"
fi

# ---------- version stamp (local mode only) ----------

if [ "$SCOPE" = "local" ]; then
  VERSION_FILE="$CLAUDE_DIR/agent-teams.version"
  INSTALLED_SHA="$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
  cat > "$VERSION_FILE" <<EOF
# agent-teams local install
installed: $(date -u +%Y-%m-%dT%H:%M:%SZ)
commit:    $INSTALLED_SHA
source:    $REPO_DIR
EOF
  ok "Wrote version stamp to $VERSION_FILE"
fi

# ---------- CLAUDE.md routing block (global only) ----------

if [ "$SCOPE" = "local" ]; then
  head "Skipping CLAUDE.md update (local install)"
  say "   Local installs don't modify ~/.claude/CLAUDE.md — it's a global file."
  say "   Add a short note about agent-teams to your repo's CLAUDE.md if you want."
else

head "CLAUDE.md model routing guidance"

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
START_MARK="<!-- agent-teams:start -->"
END_MARK="<!-- agent-teams:end -->"

ROUTING_BLOCK=$(cat <<'ROUTING'
<!-- agent-teams:start -->
## Agent Teams — model routing

This block is managed by agent-teams (https://github.com/sransom/agent-teams).
Re-running the installer will update it; delete this block to remove.

Default model assignments by role:

| Role          | Model       | Notes                                    |
|---------------|-------------|------------------------------------------|
| Orchestrator  | opus        | The lead running /spawn                  |
| Explorer      | haiku       | Read-only, fast                          |
| Implementer   | sonnet      | Set `implementer_model=gpt-4o-mini` for  |
|               |             | ~3x savings via Codex CLI                |
| Judge         | sonnet      | Pass/fail gate — needs judgment          |
| Test-writer   | haiku       | Deterministic, no reasoning              |
| Code-reviewer | sonnet      | Report-only; no file mods                |

Family aliases (`sonnet`, `haiku`, `opus`) track the latest Claude Code defaults.
Pin a specific snapshot (e.g. `claude-sonnet-4-6`) for reproducibility.
<!-- agent-teams:end -->
ROUTING
)

if ask_yn "Append a model routing block to $CLAUDE_MD?" y; then
  if [ -f "$CLAUDE_MD" ] && grep -q "$START_MARK" "$CLAUDE_MD"; then
    # Replace existing block
    cp "$CLAUDE_MD" "$CLAUDE_MD.bak.$TIMESTAMP"
    awk -v start="$START_MARK" -v end="$END_MARK" -v block="$ROUTING_BLOCK" '
      $0 ~ start { printing = 1; print block; next }
      $0 ~ end && printing { printing = 0; next }
      !printing { print }
    ' "$CLAUDE_MD.bak.$TIMESTAMP" > "$CLAUDE_MD"
    ok "Updated existing agent-teams block in $CLAUDE_MD (backup: $CLAUDE_MD.bak.$TIMESTAMP)"
  else
    if [ -f "$CLAUDE_MD" ]; then
      printf '\n\n%s\n' "$ROUTING_BLOCK" >> "$CLAUDE_MD"
    else
      printf '%s\n' "$ROUTING_BLOCK" > "$CLAUDE_MD"
    fi
    ok "Appended agent-teams block to $CLAUDE_MD"
  fi
else
  warn "Skipped CLAUDE.md update"
fi

fi  # end of SCOPE != local guard around CLAUDE.md block

# ---------- done ----------

head "Quick start"
cat <<EOF

  ${YELLOW}!${RESET} ${YELLOW}Restart Claude Code before running /spawn or /build-team.${RESET}
    Claude Code snapshots agents and commands at session start — newly
    installed ones aren't visible until the next session. Close your
    current session and start a new one.

  /build-team          — interactive wizard to create a new formula
  /spawn               — pick an existing formula and run it
  /spawn --list        — see available formulas
  /spawn --dry-run     — pour + show DAG without dispatching agents

Formulas shipped:
  mol-full-team        Ship a feature end-to-end
  mol-lite-team        Same, minus test-writer
  mol-plan-driven-team full-team with plan-checker + checkbox tracking
  mol-code-review      Parallel specialist review of a PR
  mol-implement-arm    (child, bonded by the explorer)
  mol-review-arm       (child, bonded by triage)

Docs: $REPO_DIR/docs/
EOF

if [ "$SCOPE" = "local" ]; then
cat <<EOF

${BLUE}Local install notes${RESET}
  Installed into:  $CLAUDE_DIR/  and  $BEADS_DIR/formulas/
  Version stamp:   $CLAUDE_DIR/agent-teams.version

  Commit these dirs so teammates + CI get the same flow:
    git add .claude/ .beads/formulas/
    git commit -m "chore: install agent-teams locally"

  Repo-local formulas override global by name (verified against bd 1.0.2).
  Files-unchanged formulas fall through to your global ~/.beads/formulas/.

${GREEN}Local installation complete.${RESET}
EOF
else
cat <<EOF

${GREEN}Global installation complete.${RESET}
EOF
fi
