# The swordsman's animations — what was pulled, and with which words

**All of it is pixellab, character `tockbon swordsman base` (`8d06bbf3-c757-44b7-850d-fa7cac72e519`),
40 x 60, v3 mode, `keep_first_frame=false`.** ⚠ **The generator's compass words are not the game's.**
The four facings the game installs are `right` = **south-east**, `left` = **south-west**,
`down` = **south**, `up` = **north** — verified pixel-exact against the rotations, not by their names.

## What shipped

| Strip | Frames | Where each facing came from |
|---|---|---|
| **walk** | 4 | one pull, group `9fcf68ec`, all four facings |
| **idle** | 8 | **two pulls, mixed by facing** — see below |

**The walk prompt**, and it is the one that worked first time:

> `walking forward at a steady pace`

**The idle was pulled twice and the installed set is the narrower of the two per facing:**

> **loose** — `standing still and breathing, the chest rising and falling slightly, arms relaxed at the sides, feet planted`
>
> **tight** — `standing still and breathing, only the chest and shoulders rising and falling, the arms stay pressed against the sides of the body and never swing away from it, both feet stay flat on the ground and do not move`

| Facing | Installed | Arm swing, loose vs tight (px of ink width) |
|---|---|---|
| `down` (south) | **loose** | **12** vs 15 |
| `right` (south-east) | **tight** | 15 vs **10** |
| `left` (south-west) | **tight** | 12 vs **7** — and the eyes blink |
| `up` (north) | **tight** | 16 vs **0** |

⚠⚠ **TELLING THE MODEL NOT TO SWING THE ARMS MADE THE FRONT VIEW SWING MORE.** 「never swing away from
it」 came back at 15 px on `south` against the loose pull's 12, while the other three tightened. **The
negative was obeyed on three facings out of four and reversed on the fourth**, which is why the
installed idle is two generations and not one.

## What lost, and it is all in this folder

- **`walk_template_*`** — pixellab's `walking-4-frames` skeleton, 2026-08-31. **Measured dead**: the
  silhouette came back at **27% to 68% of the standing pose, differing per facing**, and the head at
  about half size. Registering onto one canvas fixes the height and cannot fix the head.
- **`walk_v3_east_*` and `walk_v3_west_*`** — the right two frames of the **wrong two facings**. The
  first v3 walk was pulled for `north · east · south · west`, and the game wears **south-east** and
  **south-west** for its right and left. ⚠ **Only `south` and `north` of that pull are in the game.**
- **`idle_loose_*`** on the three facings where the tight pull won, and **`idle_tight_*`** on `south`.

## 공격 · 피격 · 죽음 — 2026-08-31, one pull each and none of them re-rolled

**Same character, same v3 mode, same four facings.** ⚠ **The canvas is 72 x 62 now** — a corpse lying
flat is 65 px of ink across where the standing picture is 35, and **the frames decide the canvas.**

> **attack (4 frames)** — `throwing a straight punch forward, one arm driving out ahead of the body at shoulder height while the other arm is pulled back, the near foot stepping forward, the body leaning into it`
>
> **hurt (4 frames)** — `recoiling from a blow, the head and chest thrown backward, the shoulders hunched up and both arms drawn in against the body, the feet staying planted`
>
> **death (6 frames)** — `going down, the knees folding and the body tipping over sideways, lower in every frame, the last frame a body lying flat on the ground with its limbs slack and its head down`

⚠⚠ **`lower in every frame` IS THE PHRASE THAT MADE THE DEATH WORK.** It is a shape word, not a verb —
the same lesson `tools/pixel/README.md` measured on the wolf's walk. **The body actually descends**
across the six, and the last two frames are a body on the ground rather than a body crouching.

## 공격이 여덟 장이 됐다 — 2026-08-31

> **attack, 8 frames** — `winding up and then striking: in the first frames the arm and the shoulder are pulled back and away from the target and the body leans back, in the middle frames the fist drives forward as far as it will reach and the body leans into it, in the last frames the body settles back to standing`

⚠ **The four-frame punch it replaced is still on pixellab as `attack_v3`.**
⚠⚠ **Naming the three beats — first / middle / last — is what made the wind-up appear**; the same
prompt shape fixed the wolf, whose three single-pose attempts had all failed. See the wolf's page.
