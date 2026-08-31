# `.candidates/` — every 시안 ever pulled, and **NOTHING here is ever deleted**

**One subject folder per thing that gets drawn.** Every candidate picture pulled for that subject
lives in it forever — the ones that won, the ones that lost, and the ones that were replaced later.

⚠⚠ **THIS FOLDER EXISTS BECAUSE THE LOSERS KEPT BEING THROWN AWAY** (2026-08-31, the user:
*"why does it keep pulling wolves and then deleting them from assets? Let us make an English-named
folder for the 시안 and collect the images there from now on. Do not delete them."*).

**What it cost before this folder existed**: twenty-two wolf candidates, the installed nine-frame
animation board, and the walk and bite boards were all gone from the working tree. They survived
**only by accident**, baked into Godot's import cache — which is gitignored, so one cache clear would
have ended them. They were decoded back out of that cache and put here.

## The rules, and there are four

1. **Nothing is deleted.** A losing candidate is the evidence for why the winner won. ⚠ **This is the
   opposite of `.prototypes/`**, whose README says the losers are deleted — that rule stays there and
   is not copied here.
2. **A picture keeps the name it was generated under**, seed included. The seed is how the same
   picture is pulled again.
3. **One subject, one folder.** `wolf/`, `swordsman/`, `bear/` — named after the thing, not the date.
4. **Dot-prefixed on purpose.** Godot imports everything under the project root, and a few hundred
   candidate PNGs in the import cache is cost for nothing. `.prototypes/` is dot-prefixed for the same
   reason. ⚠ **It is still committed** — only `.godot/` is ignored.

## What is NOT in here

- **What the game actually loads** — that is `assets/`, and a candidate is not an asset until it wins
- **The screenshots a decision was made from** — those are `docs/reference/`
- **The throwaway scenes that stand candidates up side by side** — those are `.prototypes/`
