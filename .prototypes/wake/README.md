# wake — what the boat leaves behind it

## The question

> **「배가 바다를 지나며 뒤에 남기는 물결을 무엇으로 그리나」**
> — *what draws the wake a boat leaves behind it as it crosses the sea?*

⚠⚠ **This does NOT reopen the sea or the 해안선.** The flat water was confirmed twice and the border was
chosen out of twenty-seven versions (`.prototypes/swash/`, the winner `27-gaps`). **Every candidate here
carries the shipped sea byte for byte** and is handed the same forty dials out of `look.gd` — so the only
thing that differs between two pictures is what happens to the water behind the hull.

⚠ **The 해안선 is not in any of these frames and that is not an override.** There is no island, so the
distance field says open sea everywhere and the shipped border has nothing to draw against — which is
what it does over open water in the game too.

## How to run it

```
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/wake/lab.gd
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/wake/lab.gd -- shoot
```

**1..5 pick a candidate · SPACE swaps the straight run for the turning one · TAB near/far camera ·
R restarts the crossing · ESC quits.** ⚠ **Never `--headless`** — every PNG comes out black with no error.

## What is in the frame, and what is not

**Water, boat, wake.** The island, the buildings, the 검사 and the 짐승 are out on purpose: anything else
in the picture is what the eye lands on instead of the thing being judged.

The boat is `assets/props/boat.glb` unmodified, at `Rules.BOAT_SPEED_TILES`, under the game's own sun,
seen through the game's own orthographic camera at the game's own pitch.

## The two crossings, and the second one is the question

| | what it is | why it is here |
|---|---|---|
| **straight** | due east across the frame | what every candidate looks like when nothing is being asked of it |
| **turn** | due east, then a quarter turn in one second onto due north | ⚠⚠ **the thing that separates them.** A 2.55 조각 turn radius against a 5.2 조각 hull — **two of the five fail here and nowhere else**, and a sheet shot only on the straight would show five pictures that all look fine |

**And a third frame, `far`**, at the ~42 조각 of visible ground the shipped island opens at.
⚠ **A wake that only reads close up is not a wake this game can use** — that is the frame a landing is
actually watched from.

## Where each one gets the wake from

| | Where the mark comes from | Bounded? | Cost grows with |
|---|---|---|---|
| `01-bake` | **a world-space texture the stern paints into**, read by the water shader | ⛔ a square, and a resolution | area covered |
| `02-ribbon` | **one strip of triangles** trailing the hull | ✅ unbounded | boats |
| `03-stamps` | **separate foam quads** dropped at intervals | ✅ unbounded | boats x trail length |
| `04-analytic` | **the shader itself**, from a list of recent positions | ✅ unbounded | pixels x samples x boats |
| `05-bowwave` | **a static V on the hull** — no trail at all | ✅ nothing to bound | boats |

**Each folder carries a `NOTES.md` with three lines: what it buys, what it costs, and what it CANNOT
do.** ⚠ The third is the one that decides.

## The second sheet — `04a` .. `04e`, and it is a DIAL sheet

**The user chose `04-analytic`** and then asked for it simpler:
> **「심플하게 있으면 될듯 4번인데 좀더 심플하게 할 수 있나」**
> — *"something simple is all it needs; it's number four, but can it be simpler?"*

⚠ **These five are not a prototype set.** They are **one mechanism at five sets of numbers**, which is
what this repo calls a candidate sheet. `04-analytic` was renamed `04a-full` — same folder, same
history, and its beading fixed — so there is exactly one copy of the mechanism on disk.

| | what moved | what it is |
|---|---|---|
| `04a-full` | nothing | the whole shape: arms and transverse crests |
| `04b-arms` | `crest_amt` | the two arms only |
| `04c-thin` | `arm_w` · `arm_hard` · `life` · `alpha` | arms only, hairline, dying in half the time |
| `04d-single` | `arm_amt` · `centre_amt` · `centre_w` · `life` | one line down the track. No V at all |
| `04e-ghost` | `alpha` | the whole shape, much fainter |

⚠⚠ **`04e-ghost` is the row that asks what 「simpler」 means** — less shape, or less loud. It is the same
geometry as `04a-full` with one number changed.

**Where the numbers live**: `kelvin.gdshaderinc` is the one copy of the mechanism, `kelvin.gd` holds
`BASE` — every dial at the value the first sheet was shot at — and **a candidate folder is one
dictionary** naming only what it changes. A sixth version is one file.

### The beading is fixed, in all five

The first sheet's arms carried a fine beading. **The cause was that each remembered moment drew a DOT at
its envelope point**, and a dot's falloff reaches nothing exactly where the next one starts — so
widening it thickened the arm without closing the gaps. **The arm is now the SEGMENT between two
consecutive envelope points**, which removes it outright and makes `arm_w` an honest stroke half-width
instead of a dot radius tuned against the sample rate.

## How each one is built

**`build.py` splices, it does not copy.** Each folder holds a `mech.gdshader` defining one function,
`vec3 wake(vec3 base, vec2 p, float t)`, and the script wraps the shipped water shader round it. **The
sea is therefore byte-identical in all five pictures by construction**, and re-splices itself the day
`src/view/water.gdshader` changes. Three of the five draw nothing in the water — their wake is geometry
— and they still go through the splice so their sea is the same sea.

The CPU half of each mechanism is its own `wake.gd`: `build` · `reset` · `step` · `present` · `teardown`,
and `lab.gd` drives all five through those five calls and nothing else.

⚠⚠ **The crossing is a function of TIME and is photographed at a fixed time**, stepped at a fixed
1/60 s from t = 0 before anything is drawn. **The real frame delta would put a different length of trail
in every picture** and the sheet would be measuring the machine's mood.

⚠ **`lab.gd` copies its numbers out of `look.gd` as literals rather than reading `Look`.** A lab that
imports the game goes down the moment the game does not parse, and this one was built while another
builder was inside `src/`. **If the sea in these pictures stops looking like the sea in the game, that
block is the first place to look.**
