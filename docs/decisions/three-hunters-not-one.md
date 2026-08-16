# Three species walk at you, not one

**Status**: valid — 2026-08-16.

## What was refused before, and is now partly done anyway

When the field grew to seven species the user refused **"여섯 개가 타이머로 걸어오는 것"** — a field where
several species march at the player on a clock. `Rules.SPECIES_HUNTS` came out of that with **exactly one
row set**: the lion, under `HOST_SPEED` so walking away always works.

**That is now three**: 사자 · 들쥐 · 들개. The refusal was not overturned wholesale and it was not forgotten;
it was narrowed. What the user actually refused was *being marched at with no answer*. What is built is:

| species | speed | what it costs you | the answer |
|---|---|---|---|
| 들쥐 | 90 (0.45×) | 2–3 damage, a tenth of a bar | kill it; it dies to one opening bite |
| 들개 | 180 (0.90×) | 12–16, and it comes three at a time at the *nearest body* | rally, or retreat |
| 사자 | 190 (0.95×) | half a bar, capped | walk away |

**Every one of the three is under `HOST_SPEED` 200**, which is the guarantee `SPECIES_HUNTS`' own comment
already made for the lion. Retreat is open at every moment against all three. That is the whole of why this
is not the thing that was refused.

## Why it was necessary

The measured opening was that **nothing in the game arrived and was safe to fight.** Everything that walked
at you (사자, 보스) took the host from full to dead on one touch, and everything killable either stood still
(까마귀) or fled (다람쥐 · 말 · 치타). `tools/look/probe_run.gd` measured 83% of a run with nothing killable
on screen and a 150-second gap between two kills — the user's *"도저히 게임이 진행이 안 돼. 잡을 수가 없어요."*

**들쥐 is the species that fixes it**, and it can only fix it by hunting: a thing that comes to you and is
safe to fight is the one shape the field had none of. 다람쥐 already occupies "walks around, harmless,
flees" and adding another of those changes nothing.

## What was NOT taken

- **No species above `HOST_SPEED` hunts**, and none may. The refusal binds there and it is where the
  original one-line guarantee lives.
- **The boss still does not consult `SPECIES_HUNTS` at all** — it has its own clock (`BOSS_HUNT_AT`) and its
  own arena, and it is the only thing in the game you cannot walk away from. That is deliberate and
  unchanged.
- **코끼리 · 말 · 치타 · 토끼 · 멧돼지 do not hunt.** Five of eleven walk at nothing.

## What is unmeasured

**Whether three feels like six.** The refusal was about a feeling and only the user can say whether this
crossed it. Nobody has played the field with 들개 in it — the probe's bot never survives to 45s with a swarm,
so the dog's own beat is asserted by nets and unexercised by play.

Related: [[august-scope-two-species]] — the same split (a species can be on the field without dropping a
part) is what made this cheap enough to try.
