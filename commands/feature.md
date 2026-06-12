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
