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
