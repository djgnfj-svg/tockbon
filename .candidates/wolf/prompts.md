# g5's animations — what was pulled, and with which words

**pixellab, character `wolf-g5-rotated` (`35a190ca-ef0a-4894-bf46-ea5820777ec1`), 64 x 64, v3 mode,
`keep_first_frame=false`.** ⚠⚠ **The generator's compass words are not the game's, and the mapping is
not the obvious one** — it was verified pixel-exact against the rotations:

| Game file | Generator rotation | What it is on screen |
|---|---|---|
| `wolf_h/east` | **south** | screen-right |
| `wolf_h/west` | **west** | screen-left |
| `wolf_h/south` | **south-west** | coming at the camera |
| `wolf_h/north` | **north-east** | going away |

**Both strips came back usable on the first pull** — no second attempt, unlike the swordsman's idle.

> **walk (4 frames)** — `walking forward at a steady pace on four legs, the front and back legs swinging in opposite pairs, the body held level`
>
> **idle (8 frames)** — `standing still on four legs and breathing, all four paws planted on the ground, the ribcage rising and falling slightly, the head steady`

⚠ **The idle reaches WIDER than the walk** — 67 px of ink against 66, on a 64 px standing picture. A
breathing animal stretches its nose and tail out, so **the canvas is sized by the breath and not by
the stride.**

## 공격 · 피격 · 죽음 — 2026-08-31, one pull each and none of them re-rolled

⚠ **The canvas is 92 x 66 now.** The attack reaches 71 px of ink and the death 74, on an animal whose
standing picture is 64 — **a snapping jaw and a body on its side are what set the frame.**

> **attack (4 frames)** — `snapping its jaws forward at something in front of it, the neck stretched out and the head pushed low and forward, the mouth opening and shutting, the front paws braced on the ground`
>
> **hurt (4 frames)** — `recoiling from a blow, the head twisted away and pulled down between the shoulders, the back hunched and the hind legs crouching under the body, all four paws staying on the ground`
>
> **death (6 frames)** — `going down, the legs folding under it and the body sinking onto its side, lower in every frame, the last frame the wolf lying flat on the ground with its legs slack and its head down`

⚠ **The old 22-candidate bite lesson did not repeat.** `tools/pixel/README.md` measured that the local
route would give 「the same wolf with its mouth open」 and refuse a real lunge; **pixellab's v3 moved the
neck and the paws on the first pull**, so the jaws-forward attack cost four generations and no re-rolls.

## ⚠⚠ 공격이 안 읽혀서 두 벌 더 뽑았고, **둘 다 실패했다** — 2026-08-31

> ***"물기가 멀리서 봤을때 너무 티가 안남 죽음은 티가 나는데 늑대 공격할때 티좀 나게해줘"***

**The user is right and the numbers say why.** Measured over the four frames of each facing, as the
change in the ink's bounding box:

| Set | width swing, rear view | width swing, side view |
|---|---|---|
| **jaws (installed)** | **0 px** — 29, 29, 29, 29 | 4-5 |
| **rearing up** | **0 px** | 2-3 |
| **pouncing** | 12 | 2-5 |

**Two more sets were pulled and neither moves the animal.** The prompts asked for the body to leave
the ground:

> **rear** — `rearing up, both front paws lifted high off the ground and reaching forward above the shoulders, the chest tall and upright, the weight back on the hind legs, the mouth wide open`
>
> **pounce** — `pouncing, the body stretched out long and low with the front paws thrown far forward off the ground and the hind legs extended straight out behind, the whole animal leaving the ground, the mouth wide open`

⚠⚠ **BOTH CAME BACK AS 「THE SAME WOLF WITH ITS MOUTH OPEN」**, which is **exactly** what
`tools/pixel/README.md` measured on the local route across 22 candidates. ⇒ **That limit is not the
local pipeline's, it is the generators'**, and this is the second route to hit it. **A wolf that
leaves the ground is not available from a prompt.**

## What was done instead, and it is code

**The body is pushed forward along its heading for the first 0.18 s of a swing and comes back** —
`Look.BODY_LUNGE_SEC` and `BODY_LUNGE_RATIO`. Measured in a real fight: **8.18 px, 0.20 조각, 39% of
the wolf's own drawn width**, with **the shadow staying where the sim says the body is**, so the
animal visibly leaves its own mark.
⚠ **A second defect was found taking that picture**: a body lunged **away** from what it was hitting,
because it faced the way it last WALKED. **A still body now faces its target** — see
`field_view._aim_of`.

## 공격이 여덟 장이 됐다 — 2026-08-31

> ***"애니메이션을 좀더 늘려줘 좀더 공격 텀이 있는 느낌?"***

**The four-frame jaw snap was replaced by an eight-frame wind-up.** ⚠ **The four-frame set is not in
`assets/` any more; it is still on pixellab as the group `attack_v3`**, beside `attack_rear` and
`attack_pounce` whose frames are in this folder.

> **attack, 8 frames** — `winding up and then striking: in the first frames the head and neck are pulled back and the shoulders drop low, in the middle frames the head is thrown forward as far as it will reach with the jaws wide open, in the last frames the animal settles back onto all four legs`

⚠⚠ **NAMING THE THREE BEATS IS WHAT MADE THE POSE MOVE.** Three earlier pulls asked for one shape —
jaws, rearing, pouncing — and **all three came back as the same wolf with its mouth open.** Asking for
**first frames / middle frames / last frames** produced a body that actually pulls back before it
reaches. **The generator will not give a pose; it will give a sequence.**

## ⚠⚠ 다섯 번째 실패, 그리고 그림 길이 끝났다 — 2026-08-31

> ***"뭔가 애니메이션이 너무 공격하기 평범해 뭔가 좀더 공격하듯해 줬으면 좋겠어"***

**The eight-frame wind-up was measured on the board and the user is right**: across all eight frames
the wolf's outline moves **7 px on a 64 px animal**. **The mouth opens and the body does not move.**

**The fifth attempt was img2img over the standing sprite itself** — `2026-08-31-attack_img2img_pose.png`
in this folder — asking for the same wolf mid-lunge with its front paws off the ground at
`init_image_strength=110`. **It came back standing.**

| Attempt | Route | Result |
|---|---|---|
| 1 | v3, `snapping its jaws forward` | mouth opens |
| 2 | v3, `rearing up, front paws lifted high` | mouth opens |
| 3 | v3, `pouncing, the whole animal leaving the ground` | mouth opens |
| 4 | v3, eight frames, `first / middle / last` beats named | mouth opens, 7 px of outline |
| 5 | **img2img over the sprite**, `mid-lunge, paws off the ground` | **stands** |

⇒ **A pose that leaves the ground is not available from this generator by any route tried.** The
swing is driven by the ENGINE from here — wind-up, snap, hold, recover, plus a stretch — and the eight
drawn frames stay underneath to carry the mouth. See `Look.SWING_WINDUP`.
