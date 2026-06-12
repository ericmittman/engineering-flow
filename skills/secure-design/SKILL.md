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
