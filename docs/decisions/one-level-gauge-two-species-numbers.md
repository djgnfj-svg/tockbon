# One shared level gauge, and two numbers per species

**Status**: **twice reversed in part.** The level's **+1 clone** died with
[the swarm grows by a key](swarm-grows-by-a-key-not-a-level.md); the **spendable balance** died with
[the card price](card-price-removed.md). ⚠ **Both refutations were written only in the docs that made
them**, and this one kept saying `valid` for a day — the exact leak `CLAUDE.md` warns about.
**What still stands**: one gauge that fills from any food and is never spent, and a per-species total that
only rises and decides which cards appear.

## What was decided

A single level gauge fills from any food and is never spent; it grants **+1 clone and three cards** per
level. Alongside it each species keeps **a total that only rises** (it weights which species appear on the
cards) and **a balance that is spent** on parts.

## What wasn't chosen

| Rejected | Why |
|---|---|
| One combined level only | Simplest, but species stop meaning anything and the hunt stops being a choice |
| Species experience only, no shared gauge | One number doing growth and currency at once — tuning either one breaks the other, and clone count had nowhere to come from |
| A separate level-up per species | Strong reward for focusing one animal, but level-ups fire constantly and the run stops being readable |
| No levels — eating grants a part directly | Most immediate, and completely uncontrollable |
| Biomass only (agar.io) | Size and split count from one number. No build emerges from it |
| A single number per species, both weighting and spending | **Buying crocodile parts would make crocodiles stop appearing.** This is why the total and the balance are separate |
| Paying for a card out of a different species' balance at a 50% loss | Cut outright. It read as a tax on mixing species — the thing the game sells — while actually being a bailout nobody had to take. It also demanded a "pay with which species" panel that no other rule needed |

## What's tied to it

Clone count (levels are the only source), card weighting, and the claim that hunting a specific animal is
the real build decision.

## Conditions to reopen

If two numbers per species turn out to be unreadable on screen. The split itself is load-bearing; the
display is not.
