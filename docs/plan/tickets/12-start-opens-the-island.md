Type: task
Status: resolved

# Pressing 시작하기 opens the ISLAND, and nothing in between

✅ **CLOSED 2026-08-28.** 시작하기 다음 화면이 섬이다. `Run._reset` no longer deals the opening round and
no longer leaves the run in `PICK`; the title is taken down by `_start_run` instead of by the card
screen the shell no longer walks through. **The cards, the eighteen items, the rarity draw and the
refit board are all untouched** — a win still deals a full round. Four nets moved with it, and
`net_shell` now measures **exactly one press** from launch to the island where it measured two.

## What closes it

**The next screen after the start button is the island.** No card round, no refit board.

## Why this ticket exists

⚠⚠ **THE WEEK'S ONLY GOAL IS THE MAP, AND TWO SCREENS STAND IN FRONT OF IT.** The user, 2026-08-27:

| What | The words |
|---|---|
| **The whole week** | ***"This week is just that one thing. I am happy if the map that comes up when I start the game is one I like."*** |
| **What start should do** | ***"Starting means the game starts, right then."*** |
| **Why the cards are in the way** | ***"There is not much to decide yet."*** |
| **What is wrong now** | ***"Something else is coming up right now. Get rid of that."*** |

**Today a run opens on a card screen.** `Run._reset` deals three cards and sets the state to `PICK`
before anything else happens, so the shell's start button hands the player a reward screen; taking a
card fills the held pile, which puts the run in `REFIT`; only 완료 opens the island. **Three presses
and two screens before the thing this week is about is on screen.**

## The rule this ticket keeps

⚠⚠ **DO NOT DELETE THE CARDS OR THE EQUIPMENT.** The eighteen items, the rarity draw, the tag combo
tiers and the refit board are this game's growth axis and they work. **Taking them off the START PATH
is a shell change; deleting them is starting over.** The user chose the cheap half.

⚠ **The refit board is also how a taken card becomes a fitted item.** Whatever skips the card round has
to leave the pile empty rather than leave an item stranded in it — `take_card`'s fork already reads
「is there anything in the pile」 for exactly this reason, and that fork is the thing to reuse.

⚠ **The title screen and its start button STAY.** The user said so in the same breath. This ticket is
about what happens AFTER the press, not about removing the press.

## What to watch for

⚠⚠ **The nets know the old path and several were repaired onto it TODAY.** `net_refit`'s and
`net_slots`' fixtures walk 시작하기 → card → 완료 to reach an island, and that walk is what took those
two nets from 56 and 9 passing to 198 and 105. **A change here moves those fixtures again.** Do it in
the same round, or the repair that just landed goes red for a reason nobody will remember.

## Open, and the user answers it

**Does the card round come back later in the run, or not at all this week?** Skipping it at the OPENING
is one line; removing it from the post-win reward as well is a different change, and the reward path is
what `net_run` and `net_cards` measure. This ticket assumes **the opening only** until told otherwise.
