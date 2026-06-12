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
diff range (base-sha → head-sha; additionally exclude docs/builds/ from the diff: `git diff <base> <head> -- . ':(exclude)docs/builds'`), the flags column, and prior concerns.

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
