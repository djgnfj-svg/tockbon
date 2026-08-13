# The host's parts come from cards; a clone's come from what it killed

**Status**: valid — decided by the user 2026-08-14.

## What was decided

**Two paths, and they never cross.**

- **The host** takes parts **only from level-up cards.** Finishing a corpse pays the host cells and nothing
  else
- **A clone** wears a part **rolled off the corpse it finished**, with no card and no choice

⇒ **The host is chosen, the swarm is grown.** That sentence was already in the GDD; this is the rule that
makes it true rather than decorative.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **The host also rolling a part off a corpse** | Then the card is redundant — the same part arrives free, faster, and without the slot decision that makes taking a card hurt |
| **Cards for clones too** | Forty pauses. The clones' whole character is that nobody chose for them |
| **Corpses paying nothing** | The corpse is the meal, and the meal is the beat ([why](eating-a-kill-takes-time.md)) |

## What's tied to it

- **The card pool rolls from what has been eaten**, and eating is the host's only route into it. Break this
  and the pool's one lock stops meaning anything ([why](card-price-removed.md))
- **`PART_DROP_CHANCE` is a clone-only number.** Naming it as a general drop rate is how the host path leaks
  back in
- **The forty-different-creatures screenshot** is entirely on the clone path

## Conditions to reopen

**If the swarm's parts turn out to be invisible in play** — the clone path is the one carrying the picture,
and if it reads as nothing, the question is whether it should exist at all, not whether the host joins it.
