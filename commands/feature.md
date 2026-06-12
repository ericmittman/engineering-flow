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
