# engineering-flow

An opinionated engineering workflow for Claude Code: the
[superpowers](https://github.com/anthropics/claude-plugins-official) discipline chained
end-to-end, plus the connective tissue that makes it run itself.

## What you get

```
skill-router nudges ─▶ /feature ─▶ brainstorming ─▶ spec ─▶ writing-plans
        ─▶ execution-strategy (serial vs parallel, decided not asked)
        ─▶ subagent execution (spec review + quality review per task)
        ─▶ smart-simplify pass on Stop ─▶ finished branch
```

- **/feature `<idea>`** — one command runs the whole pipeline, honoring every gate.
- **skill-router** (PreToolUse hook) — pattern-matches your shell commands and nudges
  the right skill ("running tests? write the failing test first"). Extend it without
  forking: `~/.claude/skill-routes.local.conf`.
- **execution-strategy** (skill) — after a plan is approved, builds the task dependency
  graph and decides serial vs parallel execution instead of asking.
- **smart-simplify** (Stop + PostToolUse hooks + skill) — after multi-file changes, the
  session can't end without a simplification pass over what changed.

## Install

```bash
git clone https://github.com/ericmittman/engineering-flow && cd engineering-flow
./install.sh          # add --dry-run to preview
```

Or manually, inside any Claude Code session:

```
/plugin install superpowers@claude-plugins-official
/plugin marketplace add ericmittman/engineering-flow
/plugin install engineering-flow@engineering-flow
```

## Smoke test

1. `/feature add a healthcheck endpoint` → you should see "I'm using the brainstorming
   skill" and get a clarifying question, not code.
2. Edit three files in one session, then stop → the Stop hook demands a simplification
   pass before the session ends.
3. Run `npm test` (or pytest/go test) → the router nudges test-driven-development.

## Uninstall

`/plugin` → remove engineering-flow (and superpowers if you want). Nothing else to
clean — this kit never touches your settings.json.

## Extending the router

Add lines to `~/.claude/skill-routes.local.conf` (created by you, survives kit
updates): `pattern | skill | path | description`, where pattern is a grep -Ei regex
matched against your Bash commands. Route to any skill you have installed.

## For the author (adoption-back)

If you previously ran these hooks from `~/.claude/settings.json` directly: remove the
personal skill-router/accumulate-simplify/smart-simplify-stop entries after installing
the kit (one router, one simplify pair — never both), and migrate personal routes to
`~/.claude/skill-routes.local.conf`.
