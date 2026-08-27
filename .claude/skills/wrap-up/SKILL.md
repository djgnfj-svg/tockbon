---
name: wrap-up
description: Closes out the session. Repairs the docs that drifted, runs the nets, and commits. Use whenever the user's message contains 마무리 — "마무리", "마무리하자", "마무리했어", "마무리 좀" — or says "wrap up".
---

# Wrap-up

## Why this skill exists

**The work finishes and the state never changes.** That is the failure that repeats every time.

A feature is built and its ticket is still `claimed`; a file is deleted and the doc pointing at it isn't fixed.
The next session starts believing all of it.

So wrap-up is not "commit" — it is **repairing the documents this session knocked out of line.** The commit
is the last line, and it is where this skill stops.

⚠⚠ **The goal is exactly two things: fix what drifted, then commit.** Anything that is not a document
gone wrong is not this skill's business.

## Order

### 1. Sweep what actually finished this session

Walk back through the conversation and list **what is genuinely done.** Built, fixed, deleted, decided.

"Almost done" is not done. Do not mix done and not-done.

### 2. Repair the docs that drifted

In order of how easily each is missed:

- **Ticket status** — is a finished ticket still `claimed`. If you resolved it, did the map's
  decisions table get its line too
- ⚠⚠ **The roadmap's status column** — `docs/plan/roadmap.md` gives every row a state
  (✅ done · ⏳ in progress · ⬜ not started · ⏸ folded). **Anything that actually finished this
  session gets its row flipped to ✅.** A row left unflipped is how the next session concludes the
  work never happened
- **Dead references** — does any doc or comment still point at what you deleted or renamed this session
- ⚠⚠ **`CLAUDE.md` — do NOT touch it here.** Not to edit it, not to measure it, not to propose lines for
  it. It loads into every session and every agent, so it grows every time a wrap-up decides something
  "belongs" in it. **Only the user adds to it, and only when they say so.** If something really has to
  land there, name it in the report and stop
- ⚠ **Acceptance — ask once, and the answer decides.** Ask the user whether they looked at it.
  **They always answer one way or the other, so do not infer it from anything else.**
  ⚠⚠ **There is no acceptance-debt file any more.** It held these rows until the user deleted it on
  2026-08-26; the rule that replaced it is in `CLAUDE.md` — **the user's own words go verbatim into the
  ticket on the live map that they belong to.** Do not recreate the deleted file.
  - **They looked** → **their own words go into that ticket that turn, verbatim**, and whatever the ticket
    was open on is struck. ⚠⚠ **Verbatim, not a paraphrase** — the sentences that lived only
    inside design docs died with them on 2026-08-22, and they were the only measurement this repo had of
    whether a game of its own was any good
  - **They did not look, or the session put something on screen and they said nothing** → **add a row to
    the ticket it belongs to**: what shipped · **how to see it** · when it landed. ⚠ **Silence is a row,
    not a pass**
  - **They looked and it was wrong** → that closes a row exactly as a pass does, and **the wrong words are
    the valuable ones** — write them down the same way
  ⚠ **The "how to see it" column is the whole point** — the user works this list off **in one sitting**,
  weeks later, and will not re-derive how to reach each thing. Name the screen, the key, and what should
  look different
- **Memory** — **delete what became wrong this session.** Do not add. Anything that can live in the repo
  lives in the repo

For each item, **say you checked it, or say it doesn't apply.** Do not skip silently.

### 3. Turn what the user decided into tickets

⚠⚠ **This is part of wrapping up, not a separate errand** (2026-08-27, the user: *"what you do on
your own is what comes after the conversation is finished — tidying, sorting the commit, adding things,
splitting into tickets"*).

**Walk the conversation for anything the user decided that no ticket holds yet.** A direction they
named, a piece of work they asked for, a judgement they passed on something they looked at.

- **A new piece of work** → write it as a ticket at `docs/plan/tickets/NN-<english-slug>.md`, numbered
  on from the last, and put its number in the roadmap's week table
- **The answer is code** → `Type: task`. **The answer is what to build** → `Type: grilling`, and the
  user answers it in conversation. ⚠⚠ **A question the user must answer never becomes a `task`**
- **A judgement they passed** → **their own words, verbatim, into the ticket it belongs to**
- ⚠ **The full procedure — the bar, the two look-ups, the shape — lives in `breakdown`.** Use it when
  a whole chunk needs splitting; what is here covers the loose pieces one session produces

### 4. Clear the loose images

**The user pastes reference screenshots and they land in the repo root** as `image.png`,
`image copy.png`, `image copy 2.png`. **They pile up and nobody ever goes back for them.**

```
ls image*.png image*.jpg 2>/dev/null
```

- **A shot the user decided something from** → **move it to `docs/reference/`** and rename it
  `YYYY-MM-DD-what-it-shows.png`. That is what makes it findable two weeks later
- **Everything else** → delete it
- ⚠⚠ **Count them and ask before deleting.** Which shots mattered is the user's call, not yours —
  say how many there are and what each looks like it shows
- ⚠ **The root `image*.png` is gitignored, so a loose shot is invisible in `git status`.** Listing
  the directory is the only way this step sees them at all

### 5. Run the nets

```
powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1
```

It's fast, so run it once more before committing. **Never commit red.**

If it fails, stop the commit and take it to the user. Do not fix the net to make it pass.

### 6. Commit — **and stop here**

- **Commit straight to `main`. Do not branch, do not ask** — that is settled for this repo (decided by the
  user). **Asking is itself friction**: "ask if on main" was written into this skill once, so it was asked,
  and the reply was *"why are you suddenly checking — we already settled that wrap-up means main"*
- Check what actually goes in with `git status`. Anything unintended mixed in
- Commit message follows this repo's way: **Korean, and it says what was done and why**
- ⚠ **Do not push.** Only when the user says so explicitly

### 7. Report

- What finished this session
- **What didn't, and why**
- Candidates to pick up next

## Do not

- **Do not write unfinished as finished.** The moment a doc says "done", the next session believes it
- Do not commit with nets red
- Do not carry on past the commit
