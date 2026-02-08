# Delegating Tasks to Cline

## Setup

- System prompt: `Base/cline/guide.md` — general instructions, code style, restrictions
- Task file: `Base/cline/taskNNN.md` — specific assignment
- Result file: `Base/cline/resultNNN.md` — completion report (Cline writes this)
- Launch: "Используя инструкции из `Base/cline/guide.md`, выполни задание из `Base/cline/taskNNN.md`"

## Task Design Principles

### Good tasks (concrete, limited scope)
- **Write code by spec**: "Write function X with this signature and behavior" — one file, clear spec
- **Move code**: "Move these functions from A to B" — two files, mechanical
- **Write tests**: "Write tests for module X following TestConv as example" — one new file
- **Fix specific issues**: "Fix tests X, Y, Z — expected values should be ... because ..." — provide reasoning
- **Research**: "Find out why test X fails" / "What depends on module Y?" — report only, no code changes

### Bad tasks (avoid these)
- "Fix compilation" — open-ended, Cline may pull in wrong dependencies or modify wrong files
- "Make it work" — no clear scope
- Any task where the fix path is unclear and may touch many files

### Key rule
If a task requires architectural understanding (e.g. knowing that Apus.Common is a donor module being phased out), either:
1. Provide that context explicitly in the task file
2. Or do that part yourself and give Cline only the mechanical work

## Task File Structure

```markdown
# Task NNN — Brief title

## Goal
What needs to be done (1-2 sentences)

## Context
Why this is needed, what the user should know about surrounding code

## Steps
1. Specific step
2. Another step

## Rules
- What NOT to change
- Scope limitations

## Files you may modify
- Explicit list of files

## Completion
Write report to `Base/cline/resultNNN.md`
```

## Reading Results

1. Read `Base/cline/resultNNN.md` — Cline's self-report
2. Run `git diff` — see actual changes made
3. Check `Base/tests/test_results_64.txt` and `test_results_32.txt` if tests were run
4. Verify Cline stayed within scope (didn't modify unexpected files)

## Common Pitfalls (from real experience)

### Task 001: "Fix TestStrings compilation and failing tests"
**What went wrong:**
- Cline modified 4 files outside scope (Types, Common, Classes, Core) to "fix compilation"
- Added 26 lines of type aliases re-exporting from Apus.Core into Apus.Types — unnecessary
- Modified Apus.Common (the donor module we said not to touch)
- Changed Apus.Classes dependency graph (added Apus.Core to uses)
- Did NOT write result file as instructed
- Report was vague — no specific test names or counts

**What went right:**
- Actual fixes in Apus.Strings.pas were legitimate (UTF8.IsValid overlong detection)

**Lesson:** "Fix compilation" is too open-ended. Cline will chase dependency chains and add aliases/uses everywhere. Better approach: diagnose the problem ourselves, then give Cline specific code-level fixes.

### General pitfalls
- Cline doesn't understand the refactoring context (old vs new modules) unless told explicitly
- "Fix compilation" tasks cascade into modifying unrelated modules
- Cline may add type aliases or uses clauses to "solve" compilation — this changes architecture
- File restrictions in the task are NOT enough — Cline ignores them under pressure to "make it compile"
- Always verify with `git diff` — Cline's self-report may omit files it changed
- Cline may not write the result file — check for its existence
