---
name: execution-strategy
description: Evaluate a plan's task dependencies to determine serial vs parallel execution — builds a dependency graph, identifies the critical path, and recommends the right approach without asking
version: 1.2.0
category: general
tools: [Read, Glob, Grep]
tags: [execution-strategy, serial, parallel, dependency-graph, plan-execution, task-ordering, subagent, orchestration]
use_when:
  - plan has been written and approved, before execution begins
  - deciding between serial, parallel, or hybrid execution
  - evaluating whether to use subagent-driven-development vs executing-plans
  - user asks "should we parallelize this?"
model: opus
mandatory: false
---

# Execution Strategy — Serial vs Parallel Decision

## Purpose

After a plan is written and approved, determine the right execution approach — serial (inline), parallel (subagent-driven), or hybrid — based on the actual dependency structure of the tasks. This replaces asking the user which approach they want with an informed recommendation backed by analysis.

## When to Use

- Immediately after a plan is approved and before execution begins
- When evaluating whether to use subagent-driven-development vs executing-plans vs inline
- When the user asks "should we parallelize this?"

## The Analysis

### Step 1: Build the Dependency Graph

For each task in the plan, identify:

1. **Files touched** — which files does this task create or modify?
2. **Imports required** — does this task depend on functions/exports created by another task?
3. **Data dependencies** — does this task need output (schema, config, test fixtures) from another task?

Map these into a directed acyclic graph (DAG):

```
Task 1 ──→ Task 2 ──→ Task 3 ──┬──→ Task 4
                                ├──→ Task 5
                                ├──→ Task 6
                                └──→ Task 7 ──→ Task 8
```

### Step 2: Identify File Ownership Conflicts

**This is the gate for parallelism.** Two tasks can run in parallel ONLY if:

- They modify **different files** (no overlapping file ownership)
- They don't depend on each other's outputs
- They can commit independently without ordering issues

Common conflict patterns:

| Pattern | Parallel? | Why |
|---------|-----------|-----|
| Both modify the same source file | No | Concurrent edits create merge conflicts |
| Task B imports a function Task A creates | No | B fails until A is committed |
| Task A modifies backend, Task B modifies frontend | Usually yes | Different files, independent compilation |
| Both modify the same test file | No | Same file conflict |
| Both add new files in different directories | Yes | No overlap |
| Task A creates a DB table, Task B writes to it | No | Schema must exist first |

### Step 3: Find the Critical Path

The critical path is the longest chain of sequential dependencies. Everything else is potential parallelism.

Measure:
- **Critical path length** — how many tasks must run sequentially no matter what?
- **Parallel window** — how many tasks could overlap after the critical path converges?
- **Task duration** — are the parallelizable tasks substantial (>10 min each) or trivial (<5 min)?

### Step 4: Evaluate Coordination Cost

Parallel execution has real overhead:

- **Branch coordination** — concurrent commits to the same branch risk ordering conflicts
- **Worktree management** — isolated worktrees need merging afterward
- **Review complexity** — reviewing interleaved changes is harder than a clean sequence
- **Failure recovery** — if one parallel agent fails, the others may need to be aware
- **Context fragmentation** — each subagent starts fresh without the previous task's context

This overhead is only worth paying when the parallelism saves significant time.

### Step 5: Make the Recommendation

Use this decision matrix:

```
                          Parallel window exists?
                         /                       \
                       Yes                        No
                      /                             \
              Tasks >10 min each?              → SERIAL (inline)
               /            \                    No parallelism possible.
             Yes              No
            /                   \
    File ownership clean?    → SERIAL (inline)
       /           \           Tasks too small to justify
     Yes            No         coordination overhead.
    /                 \
→ PARALLEL           → SERIAL (inline)
  (subagent-driven)    File conflicts make
  Non-overlapping      parallel unsafe.
  file ownership,
  substantial tasks.
```

**When in doubt, recommend serial.** The cost of a race condition or merge conflict exceeds the time saved by parallelism. Parallelism is worth it when you have genuinely independent workstreams of substantial size.

### Output for coordinators (engineering-flow nested mode)

When recommending parallel/hybrid, define each track in coordinator-consumable form:

- **Track <name>**: tasks [list], owns files [explicit path list], depends on tracks
  [list or none]

A track's ownership set must be disjoint from every other track's. If you cannot make
the sets disjoint, the tasks are not parallel — say so and recommend serial.

## Output Format

Present the analysis concisely:

```markdown
**Dependency graph:**
Tasks 1→2→3 (sequential — same file)
After 3: Tasks 4, 5, 6 (independent files) → 7 (cleanup)

**Critical path:** 5 tasks sequential (1→2→3→4→7)
**Parallel window:** Tasks 4, 5, 6 after task 3 (~15 min savings)
**File conflicts:** Tasks 4 and 7 both touch ws.js

**Recommendation: [Serial/Parallel/Hybrid]**
[1-2 sentence rationale]
```

## Hybrid Approach

Sometimes the right answer is hybrid — sequential for the core chain, then fan out for independent work:

1. Execute tasks 1-3 inline (critical path, shared files)
2. Dispatch tasks 4, 5, 6 as parallel subagents (independent files)
3. Execute task 7 inline after agents complete (needs their output)

Only recommend hybrid when:
- The parallel window has 3+ tasks of >10 minutes each
- File ownership is cleanly separable
- The sequential prefix is short enough that waiting for it doesn't negate the benefit

## Anti-Patterns

- **Parallelizing for the sake of it** — 3 tasks of 5 minutes each save at most 10 minutes but add 5-10 minutes of coordination overhead. Net zero or negative.
- **Parallel edits to shared files** — even with "careful" coordination, this creates subtle bugs. If two tasks touch the same file, they're sequential. Period.
- **Ignoring transitive dependencies** — Task C depends on Task B which depends on Task A. C cannot run with A even though they don't directly depend on each other.
- **Optimistic file ownership** — "they'll probably only touch different parts of the file" is not clean ownership. Same file = sequential.

## Field notes: subagent-driven execution at scale

Calibration from a large multi-phase build (a full Astro/MariaDB site, ~7 phases, dozens of plan tasks, executed via `superpowers:subagent-driven-development`):

- **Dispatch one cohesive, independently-shippable slice per subagent — not one plan-task.** A 5-entity admin plan had ~44 fine-grained tasks; an implementer + two reviewers each is wasteful. Group into slices that each leave the app working and form one reviewable unit ("all DB queries", "the litters admin slice", "galleries"). ~8 dispatches instead of ~44, same quality.
- **Land all shared-file work in one early slice.** Files many slices touch (a `queries.ts`, the admin sidebar, shared schema) cause contention. Do them up front (e.g. one "all queries" slice) so later per-entity slices don't collide — and run the slices serially since they edit shared files.
- **Review the template slice hard, then spot-check the clones.** When N slices mirror one pattern, review the first thoroughly (the rest copy it), then reduce later reviews to the logic-bearing files (parsers, endpoints), not the identical scaffolding.
- **Right-size the two-stage review (spec → quality).** For mechanical/foundation slices the controller can do both directly by reading the diff with full plan context; reserve subagent reviewers + a final **most-capable-model aggregate review over the whole diff** for logic-bearing/risky slices — the aggregate pass catches cross-slice bugs the per-slice reviews miss (it caught a real ordering bug on this build).
- **Commit per slice; push behind the review gate.** Implementers commit locally but **don't push**; the controller pushes a slice only after its review passes — keeps the remote review-gated with clean rollback points, and avoids half-applied remote state.
- **Execute continuously.** Don't check in between tasks of an approved plan; only stop on a genuine blocker.
- **Ops/deploy phases are NOT subagent-driven.** Interactive infra work (SSH, DNS, secrets, server config) is done hands-on by the controller — subagents can't reliably access or verify external systems, and it needs real-time judgment.

## Integration with Other Skills

After determining the execution strategy:
- **Serial** → Use `superpowers:executing-plans` or execute inline
- **Parallel** → Use `superpowers:subagent-driven-development` with file ownership boundaries from the dependency analysis
- **Hybrid** → Execute the sequential prefix, then dispatch subagents for the parallel window
