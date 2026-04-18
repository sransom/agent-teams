#!/usr/bin/env bash
# agent-teams uninstaller
# Removes the files installed by install.sh. Preserves user-modified files
# unless explicitly confirmed.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
BEADS_DIR="${BEADS_DIR:-$HOME/.beads}"

RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
RESET=$'\033[0m'

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
err()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; }
head() { printf '\n%s==%s %s\n' "$BLUE" "$RESET" "$*"; }

ask_yn() {
  local prompt="$1" default="${2:-n}" answer
  local hint="[y/N]"
  [ "$default" = "y" ] && hint="[Y/n]"
  printf '%s %s ' "$prompt" "$hint"
  read -r answer || answer=""
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

remove_if_shipped() {
  local src_name="$1" kind="$2" dst_override="${3:-}"
  local src="$REPO_DIR/$src_name"
  local dst="${dst_override:-$CLAUDE_DIR/$src_name}"

  [ -d "$dst" ] || return 0

  local removed=0 kept=0
  local f name target
  for f in "$src"/*; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    target="$dst/$name"

    [ -e "$target" ] || continue

    if cmp -s "$f" "$target"; then
      rm "$target"
      removed=$((removed + 1))
    else
      if ask_yn "  $target has been modified. Delete anyway?" n; then
        rm "$target"
        removed=$((removed + 1))
      else
        kept=$((kept + 1))
      fi
    fi
  done

  say "   $kind: ${GREEN}$removed removed${RESET}, ${YELLOW}$kept kept (modified)${RESET}"
  rmdir "$dst" 2>/dev/null && ok "Removed empty dir $dst" || true
}

head "Removing shipped files"

remove_if_shipped agents "Agents"
remove_if_shipped formulas "Formulas" "$BEADS_DIR/formulas"
remove_if_shipped commands "Commands"
remove_if_shipped profiles "Profiles" "$CLAUDE_DIR/agent-teams-profiles"

head "CLAUDE.md cleanup"

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
START_MARK="<!-- agent-teams:start -->"
END_MARK="<!-- agent-teams:end -->"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

if [ -f "$CLAUDE_MD" ] && grep -q "$START_MARK" "$CLAUDE_MD"; then
  if ask_yn "Remove agent-teams block from $CLAUDE_MD?" y; then
    cp "$CLAUDE_MD" "$CLAUDE_MD.bak.$TIMESTAMP"
    awk -v start="$START_MARK" -v end="$END_MARK" '
      $0 ~ start { skipping = 1; next }
      $0 ~ end && skipping { skipping = 0; next }
      !skipping { print }
    ' "$CLAUDE_MD.bak.$TIMESTAMP" > "$CLAUDE_MD"
    ok "Removed agent-teams block (backup: $CLAUDE_MD.bak.$TIMESTAMP)"
  else
    warn "Left CLAUDE.md untouched"
  fi
else
  ok "No agent-teams block found in CLAUDE.md"
fi

head "Uninstall complete"
say ""
say "Backups (if any) are in $CLAUDE_DIR/**.bak.*"
say "Remove them manually when you're confident."
