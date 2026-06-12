---
name: smart-simplify
description: Stack-agnostic code simplification triggered by the smart-simplify Stop hook after substantial changes
category: code-review
version: 1.0.0
mandatory: false
use_when:
  - hook triggers simplification pass after multi-file code changes
  - code complexity review after feature implementation
  - reducing complexity before PR creation
tags: [simplify, code-review, hooks, quality, refactoring, PostToolUse, Stop]
tools: [Read, Grep, Glob]
---

# Smart Simplify

Perform a simplification pass on files you just changed. This skill is
typically invoked by the smart-simplify Stop hook — not manually.

## Context Detection

Before simplifying, determine the project context:

1. **Read CLAUDE.md** if it exists in the project root — it contains
   project-specific coding conventions and patterns.
2. **Detect the primary language** from file extensions (the hook message
   tells you).
3. **Read surrounding code** in the same directory to understand local
   conventions (naming, error handling, structure).

## Universal Principles

These apply to ALL languages:

### Eliminate Unnecessary Complexity
- Remove dead code (unreachable branches, unused variables, commented-out blocks)
- Flatten deeply nested conditionals (early returns, guard clauses)
- Replace verbose patterns with idiomatic equivalents for the language
- Consolidate duplicated logic into shared functions

### Reduce Cognitive Load
- Ensure each function does one thing
- Replace magic numbers with named constants
- Simplify boolean expressions (de Morgan's, double negation)
- Replace complex ternaries or nested conditionals with clear if/else

### Minimize Surface Area
- Remove unnecessary abstractions (YAGNI)
- Collapse single-use variables that don't aid readability
- Remove unnecessary type assertions or casts

### Improve Names
- Rename variables/functions whose purpose is unclear from their name
- Follow the project's naming convention (from CLAUDE.md or neighboring files)
- Replace abbreviations that are not universally understood

## Language-Specific Guidance

Apply these ONLY to files of the matching language:

### TypeScript / JavaScript
- Replace `any` with proper types where the type is clear from context
- Use optional chaining (`?.`) and nullish coalescing (`??`) to collapse null checks
- Prefer `const` over `let` when not reassigned
- Simplify Promise chains to async/await when it reduces nesting
- Remove unnecessary `else` after `return`

### Go
- Use early returns to reduce nesting
- Simplify repetitive `if err != nil { return err }` chains where a helper would be clearer
- Use `errors.Is`/`errors.As` over string comparison
- Prefer named returns only when they aid documentation
- Simplify struct initialization (omit zero-value fields)

### Python
- Use comprehensions where they are clearer than loops
- Replace manual resource management with context managers (`with`)
- Use `pathlib` over `os.path` for path manipulation
- Use f-strings over `.format()` or `%` formatting

### Bash
- Quote all variable expansions (`"$VAR"` not `$VAR`)
- Use `[[ ]]` over `[ ]` for conditionals (when bash-specific is acceptable)
- Replace `cat file | grep` with `grep file`
- Use `"${var:-default}"` for defaults instead of if/else
- Ensure POSIX/macOS compatibility (no GNU-only flags)
- Use `case` statements over long if/elif chains for string matching

### 6502 Assembly (NES)
- Eliminate redundant loads (LDA/LDX/LDY when register already holds the value)
- Combine sequential STA operations where possible
- Use zero-page variables for frequently accessed state
- Simplify branching (remove branches that always/never fire)
- Use page-aligned data tables for performance-critical lookups

### YAML / Configuration
- Remove commented-out configuration blocks
- Ensure consistent indentation (match the rest of the file)
- Remove duplicate keys
- Simplify overly verbose structures

## Critical Constraints

### DO NOT re-trigger
After making simplification edits, you are done. The Stop hook has a
one-shot marker that prevents re-triggering. Do not manually invoke this
skill a second time in the same session.

### DO NOT change behavior
Simplification must preserve existing functionality. If unsure whether a
change preserves behavior, leave the code as-is and note it:
```
Note: Potential simplification in [function], but behavior preservation
uncertain. Leaving as-is.
```

### DO NOT over-abstract
Do not introduce new abstractions (base classes, wrapper functions,
utility modules) during a simplification pass. Flag them as suggestions
for follow-up if warranted.

### DO NOT touch files you did not change
Only simplify files listed in the hook message. Do not scan the entire
project for simplification opportunities.

### Keep changes minimal
Each simplification should be obviously correct. If a change requires
more than 30 seconds of thought to verify correctness, skip it.

## Output Format

For each file simplified:

```
Simplified [file_path]:
  - [what was simplified and why]
```

If no simplifications were needed:

```
Reviewed [file_path]: no simplifications needed.
```
