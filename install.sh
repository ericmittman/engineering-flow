#!/usr/bin/env bash
# engineering-flow installer — installs superpowers + this plugin via the Claude Code
# plugin system. Never edits your settings.json; uninstall = `claude plugin` remove.
set -euo pipefail

MARKETPLACE="ericmittman/engineering-flow"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

say()  { printf '\033[1m%s\033[0m\n' "$*"; }
run()  { if [ "$DRY_RUN" = 1 ]; then echo "DRY-RUN: $*"; else "$@"; fi; }

# ── preflight ──
if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found. Install Claude Code first: https://claude.com/claude-code" >&2
  exit 1
fi
CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
say "Found Claude Code ${CLAUDE_VERSION:-unknown}"

manual_fallback() {
  cat <<'EOF'

Your claude CLI doesn't support non-interactive plugin commands.
Run these two commands inside any Claude Code session instead:

  /plugin marketplace add ericmittman/engineering-flow
  /plugin install engineering-flow@engineering-flow

And for the superpowers dependency:

  /plugin install superpowers@claude-plugins-official

EOF
  exit 0
}

# ── superpowers (upstream dependency) ──
say "Installing superpowers from the official marketplace…"
run claude plugin install superpowers@claude-plugins-official || manual_fallback

# ── this kit ──
say "Adding the engineering-flow marketplace…"
run claude plugin marketplace add "$MARKETPLACE" || manual_fallback
say "Installing engineering-flow…"
run claude plugin install engineering-flow@engineering-flow || manual_fallback

# ── verify ──
if [ "$DRY_RUN" = 0 ]; then
  say "Verifying…"
  claude plugin list 2>/dev/null | grep -qi superpowers      || { echo "WARN: superpowers not listed"; }
  claude plugin list 2>/dev/null | grep -qi engineering-flow || { echo "ERROR: engineering-flow not listed" >&2; exit 1; }
fi

say "Done. Quickstart:"
cat <<'EOF'
  1. Open any repo in Claude Code.
  2. Type:  /feature add a healthcheck endpoint
  3. Watch the pipeline announce each stage (brainstorming first).
  Add personal skill-router routes in ~/.claude/skill-routes.local.conf
  (format: pattern | skill | path | description).
EOF
