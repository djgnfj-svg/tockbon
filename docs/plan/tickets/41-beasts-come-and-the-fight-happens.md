Type: task
Status: claimed

# 짐승이 오고 싸운다 — **2 주의 전부**

**2026-08-30 에 캐물어서 다 정해졌다.** 아래가 그 답이고, 쪼개는 것과 순서는 사용자가 정한 그대로다.

## 사용자가 정한 나눔

| 언제 | 무엇 |
|---|---|
| **월 ~ 수** | **배 타고 오는 것** |
| **목 ~ 일** | **전투** |

## 무엇이 되면 끝인가

**배가 일정하게 와서 늑대를 해안에 내려놓고, 검사가 그것과 싸우고, 성채가 타면 진다.**

## ✅ 정해진 것 — **다시 안 묻는다**

| 무엇 | 답 |
|---|---|
| **배를 누가 놓나** | **아무도 안 놓는다.** 배가 스스로 온다 |
| **얼마나 자주 오나** | **일정하게.** 랜덤은 나중 |
| **한 배에 몇** | **여덟** |
| **무엇이 타고 오나** | **늑대.** 확정 |
| **짐승이 섬에 박혀 있나** | **아니다. 배로만 온다** — 섬 파일에 짐승 글자를 안 넣는다 |
| **늑대가 무엇을 향해 걷나** | **성채** |
| **병종** | **검사 하나.** 이번 주에 안 늘린다 |
| **검사가 무기를 드나** | **든다. 그림만** — 값을 무기가 드는 것은 5 주다 |
| **조작 단위** | **몸 하나.** 부대 단위는 확정이 아니다 |
| **검사가 죽으면** | **일정 시간 뒤 성채에서 부활한다** |
| **지는 조건** | **성채가 탄다** |
| **이기는 조건** | **이번 주에 없다** — 클리어는 최종 보스이고 보스는 9 주다 |
| **자원을 떨구나** | **아니다.** 자원은 4 주다 |

⚠⚠ **「죽으면 영영 죽는다」가 부활로 뒤집혔다** (2026-08-30). 명부가 들던 그 줄이 없어졌고,
**`Battle.setup` 이 앞 섬의 시체를 다시 안 내보내던 자리**가 그 줄을 지키던 코드다.

## ⚠ 아직 안 정해진 것 셋

1. **검사가 몇으로 시작하나**
2. **부활이 몇 초인가**
3. **졌다는 것이 화면에서 어떻게 보이나**

## ⚠ 이미 재어 둔 것 — **다시 재면 라운드가 날아간다**

| 무엇 | 실측 |
|---|---|
| **사거리 보너스** | **1.75.** 1.5 에서는 계단 위 몸이 옆 고원에 대각선으로 못 닿아 **162 판 중 26 판을 졌다** |
| **상륙 가능한 해안** | **8 방향 84 조각** (직교만이면 82). 그 둘이 모서리 해변이다 |
| **배 속도** | **4.0 조각/초.** 건너는 시간이 시작과 첫 타격 사이의 전부다 |
| **거리** | **3D 로 재고 높이는 눈금에서 온다.** 대각선은 정확히 sqrt(2) 라 엡실론이 필요하다 |
| **동점** | **낮은 번호가 이긴다.** 뒤집으면 모든 상륙 지점이 움직인다 — 결정론 전부다 |
| **고지를 지키는 몸** | **처음부터 높이 선 것만.** 전부 지키게 하면 싸움이 플레이어에게 안 온다 |
| **피해와 죽음** | **다른 단계에서 걸린다.** 같이 걸면 먼저 도는 쪽이 공짜 킬을 먹는다 |
| **배가 서는 자리** | **해안에서 거리를 두고.** 사용자: 「배가 가는 게 중요하니까」 |
| **표대로 한 판** | 검사가 늑대를 죽이는 데 **6 타 7.2 초**, 늑대가 검사를 죽이는 데 **9 타 9.0 초**. **검사가 체력 4 를 남기고 이긴다** — ⚠ 표의 산수지 해 본 값이 아니다 |

## ⚠ 이미 서 있어서 다시 안 짓는 것

- **표** — 늑대와 검사의 숫자가 그대로 있다
- **걷기** — 흐름장과 당긴 길. 곧게 걷는 것까지 2026-08-29 에 끝났다
- **자리 예약** — 몸끼리 같은 조각에 안 선다
- **조작** — 조각을 누르면 가장 가까운 검사가 거기로 간다. ⚠ **검사가 여럿일 때 누구를 고르는지는 없다**
- **성채** — 섬 파일에 `keep` 하나가 2 층에 서 있다. ⚠ **체력이라는 것이 아직 없다**

## 붙어 있는 것

- **배 3D** — 티켓 47
- **늑대 판떼기** — 티켓 48

---

## Implementation plan — **the 월~수 slice only: the boat sails in with wolves aboard**

**Written 2026-08-30. Scope is the crossing and nothing past it.** The user, on a phone, cut the
eight-question interview short: ***"the boat is made, it just needs to come across the water"***, so the
numbers below were chosen rather than asked. **Every one is a single line in `rules.gd` or `look.gd`.**

### What is true right now — **measured, not assumed**

| What | State |
|---|---|
| **`Battle`** | Two phases left: `_phase_orders`, `_phase_movement`. **No combat, no boats, no spawn loop.** The boat code deleted on 2026-08-29 was player-side and is not being revived |
| **`assets/props/boat.glb`** | On disk, **referenced by nothing**, and **Godot has never imported it** — there is no `.import` beside it |
| **`assets/beast/wolf_h/`** | Four PNGs: `north` `south` `east` `west`. No animation frames |
| **The sea** | ONE `PlaneMesh`, `SEA_SPAN_TILES = 400`, at `y = Look.SEA_Y_TILES = 0.075`. The shoreline is a shader on that quad, not geometry |
| **Loading a mesh** | `load("res://...glb") as PackedScene` then instantiate — the way `island.glb`, `buildings.glb`, `props.glb` already come in |
| **Bodies** | Pooled `Sprite3D` via `FieldView._sprite()`; `pixel_size = 1/TILE_PX`; world point from `Look.tile_point_px` + a Y read off the tile's level |
| **The sim is stepped** | `Game._process` calls `battle.step(delta)` every frame once a run exists |

⚠ **Ticket 48 says the swordsman has no body picture. That is wrong** — `sword_r.png`/`sword_l.png` are
full body-with-sword drawings. The bodiless ones are `bow`/`spear`/`shield`, leftovers from a second-weapon
idea dropped 2026-08-27 and wired to nothing.

### Seam — **`src/sim/`, the agreed main seam. Net FIRST.**

**This work adds state to `Battle`, so the check is written before the code** (the folder rule).
**A new net file `tests/nets/net_boats.gd`**, driven with `.new()` and `step(dt)` alone — no tree, no
pixels. **No new seam is being introduced.**

⚠ **The boat on screen is measured at the view seam's pooled-node surface** (`Sprite3D` fields for the
wolves) **and the committed surface count** for the boat mesh — buffers alone stay green when a flush is
deleted. **Nothing asserts pixels.**

### The numbers — **all new, all one line each**

| Constant | Value | Why this one |
|---|---|---|
| `BOAT_FIRST_SEC` | **5.0** | Long enough to see the empty island, short enough that a launch shows the boat |
| `BOAT_INTERVAL_SEC` | **30.0** | 「일정하게」 — random timing is later |
| `BOAT_SPEED_TILES` | **4.0** | ⚠ **Already measured. Do not re-derive** |
| `BOAT_START_DIST_TILES` | **24.0** | 6 seconds of crossing at 4.0/s. The crossing is the whole gap between start and first blow |
| `BOAT_STANDOFF_TILES` | **2.0** | 「배가 서는 자리는 해안에서 거리를 두고」 |
| `BOAT_CAPACITY` | **8** | ⚠ **Already decided.** Four benches, two each |
| `BOAT_LANDING_STRIDE` | **37** | Walks the landing ring so consecutive boats arrive on different sides. Coprime with 84, so it visits every tile before repeating |

**Presentation, in `look.gd`:**

| Constant | Value |
|---|---|
| `BOAT_BOB_TILES` | **0.06** — vertical rise and fall |
| `BOAT_BOB_SEC` | **2.2** — one full bob |
| `BOAT_ROLL_DEG` | **3.0** — side-to-side lean, on a different period so it does not beat with the bob |
| `BOAT_DECK_SLOTS` | **eight local offsets**, four benches by two — read off the mesh, in tile units |

⚠ **The bob and roll are the view's, not the sim's.** The sim's boat has a flat position; the screen adds
the motion. **A net must not be able to see the bob.**

### Order — **each step is possible only once the one above stands**

1. **`net_boats.gd` first**, red, against nothing: a boat exists after `BOAT_FIRST_SEC`, it is
   `BOAT_START_DIST_TILES` from its landing tile, it closes that distance at `BOAT_SPEED_TILES`, it stops
   at `BOAT_STANDOFF_TILES` and never moves again, a second boat arrives one interval later on a different
   landing tile, and **eight wolves are aboard and none of them is on the board.**
2. **The landing ring.** `Grid` lost `can_land_at` with the player's boats. **Rebuild the set: every land
   tile with water in any of the 8 directions.** ⚠ **The measured answer is 84 tiles** — if the count comes
   out different, say so rather than adjusting the expectation.
3. **Boats in `Battle`.** Parallel arrays, the way `soldier_*` already is: `boat_pos` (Vector2, tile
   units), `boat_landing` (tile), `boat_state` (SAILING · ARRIVED), `boat_riders` (how many aboard).
   A `_phase_boats` between orders and movement. ⚠ **Ties break on the lower tile number** — that rule is
   the whole of determinism here.
4. **The boat on screen.** `FieldView` loads `boat.glb` the same way it loads the island, one instantiated
   node per live boat, pooled and hidden rather than freed. Y from `SEA_Y_TILES` plus the bob; yaw from the
   heading toward the landing tile.
5. **Wolves on the deck.** Pooled `Sprite3D`, one per rider, at the eight deck offsets rotated by the
   boat's yaw. Texture picked from `wolf_h` by the boat's heading against the camera's yaw.

### Risk — **what this could silently break**

- ⚠⚠ **`boat.glb` has never been imported.** Godot writes the `.import` on first open. **If the mesh comes
  in shaded in bright and dark wedges, that is a known open failure** — the keep does it too, four fixes
  were tried and all four rendered identically. **Do not spend the round on it; report it and move on.**
- ⚠ **`Battle.setup` still takes a `spawns` argument whose contents nothing reads.** Boats are the thing
  that will eventually fill it. **Do not wire spawns this round** — beasts arrive by boat and by nothing else.
- ⚠ **The camera is orthogonal and sits far back.** A fade or a scale written as "distance from camera"
  multiplies by zero here. **That has cost a round before.**
- ⚠ **A wolf sprite and a boat mesh are different pipelines.** The sprite is a pooled `Sprite3D` at
  `pixel_size = 1/TILE_PX`; getting it to sit ON the deck rather than through it is a Y offset, not a scale.
- ⚠ **`net_islands` and `net_tiers` are already red for reasons that predate this** (the island is smaller
  than the nets expect). **Do not fold those reds into this ticket** — ticket 15 holds them.

### Acceptance

- **`net_boats` green**, and it fails when `BOAT_SPEED_TILES` is changed — a net that passes at any speed
  is measuring nothing
- **The total net count does not go down.** Report 통과/실패 before and after
- **On screen**: a boat appears out at sea, crosses, and stops short of the shore with eight wolves
  standing on it, and **the next boat comes to a different side**

### Out of scope — **builder does not expand into these**

- **Landing, unloading, walking ashore** — 목~일
- **Combat of any kind** — no damage, no death, no keep health
- **Replacing the walking wolf's 46 pictures** — ticket 48's open question, untouched
- **Fixing the sail size, the smooth hull, the grey sail** — ticket 47 says those are judged on the game
  screen, after it is in
- **Random boat timing** — 「일정하게」. ⚠ **Boats DO pile up**: an arrived boat never leaves this round, so by the second interval two sit off different shores. That is wanted, not a defect

---

## ✅ The Mon–Wed half is done — 2026-08-30

**A boat sails in and stops off the shore with eight wolves on it.** First at 5s, then every 30s, taking
**18 seconds** to cross, arriving on a different beach each time out of a ring of **61**.

**The user, on the wake and the hull's contact with the water**: ***"That's good enough."***

### ⚠ Built this round but NOT yet judged on screen

- **The camera moved to the mouse** — screen-edge pan, right-button drag, wheel to rotate,
  **Shift+wheel to zoom**. ⚠ **Shift+wheel was my choice, not the user's.**
  **How to see it**: launch, press 시작하기, push the cursor into any screen edge. Then drag with the right
  button over the ISLAND — **that used to do nothing at all and put a walk order in instead.**
- **WASD, Q/E and R/F all still work.** Nobody asked for them to be removed.

### ⚠⚠ What the Thu–Sun half still has to build, and it is more than it sounds

**There is no beast in this game.** `boat_riders` is an integer and the eight wolves on a deck are drawn
from it. **No enemy column, no landing, no damage, no death, no keep health.**
⇒ The three unanswered questions above are still unanswered and still block it.
