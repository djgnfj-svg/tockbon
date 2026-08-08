---
name: harness-audit
description: Inspects this repo's harness (CLAUDE.md, .claude/agents/, .claude/skills/, tests/) and reports problems. Use when the user says "하네스 평가" "하네스 점검" "감사" "지금 상태 어때" "제대로 돌아가나" "audit the harness", or asks for a full harness review. Reports only; fixes nothing.
---

# Harness audit

## Absolute rule

**Fix nothing.** Do not create, modify or delete any file.

Find problems and report them. The user reads and decides what to fix. Not even "this one's obvious, let's just fix it."
Once the auditor starts fixing, the next audit is auditing its own work.

## Second rule: do not grade generously

This harness was usually built by you. Your own work looks good. So:

- **No evidence means "unverified".** Not a pass.
- To write "this is in good shape", write down what you looked at to conclude that.
- Never write "works" about something you didn't run.

## Checklist

### 1. Dead references

Does what a doc points at actually exist. This repo got burned badly by this before — code comments referenced
`SKILL.md`, `설계 §8`, and `test_cell_grid_auto.gd`, none of which existed.

- Do the paths named in `CLAUDE.md`, skills and agent definitions exist
- Do the docs and tests referenced by `src/` comments exist
- When a skill names another skill or agent, does that name exist

### 2. Does it run

"Exists" and "runs" are different.

- Actually run `tests/run_nets.ps1` and look at the result. Record pass count and elapsed time
- If hooks are configured, confirm they actually fire
- If an agent definition exists but has never been used, record that

### 3. Role gaps and overlaps

Put the agent definitions side by side.

- **Gap**: is there work nobody owns
- **Overlap**: do two agents do the same thing. Do their boundary statements contradict
- **Boundary leak**: does each "never do" list pair with the other agent's "do" list

### 4. Triggers

A skill with a mismatched description is never invoked. That is the most common failure.

- Does the description contain **words the user would actually type**. Is it a trigger phrase, not a summary
- Is it written in third person
- Do two skills' triggers overlap so it's ambiguous which fires

### 5. Bloat

- `CLAUDE.md` — fully loaded every session. Length is a per-session cost
- Skill body — 500 lines is the ceiling. Over that, split into references/
- Is it explaining what you already know. That is pure waste

### 6. Fake harness

The most dangerous item. **Written as present, does nothing in reality.**

- A net exists and nobody runs it
- A rule is written with nothing enforcing it
- A hook is configured and nobody notices when it fails
- A verifier exists with empty acceptance criteria

This is worse than absence, because it makes people believe it's there.

## Report format

```
## Summary
One paragraph. What the harness actually prevents right now.

## Problems
Worst first. Per item:
- What is wrong
- Evidence (file · line, or run output)
- What happens if it isn't fixed

## Unverified
What you couldn't check, and why.

## Sound
Briefly, with evidence.
```

If there is no problem, say so. Do not manufacture findings. But **be suspicious of an empty "Unverified"** —
it claims everything was checked, and usually it wasn't.
