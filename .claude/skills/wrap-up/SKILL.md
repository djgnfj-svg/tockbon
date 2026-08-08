---
name: wrap-up
description: Closes out the session. Reflects what actually finished into the docs, runs the nets, and commits. Use when the user says "마무리" "마무리하자" "정리하고 끝내자" "커밋하고 끝" "wrap up".
---

# Wrap-up

## Why this skill exists

**The work finishes and the state never changes.** That is the failure that repeats every time.

A feature is built and left in `2.active/`; a file is deleted and the doc pointing at it isn't fixed;
something learned never reaches memory. The next session starts believing all of it.

So wrap-up is not "commit" — it is **making the docs match reality.** The commit is the last line.

## Order

### 1. Sweep what actually finished this session

Walk back through the conversation and list **what is genuinely done.** Built, fixed, deleted, decided.

"Almost done" is not done. Do not mix done and not-done.

### 2. Make the docs match reality

In order of how easily each is missed:

- **`docs/plans/` status moves** — is a finished doc still sitting in `2.active/`. If you moved it, did you fix the `**Status**:` line inside too
- **Dead references** — does any doc or comment still point at what you deleted or renamed this session
- **`CLAUDE.md`** — does a structure or rule that changed this session need to land here. Keep it short
- **Memory** — **delete what became wrong this session.** Do not add. Anything that can live in the repo lives in the repo

For each item, **say you checked it, or say it doesn't apply.** Do not skip silently.

### 3. Run the nets

```
powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1
```

It's fast (tens of ms), so run it once more before committing. **Never commit red.**

If it fails, stop the commit and take it to the user. Do not fix the net to make it pass.

### 4. Commit

- **Commit straight to `main`. Do not branch, do not ask** — that is settled for this repo (decided by the user).
  **Asking is itself friction** — "ask if on main" was written here once, so it was asked, and the reply was
  "왜 갑자기 확인하지, 마무리하면 main인 걸로 했었는데"
- Check what actually goes in with `git status`. Anything unintended mixed in
- Commit message follows this repo's way: **one Korean sentence.** What was done and why, visible

### 5. Report

- What finished this session
- **What didn't, and why**
- Candidates to pick up next

## Do not

- **Do not write unfinished as finished.** The moment a doc says "done", the next session believes it
- **Do not push.** Only when the user says so explicitly
- Do not commit with nets red
