# Design-doc review — what runs first, and how the docs hold each other

**Status**: ready — **review only, and the user has since closed every decision it was waiting on**
**One line**: ~~the milestone chain has **three gaps left** — the two bosses, the rune lock, an ending —
and they must land in that order because **the lock cannot go in before the bull exists.**~~
⇒ **All three landed in that order. The chain has no gap left in code — and it is now literally walkable**:
`3.done/monster-placement-stage1.md` (written after this review) stands the mobs **and both bosses** on the
map before you arrive, so nothing in the chain needs a debug key. What remains of the milestone is a
playthrough (`docs/GDD.md` "First milestone"). **Landed is not accepted** — none of it has been seen on
screen by the user. **This doc is now a record of the order, not a queue.**

**Source**: `docs/GDD.md` "First milestone" (the chain and its gap table) ·
[planning-review-fixes.md](planning-review-fixes.md) (items 3 · 5 · 6, still open).
**Do not duplicate those.** This doc adds only **order** and **what went stale since.**

Checked against code, not against the docs' own claims: `src/actor/monster_defs.gd` ·
`src/actor/spell_circle.gd` · `src/sim/spell_sim.gd` · `src/stage/terrain_map_generated.gd` ·
`src/actor/progress.gd`.

---

## The order

The chain (GDD): `map → wood wall → pit ① → bull → fire rune → water rises, escape → wood wall → rooster → water rises → gate`

| # | Do | Why here | Size |
|---|---|---|---|
| ~~0~~ | ~~Look at water on screen~~ | **Dropped by the user.** Water took too long ⇒ **unlimited jumping underwater is all that is needed now**, and the pour · current · escape **get pulled back out and looked at when that work reopens.** The price: steps 2–4 build on an unaccepted base, and **the water part of the chain (rising water in ① and at the end) is unproven until then** | — |
| ~~1~~ | ~~Decide who pours pit ①'s water~~ | **Decided by the user — take the reward, then the side wall collapses and water comes in.** `3.done/stage1-bosses` owns it now ("the way out of the pit"), and it lands as part of the bull. **Review item 3 is closed** | — |
| ~~**2**~~ | ~~**The two bosses**~~ | **Built, not accepted** → `3.done/stage1-bosses`. ~~Zero code — `monster_defs.ALL` is still `[PIG, HEN]`~~. It was the largest remaining piece and steps 3–4 had nothing to attach to without the bull; both now do | large |
| ~~**3**~~ | ~~**The lock pair — ~~two~~ **three** changes, one landing**~~ | **Built, not accepted** → [rune-lock-and-receiving.md](../3.done/rune-lock-and-receiving.md). **The third is the palette** (`palette_layout.items_of(KIND_RUNE)` returns `ELEM_ALL` unconditionally, so locking `DEFAULT_RUNE` alone is void). **And "no receiving screen" was wrong** — `circle_window.gd:158-161` has always placed runes; what is missing is ownership. **Was three, then two after the user dropped the ignition gate, and is three again for a different reason** | medium |
| ~~**4**~~ | ~~**The gate (an ending)**~~ | **Built — the chain's last square** → [`3.done/gate-ending-to-game.md`](../3.done/gate-ending-to-game.md), design [`design/gate-ending.md`](../../design/gate-ending.md). ~~No doc owns it~~. "Small" held: **one string, one argument, one branch** on top of the settlement screen it was waiting on (`3.done/run-end-settlement.md`). **Screen unverified — the arch and the clear title have not been looked at** | small |

**Off the chain, and both landed while this review sat**: `3.done/bolt-speed-and-visibility` ·
`3.done/triangle-circle-to-game`. **Implemented, screen unverified** — what is left of each is a look, not a build.

**The three-pick is no longer one of them.** While this review was being written another session finished
`levelup-and-three-picks` **A through E**, and the user accepted it ⇒ the doc is in `3.done/`.
**That changes step 3 below**: the receiving screen it needed already exists.

### Why step 3 is one landing and not separate items

**The starting kit is fixed: the none rune and the basic circle** (decided by the user).
So two of `planning-review-fixes`'s open items are **the same lock seen from two sides**:

```
DEFAULT_RUNE = ELEM_FIRE      →  the player already has fire    (review 1, still true in code)
no screen to receive a rune   →  so fire cannot be handed over  (review 6)
```

**Fix one alone and the game gets worse, not better:**

- Lock the rune to none **without the bull built** ⇒ the pit never opens and the run dead-ends
- Lock the rune **without a receiving screen** ⇒ the bull's reward has nowhere to go (one rune slot, no stash)

⇒ **Both, after the bull exists.** That is why step 3 follows step 2.

**The third one was dropped** (decided by the user). A runeless blast does ignite wood
(`spell_sim.gd:633` — `element` reaches the FX and never the ignition), **and it doesn't matter**:
the wood wall is beyond pit ①, the pit only opens with the water the bull brings,
⇒ **you are already carrying fire by the time you can stand in front of that wall.**

**Write down what this costs**, because it is a real price paid knowingly: **the lock now rests on the map's
shape, not on a rule.** Put a second route into ②, or hand the player a way out of the pit that isn't the
bull, and **the wood wall stops being a lock the same day** — with nothing in code to complain.

~~**Scope of the receiving screen**: the GDD already pinned it — the minimum rune-receiving path, not the
three-pick window. That is a subset of `levelup-and-three-picks` Stage E; the rest of E stays cut.~~
 **Void — there is no receiving screen to scope** (see the confirmed box below). The paragraph is kept
only because the town/tutorial sentence under it is still live.

**And it shrinks again** (decided by the user): **the starting kit is handed over in town**, and **usage is
taught by a tutorial** ⇒ this screen covers **only the bull's fire rune.** Town is cut from this week, so
**code holds the fixed none-rune-plus-basic-circle directly** until town exists (`design/town.md`,
"the starting kit is handed over here"). **The tutorial has no doc and no owner** — it is now carrying the
GDD's "the rule is taught in onboarding" as well.

~~**And then it mostly stopped being work at all.** Stage E shipped: the pick window already hands something
over and makes you place it. ⇒ What remains for the fire rune is a rune-shaped card in that same window.
**Confirm before building** that the window's card and placement path are not glyph-only.~~

 **Confirmed, and the answer changed the plan twice.** The three-pick window **is** glyph-only
(`three_pick.draw()` draws from `Glyph.ALL` · `_draw_card` indexes `Glyph.DEFS` · `_gui_input_step2` calls
`place_glyph`, and `ELEM_FIRE == 0 == GLYPH_NONE` makes a rune id indistinguishable from "no glyph").
**But the rune card is not needed at all** — the premise "there is no screen to receive a rune" was wrong:
**`circle_window.gd:158-161` has always placed runes** (pick from the palette → click the rune seat).
⇒ **What is missing is not a screen but ownership**, and the palette is where the lock actually lives
(`palette_layout.gd:73-74` offers `ELEM_ALL` unconditionally).
**The whole of it is in** [rune-lock-and-receiving.md](../3.done/rune-lock-and-receiving.md).

---

## Where the code is, in three lines

| Claim in a doc | Code today |
|---|---|
| `DEFAULT_RUNE` must become none | `spell_circle.gd:50` — **still `ELEM_FIRE`** |
| ~~the blast must carry element~~ | `spell_sim.gd:633` — `element` reaches `_notify_blast` (the FX) and never the ignition ⇒ a runeless blast burns wood. **Left as is on purpose** (above) |
| stage-1 bosses | `monster_defs.ALL == [KIND_PIG, KIND_HEN]`. **No bull, no rooster** |

---

## Docs that disagree with the code — fix while passing, they are cheap

| Where | Says | Actually |
|---|---|---|
| ~~`design/README.md`, "Three-pick screen" · "Level · XP"~~ | ~~Impl `none`~~ | **Fixed** — A·B·C are in the tree (`progress.gd` · `three_pick.gd` · `xp`/`money` columns · `net_progress`). Both rows now read `partial`, and D·E are named as the absent part |
| `3.done/levelup-and-three-picks.md`, "the tree is shared right now" | another session added `KIND_ROOSTER` and `contact_damage` | **Neither is in `monster_defs`.** The warning reads as live and isn't — it is a note from a moment, left standing in a doc that is now `3.done` |
| `GDD.md` TBD, "seed distribution" | stage 1 is **312×126 tiles** | **400×48** (`terrain_map_generated.gd:12`). The GDD's own milestone section says 400×48 ⇒ **the GDD contradicts itself in two places**, and the TBD one is the stale copy |

**None of these change what to build.** They change what the next session *believes* is built, which is
the same failure `design/README.md`'s header section was created to prevent.

---

## How the docs hold each other

```
GDD  "First milestone" ── the chain, and the only acceptance
 │
 ├── 3.done/stage1-map-layout ──── terrain · wood wall · pit ① is a bedrock bowl
 │        ▲                        (acceptance 3·4 still unconfirmed on screen)
 │        │ three-way constraint, and the hole is in the middle
 ├── 3.done/stage1-bosses ─────── bull in ① · rooster in ③   "there is no water in ①"
 │        │
 ├── 2.active/water-jump-and-escape ── "scope is right after boss ③"
 │                                     ⇒ nobody owns ①'s water  → step 1 above
 │
 └── 3.done/levelup-and-three-picks ── Stage E is the repo's ONLY receiving screen — **and it is built**
          ▲                              ⇒ the fire rune reuses it instead of needing one
          │
     1.ready/planning-review-fixes ── items 3 · 5 · 6 open, all three inside the chain

off the chain: 3.done/bolt-speed-and-visibility   (built — all that is left is the screen)
               3.done/triangle-circle-to-game     (built — all that is left is the screen)
```

**The one relationship worth remembering**: `stage1-bosses` and `levelup-and-three-picks` look unrelated —
one is monsters, one is a menu — and **the fire rune ties them together.** The bull's whole purpose is to
hand over a rune, and there is nowhere to put it. **The milestone cut the three-pick believing it was outside
the chain**; it is not, and step 3 is where that shows.

---

## TBD

- ~~**Who pours pit ①'s water**~~ → **decided by the user.** Take the reward, then the side wall collapses.
  `3.done/stage1-bosses` owns it
- **Whether the lock pair stays in this milestone at all.** It is the honest alternative: ship the chain with
  fire from the start (the wall opens, nothing is locked), and lock it after the bosses land.
  **The GDD's acceptance ("start once and reach the end without getting stuck") passes either way** — what fails
  is "the midboss is the key to progression", which is a GDD thesis, not this week's acceptance
