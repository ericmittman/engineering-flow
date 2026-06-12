#!/bin/bash
# smart-simplify-stop.sh — Stop hook
# Evaluates accumulated file changes and suggests simplification when threshold met.
# Three-layer loop prevention: stop_hook_active + done marker + prompt instruction.
set -euo pipefail

INPUT=$(cat)

# --- Loop prevention layer 1: Stop hook reentrance guard ---
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)

ACCUM_FILE="${TMPDIR:-/tmp}/cc-simplify-files-${SESSION_ID}"
DONE_FILE="${TMPDIR:-/tmp}/cc-simplify-done-${SESSION_ID}"

# --- Loop prevention layer 2: already suggested this session ---
if [ -f "$DONE_FILE" ]; then
  exit 0
fi

# --- Guard: no accumulated files ---
if [ ! -f "$ACCUM_FILE" ]; then
  exit 0
fi

# --- Threshold evaluation ---
# Count unique code files
FILE_COUNT=$(cut -f1 "$ACCUM_FILE" | sort -u | wc -l | tr -d ' ')

# Sum total lines changed
TOTAL_LINES=$(awk -F'\t' '{sum+=$2} END {print sum+0}' "$ACCUM_FILE")

# Thresholds: 2+ unique code files OR 50+ total lines changed
if [ "$FILE_COUNT" -lt 2 ] && [ "$TOTAL_LINES" -lt 50 ]; then
  exit 0
fi

# --- Mark as suggested (before outputting, to prevent race) ---
touch "$DONE_FILE"

# --- Build file list for the message ---
FILE_LIST=$(cut -f1 "$ACCUM_FILE" | sort -u | head -10 | tr '\n' ',' | sed 's/,$//')

# --- Detect primary language from extensions ---
PRIMARY_EXT=$(cut -f3 "$ACCUM_FILE" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

case "$PRIMARY_EXT" in
  ts|tsx)     LANG="TypeScript" ;;
  js|jsx)     LANG="JavaScript" ;;
  py)         LANG="Python" ;;
  go)         LANG="Go" ;;
  rs)         LANG="Rust" ;;
  php)        LANG="PHP" ;;
  sh|bash)    LANG="Bash" ;;
  asm|s|inc)  LANG="6502 Assembly" ;;
  rb)         LANG="Ruby" ;;
  java)       LANG="Java" ;;
  c|h)        LANG="C" ;;
  *)          LANG="mixed" ;;
esac

# --- Check if project CLAUDE.md exists ---
HAS_CLAUDE_MD="no"
if [ -f "${CWD}/CLAUDE.md" ]; then
  HAS_CLAUDE_MD="yes"
fi

# --- Resolve plugin-relative skill path ---
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SKILL_PATH="${PLUGIN_ROOT}/skills/smart-simplify/SKILL.md"

# --- Return decision to block and simplify ---
# Using printf to avoid issues with special characters in file paths
REASON="[SIMPLIFY] You modified ${FILE_COUNT} code files (${TOTAL_LINES} lines, primarily ${LANG}). Before finishing, do a simplification pass on the files you changed. Read the smart-simplify skill at ${SKILL_PATH} for guidance. Files: ${FILE_LIST}. Project CLAUDE.md available: ${HAS_CLAUDE_MD}. Primary language: ${LANG}. After simplifying, resume and complete your response. Do NOT simplify a second time."

printf '{"decision":"block","reason":"%s"}\n' "$(echo "$REASON" | sed 's/"/\\"/g')"
