# Bigger monsters — what 1.5× actually costs

**Status**: ready
**One line**: the user says monsters read too small. The box can grow, but **the art has to be regenerated
from scratch** (the seeds cannot reproduce the same beast at a new size), the 60Hz cost roughly doubles,
and **one tuned constant silently stops working.**

**Design doc**: [../../design/monsters.md](../../design/monsters.md) — "Size — go big" and its own
"Build at this size anyway, **then measure and adjust**" (user decision). This is that adjustment.
**Preceding doc**: [../3.done/stage1-bosses.md](../3.done/stage1-bosses.md) — where the bull's box, the
padding trick and the first cost measurement came from.

**Nothing here is implemented. `src/`, `tests/` and `assets/` are untouched.**

---

## 1. Target sizes

Both dimensions must be a multiple of 4 (`net_monster._defs_preconditions`, the cell size).
**1.5× lands exactly on both bosses** — pig and hen have a dimension that is `4 × odd`, so they round.

| Kind | Now | Exact ×1.5 | **Proposed** | Real factor (w / h) | Aspect error |
|---|---|---|---|---|---|
| 돼지 pig | 44×32 | 66×48 ✗ | **68×48** | 1.545 / 1.500 | +3.0% |
| 닭 hen | 24×28 | 36×42 ✗ | **36×44** | 1.500 / 1.571 | −4.5% |
| 황소 bull | 88×56 | 132×84 ✓ | **132×84** | 1.500 / 1.500 | 0 |
| 거대 수탉 rooster | 72×80 | 108×120 ✓ | **108×120** | 1.500 / 1.500 | 0 |

**Why not another factor.** Every current dimension is already a multiple of 4, so a factor `f` lands
cleanly only where `dim × f` stays a multiple of 4. `f`=1.25 breaks the pig (55px) outright. `f`=2 lands
everywhere — see §3, it is the only factor that needs no new art, and it is also the one that costs 4×.
**1.5 is the best grid fit above 1.0 that is not 2.**

Alternatives if a dimension is disputed: pig **64×48** (−3.0% aspect, same error the other way, smaller);
hen **36×40** (−5.0%). Neither changes anything below materially.

---

## 2. The regeneration path — confirmed from the code, not from the summary

`tools/pixel/gen.py` `PRESETS["monster"]` is the path. Reading its own header comments:

- **Local ComfyUI** (`config.json` → `comfy_root`, FLUX.2 klein). Zero pixellab credits. `--lora 0`.
- **The preset deliberately carries no `size`/`down`** — "every monster has a different box … **the caller
  supplies `--width/--height/--down`**".
- **Generate at exactly 4× the target.** Not "draw big and downscale" like every other preset — 16× and 8×
  were measured and **fail to fill the box** (41×24 came out of a 44×32 slot); `k_centroid` picks a block's
  dominant color, so a larger factor eats legs and outlines wholesale.
- **Chroma-green ground, cut afterwards** with `tools/pixel/cutbg.py` (white ground punched a hole straight
  through the white chicken).

Generation sizes that make `run_one`'s `dh = round(down × raw.h / raw.w)` land on the target exactly:

| Kind | `--width` | `--height` | `--down` | → |
|---|---|---|---|---|
| pig | 272 | 192 | 68 | 68×48 |
| hen | 144 | 176 | 36 | 36×44 |
| bull | 528 | 336 | 132 | 132×84 |
| rooster | 432 | 480 | 108 | 108×120 |

All four divide exactly. **A side benefit**: the bull now generates at 528px, past the 512 line the preset
comments call FLUX's form-breakdown floor — the art may come out *better*, not just bigger.

### The seeds do not carry over. This is the real cost.

- **Seeds survive only in filenames** (`boss_bull_05_seed1882469963_96px.png`, `boss_rooster_*`,
  `mon_pigA_farm/`…). `tools/pixel/out/` is **gitignored** — they exist on this machine only.
- **The prompt text is recorded nowhere in the repo.** Not in `README.md`, not in `monsters.md`, not in
  `stage1-bosses.md`, not in a log (`out/_comfy.log` is 0 bytes). Only the preset's *style* clause is committed.
- **And even with both, a seed does not reproduce the same animal at a different resolution.** FLUX's
  latent geometry changes with the canvas.

⇒ **Regenerating means the user re-picks four monsters that look different from the four they already
approved.** That is a user-time cost and a taste risk, not a compute cost. It is the single biggest reason
to consider §3 instead.

### There is no tool that lands a png on the box contract

`cutbg.py` trims to the opaque bbox and pads all four sides equally. The contract is not symmetric:
`minx + maxx == w−1` (a horizontal flip lands in place) **and `maxy == h−1`** (feet on the bottom row).
The bull was fixed **by hand** — 86×54 placed at (1,2): 1px each side, 2px on top, **0 at the bottom**.

⇒ Doing this four times by hand invites the exact arithmetic slip the bull already made once.
**Propose a small `tools/pixel/fit_box.py`**: trim → pad to a given W×H with all vertical slack on top and
the horizontal slack split evenly, erroring if the slack is odd. Three lines of arithmetic, and it makes
the contract a tool instead of a habit.

### The 21 animation sheets go stale — and they are pixellab, not local

`assets/monster/` holds **27 pngs**; only the four `*_body.png` are wired in (`fx_tuning.MONSTER_SHEETS`).
The other 21 (`pig_walk` 9f, `bull_gore`, `rooster_leap`, …) are generated and **unused** — nothing in
`src/` or `tests/` names them, so **no net goes red today.**

But they were made with **pixellab `animate_image` from the standing frame** — `tools/pixel/README.md`:
"**this is the one thing local cannot do**", the walk LoRA is human-only. Change the standing frames and
all 21 are wrong-sized and derived from a beast that no longer exists.

⇒ **~21 pixellab generations of rework, deferred to whenever animation lands.** Not a cost today. It is a
cost that grows the longer the size question stays open, which argues for deciding it **now** rather than
after animation is wired.

---

## 3. The alternative that needs no art at all: ×2

**Nearest-neighbour doubling of a pixel-art png is lossless** — each source pixel becomes a 2×2 block, no
resampling, no broken pixels. It is the same trick `tools/pixel/README.md` already names for the blast
("`flash_px` 72/36 is **exactly 2×**, so generating the small one and doubling it covers both").

**Both alignment contracts survive doubling, provably:**
- `minx′ + maxx′ = 2·minx + (2·maxx+1) = 2(minx+maxx) + 1 = 2(w−1) + 1 = 2w − 1 = W − 1` ✓
- `maxy′ = 2·maxy + 1 = 2h − 1 = H − 1` ✓

So ×2 (pig 88×64, hen 48×56, bull 176×112, rooster 144×160) keeps **the exact art the user already picked**,
costs zero generations, zero credits, zero re-picking, and the 21 animation sheets double just as cleanly.

**Reject it on cost, not on art**: cells go ×4, not ×2.25 (§4) — the rooster alone would eat ~24% of the
60Hz budget and 20 pigs would exceed it outright. And the monsters' pixels become twice the size of the
player's, on a screen where the player is 20×32 at zoom 1.

**Named but not recommended, third option**: raise the play zoom. `stage.gd`'s `ZOOM_STEPS[0] = 1.0` is
"the play scale". Adding `2.0` at the front makes **everything** bigger — player, monsters, terrain — for
zero art, zero sim cost and zero net breakage beyond the camera clamp. It also halves the visible world to
480×270 world px, which is probably fatal for a game about blowing holes in terrain. **Worth one screenshot
before committing to regeneration**, because it answers "things look small" more cheaply than anything else here.

---

## 4. Cost — projected from the measurements that already exist

The baseline is the boss-box profile left in `src/actor/monster_defs.gd` (verify-run: 600 frames warmed,
3 runs, one `world.frame()` per frame; empty frame 81–93µs; 60Hz budget 16,667µs).

Box cells = `(w/4) × (h/4)` when aligned (add one row and column when straddling — the pig's `~108` in that
comment is the straddling count, `88` the aligned one).

| Kind | cells now | cells after | ×area | measured now | **projected** | % of 16,667µs |
|---|---|---|---|---|---|---|
| pig | 88 | 204 | 2.32 | +220µs | **~510µs** | 3.1% (was 1.3%) |
| hen | 42 | 99 | 2.36 | *never measured* | **~250µs** | 1.5% |
| bull | 308 | 693 | 2.25 | +570µs | **~1,283µs** | 7.7% (was 3.4%) |
| rooster | 360 | 810 | 2.25 | +1,010µs | **~2,273µs** | 13.6% (was 6.1%) |

**The number that should decide this is not the boss.** `MAX_MONSTERS` is 20 (a value the user set):

| Scene | Now | After ×1.5 | After ×2 |
|---|---|---|---|
| 20 pigs | 4,400µs (26%) | **10,200µs (61%)** | 17,600µs (**106% — over budget**) |
| bull + rooster together | 1,580µs (9%) | **3,556µs (21%)** | 6,320µs (38%) |
| rooster alone | 1,010µs (6%) | 2,273µs (14%) | 4,040µs (24%) |

**Three honesty notes on those projections:**

1. **Linear-in-cells is an assumption, not a measurement.** `monster_defs.gd` says so itself: the rooster
   costs **1.6× the bull on only 17% more cells**, and nobody has isolated why (`speed_px` 200 vs 140 →
   more `Body.move_x`/`move_y` sub-steps per frame is the suspect). If the extra cost is per-sub-step
   rather than per-cell, ×1.5 is **cheaper** than the table above. If it is superlinear, it is worse.
   **verify-run must re-measure, not trust this table.**
2. **The 60Hz budget is already contested.** `docs/design/monsters.md` "There are two budgets":
   water's **acceptance 7 (FPS) is open as a failure**, and the scene this game is built for is
   "the forest burns while water pours and monsters swarm". 20 pigs at 61% is that scene's monster share alone.
3. **The nets get slower too.** `net_monster_slam` already runs 600 ticks of a real bull on the real baked
   map and was cut from 4000 specifically because the round crossed CLAUDE.md's 10s line. 2.25× the cells
   per tick lands straight back there. **harness-manager, not a free cost.**

---

## 5. What else is pinned to these numbers

### ✗ Breaks — `MOVE_SLAM.ignite_spread_cells` (the one real casualty)

`src/actor/boss_ai.gd` `MOVE_SLAM`: `ignite_spread_cells` was **6, and it was 3 before that.** The 3 → 6
correction is written up at length — at 3 the outer fire points landed at ±8 cells = ±32px, **inside the
bull's own 44px half-width**, and verify-look saw "the bull is standing on a small fire" instead of "the
impact threw fire outward". 6 puts them at ±14 cells = **±56px**, clearing 44px with margin.

**At 132px wide the half-width is 66px. 56 < 66. The ring goes back under the body — the exact bug, restored.**

⇒ raise to **`ignite_spread_cells` = 8** (outer pair at ±(2·8 + 2) = ±18 cells = **±72px**, clearing 66px
with the same kind of margin 6 gave 44px). Three edits in one change:
`boss_ai.gd`'s constant, its comment's arithmetic, and **`net_monster_slam.gd:718-719`** — that check
hardcodes `center_cx ± 14` and labels it "몸 절반너비(11칸)를 벗어난다". At the new box the half-width is
16.5 cells, so **the check would stay green while its label became false** — a fake net by CLAUDE.md's own
definition. The literals and the label move together.

### ✓ Strengthens — charge confinement

`boss_ai.gd:79-84`: `carve_r`=3 digs a hole `2r+1` = **7 cells** tall; the bull needs all **14** rows of a
column clear to advance into it, so it can never enter what it just carved. At `h_px`=84 that is **21 rows**
vs the same 7. Confinement gets *more* structural, not less.
⇒ **Comment only** — "the bull's own box (`h_px`=56 = 14 cells)" becomes 84 = 21 cells.

### ✓ Improves — the gore dead band

`MOVE_GORE.range_px`=120 against a box-overlap reach of `(88+20)/2` = **54px** leaves a documented ~66px
band where gore commits and cannot land (Risk 8-addendum). At 132 wide the reach is `(132+20)/2` = **76px**
and the band shrinks to ~44px. ⇒ **Comment only**, but it moves a named open tuning choice.

### ⚠ New — the rooster stops fitting under one map feature

Scanned `src/stage/terrain_map_generated.gd` (400×48 tiles, 1 tile = 8 cells = 32px). **The map has only
three ceilinged pockets anywhere**, and room ① is **open-topped** (columns tx230–258 are clear all the way
to row 0), so a taller bull has unlimited headroom where it fights.

| Pocket | Floor | Headroom | 84px bull | 120px rooster |
|---|---|---|---|---|
| tx 149–150 (bedrock block over the left plateau) | ty 20 | **96px** | fits (12px) | **blocked** (fits today at 80px, 16px clear) |
| tx 345–346 | ty 25 | 128px | fits | fits (8px) |
| tx 347–366 | ty 25 | 384px | fits | fits |

Not fatal — it is a 2-tile decorative overhang, not a corridor — but a 120px rooster walking the left
plateau now stops there, and **a leap needs 120 + ~40px apex = ~160px**, which only the third pocket gives.

### ⚠ New — the debug spawn key silently fails nearer the top of the map

`world_step.spawn_monster` rejects the whole box outside the grid, and `stage._spawn_monster_at` centres
the box on the mouse. A rooster now needs the cursor **≥60px** from the top edge (was 40px) and ≥66px from
the left/right (was 36px) or the press does nothing. Behaviour is unchanged, the dead zone just widens.

### ✓ Unaffected, checked

- **Slam apex** — 32px flat / 39px in room ①, against room ①'s **64px** left step. Apex is a `y` delta from
  `jump_vy_px`; **`h_px` does not enter it.** The feet still fall 25–32px short of the step. Confinement holds.
- **Slam horizontal travel** (60–100px) and the rooster's own 130–170px — driven by `leap_speed_mult`, not the box.
- **`step_cells`** and `_pig_and_hen_cross_the_ledge_differently` — the ledge contract is a `step_cells`
  property; the table column does not move. (The *loop caps* were measured against the current boxes — see §6.)
- **`monster_view` / `fx_tuning`** — the hp bar width and position already derive from `Defs.w_px`; the
  silhouette shader fills the sprite. Nothing hardcodes a box size on the view side.

---

## 6. Re-verification list

**Nets that must change (values, not logic):**

| Net | What |
|---|---|
| `net_monster._defs_accessors` | **8 literal `w_px`/`h_px` lines**, plus the bull's two Korean labels ("그림 86 + 좌우 패딩 1+1" / "그림 54 + 위 패딩 2") which describe padding that no longer exists |
| `net_monster_slam` (ignite ring) | `center_cx ± 14` → ±18, and the "몸 절반너비(11칸)" label → 16.5칸. **Same edit as `boss_ai.gd`'s constant** |
| `net_monster_sprite` | No edit — but it passes **only** if all four new pngs hit W×H, `minx+maxx == w−1` and `maxy == h−1` exactly |

**Nets that must be re-run and re-measured (geometry-dependent, no edit expected):**

- `net_monster` — ledge crossing (**the 150-tick loop cap was measured against the current boxes**; a wider
  body reaches the ledge on a different tick), wall stop, landing, spawn bounds
- `net_monster_slam` — `_bull_slam_does_not_leave_room1_on_the_real_map` (600 ticks, phase 2, real baked map)
- `net_monster_charge` — carve impact, blocked→stun, the 3-cell ledge under a charge
- `net_monster_breath` — the breath's origin relative to the box
- `net_render` · `net_layers` · `net_determinism` — draw order and integer determinism at the new sizes
- **Whole-round runtime against CLAUDE.md's 10s line.** Expect it to move; call `harness-manager` when it does

**Behaviours verify-run must re-measure:**

1. **The per-kind frame cost, all four kinds** — replacing §4's projection with numbers, and leaving them in
   `monster_defs.gd` beside the existing table (that comment's own standing instruction)
2. **20 pigs at 60Hz** — the scene §4 says decides this, and the one nobody has ever measured
3. Bull confinement in room ①, phase 2, on the real map
4. Gore reach vs `range_px` — the dead band's new width

**Behaviours verify-look must re-see:**

1. **The slam fire ring clears the body** — the exact thing `ignite_spread_cells` 3→6 fixed, at 8
2. **Do they actually read bigger** — the whole point. Against the 20px player, at zoom 1.0
3. The hp bar, the hit flash and the damage numbers at the new sizes
4. The four regenerated beasts side by side with `wizard_body.png` — the `monster` preset's own standard
   ("does it live in the same world as the player"), which four fresh generations put back at risk

---

## 7. Open — for the user

- **Regenerate (×1.5, four new beasts to re-pick) or double the art (×2, same beasts, 4× the cost)?**
  §2 and §3. This is the fork, and it is a taste question, not a technical one
- **Or is the real complaint the zoom, not the monsters?** §3's third option, one screenshot to find out
- Pig **68×48** vs **64×48**; hen **36×44** vs **36×40**. Both pairs are within 2% of each other
