# The run-end screen is settlement only — one screen, no run summary

**Status**: valid

## What was decided

A run ends on **one screen**, and that screen does **one thing**: settle what the run leaves behind
(run-scoped numbers → what the town keeps). Death and clearing both go through it.

**No run summary of any kind on it** — not the magic circle you ended with, not a route, not a kill list.

**Two figures are printed beside the settlement**: total play time and total damage dealt
(`../plans/3.done/run-end-settlement.md`). They are not a summary in the rejected sense — **the only thing
that animates is the currency counting up**, and those two do not scroll, expand or break down.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A run summary — a snapshot of the magic circle you assembled** | It was proposed as the one thing that would make this game's result screen not look like every other roguelike's. **The user cut it**: the screen settles, it does not report |
| A second screen (settle, then summary) | **One screen.** Two screens make the end of a run a sequence of menus |
| A cause-of-death shot (Spelunky/Noita) | Death and clearing share this screen; a death-only picture doesn't fit it |
| Settling inside the town instead (a shelf, a board) | Would remove the screen entirely — the fork above is about what the screen holds, not whether it exists |
| **The end-of-content notice in the town instead** (added later — the "지금은 여기까지" lines a cleared stage must say) | The town's only text channel is `_town_message`, a debug HUD line already flagged as noise. Putting the one message that must not be missed on the surface already flagged as noise is the worst option — **and the moment has passed**, the player has pressed the button and walked into another room. Its own beat between the panel and the town was refused by the "second screen" row above |

## What's tied to it

- **The screen has nothing to show unless something converts.** With settlement as its only job, a run with
  no boss kill settles nothing and the screen is blank. What actually converts is the next question
- `docs/design/town.md`'s TBD **"do death and clearing look different"** now lands *on this screen*, not in the room
- **The end-of-content notice does not reverse this.** It is two static lines that never scroll, expand or
  break down, and — the deciding point — **they say nothing about the run.** They are a statement about the
  build: a run that ends the same way twice prints the identical two lines. The banned thing is a *run report*
  (`../plans/3.done/stage-clear-sequence.md`)

## Conditions to reopen

The circle snapshot comes back only if the town later needs a record of past runs (a compendium of builds).
That is a town fixture, not this screen.
