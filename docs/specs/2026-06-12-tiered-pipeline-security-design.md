# engineering-flow v0.2 — Tiered Pipeline, Security Posture, Nested Execution

**Date:** 2026-06-12 · **Status:** approved direction (Eric, conversation) · **Supersedes:** extends the v0.1 kit (spec 2026-06-11)

## Context

v0.1 ships a single `/feature` command that sequences the superpowers chain on whatever
model the session runs. Eric wants: (1) model tiering — the strongest model (Fable-class)
for design and final evaluation, Opus for plan-writing and execution management, Haiku for
mechanical work, Sonnet for implementation; (2) security posture woven through design,
build, and review — selective per-task security review during the build, full assessment
at the end; (3) exploitation of subagent nesting (Claude Code ≥ 2.1.172: subagents can
spawn subagents, 5 levels deep — CLI only, the Agent SDK remains depth-1).

## Decisions (Eric, 2026-06-12)

- **Architecture: staged three-command backbone** (not a single-command nested
  orchestrator). Rationale: stage boundaries are the model handoffs AND the user's
  review gates; a headless orchestrator subagent cannot ask the user anything mid-build;
  long builds outlive one subagent context; peers on CLI < 2.1.172 still work.
- **Nesting is used INSIDE the build stage** when the dependency analysis justifies
  parallel tracks — never as the backbone.
- **Security depth: selective + final.** Plan tasks touching sensitive surfaces are
  flagged; the Opus orchestrator reviews those diffs inline; the final stage runs a
  full-feature assessment regardless.
- **Haiku: execution without judgment.** Verification runners and inventory scouts only.
  Never reviews, never decisions.

## The three commands

| Command | Model | Responsibility |
|---|---|---|
| `/feature <idea>` | inherits session (run your best model) | superpowers:brainstorming with secure-design questions folded in → spec with a MANDATORY "Security & Reliability Considerations" section → user spec review → "now run `/feature-build`" |
| `/feature-build` | `model: opus` (frontmatter pin) | superpowers:writing-plans (with `[SEC]`/`[REL]` task flags + per-flag acceptance notes) → engineering-flow:execution-strategy → execution (below) → "now run `/feature-review`" |
| `/feature-review` | inherits session | adversarial closeout: spec-coverage table, cross-task integration seams, full security+reliability assessment per the secure-design rubric, verdict + findings with confidence + follow-ups. Evaluates only — builds nothing. |

`/feature` (stage 1) replaces the v0.1 command body; stages 2–3 are new files. Each
stage opens by locating its input artifact (stage 2: newest approved spec; stage 3: the
plan + the diff range recorded in the build journal) and stops with a clear error if
it's missing — stages are re-runnable and order-enforcing.

## Execution model inside `/feature-build`

**Tier table (embedded in the command, not a skill):**

| Role | Model | Notes |
|---|---|---|
| Plan writing, orchestration, inline security review | opus (the command's own loop) | |
| Track coordinators (nested mode) | opus | one per independent track |
| Implementers | sonnet | per task, fresh subagent |
| Spec-compliance + code-quality reviewers | sonnet / opus respectively | as in superpowers two-stage review |
| Verification runners | haiku | run the plan's EXACT verify commands, report raw output verbatim, no interpretation |
| Inventory scouts | haiku | enumerate files/symbols for the plan writer; facts only |
| BLOCKED escalation | re-dispatch one tier up | per superpowers handling rules |

**Flat mode (default, and the fallback):** the Opus loop dispatches implementer →
reviews per task, exactly like superpowers:subagent-driven-development, with Haiku
verification runners for the plan's verify steps.

**Nested mode (parallel tracks):** when execution-strategy recommends parallel AND the
CLI supports nesting (runtime check: CLI version ≥ 2.1.172; on failure of the first
nested dispatch, fall back to flat mode and say so), the orchestrator dispatches one
**track coordinator** (opus) per independent track. Each coordinator follows the
engineering-flow:track-coordinator skill: owns ONLY its track's files (per
execution-strategy's ownership analysis), runs the implement → spec-review →
quality-review loop internally (its own nested dispatches), uses an isolated worktree
when tracks share a repo (superpowers:using-git-worktrees), and reports a structured
result. Coordinators never touch another track's files and never talk to the user —
anything needing a user decision is returned to the orchestrator as BLOCKED.

**Inline security review:** after each `[SEC]`-flagged task's reviews pass, the
orchestrator (not a subagent) reviews that task's diff against the secure-design
rubric's review section and records the verdict in the build journal. `[REL]`-flagged
tasks get the reliability rubric the same way.

## New skills (and what was rejected)

### `skills/secure-design/SKILL.md` — security AND reliability rubrics, one source of truth

Three sections consumed by different stages:
1. **Design-time questions** (stage 1): trust boundaries, data classification/handling,
   authn/z model, secrets lifecycle, injection surfaces, third-party/dependency risk,
   blast radius of compromise.
2. **Flagging criteria** (stage 2 planning): `[SEC]` = task touches input parsing,
   authn/z, secrets, network listeners/clients, exec/subprocess, file permissions,
   crypto, deserialization. `[REL]` = task adds blocking waits, locks/queues,
   retries, state machines, resource acquisition, cross-process coordination.
3. **Review rubrics** (build inline + stage 3): security — input validation, output
   encoding, least privilege, secrets exposure, path traversal/SSRF, injection, error
   message leakage, audit logging; reliability — **every blocking wait has a timeout**,
   every external call a failure path, stuck-state recovery, idempotency, partial-failure
   cleanup, race windows.

The reliability half is earned by direct evidence: two untimeouted-semaphore bugs found
in one day (the IPC main-hop hang and the speech-FIFO wedge) — exactly the class a
`[REL]` rubric catches at review time.

### `skills/track-coordinator/SKILL.md` — the contract for nested level-2 coordinators

A coordinator subagent's operating rules: scope = its track's file-ownership set, nothing
else; internal loop = implement (sonnet) → spec review → quality review with fix-and-
re-review until clean; verification via haiku runners; worktree isolation when tracks
share a repo; commit discipline (per-task commits, track branch when worktree'd);
escalation = return BLOCKED with specifics rather than improvise outside scope;
report format = per-task status, SHAs, review verdicts, deviations, concerns. Exists
because a protocol-following subagent needs its protocol in a referenceable document —
the same reason superpowers ships prompt templates.

### `skills/build-journal/SKILL.md` — durable build state and resume protocol

The orchestrator maintains `docs/builds/<feature>-journal.md`: per-task status, commit
SHAs, review verdicts, security/reliability check results, open concerns, and the diff
range for stage 3. Updated after every task (and every track report in nested mode).
`/feature-build` checks for an existing journal at start → resume mode (skip completed
tasks, continue). Earned by direct evidence: today's session survived context
summarization and machine handoff only because durable docs (HANDOFF.md) existed;
long builds deserve the same by construction, and stage 3 needs the journal to know
what to assess.

### Rejected (deliberately, YAGNI)

- **model-tiering skill** — the tier table is small and only `/feature-build` consumes
  it; embedded in the command. A skill would be indirection without reuse.
- **final-review rubric skill** — stage 3 is its only consumer; the rubric lives in the
  command body (it references secure-design for the security/reliability parts rather
  than duplicating them).
- **debugging/verification skills** — superpowers already ships systematic-debugging and
  verification-before-completion; duplicating upstream is drift waiting to happen.

## Changes to existing pieces

- `commands/feature.md`: becomes stage 1 only (brainstorm + spec); folds secure-design
  design-time questions into the brainstorming instruction; requires the spec's
  Security & Reliability section; hands off to `/feature-build`.
- `skills/execution-strategy/SKILL.md`: gains a short "track coordinator mapping"
  note — when recommending parallel, name the tracks and their file-ownership sets in
  coordinator-consumable form. (Upstream copy in claude-knowledge gets the same edit —
  Eric's copy and the kit's must not drift.)
- `README.md`: new pipeline diagram (3 stages + models + nesting), Security Posture
  section, tier table, nesting version note (≥ 2.1.172, falls back flat), updated smoke
  test (stage commands).
- `plugin.json`: version 0.2.0.

## Degradation paths (kit must stay shareable)

- No Fable access → stages 1/3 run the session's best model; pipeline unchanged.
- No Opus access → stage 2's pin falls back to the session model (Claude Code behavior
  for unavailable model pins is verified at implementation; if a hard error, the command
  documents removing the pin).
- CLI < 2.1.172 → nested mode unavailable; flat mode always works.
- The Agent SDK is out of scope (depth-1 there; this kit targets the CLI).

## Testing

- Structural: `claude plugin validate`, JSON manifests parse, three commands + four
  skills listed, scrub greps clean (same gates as v0.1).
- Rubric integrity: stage 1/3 commands and the build command reference
  `secure-design` by its plugin skill name; grep-verified.
- Behavioral smoke (manual, documented in README): run `/feature` with a toy idea in a
  scratch repo through one full cycle on this machine — verify the model pin engages in
  stage 2 (`/status` shows opus), a `[SEC]` flag appears in a plan when the toy idea
  touches input parsing, the journal file exists and stage 3 reads it.
- Nested-mode smoke: a toy plan with two disjoint-file tasks → verify a track
  coordinator dispatch succeeds on this CLI and the fallback message appears when
  nesting is artificially disabled (env guard in the command text).

## Out of scope

Single-command nested orchestrator (revisit if interactive subagent gates ever ship);
auto-switching the session model (platform constraint); SDK support; CI integration of
the pipeline; vendoring superpowers.
