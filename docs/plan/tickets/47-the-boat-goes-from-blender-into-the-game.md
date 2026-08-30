Type: task
Status: resolved

# 배가 블렌더에서 게임으로 들어간다

## 무엇이 되면 끝인가

**만들어 둔 배가 게임의 바다 위에 뜬다.**

## ✅ 이미 만들어져 있다

**2026-08-30 에 블렌더로 뽑아 `assets/props/boat.glb` 로 내보냈다.** 사용자가 보고 ***"야 너무 잘
만들었어"*** 라고 했다.

| 무엇 | 값 |
|---|---|
| **크기** | **길이 5.2 조각 · 폭 1.9 조각.** 한 조각이 1 미터다 |
| **태우는 수** | **여덟** — 벤치 넷, 벤치마다 둘 |
| **면** | **138 장** |
| **색** | **부분마다 단색 다섯** — 선체(어두움) · 뱃전 테두리(밝음) · 갑판 · 벤치 · 돛대. 돛은 아마천 |
| **방향** | **뱃머리에 기둥, 고물에 낮은 블록** — 배가 섬으로 오는 것이라 앞뒤가 보여야 한다 |

## ⚠ 티켓 01 에서 지킨 것

- **모서리를 45 도로 안 깎았다** — 선체 옆면이 위로 갈수록 살짝 벌어진다
- **디테일은 면이 아니라 모서리에** — 뱃전 테두리 하나가 윤곽을 잡는다
- **평면 셰이딩, 뷰 트랜스폼 `Standard`**

## ⚠ 사용자가 아직 안 본 각도에서 걸릴 만한 것 셋

1. **돛이 크다** — 위에서 보면 배를 반쯤 가린다
2. **선체가 매끈하다** — 섬 블록처럼 각지지 않았다. 단면을 열셋에서 줄이면 각져진다
3. **돛 색이 회색으로 떴다** — 아마천으로 넣었는데 조명이 눌렀다

⚠ **셋 다 판정은 게임 화면에서 난다.** 블렌더에서 고치고 게임에서 다시 본다.

## ⚠ 게임에 들일 때

- **섬 메시를 부르는 자리가 이미 있다** — 같은 방식으로 부른다
- **한 조각이 세계 좌표 1 이다.** 배는 그 좌표계로 이미 만들어져 있어서 배율을 안 곱한다
- ⚠ **배는 물 위에 뜨고 땅에 안 선다** — 높이를 눈금에서 읽지 않는다

## 안 하는 것

- **항해 계산과 상륙** — 티켓 41
- **플레이어가 만드는 나무 배** — 10 주

---

## Answer — **2026-08-30. It went in, and then it was re-baked because of what the screen said**

**The boat is in the game**, loaded the way the island is, and it sails, bobs, rolls and points where
it is going. **But the three things this ticket said would be judged on the game screen all failed
there**, and a second Blender round fixed them:

| What the screen said | What was done |
|---|---|
| **It reads as a shallow bowl, not a boat** | Rebuilt angular — three cross-sections deliberately colinear, twice, so the bow and stern are each ONE flat panel. **Angularity came from WHERE the sections sit, not how many** |
| **The five per-part colours all sat in one cream band** — the dark hull did not exist on screen | Hull-to-gunwale luminance **1.36 → 2.55**, the same six colours the small boat uses, so the two read as one fleet |
| **The sail's shadow lay across the deck as a grey stain** | Sail halved in area, 1.772 × 1.229 → 1.100 × 1.000 |

## ⚠⚠ And the wedge banding was measured, not guessed — it was GEOMETRY

**The old `boat.glb` had 24 hull polygons up to 20.4° out of plane and 38 sail polygons up to 35.8°.**
A non-planar quad exports as two triangles with different normals, and that is the bright/dark panel
on screen. **The new one has zero.**

⚠ **Two documents were measured wrong by this and `wrap-up` did not fix them** — see the new ticket:
`docs/how-nets-lie.md` still calls the keep's wedge shading OPEN, and `buildings_build.py` claims
`use_smooth = False` is insufficient in Blender 4.1+, which is **not true in the Blender this repo runs**.

## ✅ What else came out of it

- **`tools/blender/boat_build.py` now exists.** ⚠⚠ **Before this the big boat could not be re-baked at
  all** — there was no script.
- **The mesh's AABB is unchanged to four decimals**, deliberately: `Rules.BOAT_HULL_HALF_TILES` and
  `BOAT_HULL_BEAM_TILES` are read from it and 61 beaches depend on them. **The build script asserts it.**
