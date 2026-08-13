# `1` calls the swarm to the host, and `3` is what sends it somewhere

**Status**: valid — decided by the user 2026-08-14. **Reverses a rule the prototype shipped and defended.**

## What was decided

**`1` gathers every clone at the host**, and the gathering point moves with the host. **`3` sends the swarm
at the mouse point**, where it stays and fights. The two together replace one key that did half of each job.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **`1` places a rendezvous on the ground** (what the prototype shipped) | The user read the key as "come to me" and could not use it as "go there". A command whose name has to be explained is the wrong command |
| Folding both into one key with a modifier | Three swarm keys already fit under the left hand; a modifier buys nothing and costs a rule |
| Keeping the placed rendezvous **and** adding `3` | Two keys that both mean "go there" and none that means "come here" |

## What's tied to it

**The argument the old rule was protecting** — that recalling to the host lets the player park in cleared
ground while the clones bear the whole return trip. It was written into `swarm.gd`'s header and into the
GDD, and it is a real tension.

⇒ **`3` inherits it.** The key that sends the swarm into ground the host is not standing in is the key that
gets clones killed, and a clone killed out there still takes its cargo and its force with it. **The tension
moved keys; it was not deleted.** If play shows it did get lost, this is the doc to reopen.

⚠ **The first version of this doc claimed `swarm.gd::command_rally` and `cell-game.md` "were both edited".
They were not, and an adversarial review found it the same day.** The paragraph in `cell-game.md`'s *Harvest*
was edited; **the one in its *Screen* section and the comment in `swarm.gd:34-36` were not.**
⇒ **A decision doc asserting a code edit is the same failure as asserting acceptance** — it reads as done and
nobody opens the file. **The code comment is plan 2's job** (`hands-and-commands`, *`1` — rally to the host*)
and is not done until that plan is built. This doc records the decision; it does not record the work.

## Conditions to reopen

**Play shows the swarm is never in danger** — if `3` goes unpressed and the round trip stops costing
anything, the placed rendezvous was carrying more than it looked.
