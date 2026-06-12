#!/bin/bash
# skill-router.sh — PreToolUse(Bash) hook
# Suggests relevant skills when commands match known patterns.
# Reads stdin JSON: {"tool_name":"Bash","tool_input":{"command":"..."}}
set -euo pipefail

# Plugin-relative routes + optional user extension (add your own without forking).
HOOK_DIR="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/hooks}"
HOOK_DIR="${HOOK_DIR:-$(cd "$(dirname "$0")" && pwd)}"
ROUTES_FILE="${HOOK_DIR}/skill-routes.conf"
LOCAL_ROUTES="${HOME}/.claude/skill-routes.local.conf"
DEDUP_TTL=600  # 10 minutes

# Read command from stdin JSON
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Extract first line of command (multi-line commands: just check the first)
FIRST_LINE=$(echo "$COMMAND" | head -1)

# Check routes file exists
[ ! -f "$ROUTES_FILE" ] && exit 0

# Parse routes using ' | ' (space-pipe-space) as field separator.
# This avoids conflicts with '|' inside regex patterns (which use | without symmetric spacing).
# Pre-parse into tab-separated temp for efficient iteration.
ROUTE_SOURCES=("$ROUTES_FILE")
[ -f "$LOCAL_ROUTES" ] && ROUTE_SOURCES+=("$LOCAL_ROUTES")
PARSED=$(cat "${ROUTE_SOURCES[@]}" | grep -v '^#' | grep -v '^$' | awk -F ' \\| ' '{OFS="\t"; print $1, $2, $3, $4}')
[ -z "$PARSED" ] && exit 0

# Build combined pattern from all routes (fast path — single grep)
COMBINED_PATTERN=$(echo "$PARSED" | cut -f1 | paste -s -d '|' -)
[ -z "$COMBINED_PATTERN" ] && exit 0

# Fast exit if no pattern matches at all
if ! echo "$FIRST_LINE" | grep -qEi "$COMBINED_PATTERN" 2>/dev/null; then
    exit 0
fi

# Slow path: find which specific route matched
while IFS=$'\t' read -r pattern skill_name skill_path description; do
    [ -z "$pattern" ] && continue

    # Check if this route's pattern matches
    if echo "$FIRST_LINE" | grep -qEi "$pattern" 2>/dev/null; then
        # Dedup: skip if we suggested this skill recently
        DEDUP_FILE="/tmp/skill-router-${PPID}-${skill_name}"
        if [ -f "$DEDUP_FILE" ]; then
            FILE_AGE=$(( $(date +%s) - $(date -r "$DEDUP_FILE" +%s 2>/dev/null || echo 0) ))
            if [ "$FILE_AGE" -lt "$DEDUP_TTL" ]; then
                exit 0
            fi
        fi

        # Mark as suggested
        touch "$DEDUP_FILE"

        # Output suggestion (3 lines max)
        echo "[SKILL] $skill_name — $description"
        if [ "$skill_path" = "(plugin)" ] || [ "$skill_path" = "-" ]; then
          # Namespaced skill — decide how to resolve it
          if [[ "$skill_name" == engineering-flow:* ]]; then
            # Ships in this plugin — read from disk
            PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
            echo "  Read: ${PLUGIN_ROOT}/skills/${skill_name#*:}/SKILL.md"
          elif [[ "$skill_name" == *:* ]]; then
            # Any other namespace (e.g. superpowers:*) — invoke via Skill tool
            echo "  Invoke it with the Skill tool: $skill_name"
          else
            # Un-namespaced with no path — nothing useful to print; skip path line
            :
          fi
        else
          echo "  Read: $skill_path"
        fi
        echo "  Before proceeding, read the skill above for best practices."
        exit 0
    fi
done <<< "$PARSED"

exit 0
