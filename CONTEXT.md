# CONTEXT — the words this repo uses

**Rewritten 2026-08-22 저녁** when the magic-circle game was dropped and the island game came back as a
**wolf** game. `tdd` and `domain-modeling` both read this file for the vocabulary that test names and
interfaces are built from.

⚠ **The user speaks Korean and the code speaks English.** Both columns are load-bearing: **an answer that
uses only the English word is not an answer to the user**, and a symbol named in Korean is not a symbol.

⚠⚠ **`src/` is restored, so most of this file is now taken from code and not from a design.**
**Where the code and this file disagree, the code wins and this file is corrected.**
**Rows still marked 미정 are designs, and they say so.**

---

## 짐승과 종족 — **the one that was renamed**

| 한국어 | Code | What it is |
|---|---|---|
| 짐승 | **beast** | **One creature on the field.** The thing that lands, walks, and hits |
| 종족 | **species** | **What the run is started as.** **늑대 (wolf)** is the first, and **근접 위주**다 |
| 빌드 | **build** | **Which beasts the horde is filled with.** Wolves make it fast and many; bears make it few and strong |

⚠⚠ **「캐릭터」도 죽은 낱말이다** (2026-08-24, 사용자: *"뭔가 캐리터는 아님"*). **그 말이 가리키던 것은
종족**이고, 낱말이 죽은 이유는 **티켓 01이 빌드를 「무리 구성」으로 바꾸면서 캐릭터와 빌드가 같은 축이
됐기 때문**이다. ⇒ **「종족 하나 × 빌드 하나」로 읽는다** — 무엇으로 시작하나 × 무엇으로 채웠나.

⚠⚠ **「세포」는 죽은 낱말이다.** 게임이 세포에서 늑대로 바뀌었다(2026-08-22 저녁).
**종족은 데이터지 타입이 아니다** — 코드는 **짐승**을 알고, **늑대는 종족 값 한 줄**이다. 목표가 캐릭터
둘이므로, 코드에 늑대를 박으면 둘째를 넣는 날 전부 다시 고친다.

### ⚠ 코드가 지금 실제로 쓰는 이름 — **아직 안 바꿨다**

| 정한 말 | 코드가 지금 쓰는 것 | 상태 |
|---|---|---|
| 짐승 · beast | **`soldier` · `army` · `unit`** | ✅ **이미 종족 중립이다. 바꿀 이유가 없다** |
| 짐승 다섯 종 | **`SQUIRREL` · `WOLF` · `COW` · `BEAR` · `CROW`** | ✅ **2026-08-25(티켓 15)에 바뀌었다.** `cell_melee` · `cell_ranged` 가 `WOLF` · `CROW` 가 되면서 **세포가 짐승 이름에서 사라졌다** |
| 인간 넷 | **`SPEARMAN` · `ARCHER` · `SHIELDBEARER` · `WARRIOR`** | ✅ **제 줄을 가졌다.** ⚠ **그 전에는 소와 까마귀 줄을 빌려 쓰고 있었다** — 개명이 아니라 줄 이사였다 |
| — | **`cell_at` · `cells` · `_cell_centre`** | ✅ **격자 칸이다. 생물이 아니다 — 건드리지 않는다** |
| — | **`title_cell_*` · `refit_cell_*`** | ✅ **화면의 칸이다. 건드리지 않는다** |

⚠ **한국어 「세포」는 2026-08-22 저녁에 서른한 곳을 「짐승」으로 바꿨다.** 주석과 그물 라벨이라
코드를 안 깬다. **열일곱 곳은 일부러 남겼다**:

- **사용자가 한 말을 그대로 인용한 두 줄** (`look.gd`·`rules.gd`). ⚠⚠ **인용은 낱말이 바뀌면 인용이
  아니다.** 이 저장소가 사용자 말을 잃은 적이 한 번 있고, 그래서 인용은 절대 안 고친다
- ~~**타이틀 화면의 떠다니는 배경 열다섯 곳** (`net_title`)~~ ✅ **2026-08-25 에 같이 바뀌었다**
  (티켓 23). **상수가 `Look.TITLE_TILE_*` 이 되면서 라벨 열다섯 곳도 「타일」로 갔다** — 예고한 대로
  상수와 라벨이 같은 날 움직였다. ⚠ **그림도 원에서 네모가 됐다**: 짐승 로그라이크의 첫 화면이
  반투명한 원 아홉 개, 곧 죽은 세포 게임의 그림이었다. **빌더가 고른 임시안**이고 움직임·개수·알파·
  두 진동수는 그대로라 재어 둔 값이 전부 살아 있다

## 한 판 — **the loop, and it is in code**

| 한국어 | Code | What it is |
|---|---|---|
| 회차 | **`Run`** | 한 판. 지도의 어느 노드에 서 있고 무슨 보상이 기다리는가 |
| 지도 | **`RunMap`** | 5층 7노드. 갈라졌다 합쳐지고 전체가 늘 보인다. 마지막은 보스 |
| 섬 | **`Islands`** · **`Grid`** | 싸우는 판. 격자에 통행·물·해안·상륙 거리가 얹혀 있다 |
| 전투 | **`Battle`** | 한 섬의 싸움. `step(dt)` 하나가 배·상륙·조준·이동·공격을 전부 민다 |
| 명부 | **`Army`** | 섬을 건너 살아남는 병력. **죽으면 영영 죽는다** |
| 정비 판 | **`Loadout`** | **짐승 종류마다 하나.** 카드가 여기에 값을 치른다. ⚠ **소환 칸이 아니라 종에 매달린다** — 판에 못 서는 종도 장비를 받는다(티켓 11) |

⚠ **전투 중에는 손이 안 움직인다.** 시작 전에 다 정하고, 그다음은 구경한다.
⇒ **어디에 내리느냐가 누구와 붙느냐를 정한다. 이게 이 게임의 결정이다.**

## 화면 — **and where the seam is**

| 한국어 | Code | What it is |
|---|---|---|
| 섬 화면 | **`FieldView`** | 지형·해안·바다의 배·몸·체력 |
| 지도 화면 | **`MapView`** | 어디를 지나왔고 어디로 갈 수 있나 |
| 보상 화면 | **`RewardView`** | **카드 세 장 중 하나.** 이긴 뒤에도 뜨고 **회차가 열릴 때도 뜬다**(그때는 짐승만) |
| 껍데기 | **`Game`** | **입력을 읽는 유일한 파일**이고 `sim`과 `view`를 잇는 유일한 자리 |

## 미정 — **⚠ 아래는 설계이고 코드에 없다**

| 한국어 | Code | 상태 |
|---|---|---|
| 아기 | **pup** | **아기 짐승으로 시작해 자란다.** 자람이 **크기**로 보인다 — 스케일이라 그림 값이 0 |
| 속도 | **swift** | 늑대 빌드 하나. **움직임이 빨라진다 — 그림 값 0** |
| 출혈 | **bleed** | 늑대 빌드 하나. **문 자리에 피가 남는다 — 이펙트 하나** |
| 무리사냥 | **pack** | 늑대 빌드 하나. **여럿이 한 표적으로 모인다 — 대형이 바뀐다, 그림 값 0** |
| 빌드가 보이는 법 | — | ⚠ **위 셋이 서로 다른 채널을 쓴다** — 움직임 · 색 · 대형. **안 겹쳐서 한눈에 갈린다** |
| ~~일반 늑대 · 무거운 늑대~~ | — | ⚠⚠ **죽었다 (2026-08-25, 티켓 15).** 한 종을 둘로 가르는 대신 **다섯 종이 됐다.** 지우지 않고 남긴다 — 「하나는 먼저 닿고 하나는 오래 버틴다」는 **늑대와 곰이 대신 한다** |
| 칸이 늘어난다 | **`Army.slots`** | ✅ **지어졌다 (2026-08-25, 티켓 15).** 칸 수가 고정 상수에서 **회차 상태**로 옮겨졌다. **회차는 칸 하나로 열리고 짐승 카드가 칸을 채우며 다섯에서 멈춘다** |
| 성장 | — | ✅ **찼다**(2026-08-23, 티켓 02). **카드 여섯 중 둘이 짐승과 장비를 준다**, 둘 다 등급이 있고 **레전더리 장비만 외형이 바뀐다** |
| 장비 칸 | — | **이름이 없는 빈 칸 여러 개**이고 **아무 장비나 꽂는다**(2026-08-23 밤). ⚠⚠ **지금 코드는 칸이 곧 부위라 반대다** — 올리는 숫자가 칸에 박혀 있고, 그것을 **장비 자체로 옮겨야 한다** |
| 장비가 붙는 자리 | — | **짐승 종류마다 판이 하나.** 늑대에게 꽂으면 **모든 늑대**가 낀다. ⚠ **지금 코드는 칸마다 판이 하나라 다르다** |

✅ **`Loadout`·`RefitView`·「부리」의 자리는 2026-08-23에 티켓 02가 채웠다.**
**`Loadout`과 `RefitView`에는 장비가 온다** — 다만 **판이 칸이 아니라 짐승 종류에 매달려야 하고**,
**칸에서 이름을 떼야 한다.** ~~**「부리」는 그대로 둔다** — 근접 늑대의 사거리를 1 올리면 뒷줄이 앞줄
너머로 물기 때문에 **근접에서 오히려 값이 크다.**~~

⚠⚠ **취소선 부분은 2026-08-25 에 사용자가 뒤집었다** (***"부리 보상 없지 끝나면 카드보상으로
통일했잖아"***). **보상 종류가 통째로 삭제됐고 「+1 사거리」 장치도 같이 죽었다.** 옛 부리 노드 둘은
**카드 노드**가 됐다. **근거가 틀려서가 아니라 성장 고리가 카드로 통일됐기 때문이다** — 티켓 06 이
「이긴다 → 세 장 중 한 장」으로 닫았고 티켓 05 가 「끝까지 세 장에 한 장」으로 굳혔다.

## 도구

| 한국어 | Code | What it is |
|---|---|---|
| 그물 | **net** | 시험 하나. **라벨이 말하는 것보다 적게 재는 초록은 빨강보다 나쁘다** |
| 지도 | **map** | 한 갈래의 계획. `wayfinder`가 갖는다 |
| 티켓 | **ticket** | 질문 하나. 그 답이 **곧** 설계다 |

---

## Where the seams are

`tdd` will not write a test at an unagreed seam. **These are the agreed ones**, and they come from the
folder rule in `CLAUDE.md`:

- **`src/sim/`** — constructible with `.new()`, never touches the tree. **The main seam.** A net drives the
  whole game here in seconds
- **`src/view/`** — reads `sim`, never writes it. **The measuring surface is three-fold**
  (2026-08-24, user-approved — the old `_paint_*` hook died with the 3D move): **the pure camera
  functions** (drivable with `.new()`), **pooled node state** (the Sprite3D fields the engine consumes:
  position, modulate, scale, texture, visible), and **the fx buffers plus committed surface counts**
  (buffers prove geometry was built; surface count proves the flush committed it — buffers alone stay
  green when the flush is deleted)
- **`src/shell/`** — the only reader of `Input`. **Seam is `_ready()`**, which builds the real wiring

**Do not add a seam inside a file.** If something is hard to test, it is in the wrong folder.

⚠ **These three survived three deletions and are not re-decided per game.** The 2026-08-24 change
above moved the view seam's measuring surface, not the seam itself — the folder boundary stands.
