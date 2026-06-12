#!/bin/bash
# accumulate-simplify.sh — PostToolUse(Write|Edit) hook
# Silently accumulates modified file paths for the Stop hook simplifier.
# Produces NO output. Designed to be invisible to the main workflow.
set -euo pipefail

INPUT=$(cat)

# Extract fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)

# Guard: must be Write or Edit with a file path
case "$TOOL_NAME" in
  Write|Edit) ;;
  *) exit 0 ;;
esac
[ -z "$FILE_PATH" ] && exit 0

# Guard: skip non-code files by extension
FILE_EXT="${FILE_PATH##*.}"
case "$FILE_EXT" in
  md|txt|json|yaml|yml|toml|lock|sum|mod|gitignore|env|csv|png|jpg|gif|svg|ico|woff|woff2|ttf|eot) exit 0 ;;
esac

# Guard: skip test files, generated files, vendor directories
case "$FILE_PATH" in
  *test*|*spec*|*.test.*|*.spec.*|*__tests__*) exit 0 ;;
  *vendor/*|*node_modules/*|*dist/*|*build/*|*.min.*) exit 0 ;;
esac

# Estimate change size (line count of content/new_string)
if [ "$TOOL_NAME" = "Write" ]; then
  CHANGE_SIZE=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null | wc -l | tr -d ' ')
else
  CHANGE_SIZE=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null | wc -l | tr -d ' ')
fi

# Accumulate: file_path<TAB>change_lines<TAB>extension
ACCUM_FILE="${TMPDIR:-/tmp}/cc-simplify-files-${SESSION_ID}"

# Dedup: skip if this exact path is already the last entry
LAST_PATH=""
if [ -f "$ACCUM_FILE" ]; then
  LAST_PATH=$(tail -1 "$ACCUM_FILE" | cut -f1)
fi
if [ "$FILE_PATH" != "$LAST_PATH" ]; then
  printf '%s\t%s\t%s\n' "$FILE_PATH" "$CHANGE_SIZE" "$FILE_EXT" >> "$ACCUM_FILE"
fi

exit 0
