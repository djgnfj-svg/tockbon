Type: task
Status: resolved

# 진영 선택 화면을 세운다

## Question

**타이틀과 지도 사이에 진영을 고르는 화면을 세운다. 진영 셋이 보이고, 데모에서는 포유류 하나만 열려
있으며, 고르면 시작 짐승은 늑대로 고정이다.**

## 어디서 왔나

**티켓 13 의 답이다** (2026-08-24, 사용자):
***"내가 뭔가 진영을 선택하고, 시작은 늑대로 고정인, 고정인거지"*** ·
***"지금은 바로 게임 시작해 버리니까 그러지 말고"***

## 정해진 것

- **화면 자리**: 타이틀 → **진영 선택** → 지도
- **진영 셋이 보인다.** 데모에서 **열린 것은 포유류 하나**, 나머지는 잠금 — 「확장될 자리」를 화면이 말한다
- **포유류를 고르면 시작 짐승은 늑대 고정.** 지도의 「시작은 종족 하나 × 빌드 하나」가 그대로 산다
- ⚠ **진영 이름은 미정** — 화면 글자는 일단 계통 이름(포유류)을 쓴다

## 이음매

**화면 + 껍데기.** 고른 진영은 상태에 남아야 하므로 `sim` 에 한 줄이 생길 수 있다 —
**그 줄이 생기면 그물 먼저**(2026-08-24 규칙), 화면은 짓고 나서.

## Answer

<!-- 아직 -->

## Implementation plan

### 구조 — 변형이지 새 종류가 아니다

- **화면**: `TitleView` 의 변형이다 — 칸 여럿, 일부만 눌리고, 안 눌리는 칸은 설정하기의 규칙
  그대로(흐리게, 호버 없음, `note_press` 호출 안 함). 새 위젯 개념이 없다
- **sim**: `Run` 에 진영 한 줄 — **회차는 진영을 갖고 태어나고, 태어난 뒤에는 안 바뀐다.**
  `Run.State` 에 새 상태를 **넣지 않는다**: 진영 고르기는 시작하기와 같은 종류다 — 아직 없는 회차를
  구성하는 일이지 회차가 지나는 단계가 아니다. `title-and-map` 이 `State.TITLE` 을 거부한 논리
  (없는 객체 위의 상태는 도달 불가)가 그대로 적용되고, `Run.new()` 를 쓰는 그물 18곳이 안 깨진다
- **진영 하나를 더 열거나 넷째를 붙이는 값**: `rules.gd` 의 표 한 줄 — **파일 하나.**
  뷰는 `Rules.faction_count()` 를 돈다

### 이음매 — 새 이음매 없음, 셋 다 이미 합의된 것

- **`src/sim/`** (주 이음매): `Rules.FACTIONS` 정적 접근자 + `Run.new(f)` 가 진영을 기록한다.
  헤드리스, `.new()` 만으로
- **`src/shell/`**: `game._ready()` 뒤 이벤트를 `_unhandled_input` 에 직접 넣어 타이틀 → 진영 → 지도를
  달린다 — `net_shell` 이 이미 쓰는 방식 그대로
- **`src/view/`**: `FactionView` 의 `_paint_*` 훅, `net_draw_leaf` 의 표에 등록

### 고칠 파일과 이유

| 파일 | 왜 |
|---|---|
| `tests/nets/net_run.gd` | **맨 먼저 (sim 은 검사 먼저).** 새 줄: `FACTIONS` 는 세 줄이고 열린 것은 정확히 `FACTION_MAMMAL` 하나 · `Run.new().faction == FACTION_MAMMAL` (기본값) · `Run.new(f)` 가 f 를 기록 · `restart()` 는 진영을 **보존**한다 — 진영은 태생이지 진행이 아니라서 `_reset` 이 안 만지는 게 맞다는 결정을 그물이 문장으로 갖는다 |
| `src/sim/rules.gd` | 새 절: `FACTIONS := [["포유류", true], ["파충류", false], ["공룡", false]]` (라벨·열림 두 열, 라벨 한국어는 `ITEMS` 가 이미 지닌 예외 — 사용자가 화면에서 읽는 글자) + `FACTION_MAMMAL := 0` + `faction_count()` / `faction_label_of(f)` ("" 범위 밖) / `faction_unlocked(f)` (범위 밖 false). 열림이 여기 있는 이유: 무엇으로 시작할 수 있느냐를 정하므로 rules 다 |
| `src/sim/run.gd` | `var faction` + `_init(f := Rules.FACTION_MAMMAL)` 에서 한 번만 쓴다. `_reset` 은 안 만진다(위 그물 줄이 그 결정을 잡는다). 상태 기계 무변경 — 새 회차는 지금처럼 `MAP` 에서 연다 |
| `src/look.gd` | `FACTION_SLOT_*` (origin·size·gap·font·text offset) + `FACTION_HEADING_*` + `faction_slot_rect_px(i)` / `faction_slot_hit_rect_px(i)`. 타이틀 상수를 **재사용하지 않는다** — 두 화면이 상수 하나에 묶이면 한쪽을 옮기는 날 다른 쪽이 따라 움직인다. 호버 램프·눌림 딥·히트 패드는 이미 공유인 `PRESS_*` 를 그대로 읽는다 |
| `src/view/faction_view.gd` | **새 파일.** `TitleView` 의 모양: 슬롯 사각형·호버·눌림 딥·자기 시계(`_fx_step`), 전부 `_paint_*` 훅으로만 그린다. 라벨과 눌림 가능은 **`Rules` 에서 읽는다** (`faction_label_of` / `faction_unlocked`) — 잠긴 칸은 설정하기 규칙 그대로: 흐린 채움, 테두리 알파 0, 호버 절대 안 켜짐, `note_press` 거부. 슬롯 인덱스가 곧 진영 id 다(따로 매핑 표 없음). 머리글 「진영 선택」은 `TITLE_TEXT` 와 같은 자격의 자리표시자 |
| `src/shell/game.gd` | `_ready` 에서 `faction_view` 를 title 다음·panel 앞에 짓고 **`visible = false` 로 시작**. run == null 분기를 쪼갠다: `faction_view.visible` 이면 `_faction_input`, 아니면 `_title_input` — 깃발을 새로 두지 않는다(보임 비트가 곧 모드고, 깃발을 더 두면 같은 사실 두 곳). `_title_input` 의 SLOT_START 는 `_start_run()` 대신 타이틀을 끄고 진영 화면을 켠다. `_faction_input`: 호버 + 왼클릭, `is_slot_pressable` 거부 → `note_press` → `_start_run(f)`. `_start_run(f)` 는 `Run.new(f)`. `_enter_map_screen` 이 title 을 끄는 줄 옆에 faction 도 끈다; `_click_panel` 의 재시작 블록도 마찬가지(재시작은 타이틀로, 진영 화면으로가 아니다). 머리 주석의 「run 하나로 세 화면을 가른다」 주장을 「run == null 은 타이틀 또는 진영 화면, `faction_view.visible` 로 가른다」로 고친다 |
| `tests/nets/net_shell.gd` | `_ready` 자식 수/순서 핀에 faction_view 추가. 타이틀 흐름 줄 갱신: 시작하기 → **run 은 아직 null 이고 진영 화면이 떴다** → 잠긴 칸 클릭 → 여전히 null, 눌림 애니메이션도 없다 → 포유류 클릭 → run 생성, `run.faction == FACTION_MAMMAL`, 지도. ⚠ 이 그물의 존재 이유인 돌연변이(「`if run == null: return` 을 되돌리면 시작하기가 안 눌린다」)는 사슬 전체가 run 생성으로 끝나는 줄이 그대로 문다 |
| `tests/nets/net_draw_leaf.gd` | `_table()` 에 `FactionView` 의 훅과 각 훅의 draw_* 수 등록 — 등록 안 하면 이 그물이 모르는 함수로 빨개진다 |
| `tests/nets/net_faction.gd` | **새 파일, 화면이니 검사는 나중.** `net_title` 의 필수 줄만 거울: 기하가 Look 접근자에서 읽힌다 · 칸은 셋이고 라벨이 `Rules` 표와 같다 · 잠긴 칸은 죽었다고 말한다(호버 0 고정, 채움 흐림, 눌림 불가) · 호버/눌림이 손에 답한다 · 잎이 받은 것을 그린다(스파이) |
| `CONTEXT.md` | 낱말 한 줄: 진영 · **faction** — 회차가 무엇으로 태어났나, 데모에서 열린 것은 포유류 하나. 화면 표에 진영 화면 · `FactionView` 한 줄 |

### 순서

1. `net_run.gd` 새 줄 (빨강) — **sim 은 검사 먼저** (2026-08-24 규칙)
2. `rules.gd` + `run.gd` — 1 이 초록이 된다
3. `look.gd` 상수·접근자
4. `faction_view.gd`
5. `game.gd` 배선 — ⚠ **이 시점에 `net_shell` 의 기존 타이틀 흐름 줄이 빨개지는 게 정상이다**
   (시작하기가 더는 즉시 run 을 만들지 않으므로)
6. `net_shell.gd` 갱신 + `net_draw_leaf.gd` 표 + `net_faction.gd` — **화면은 검사가 나중**
7. `CONTEXT.md` 두 줄

### Risk

- **병렬 작업과 겹치는 파일** (순서 조율용, 전체 목록): `src/sim/rules.gd` (티켓 11 이 장비 절을
  갈아엎는 중 — 이 계획은 **새 절 추가**만이라 영역이 다르지만 같은 파일), `src/look.gd` ·
  `tests/nets/net_draw_leaf.gd` (티켓 12 카드 화면이 만질 수 있음), 그 외 `src/sim/run.gd` ·
  `src/shell/game.gd` · `src/view/faction_view.gd`(신규) · `tests/nets/net_run.gd` ·
  `tests/nets/net_shell.gd` · `tests/nets/net_faction.gd`(신규) · `CONTEXT.md`
- **가짜 코드 목록 대조**: 잠긴 칸에 `note_press` 를 부르면 「화면은 변하는데 sim 은 안 변한다」다 —
  설정하기가 이미 밟고 기록한 지뢰, 같은 규칙으로 막는다. 진영 화면 자체는 sim 을 안 바꾸는 게
  맞다(타이틀과 같은 회차 이전 화면)
- **sim 은 잠긴 진영을 생성 시점에 거부하지 않는다** — `Run.new(1)` 을 코드로 부르면 그대로 기록된다.
  문은 껍데기의 `is_slot_pressable` 하나고, 그 술어의 임자는 `Rules.faction_unlocked` 다. 이것은
  설정하기와 같은 모양이며 계획이 아는 채로 두는 구멍이다 — `net_shell` 이 잠긴 칸 클릭으로 run 이 안
  생기는 것을 문다
- **「포유류를 고르면 늑대 고정」은 지금 공허하게 참이다** — `SUMMON_SLOTS` 가 이미 늑대의 표라서,
  고르기는 기록이지 선택이 아니다. 코드 주석이 「진영이 명부를 고른다」고 말하면 거짓말이 된다 —
  진영→명부 연결은 둘째 진영이 열리는 날의 일이라고 쓴다
- `net_shell` 의 자식 인덱스 핀과 `game.gd` 머리 주석의 「세 화면」 주장 — 어느 한쪽만 고치면 주석이
  거짓이 된다

### Acceptance

- 헤드리스 (`net_shell` 방식): `_ready()` → 시작하기 클릭 → 타이틀 꺼짐 · 진영 화면 켜짐 ·
  `run == null` → 잠긴 칸 클릭 → 아무 일도 없음(눌림 흔적조차) → 포유류 클릭 → `run != null` ·
  `run.faction == Rules.FACTION_MAMMAL` · 지도 화면
- `net_run`: 표 세 줄 · 열린 것 하나 · 기본/기록/재시작 보존
- 모든 그물 초록, `net_draw_leaf` 가 `FactionView` 훅을 안다
- 눈: 게임을 켜면 타이틀 → 진영 셋(포유류만 눌리고 둘은 흐림) → 지도

### Out of scope

- **진영 화면에서 타이틀로 되돌아가기 없음** — 이 게임의 어느 화면에도 뒤로가 없고 티켓도 안 시켰다
- **진영이 명부(`SUMMON_SLOTS`)를 고르는 연결 없음** — 둘째 진영이 열리는 날의 일
- **진영 이름 확정 없음** — 「포유류·파충류·공룡」은 티켓 13 의 갈림표에서 온 계통 자리표시자,
  바꾸는 날 `rules.gd` 라벨 한 줄
- **잠금 해제·저장 없음** — 열림은 const, 데모에 메타 없음
- **TitleView 와의 공용 위젯 추출 없음** — 화면 둘로는 아직 복제가 싸다
- 설정하기는 그대로 죽어 있다

---

## Answer — ⚠⚠ **접었다. 안 짓는다** (2026-08-24, 사용자: *"접고 바로 시작하자"*)

**계획은 다 서 있었고 코드는 한 줄도 안 쓰였다** — 그러라고 계획을 먼저 뽑았다.
근거는 티켓 13 의 뒤집힘 기록에 있다. **위의 Implementation plan 은 지우지 않는다** —
진영 화면이 언젠가 돌아오면(펀딩 뒤, 진영이 둘이 되는 날) 이 계획이 출발점이다.
