# Core defense is off — the hands were idle, and that is what the genre is

**Status**: valid (2026-08-12). **Shelved, not disproved** — the structure below is complete and could be
picked back up whole.

## What was decided

**Tower-defense is dropped**, and the magic circle goes with it. The direction is now a **busy minimal
roguelike** — the Vampire-Survivors / Brotato shelf — where the player kills things with their own hands.

The reason is one sentence from the user: **"the hands being idle would drive me mad."**

⇒ That is not a flaw in the design below. **Automatic defenders are what defense-genre means.** Soldiers
that fight on their own, towers that shoot on their own, workers that build on their own — every one of
them takes work away from the player's hands, which is the point of the genre and the thing the user cannot
sit through.

**And it removes the magic circle's job.** The circle was a part fitted onto things that run themselves.
With nothing running itself, there is nothing to fit it to.

**It also lines up with why the last game died**: the user likes melee, and eight months went into a game
that did not give them any.

## What wasn't chosen

Everything below was settled in conversation and is shelved intact.

| Piece | What it was |
|---|---|
| Soldiers | Come out of a **summoning circle** continuously and on their own. Walk out, fight, die. No population, no supply, no orders |
| Towers | **Built, not summoned** |
| Workers | **You start with a few.** Count rises only by taking `worker +1` at a choice node, so throughput competes with circles for the same node |
| Magic circles | Won as a reward, **fitted into a tower**, and **the bullet changes with the circle in it** |
| Build time | **The worker's walk is the build time.** No timer UI. A worker who dies stops the building. Walls take longest, so the worker is exposed longest |
| Placing a site | Ordinary tower-defense UI. Numbered bar at the bottom, press one, click the map |
| No prep phase | Wave ends → drops absorbed automatically → level-up → handed a circle → **pick the next wave from two branches** |
| The two branches | Marked by **reward**, not by enemy. Money or a guaranteed item. **The better reward sits on the harder branch** |

**What was never solved, and is why it fell**: what the player's body does while a wave runs. The only
answer reached was "click to place a build site", which is a few clicks a wave.

The adversarial pass also had it: **soldiers and towers do the same job**, safe placement removes the
worker-death risk on its own, and a reward-marked fork is a skill check rather than a choice.

## What's tied to it

- **`next-game.md` is half void.** Its "core defense" framing, the summon/build/fit loop and the December
  scope all assumed this
- [The circle modifies the tower](circle-modifies-the-tower-not-fires.md) and
  [Not everything is a magic circle](one-noun-for-everything.md) are **both moot** while this is shelved.
  They stay valid *inside* the shelved design
- [No leaving the core to fight](no-leaving-the-core-to-fight.md) is **effectively reversed** — the new
  direction is the player's hands doing the killing. Its stated reason, two deep systems in twelve weeks,
  no longer applies once the defense half is gone
- **`tools/pixel/` glyph work is not needed** for now. The legibility risk it was going to test belonged to
  the circles

## Conditions to reopen

The new direction turns out to need something automatic on the field, or the hands-busy version proves thin
and the fork rewards are what was actually wanted.
