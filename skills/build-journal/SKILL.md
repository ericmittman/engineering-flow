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
