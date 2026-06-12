# engineering-flow Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public GitHub repo that is simultaneously a Claude Code plugin (hooks + skills + /feature command) and its own installer, sharing Eric's superpowers-based workflow with peers.

**Architecture:** Repo root is the plugin (`.claude-plugin/plugin.json` + self-listing `marketplace.json` so the bare GitHub repo is installable). Hooks are behavior-preserving ports of Eric's personal scripts with `${CLAUDE_PLUGIN_ROOT}` paths and a `~/.claude/skill-routes.local.conf` extension hook. Spec: `docs/specs/2026-06-11-engineering-flow-kit-design.md` (read it first).

**Tech Stack:** bash, JSON manifests (verified against Claude Code 2.1.173 plugin docs), markdown command/skills. Verification: `claude plugin validate`, direct-stdin hook tests, scrub-audit grep, `--plugin-dir` smoke.

**Working directory:** `/Users/eric/repos/engineering-flow` (fresh repo, main branch, spec already committed).

**Source files to port/vendor (read them — they are the ground truth):**
- `~/.claude/hooks/skill-router.sh`, `~/.claude/hooks/accumulate-simplify.sh`, `~/.claude/hooks/smart-simplify-stop.sh`
- `~/repos/claude-knowledge/hooks/enforcement/skill-routes.conf` (format reference ONLY — content is personal, do not copy)
- `~/repos/claude-knowledge/skills/general/execution-strategy/SKILL.md`
- `~/repos/claude-knowledge/skills/code-review/smart-simplify/SKILL.md`

---

### Task 1: Plugin scaffold (manifests)

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `.gitignore`

- [ ] **Step 1: plugin.json** (hooks key added in Task 2; omit it now so validate passes):

```json
{
  "name": "engineering-flow",
  "displayName": "Engineering Flow",
  "description": "Opinionated engineering workflow: superpowers chained end-to-end — skill routing nudges, execution-strategy analysis, automatic simplification passes, and a /feature pipeline command",
  "version": "0.1.0",
  "author": { "name": "Eric Mittman" },
  "repository": "https://github.com/ericmittman/engineering-flow",
  "license": "MIT",
  "keywords": ["workflow", "superpowers", "hooks", "skills"]
}
```

- [ ] **Step 2: marketplace.json** (self-listing — makes `claude plugin marketplace add ericmittman/engineering-flow` work on the bare repo):

```json
{
  "name": "engineering-flow",
  "owner": { "name": "Eric Mittman" },
  "plugins": [
    {
      "name": "engineering-flow",
      "source": "./",
      "description": "Superpowers-based engineering workflow kit"
    }
  ]
}
```

- [ ] **Step 3: .gitignore**

```
.DS_Store
*.swp
```

- [ ] **Step 4: Validate.** Run: `cd /Users/eric/repos/engineering-flow && claude plugin validate .`
Expected: validation passes (no hooks/commands/skills yet is fine).

- [ ] **Step 5: Commit:** `git add -A && git commit -m "feat: plugin scaffold — manifest + self-listing marketplace"`

---

### Task 2: Hook ports + hooks.json + kit routes

**Files:**
- Create: `hooks/hooks.json`, `hooks/skill-router.sh`, `hooks/skill-routes.conf`, `hooks/accumulate-simplify.sh`, `hooks/smart-simplify-stop.sh`
- Modify: `.claude-plugin/plugin.json` (add `"hooks": "./hooks/hooks.json"`)

- [ ] **Step 1: hooks.json:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/skill-router.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/accumulate-simplify.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/smart-simplify-stop.sh" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Port skill-router.sh.** Copy `~/.claude/hooks/skill-router.sh` to `hooks/skill-router.sh`, then apply EXACTLY these changes (everything else stays byte-identical — verify with diff afterward):

Replace the line:
```bash
ROUTES_FILE="${HOME}/repos/claude-knowledge/hooks/enforcement/skill-routes.conf"
```
with:
```bash
# Plugin-relative routes + optional user extension (add your own without forking).
HOOK_DIR="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/hooks}"
HOOK_DIR="${HOOK_DIR:-$(cd "$(dirname "$0")" && pwd)}"
ROUTES_FILE="${HOOK_DIR}/skill-routes.conf"
LOCAL_ROUTES="${HOME}/.claude/skill-routes.local.conf"
```
Replace the PARSED line:
```bash
PARSED=$(grep -v '^#' "$ROUTES_FILE" | grep -v '^$' | awk -F ' \\| ' '{OFS="\t"; print $1, $2, $3, $4}')
```
with:
```bash
ROUTE_SOURCES=("$ROUTES_FILE")
[ -f "$LOCAL_ROUTES" ] && ROUTE_SOURCES+=("$LOCAL_ROUTES")
PARSED=$(cat "${ROUTE_SOURCES[@]}" | grep -v '^#' | grep -v '^$' | awk -F ' \\| ' '{OFS="\t"; print $1, $2, $3, $4}')
```
If the original references any other absolute path (`/Users/eric`, `claude-knowledge`) below the shown lines, replace per the same `${HOOK_DIR}`/tmp logic and note it in your report. Keep the script executable (`chmod +x`).

- [ ] **Step 3: Rebuild skill-routes.conf** (do NOT copy Eric's — content is personal). Format is `pattern | skill | path | description` with ` | ` (space-pipe-space) separators; patterns are `grep -Ei` regexes:

```
# engineering-flow kit routes — targets MUST be skills every installee has
# (superpowers:* or this plugin's). Add personal routes in
# ~/.claude/skill-routes.local.conf (same format), never here.
(npm|yarn|pnpm|bun) (run )?test|pytest|go test|cargo test|swift test | superpowers:test-driven-development | (plugin) | Failing test first — use test-driven-development
git (commit|push) | superpowers:verification-before-completion | (plugin) | Evidence before done — run verification-before-completion
git checkout -b|git switch -c | superpowers:using-git-worktrees | (plugin) | Consider an isolated worktree for feature work
```

- [ ] **Step 4: Port accumulate-simplify.sh and smart-simplify-stop.sh.** Copy both from `~/.claude/hooks/`. Apply this rule to each: every reference to `~/repos/claude-knowledge/...` or `/Users/eric/...` becomes plugin-relative — specifically, references to the smart-simplify skill file become `${PLUGIN_ROOT}/skills/smart-simplify/SKILL.md` resolved via the same two-line `HOOK_DIR`/`PLUGIN_ROOT` pattern as Step 2 (`PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"`); any state/accumulator files move to `${TMPDIR:-/tmp}` if not already there. NO other behavior changes. Keep executable bits. Report every line you changed (file:line, before → after).

- [ ] **Step 5: Wire hooks into plugin.json** — add to `.claude-plugin/plugin.json`:
```json
  "hooks": "./hooks/hooks.json",
```
(keep valid JSON — add after `"license"`).

- [ ] **Step 6: Verify.**
Run: `grep -nE '/Users/eric|claude-knowledge' hooks/*.sh hooks/*.conf` → expected: NO matches.
Run: `bash -n hooks/skill-router.sh hooks/accumulate-simplify.sh hooks/smart-simplify-stop.sh` → no output.
Run: `claude plugin validate .` → passes.
Direct-stdin router test:
```bash
cd /Users/eric/repos/engineering-flow && echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' | CLAUDE_PLUGIN_ROOT="$PWD" hooks/skill-router.sh
```
Expected: output mentioning `superpowers:test-driven-development` (exact shape per the original script's output format). Then a non-matching command:
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | CLAUDE_PLUGIN_ROOT="$PWD" hooks/skill-router.sh
```
Expected: no output, exit 0. NOTE: the router has a 10-minute dedup TTL — if the first test produces no output on re-runs, clear its dedup state (find the state path in the script, usually under /tmp) and retry.

- [ ] **Step 7: Commit:** `git add -A && git commit -m "feat: ported hooks — router with local-extension routes, simplify pair"`

---

### Task 3: Vendor the two skills

**Files:**
- Create: `skills/execution-strategy/SKILL.md`
- Create: `skills/smart-simplify/SKILL.md`

- [ ] **Step 1:** Copy `~/repos/claude-knowledge/skills/general/execution-strategy/SKILL.md` to `skills/execution-strategy/SKILL.md` verbatim, then scan it: remove/neutralize any `/Users/eric`, `claude-knowledge`, CLAW/Quinn/personal references (report findings; the skill is believed generic already).

- [ ] **Step 2:** Copy `~/repos/claude-knowledge/skills/code-review/smart-simplify/SKILL.md` to `skills/smart-simplify/SKILL.md`; same scan + scrub rule. Keep frontmatter fields the Stop hook's message relies on (read `hooks/smart-simplify-stop.sh` to see what it tells the model to read — the path it now prints must be the plugin path).

- [ ] **Step 3: Verify:** `grep -nE '/Users/eric|claude-knowledge|quinn|claw' skills/*/SKILL.md` (case-insensitive: add `-i`) → no matches. `claude plugin validate .` → passes, lists 2 skills.

- [ ] **Step 4: Commit:** `git add -A && git commit -m "feat: vendor execution-strategy + smart-simplify skills"`

---

### Task 4: /feature pipeline command

**Files:**
- Create: `commands/feature.md`

- [ ] **Step 1: Write the command:**

```markdown
---
description: Run the full engineering pipeline — brainstorm → spec → plan → execution-strategy → reviewed execution → finish
argument-hint: [feature idea]
disable-model-invocation: true
---

You are running the engineering-flow pipeline for this feature idea: $ARGUMENTS

Sequence the following skills IN ORDER. Let each skill's own gates run fully — this
command sequences, it does not re-implement or shortcut them. Project conventions
(CLAUDE.md) outrank any skill default at every stage.

1. Invoke `superpowers:brainstorming` with the idea. Run its full cycle: context
   exploration, clarifying questions one at a time, 2-3 approaches, design approval,
   spec document written and committed, and the user's review of the written spec.
2. Invoke `superpowers:writing-plans` to turn the approved spec into a bite-sized,
   no-placeholders implementation plan. Commit it.
3. Invoke `engineering-flow:execution-strategy` on the written plan: build the task
   dependency graph, check file-ownership conflicts, and recommend serial, parallel,
   or hybrid execution. Present the recommendation with one line of reasoning —
   do NOT ask the user to choose; the analysis decides.
4. Execute per the recommendation: `superpowers:subagent-driven-development` for
   same-session execution (serial or parallel per the analysis) or
   `superpowers:executing-plans` when a parallel session is warranted. Fresh
   subagent per task; spec-compliance review then code-quality review after each;
   fix-and-re-review loops until clean.
5. Invoke `superpowers:finishing-a-development-branch` to integrate.

Do not write code before the design is approved. Do not claim completion without
verification evidence. If any stage is blocked on a decision only the user can make,
stop and ask — otherwise drive to completion.
```

- [ ] **Step 2: Verify:** `claude plugin validate .` → passes, lists the command.

- [ ] **Step 3: Commit:** `git add -A && git commit -m "feat: /feature pipeline command"`

---

### Task 5: install.sh + README

**Files:**
- Create: `install.sh` (chmod +x)
- Create: `README.md`

- [ ] **Step 1: install.sh:**

```bash
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
```

- [ ] **Step 2: README.md:**

```markdown
# engineering-flow

An opinionated engineering workflow for Claude Code: the
[superpowers](https://github.com/anthropics/claude-plugins-official) discipline chained
end-to-end, plus the connective tissue that makes it run itself.

## What you get

```
skill-router nudges ─▶ /feature ─▶ brainstorming ─▶ spec ─▶ writing-plans
        ─▶ execution-strategy (serial vs parallel, decided not asked)
        ─▶ subagent execution (spec review + quality review per task)
        ─▶ smart-simplify pass on Stop ─▶ finished branch
```

- **/feature `<idea>`** — one command runs the whole pipeline, honoring every gate.
- **skill-router** (PreToolUse hook) — pattern-matches your shell commands and nudges
  the right skill ("running tests? write the failing test first"). Extend it without
  forking: `~/.claude/skill-routes.local.conf`.
- **execution-strategy** (skill) — after a plan is approved, builds the task dependency
  graph and decides serial vs parallel execution instead of asking.
- **smart-simplify** (Stop + PostToolUse hooks + skill) — after multi-file changes, the
  session can't end without a simplification pass over what changed.

## Install

```bash
git clone https://github.com/ericmittman/engineering-flow && cd engineering-flow
./install.sh          # add --dry-run to preview
```

Or manually, inside any Claude Code session:

```
/plugin install superpowers@claude-plugins-official
/plugin marketplace add ericmittman/engineering-flow
/plugin install engineering-flow@engineering-flow
```

## Smoke test

1. `/feature add a healthcheck endpoint` → you should see "I'm using the brainstorming
   skill" and get a clarifying question, not code.
2. Edit three files in one session, then stop → the Stop hook demands a simplification
   pass before the session ends.
3. Run `npm test` (or pytest/go test) → the router nudges test-driven-development.

## Uninstall

`/plugin` → remove engineering-flow (and superpowers if you want). Nothing else to
clean — this kit never touches your settings.json.

## Extending the router

Add lines to `~/.claude/skill-routes.local.conf` (created by you, survives kit
updates): `pattern | skill | path | description`, where pattern is a grep -Ei regex
matched against your Bash commands. Route to any skill you have installed.

## For the author (adoption-back)

If you previously ran these hooks from `~/.claude/settings.json` directly: remove the
personal skill-router/accumulate-simplify/smart-simplify-stop entries after installing
the kit (one router, one simplify pair — never both), and migrate personal routes to
`~/.claude/skill-routes.local.conf`.
```

- [ ] **Step 3: Verify:** `bash -n install.sh` → no output. `./install.sh --dry-run` → prints the DRY-RUN command lines and quickstart, exit 0.

- [ ] **Step 4: Commit:** `git add -A && git commit -m "feat: installer + README"`

---

### Task 6: Scrub audit + plugin-level smoke

- [ ] **Step 1: Scrub audit** (the public-repo gate — run over the full tree):
```bash
cd /Users/eric/repos/engineering-flow && grep -rniE 'quinn|claw|robotcrab|192\.168|x\.ai|api[_-]?key|sk-ant|oauth' --exclude-dir=.git . ; echo "exit=$?"
```
Expected: `exit=1` (no matches). `eric`/`ericmittman`/`Eric Mittman` are ALLOWED (author attribution) — but run `grep -rniE '/Users/eric' --exclude-dir=.git .` separately and expect only matches inside `docs/` (spec/plan reference source paths; acceptable) and NONE in hooks/, skills/, commands/, install.sh, README.md, .claude-plugin/.

- [ ] **Step 2: Strict validate + local load:**
```bash
claude plugin validate . --strict
```
Expected: pass, listing 1 command, 2 skills, 3 hook registrations.
```bash
cd /tmp && mkdir -p ef-smoke && cd ef-smoke && claude --plugin-dir /Users/eric/repos/engineering-flow -p "Reply with exactly: PLUGIN-OK" 2>&1 | tail -3
```
Expected: PLUGIN-OK (proves the plugin loads without breaking a session).

- [ ] **Step 3: Hook-fire smoke via direct stdin** (re-run both router probes from Task 2 Step 6 plus a Stop-hook probe):
```bash
cd /Users/eric/repos/engineering-flow
echo '{}' | CLAUDE_PLUGIN_ROOT="$PWD" hooks/smart-simplify-stop.sh; echo "stop-exit=$?"
```
Expected: exits 0 quickly with no simplify demand (no accumulated edits in state) — the point is it runs without path errors. If it errors on missing state file, that's a bug to fix (must tolerate first-run).

- [ ] **Step 4: Commit any fixes:** `git add -A && git commit -m "fix: smoke findings"` (skip if no changes).

---

### Task 7: Publish + adoption-back (Eric becomes consumer #1)

- [x] **Step 1: Create the public repo and push** (gh is authenticated as ericmittman):
```bash
cd /Users/eric/repos/engineering-flow && gh repo create ericmittman/engineering-flow --public --source=. --push 2>&1 | tail -2
```
Expected: repo URL printed, branch pushed. GATE: do NOT run this until Task 6's scrub audit passed clean in this same working tree.

- [x] **Step 2: Install for Eric from the published repo:**
```bash
claude plugin install superpowers@claude-plugins-official 2>&1 | tail -1   # likely already installed — fine
claude plugin marketplace add ericmittman/engineering-flow 2>&1 | tail -1
claude plugin install engineering-flow@engineering-flow 2>&1 | tail -1
claude plugin list | grep -i engineering-flow
```
If the non-interactive CLI forms are unsupported, report DONE_WITH_CONCERNS with the exact error — Eric runs the slash-command forms himself (do not simulate them).

- [x] **Step 3: Migrate personal routes:**
```bash
cp ~/repos/claude-knowledge/hooks/enforcement/skill-routes.conf ~/.claude/skill-routes.local.conf
```

- [x] **Step 4: Disable the now-duplicated personal hooks** — with backup:
```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak-ef-adoption
python3 - <<'EOF'
import json
p = "/Users/eric/.claude/settings.json"
d = json.load(open(p))
def drop(event, needle):
    if event not in d.get("hooks", {}): return
    d["hooks"][event] = [m for m in d["hooks"][event]
                         if not any(needle in h.get("command","") for h in m.get("hooks",[]))]
drop("PreToolUse", "skill-router.sh")
drop("PostToolUse", "accumulate-simplify.sh")
drop("Stop", "smart-simplify-stop.sh")
json.dump(d, open(p,"w"), indent=2)
print("removed entries; remaining hook events:", {k: len(v) for k,v in d.get("hooks",{}).items()})
EOF
```
Verify the remaining hooks still include observe-task-model, external-analysis-suggest, scan-secrets-output, stop-shim, session-compact-reinject (untouched).

- [x] **Step 5: Commit nothing here (machine config), but update the repo's plan checkboxes and push:**
```bash
cd /Users/eric/repos/engineering-flow && git push origin main 2>&1 | tail -1
```

- [x] **Step 6: Report:** repo URL, install verification output, settings backup path, and the one manual step (if any) left for Eric.
