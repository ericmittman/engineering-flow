# engineering-flow — Shareable Workflow Kit Design Spec

**Date:** 2026-06-11 · **Status:** approved by Eric (conversation) · **Owner:** Eric Mittman
**This repo IS the deliverable:** a public GitHub repo that is simultaneously a Claude Code
plugin and its own installer.

## Context

Eric's engineering workflow chains the public superpowers plugin (brainstorm → spec →
plan → reviewed subagent execution) with a custom layer living on his machine: a
skill-router PreToolUse hook, smart-simplify Stop/PostToolUse hooks, and an
execution-strategy skill that picks serial vs parallel execution from a plan's
dependency graph. He wants to share the complete experience with his workplace and a
peer via "a little script."

## Decisions (Eric, 2026-06-11)

- **Scope: full workflow kit** — superpowers install + the custom layer + a new
  `/feature` pipeline command that becomes the kit's front door.
- **Distribution: public GitHub repo** — one artifact for both audiences; forces the
  personal-content scrub; workplace can fork internally.
- **Packaging: Claude Code plugin** (approach A) — hooks/skills/commands ship in the
  native plugin format; nothing ever edits an installee's `settings.json`; updates via
  the plugin mechanism; `${CLAUDE_PLUGIN_ROOT}` solves the hardcoded-path problem.
  Rejected: settings-merging `install.sh` (fragile JSON surgery, no uninstall);
  dotfiles-style clone (imposes Eric's directory layout, overshares).

## Repo structure

```
engineering-flow/
├── .claude-plugin/
│   └── plugin.json              # name "engineering-flow", version, description,
│                                # hooks manifest reference
├── commands/
│   └── feature.md               # /feature <idea> — pipeline front door
├── skills/
│   ├── execution-strategy/SKILL.md   # vendored from claude-knowledge (generic already)
│   └── smart-simplify/SKILL.md       # vendored; Stop hook reads it by plugin path
├── hooks/
│   ├── hooks.json               # PreToolUse(Bash): skill-router · Stop: smart-simplify
│   │                            # · PostToolUse(Edit|Write): accumulate-simplify
│   ├── skill-router.sh          # ported: routes file at ${CLAUDE_PLUGIN_ROOT}/hooks/
│   ├── skill-routes.conf        # REBUILT, not copied (see scrub policy)
│   ├── accumulate-simplify.sh   # ported: state file under ${TMPDIR}, skill path via
│   └── smart-simplify-stop.sh   #   ${CLAUDE_PLUGIN_ROOT}/skills/smart-simplify/SKILL.md
├── install.sh                   # the bootstrap script
├── README.md                    # the workflow story + quickstart + smoke test
└── docs/specs/                  # this document
```

## Components

### 1 · `/feature` command (`commands/feature.md`)

A command prompt that sequences the full pipeline for `$ARGUMENTS` (the feature idea):

1. Invoke `superpowers:brainstorming` with the idea — its own gates run (clarifying
   questions, approaches, design approval, spec doc, user spec review).
2. Invoke `superpowers:writing-plans` for the approved spec.
3. Invoke **`engineering-flow:execution-strategy`** on the written plan — dependency
   graph → serial / parallel / hybrid recommendation, replacing the "which approach?"
   question.
4. Execute per the recommendation: `superpowers:subagent-driven-development` (parallel/
   hybrid or same-session serial) or `superpowers:executing-plans` (parallel-session).
5. Finish with `superpowers:finishing-a-development-branch`.

The command defers to each skill's own gates — it sequences, it does not re-implement.
It must state explicitly: project conventions (CLAUDE.md) outrank skill defaults.

### 2 · Vendored skills

- **execution-strategy**: copied as-is (already generic — no personal paths/content).
- **smart-simplify**: copied; any references to `~/repos/claude-knowledge` removed.
  Frontmatter kept compatible with the Stop hook's expectations.

### 3 · Hooks (ported, not rewritten)

Behavior-preserving ports of the four scripts with exactly these changes:
- Path resolution via `${CLAUDE_PLUGIN_ROOT}` (hooks.json passes it; scripts fall back
  to their own directory via `$(dirname "$0")` when unset, so the scripts also work
  standalone).
- `skill-routes.conf` is **rebuilt for the kit**: route targets may ONLY be skills the
  installee is guaranteed to have — `superpowers:*` or this plugin's two skills.
  Eric's personal routes (CLAW, Quinn, nesdev, playwright-library, etc.) stay home.
  Initial route set: test-command patterns → superpowers:test-driven-development;
  debugger-ish patterns (re-running failing commands) → superpowers:systematic-debugging;
  `git commit/push` patterns → superpowers:verification-before-completion.
- `hooks.json` registers: PreToolUse(Bash)→skill-router, PostToolUse(Edit|Write)→
  accumulate-simplify, Stop→smart-simplify-stop.

### 4 · `install.sh` (the "little script")

Idempotent bootstrap, never edits `settings.json`:
1. Preflight: `claude` CLI present and version supports plugins; `git` present. Clear
   error + install URL if not.
2. Install superpowers from the official marketplace (exact commands verified against
   current Claude Code plugin docs at implementation time — they are a moving target).
3. Install engineering-flow from this repo (marketplace-add of the GitHub repo, or
   `--plugin-dir` style fallback per current docs).
4. Verify: both plugins appear in the plugin list; print the result.
5. Print quickstart: "open any repo, type `/feature add a healthcheck endpoint`" +
   pointer to README's smoke test.
Flags: `--dry-run` (print what would run). Failure mode: any step fails → stop with the
failing command's output; nothing partial to undo (plugin installs are atomic units).

### 5 · README.md

The workflow story for someone who has never seen it: the chain diagram
(router nudges → brainstorm → spec → plan → execution-strategy → reviewed subagent
execution → simplify pass), what each custom piece adds over stock superpowers, the
two-command manual install for script-skeptics, the smoke test (run `/feature`, watch
for the brainstorming announcement; make a 3-file edit, watch the Stop hook demand a
simplify pass), and an uninstall section (plugin remove — nothing else to clean).

## Scrub policy (public-repo gate)

Nothing ships unless it passes: no secrets/keys/tokens; no Eric-specific paths,
hostnames, or IPs; no references to CLAW/robotcrab/Quinn/personal projects; routes
reference only guaranteed-present skills. Implementation must include a grep-based
audit step over the staged kit (patterns: `eric|quinn|claw|robotcrab|192\.168|x\.ai|
api[_-]?key`), and `git log` starts fresh in this repo (no imported history).

## Adoption-back (Eric becomes consumer #1)

After the kit works, Eric's own machine installs the plugin and disables the
overlapping personal hooks (the settings.json entries for skill-router and the
simplify pair) to avoid double-firing. His richer personal routes stay in his local
conf only if he keeps the personal router active INSTEAD of the kit's — choose one
router, never both. This step is documented in the README's "for the author" footnote
and executed for Eric as part of the rollout, not left implicit.

## Testing

- **Manifest validity**: implementation verifies plugin.json/hooks.json structure
  against current Claude Code plugin docs (use the claude-code-guide agent), then
  `claude plugin` tooling confirms the plugin loads from a local checkout.
- **Hook smoke**: with the plugin installed in a scratch project, a Bash command
  matching a route produces the router's nudge; a 3-file edit then Stop produces the
  simplify demand. (Driven in a disposable session; assertions = hook output text.)
- **install.sh**: `--dry-run` output reviewed; real run on Eric's machine (consumer #1)
  ends with both plugins listed and `/feature` visible in the command list.
- **Scrub audit**: the grep gate above runs clean over the final tree.

## Out of scope

Vendoring or forking superpowers itself (upstream dependency, always); auto-updating
peers' installs (plugin update is theirs to run); Windows support (macOS/Linux shells
assumed); team-managed settings deployment (enterprise MDM distribution is the
workplace's call after forking); migrating Eric's full personal route set.
