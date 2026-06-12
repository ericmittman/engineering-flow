# engineering-flow v0.2 Implementation Plan — Tiered Pipeline + Security Posture

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three staged pipeline commands (Fable-class design → Opus build → Fable-class review) with security/reliability posture at every stage, nested parallel execution, and three new skills (secure-design, track-coordinator, build-journal).

**Architecture:** All deliverables are markdown prompt-documents plus manifest edits — the complete content for every file is IN THIS PLAN; tasks are transcription + verification. Spec: `docs/specs/2026-06-12-tiered-pipeline-security-design.md` (read first).

**Tech Stack:** Claude Code plugin format (CLI ≥ 2.1.172 for nested mode, degrades gracefully), markdown skills/commands, bash verification.

**Working directory:** `/Users/eric/repos/engineering-flow` (main branch).

---

### Task 1: secure-design skill

**Files:** Create: `skills/secure-design/SKILL.md`

- [ ] **Step 1: Write the file** (complete content):

```markdown
---
name: secure-design
description: Security AND reliability posture for the engineering-flow pipeline — design-time questions, [SEC]/[REL] task-flagging criteria, and review rubrics. One source of truth consumed by /feature, /feature-build, and /feature-review.
version: 1.0.0
category: security
tags: [security, reliability, threat-model, review, rubric]
use_when:
  - designing a feature (fold the design-time questions into brainstorming)
  - writing an implementation plan (apply the flagging criteria to every task)
  - reviewing code inline during a build or at final assessment
---

# Secure & Reliable by Design

Three sections for three moments. Use the one that matches your stage; never skip a
stage's section because another stage "will catch it" — later is always costlier.

## 1 · Design-time questions (stage: /feature brainstorming)

Work these into the design conversation naturally — they are design questions, not a
compliance checklist. The spec MUST gain a "Security & Reliability Considerations"
section recording the answers (one line each is fine; "none — no trust boundary
crossed" is a valid answer when true).

- **Trust boundaries:** where does data cross from untrusted to trusted? (user input,
  network, files, env vars, subprocess output, third-party APIs)
- **Data:** what's sensitive (secrets, PII, tokens)? Where does it live, flow, and die?
- **AuthN/Z:** who may do what? What enforces it, and what happens when it's bypassed?
- **Secrets lifecycle:** how are they provisioned, stored (perms!), rotated, and kept
  out of logs/output/commits?
- **Injection surfaces:** anywhere strings become code/commands/queries/paths/markup?
- **Dependencies:** what third-party code is being added, and what is its blast radius?
- **Failure blast radius:** if this component is compromised or wedges, what else falls?
- **Concurrency shape:** any new blocking waits, locks, queues, or shared state? What
  is the stuck-state story?

## 2 · Flagging criteria (stage: /feature-build planning)

Apply to EVERY task in the plan. A task gets:

- **[SEC]** if it touches: input parsing/deserialization, authn/z, secrets or key
  material, network listeners or clients, exec/subprocess/shell, file permissions or
  path construction from variables, crypto, HTML/SQL/command string building.
- **[REL]** if it adds or modifies: blocking waits (semaphores, locks, joins, reads),
  queues/FIFOs, retries/timeouts, state machines, resource acquisition (fds, procs,
  temp files), cross-process or cross-thread coordination.

Flags go in the task title (`### Task 3: [SEC] parse upload manifest`). Each flagged
task's steps must include the relevant acceptance line(s) from section 3 as explicit
verify steps. Unflagged tasks skip inline security/reliability review — that is the
point of flagging honestly.

## 3 · Review rubrics (stage: inline [SEC]/[REL] checks + /feature-review)

Review the DIFF, not the report. For each line, the question is "show me where this is
handled" — absence of evidence is a finding.

**Security:**
- All untrusted input validated/bounded before use; deserialization is type-constrained
- Anything interpolated into commands/queries/paths/markup is escaped or parameterized
- Least privilege: file modes, scopes, capabilities no broader than needed
- Secrets: never in logs, error messages, commits, or world-readable files
- Path traversal/SSRF: user-influenced paths/URLs are canonicalized and allowlisted
- Errors fail closed and don't leak internals; security events are observable
- New dependencies pinned and justified

**Reliability:**
- **Every blocking wait has a timeout and a defined behavior on expiry** (the #1 repeat
  offender — two production bugs in one day proved it)
- Every external call (network, subprocess, IPC) has a failure path that releases
  resources
- No stuck states: anything that sets "busy" has a guaranteed path back to "idle"
- Retries are bounded and idempotent; partial failures clean up after themselves
- Shared state mutations are serialized or documented as single-threaded; race windows
  between check and use are closed or accepted in writing

**Verdict format** (inline checks and final assessment alike): per finding — severity
(Critical/Important/Minor), confidence (0-100), file:line, the rubric line it violates,
and the smallest fix. End with: pass / pass-with-findings / fail.
```

- [ ] **Step 2: Verify:** `grep -c "SEC\|REL" skills/secure-design/SKILL.md` ≥ 8; file parses as frontmatter+body (`head -12` shows closing `---`).

- [ ] **Step 3: Commit:** `git add -A && git commit -m "feat: secure-design skill — security+reliability rubrics"`

---

### Task 2: track-coordinator skill

**Files:** Create: `skills/track-coordinator/SKILL.md`

- [ ] **Step 1: Write the file** (complete content):

```markdown
---
name: track-coordinator
description: Operating contract for a nested track-coordinator subagent in /feature-build parallel mode — scope discipline, internal review loop, escalation, and report format. Requires Claude Code >= 2.1.172 (nested subagents).
version: 1.0.0
category: orchestration
tags: [subagents, parallel, coordination, worktree]
use_when:
  - you are a subagent dispatched as a track coordinator by /feature-build
  - designing parallel execution where each track runs its own implement/review loop
---

# Track Coordinator Contract

You coordinate ONE track of a larger build: a set of plan tasks that own a disjoint
set of files (the orchestrator gives you the task list and the ownership set). You are
a subagent with the ability to dispatch your own subagents. These rules are not
advisory.

## Scope

- Touch ONLY files in your ownership set. If a task seems to require editing outside
  it, STOP and return BLOCKED — the dependency analysis was wrong, and that is the
  orchestrator's problem, not yours to improvise around.
- When other tracks share the repo, work in an isolated worktree
  (superpowers:using-git-worktrees); name your branch `track/<track-name>`. The
  orchestrator merges; you never merge other tracks.
- Never talk to the user. Anything needing a human decision returns as BLOCKED with
  specifics.

## Loop (per task, in plan order)

1. Dispatch an implementer subagent (sonnet) with the task's FULL plan text — it
   implements, verifies per the plan's steps, commits, self-reviews.
2. Dispatch a spec-compliance reviewer (sonnet): does the diff match the task, nothing
   more, nothing less? Findings → implementer fixes → re-review.
3. Dispatch a code-quality reviewer (opus): correctness, clarity, the project's
   conventions. Findings → fix → re-review.
4. Run the task's verify commands via a verification runner (haiku): it executes the
   EXACT commands and returns raw output; you judge the output, it doesn't.
5. Record the task in your report (status, SHA, review verdicts) and move on.

## Escalation

Return BLOCKED (with what you tried, the exact error/conflict, and what you need) when:
ownership conflicts appear; a task's plan is wrong or impossible as written; reviews
deadlock after two fix cycles; anything requires a user decision. Never mark a task
complete on partial work — your report is trusted downstream.

## Report format (your final message)

- Track name; tasks completed/total
- Per task: status, commit SHA, review verdicts, [SEC]/[REL] flags present (the
  ORCHESTRATOR runs those rubric checks — list the flags so it knows to)
- Worktree/branch name if used
- Deviations from plan (what + why), concerns, BLOCKED details if any
```

- [ ] **Step 2: Verify:** `grep -c "BLOCKED" skills/track-coordinator/SKILL.md` ≥ 3.

- [ ] **Step 3: Commit:** `git add -A && git commit -m "feat: track-coordinator skill — nested parallel contract"`

---

### Task 3: build-journal skill

**Files:** Create: `skills/build-journal/SKILL.md`

- [ ] **Step 1: Write the file** (complete content):

```markdown
---
name: build-journal
description: Durable build state for /feature-build — journal format, update cadence, and resume protocol. The journal is what lets a build survive context loss and what /feature-review assesses against.
version: 1.0.0
category: orchestration
tags: [state, resume, journal, continuity]
use_when:
  - starting /feature-build (check for an existing journal -> resume)
  - after every completed task or track report during a build
  - starting /feature-review (the journal names the diff range to assess)
---

# Build Journal

Long builds outlive context windows, sessions, and machines. The journal is the build's
memory: cheap to write, decisive to have. (Earned the hard way: a build session that
survived a machine handoff did so only because a handoff doc existed.)

## Location & creation

`docs/builds/<feature-slug>-journal.md` in the target repo, created by /feature-build
immediately after the plan is approved, committed with the plan.

## Format

    # Build Journal — <feature>
    plan: <path> · spec: <path> · started: <ISO date> · base-sha: <sha before task 1>

    ## Tasks
    | # | Task | Flags | Status | SHA | Spec rev | Quality rev | Sec/Rel check |
    |---|------|-------|--------|-----|----------|-------------|----------------|
    | 1 | scaffold | — | done | abc1234 | pass | pass | n/a |
    | 2 | parse manifest | [SEC] | done | def5678 | pass | pass (2 rounds) | pass-with-findings |

    ## Concerns / deviations
    - <dated one-liners; empty section is fine>

    ## Resume pointer
    next: task 3 · mode: flat|nested · tracks: <names if nested>

## Cadence

Update after EVERY task completion (or track report in nested mode) — table row +
resume pointer, then `git add docs/builds && git commit -m "journal: task N"`. The
journal commit rides with the work; a journal that lags its build is fiction.

## Resume protocol (/feature-build start)

1. Journal exists for this feature? → verify each "done" row's SHA exists in git;
   resume from the resume pointer. State the resumption to the user in one line.
2. No journal → fresh build: create it before task 1.
3. Journal says done but tasks remain? Trust the table over memory — never redo a
   done task (idempotence beats enthusiasm).

## Handoff to /feature-review

The review stage reads: base-sha → HEAD as the assessment diff, the flags column for
where inline checks ran, and the concerns section as its starting findings list.
```

- [ ] **Step 2: Verify:** `grep -c "base-sha\|Resume" skills/build-journal/SKILL.md` ≥ 3.

- [ ] **Step 3: Commit:** `git add -A && git commit -m "feat: build-journal skill — durable build state + resume"`

---

### Task 4: rewrite commands/feature.md (stage 1)

**Files:** Modify: `commands/feature.md` (full replacement)

- [ ] **Step 1: Replace the file** (complete content):

```markdown
---
description: Stage 1 of the engineering-flow pipeline — security-aware brainstorm + spec. Run on your strongest model; hand off to /feature-build.
argument-hint: [feature idea]
disable-model-invocation: true
---

You are running STAGE 1 of the engineering-flow pipeline for: $ARGUMENTS

This stage designs; it never writes code or plans. Project conventions (CLAUDE.md)
outrank any skill default at every step.

1. Read the `engineering-flow:secure-design` skill, section 1 (design-time questions).
2. Invoke `superpowers:brainstorming` for the idea, running its full cycle — context
   exploration, ONE question at a time, 2-3 approaches with a recommendation, design
   approval. Fold the secure-design questions into the design conversation where they
   apply (trust boundaries, data, authn/z, secrets, injection, dependencies, failure
   blast radius, concurrency shape) — as natural design questions, not a checklist
   recital.
3. The spec document MUST contain a "Security & Reliability Considerations" section
   recording the answers. A spec without it is incomplete — do not present it for
   review. ("None — no trust boundary crossed" is valid when true.)
4. Complete brainstorming's spec self-review and the user's review of the written,
   committed spec.

When the user approves the spec, close with EXACTLY this handoff:

> Stage 1 complete. The spec is approved and committed. Next: run `/feature-build` —
> it pins the build to Opus, writes the security-annotated plan, and manages reviewed
> execution. (Stage 3, `/feature-review`, runs back on your strongest model.)
```

- [ ] **Step 2: Verify:** `grep -c "secure-design\|feature-build" commands/feature.md` ≥ 3.

- [ ] **Step 3: Commit:** `git add -A && git commit -m "feat: /feature becomes stage 1 — security-aware design"`

---

### Task 5: commands/feature-build.md (stage 2)

**Files:** Create: `commands/feature-build.md`

- [ ] **Step 1: Write the file** (complete content):

```markdown
---
description: Stage 2 of the engineering-flow pipeline — Opus-pinned plan writing, security-annotated, with managed (optionally nested-parallel) reviewed execution.
argument-hint: [optional: path to approved spec]
disable-model-invocation: true
model: opus
---

You are running STAGE 2 of the engineering-flow pipeline (Opus build phase).

## Locate inputs

The approved spec: $ARGUMENTS if given, else the newest file in docs/superpowers/specs/
or docs/specs/. If none exists, STOP: "No approved spec found — run /feature first."
Then read the `engineering-flow:build-journal` skill and check for an existing journal
for this feature → if found, follow its resume protocol instead of restarting.

## Plan

1. Invoke `superpowers:writing-plans` for the spec — bite-sized tasks, complete code,
   exact verify commands.
2. Apply the `engineering-flow:secure-design` skill section 2 to EVERY task: add
   [SEC]/[REL] flags to task titles and fold the matching rubric lines into flagged
   tasks' verify steps. A plan with zero flags on a feature that parses input or adds
   a queue is wrong — re-check before proceeding.
3. Invoke `engineering-flow:execution-strategy` on the plan: dependency graph,
   file-ownership conflicts, serial/parallel/hybrid recommendation with track
   definitions (names + ownership sets). Present the recommendation in two lines; the
   analysis decides — do not ask.
4. Create the build journal (per the build-journal skill) and commit it with the plan.

## Execute

**Model tiers (fixed):** implementers = sonnet · spec-compliance reviewers = sonnet ·
code-quality reviewers = opus · verification runners = haiku (run the plan's EXACT
commands, return raw output, no interpretation) · inventory scouts = haiku ·
BLOCKED escalation = re-dispatch one tier up. Haiku NEVER reviews or decides.

**Flat mode (serial recommendation, or fallback):** per task — implementer subagent
(full task text) → spec review → quality review, fix-and-re-review until clean →
haiku verification run → journal row + commit.

**Nested mode (parallel recommendation):** requires Claude Code ≥ 2.1.172 (subagents
spawning subagents). Probe before relying on it: dispatch one trivial subagent
instructed to dispatch a sub-subagent that replies "NEST-OK"; if that fails, say
"nesting unavailable — running flat" and use flat mode. Otherwise dispatch one
track-coordinator subagent (opus) per track with: the track's full task texts, its
file-ownership set, and the instruction to follow `engineering-flow:track-coordinator`
to the letter. Integrate per its report; verify its SHAs exist; merge worktree branches
serially; journal every track report. Tracks with dependencies between them run in
dependency order — nesting parallelizes only what the analysis proved independent.

**Inline security/reliability checks (you, the orchestrator — not a subagent):** after
each [SEC]/[REL] task's reviews pass, review that task's DIFF against secure-design
section 3 (matching rubric). Record verdict in the journal. Critical findings block
the next task until fixed.

## Discipline

Honest reports only — failures, skips, and concerns go in the journal, not under the
rug. Stop for: BLOCKED you cannot resolve, scope changes, or any decision that belongs
to the user. Per-task commits; never claim done without the verification runner's
output in hand.

When all tasks are done and the journal is current, close with EXACTLY:

> Stage 2 complete. Build journal: <path> (<N> tasks, <flags summary>). Next: run
> `/feature-review` on your strongest model for the final functional + security
> assessment.
```

- [ ] **Step 2: Verify:** `grep -c "model: opus" commands/feature-build.md` = 1; `grep -c "NEST-OK\|track-coordinator\|build-journal\|secure-design" commands/feature-build.md` ≥ 5.

- [ ] **Step 3: Commit:** `git add -A && git commit -m "feat: /feature-build — opus-pinned, security-annotated, nesting-aware"`

---

### Task 6: commands/feature-review.md (stage 3)

**Files:** Create: `commands/feature-review.md`

- [ ] **Step 1: Write the file** (complete content):

```markdown
---
description: Stage 3 of the engineering-flow pipeline — final adversarial assessment (spec coverage, integration seams, full security+reliability review). Run on your strongest model. Evaluates only; builds nothing.
argument-hint: [optional: path to build journal]
disable-model-invocation: true
---

You are running STAGE 3 of the engineering-flow pipeline: the closeout assessment.
You evaluate; you do not build. If findings require code changes, they become a
findings list for the user — fixes happen via a follow-up build, not here.

## Locate inputs

Journal: $ARGUMENTS if given, else newest in docs/builds/. No journal → STOP:
"No build journal found — run /feature-build first." From it: the spec, the plan, the
diff range (base-sha → HEAD), the flags column, and prior concerns.

## Assess (three passes over the REAL diff — never trust reports)

1. **Spec coverage:** walk the spec requirement by requirement → a table of
   requirement → where implemented (file:line) → OK / GAP. Every gap is a finding.
2. **Integration seams:** the per-task reviews saw trees; you see the forest. Trace
   the cross-task data flows end to end; check the pieces compose (formats, units,
   ordering, error propagation across boundaries). Check the plan's deviations and the
   journal's concerns were resolved, not forgotten.
3. **Security & reliability:** apply `engineering-flow:secure-design` section 3 — BOTH
   rubrics — to the full diff, regardless of which tasks were flagged (flags scoped the
   inline checks; the final pass is unconditional). Pay extra attention to unflagged
   code: misflagging is itself a finding.

## Verdict

- Findings list: severity (Critical/Important/Minor), confidence (0-100), file:line,
  rubric line or spec requirement violated, smallest fix.
- Coverage table from pass 1.
- One verdict: SHIP / SHIP WITH FOLLOW-UPS / DO NOT SHIP — with the two-sentence
  justification a teammate could act on.
- Append the verdict + findings to the build journal under "## Final assessment" and
  commit it.
```

- [ ] **Step 2: Verify:** `grep -c "secure-design\|journal" commands/feature-review.md` ≥ 4; `grep -c "model:" commands/feature-review.md` = 0 (inherits session).

- [ ] **Step 3: Commit:** `git add -A && git commit -m "feat: /feature-review — final assessment stage"`

---

### Task 7: execution-strategy edit (both copies), README, version, verification

**Files:**
- Modify: `skills/execution-strategy/SKILL.md` AND `~/repos/claude-knowledge/skills/general/execution-strategy/SKILL.md` (same edit — no drift)
- Modify: `README.md` (sections below), `.claude-plugin/plugin.json` (version)

- [ ] **Step 1: execution-strategy edit.** In BOTH copies, at the END of the "## The Analysis" section (after its last step), append:

```markdown
### Output for coordinators (engineering-flow nested mode)

When recommending parallel/hybrid, define each track in coordinator-consumable form:

- **Track <name>**: tasks [list], owns files [explicit path list], depends on tracks
  [list or none]

A track's ownership set must be disjoint from every other track's. If you cannot make
the sets disjoint, the tasks are not parallel — say so and recommend serial.
```
Bump the kit copy's frontmatter `version:` to `1.2.0` and the claude-knowledge copy's to `1.2.0`. Run `diff` between the two files' Analysis sections — the appended block must be identical.

- [ ] **Step 2: README updates.** Replace the chain diagram in "## What you get" with:

```
/feature (your best model) ─▶ security-aware brainstorm ─▶ spec
  └▶ /feature-build (opus) ─▶ [SEC]/[REL]-annotated plan ─▶ execution-strategy
        ─▶ reviewed execution (sonnet builds · opus reviews · haiku verifies
           · nested parallel tracks on CLI ≥ 2.1.172, flat otherwise)
  └▶ /feature-review (your best model) ─▶ coverage + seams + full security audit
```

Add after the "What you get" bullet list, a new section:

```markdown
## Security posture

One rubric file (`secure-design` skill) drives all three stages: design-time questions
in the brainstorm, [SEC]/[REL] flags on plan tasks, inline diff checks on flagged
tasks during the build, and an unconditional full-diff security + reliability
assessment at review. The reliability half exists because untimeouted blocking waits
are the most common serious bug we ship — the rubric makes them un-shippable quietly.

## Model tiers

Design and final review run on your session's strongest model. `/feature-build` pins
itself to Opus. Inside the build: Sonnet implements, Opus reviews, Haiku runs
verification commands and inventories (never reviews, never decides). No Fable/Opus
access? Stages degrade to your session model — the pipeline still works.
```

Update the "## Smoke test" first item to: `1. /feature add a healthcheck endpoint →
brainstorming announces and asks a question (no code); approve the spec, then
/feature-build writes a flagged plan before any implementation.`

- [ ] **Step 3: Version bump.** `.claude-plugin/plugin.json`: `"version": "0.1.0"` → `"version": "0.2.0"`.

- [ ] **Step 4: Verify (structural + capability probe).**
```bash
cd /Users/eric/repos/engineering-flow
python3 -m json.tool .claude-plugin/plugin.json >/dev/null && echo manifest-ok
ls commands/  # expect: feature.md feature-build.md feature-review.md
ls skills/    # expect: build-journal execution-strategy secure-design smart-simplify track-coordinator
grep -rniE 'quinn|claw|robotcrab|192\.168|x\.ai|api[_-]?key|sk-ant|oauth' --exclude-dir=.git --exclude-dir=docs . && echo "SCRUB-FAIL" || echo "scrub-ok"
grep -rn "engineering-flow:secure-design" commands/ | wc -l   # expect ≥ 3 (all three commands reference it)
pkill -f "plugin validate" 2>/dev/null; sleep 1; timeout 60 claude plugin validate . || echo "validate hung/failed — fall back to manual structural check (already done above)"
```
Nesting probe (proves the platform capability feature-build relies on): dispatch via a Claude Code agent run from a scratch dir — `cd /tmp/ef-smoke && claude --plugin-dir /Users/eric/repos/engineering-flow -p "Use your Agent/Task tool to dispatch ONE subagent whose entire job is to dispatch its own sub-subagent that replies NEST-OK, and report what came back. If you cannot dispatch nested agents, say NEST-UNAVAILABLE." 2>&1 | tail -5` — expected: output containing NEST-OK (on this 2.1.174 machine). NEST-UNAVAILABLE here = finding to report, not to hide.

- [ ] **Step 5: Commit + push:**
```bash
git add -A && git commit -m "feat: v0.2 — pipeline docs, execution-strategy track output, version bump" && git push origin main
cd ~/repos/claude-knowledge && git add skills/general/execution-strategy && git commit -m "execution-strategy: track-coordinator output for engineering-flow nested mode" && git push 2>&1 | tail -1
```
(If claude-knowledge has no pushable remote from this machine, commit locally and note it.)

- [ ] **Step 6: Report** — file list, verification outputs (scrub, references count, nest probe), both commit SHAs.
