# 구조 정비 계획 — 본격 개발 전 뼈대 고치기

> ## ✅ **세션 22(2026-07-17)에 전부 처리됐다 — 이 문서는 이제 이력이다.**
> 결과 요약 = `docs/STATUS.md` 「세션 22」. 커밋 `4d98c73`(C1+I1+C3) · `c0e57b0`(C2+M2+I4) · `e8890f0`(C4+I3).
>
> **아직 유효한 부분**: 아래 「🟢 문제가 아닌 것」 절 — 판정은 그대로다, 건드리지 마라.
> **계획과 달랐던 점 2가지:**
> 1. **C3가 계획보다 넓었다** — projectile의 착탄 충격파·중첩 진도 `_design`을 타는 죽은 분기여서
>    함께 나갔고, `ink_render.gd`(320줄)까지 삭제됐다. ⚠ **부작용: `shockwave.gd`·`.tscn`이 참조 0이
>    됐다** (삭제 목록에 없어 남겨 뒀다 — 지울지는 사용자 판단).
> 2. **C4 중 `test_ring_trace_auto`가 조용히 깨져 있던 걸 발견** — 내부 필드를 더듬다 런타임 에러로
>    중단됐는데 `failures=0`이라 "OK"를 찍었다. 공개 API로 교체했다.
>
> 아래는 세션 21이 쓴 원문이다 (판단 근거·줄 번호는 그때 기준).

---

> 작성: 2026-07-17 세션 21 끝. 근거 = 대청소(194파일 삭제) 직후 전체 구조 리뷰.
> 사용자: *"이제 본격적인 개발이여서, 지금까지는 핵심재미 검증이였고"* → **다음 세션에 아래를 모두 처리한다.**
>
> **총평: 뼈대는 건강하다.** 실제 결함은 "설계가 틀렸다"가 아니라 **"죽은 세대를 아직 안 묻었다"**와
> **"규칙을 스스로 안 지킨 곳 2군데"**다.
>
> ⚠ 줄 번호는 세션 21 종료 시점(`bfbc3cc`) 기준 — 손대면 밀린다. 먼저 grep으로 확인할 것.

## 🟢 문제가 아닌 것 (건드리지 마라 — 이미 판정 끝났다)

- **`src/drawing` 이름** — 정확하다. 고리 "조립"만 남은 게 아니라 `trace_stroke`(`ring_board.gd:285`)·
  `coverage`(`:238`)·`accuracy`(`:247`)가 **손그림 탁본**이고 그게 이 게임의 심장이다
  ([[takbon-hand-trace-commit]] · [[takbon-core-fun-drawing]]). **그대로 둔다.**
- **`base.gd:14`가 `ring_forge_panel`을 preload** — 위반 아니다. 진입 씬 = **조합 루트**이고 누군가는
  모듈을 조립해야 한다. 결합도 얕다(`open`/`design_committed`/`closed` 3계약뿐, 보드 내부를 모른다).
  ⚠ 반면 **C2(`spell` → `drawing`)는 조합 루트가 아니라 진짜 위반이다** — 둘을 구별할 것.
- **`data/runes/*.tres` → `projectile.tscn` 결합** — 좋은 설계다. 룬 3개가 **같은 씬 하나**를 가리키니
  부팅 비용은 PackedScene 1개다. "데이터가 씬을 가리킨다"는 이 프로젝트의 핵심 철학
  (`jin_def.gd:6` *"진 모양 추가 = .tres 한 장"*). **문제는 반대쪽 → M2 참조.**
- **조용한 발신자들** — `player_hp_changed`·`resources_changed`·`equipment_changed`·`phase_changed`는
  emit되는데 리스너가 0이다. **정상이다**(HUD가 삭제됨, 발신 측은 계약을 지킴). 지우지 마라.
- **성능·입력·리소스 관리** — 리뷰에서 지적 사항 없음. `_process` 게이팅·StringName·`accept_event`
  규율·`call_deferred`(물리 콜백 회피, 이유가 주석에 있음) 전부 정석.

## 🔴 권장 순서 (의존성 순 — 뒤집지 마라)

### 1. C1 — `.call(&"...")` 44곳을 타입 주석으로 (**먼저. 나머지의 안전망**)

- **무엇**: `ring_forge_panel.gd`가 보드·책을 문자열 동적 디스패치로 부른다(42곳) + `base.gd:37` +
  `ring_spell_system.gd:49,52`. 반환이 Variant라 `bool(...)`·`float(...)` 캐스팅이 사방에 붙는다.
  원인 = `var _board: Control`(`ring_forge_panel.gd:66`)로 실제 타입을 버린 것.
- **왜 지금**: 오타가 파싱 에러가 아니라 **런타임 에러**다. 보드 API는 앞으로 계속 는다(그리는 재미 =
  로드맵의 심장) — 리팩터할 때마다 42곳이 조용히 깨질 수 있다. **C4 분할도 이게 있어야 타입으로 주고받는다.**
- **어떻게**: `class_name` 금지 규칙을 지키면서 정적 타입을 받을 수 있다 — **헤드리스로 검증됨**:
  ```gdscript
  const RingBoard := preload("res://src/drawing/ring_board.gd")
  var b: RingBoard = RingBoard.new()
  var ok: bool = b.can_commit()   # 동작 확인함
  ```
  `var _board: RingBoard` / `var _book: RingBook`으로 바꾸고 `.call(&"...")`을 직접 호출로 교체.

### 2. I1 — `src/base` 폴더째 삭제 (독립적)

- **무엇**: `research_service.gd`(74) + `recipes.gd`(75) = **149줄**.
- **왜**: `save_manager.gd:8`이 스스로 *"위반"*이라 인정하며 preload하는데, **처방이 틀렸다.**
  `ResearchService`를 참조하는 건 `save_manager.gd`(:8,78,79,143,144)와 `tests/test_save_auto.gd:25`가
  전부고 **`start()`를 부르는 코드가 없다.** `research_service.gd:56` 주석의 *"거점 씬이 매 프레임
  호출"* — **그 거점 씬은 세션 21에 삭제됐다.** 즉 SaveManager가 **아무도 만들 수 없는 상태를
  직렬화 중**이다. GameState로 이관하면 유저 0인 시스템을 core에 영구히 모시는 셈.
- **어떻게**: 폴더 삭제 + `save_manager.gd`의 `:8` preload·`:78-79` 저장·`:143-144` 로드 삭제 +
  `event_bus.gd:50` `research_completed` + `game_state.gd:39` connect 삭제. **위반이 저절로 증발한다.**
  세이브 호환 안전(로드가 전부 `data.get(키, 기본값)`). 나중에 연구가 필요하면 그때 설계(레시피는 git에).

### 3. C3 — 옛 SpellDesign 매장 (**순서 엄수 — 뒤집으면 부팅 불가**)

- **얽힘**: `event_bus.gd:8,9,13,14,15,51`이 시그널 시그니처에 `SpellDesign`을, `:31`이 `EnemyDef`를
  **타입으로** 쓴다. 스키마를 먼저 지우면 → EventBus 파싱 실패 → **오토로드 전부 연쇄 실패 → 부팅 불가.**
  또 `projectile.gd:91,124,162,197`이 `SpellDesign`을 쓰는데 **projectile은 살아 있는 고리 경로가 쓴다**
  (`ring_spell_system.gd:18`). 다만 `:124` `p_design: SpellDesign = null`이 기본값이고
  `ring_spell_system.gd:82`가 8인자로 호출해 안 넘기므로 **이미 null로만 쓰인다.**
- **순서**:
  1. `event_bus.gd` — 참조 0 시그널 13개 삭제: `design_updated`·`recognition_result`·`ring_cast_executed`·
     `enemy_died`·`player_damaged`·`player_died`·`rubbing_started`·`rubbing_completed`·`design_repaired`·
     `training_hit`·`tutorial_focus`·`scene_change_requested`·`scene_changed`. 이어서 옛 경로 전용
     `design_created`·`cast_requested`·`cast_executed`·`cast_failed`.
  2. `game_state.gd` — `:17` `equipped`, `:21` `designs`, `:41` connect, `:180` `equip()`, `:186` `_on_design_created()`.
  3. `save_manager.gd` — `:32-41`·`:117-129` 옛 도안 블록, `DESIGN_DIR`·`_prune_design_files`.
  4. `projectile.gd` — `p_design` 파라미터·`_setup_body`의 ink·`_design_radius_px` 제거(호출측이 이미 null).
  5. 그제야 삭제: `spell_system.gd`(281·완전 사장) + `ink_render.gd`(320) + `spell_design.gd`(78) +
     `arrow_data.gd`(53) + `rune_instance.gd`(20) + `stroke_data.gd`(7) ≈ **759줄**.
  6. ⚠ `sheet_lib.gd`는 **남겨라** — `projectile.gd:215`가 쓴다.
- ⚠ `enums.gd:9`의 `RuneType { FIRE=0, WATER=2, WIND=3 }` 구멍과 `LEGACY_IMPACT`는 **세이브 호환용이니
  건드리지 마라**(주석이 옳다). `migrate_legacy_runes` 언급(`:8`)만 주석 갱신.

### 4. C2 + M2 — 발사 계약을 core로 (둘 다 `ring_spell_system.gd:16,18` preload 제거로 수렴)

- **C2 (진짜 위반)**: `ring_spell_system.gd:16`이 `ring_board.gd`(757줄 Control·렌더·입력 포함)를
  preload하는데 **쓰는 건 정수 2개뿐**(`:66` `G_RADIATE`, `:68` `G_GATHER`). 발사가 UI에 의존하는 방향이라
  나중에 헤드리스 발사나 UI 교체 때 정면으로 막힌다. **정답이 이미 core에 있다** —
  `glyph_def.gd:8` 주석이 *"code = 발사 계약의 정수 코드 — ring_spell_system이 이 값으로 전개를 가른다"*
  라고 적어 놓고 정작 안 지킨다.
  → `enums.gd`에 `enum GlyphCode { GATHER = 0, RADIATE = 1 }` 추가, `ring_board.gd:31-32`와
  `ring_spell_system.gd:66,68`이 둘 다 이걸 참조. preload 삭제.
- **M2 (데이터 철학 배신)**: `ring_spell_system.gd:18`이 `const BoltScene := preload(projectile.tscn)`로
  **하드코딩**한다. `projectile_scene`을 읽는 코드는 **죽은 `spell_system.gd:178-179`뿐** — 지금은
  결합 비용만 내고 이득이 0이고 "새 룬 = .tres 한 장" 약속이 새 경로에서 깨져 있다.
  → `:76` `_spawn_bolt`가 `Db.get_rune(...).projectile_scene`을 쓰게(`_fire_hit()`가 이미 `RuneDef`를
  읽는다 — `:98`). preload 사라지고 **물·바람 룬 추가가 진짜로 .tres 한 장**이 된다.

### 5. I4 — `src/playground` → `src/base` 개명 (2 이후)

- **왜**: `project.godot:14`가 가리키는 **본 게임 진입점**인데 이름이 "버려도 되는 실험"이라고 거짓
  신호를 준다. **세션 21에 리드가 정확히 이것 때문에 헤맸다**(엉뚱한 씬을 띄워 "다 사라졌다"는 오해).
  `base.tscn`/`base.gd`가 이미 그 이름이고, 참조가 `project.godot:14` + 스크립트 3개뿐이라 지금이 제일 싸다.
- **어떻게**: I1으로 `src/base`가 빈 뒤 개명. `project.godot:14`·`.uid` 갱신 + 리드가 `--import` 1회.

### 6. C4 — `ring_board.gd`(757줄) 3분할 (**가장 큼. C1 이후**)

- **무엇**: 조립 상태기계 + 손그림 캡처 + 기하 + 채점 + 렌더 + 입력 + 애니가 한 파일에.
  상태도 untyped다 — `:123` `var _scores := {}`, `:124` `var _locked: Array = []` → `:714` `int(L.target)`,
  `:746` `var ink: PackedVector2Array = L.ink`처럼 Dictionary를 문자열로 더듬는다(바로 옆 `:127`
  `_glyph_scale: Dictionary`는 타입이 있어 일관성도 없음).
- **왜**: [[takbon-core-fun-drawing]]이 *"핵심 재미 = 그리는 것"*이라 **채점 규칙은 매 세션 바뀐다.**
  지금은 채점 하나 고치려면 렌더·입력을 소유한 파일을 열어야 하고 컴파일러가 아무것도 안 잡아준다.
- **어떻게** (전부 `const preload` 유지, class_name 없음):
  - **`ring_assembly.gd`** (RefCounted·순수 데이터) — `_stage`/`_has_jin`/`_has_rune`/`_slots`/`_open` +
    `advance` 상태전이 + `get_assembly`/`can_commit`/`set_template`/`_next_open_slot`. 헤드리스 완전 테스트 가능.
  - **`trace_scorer.gd`** (RefCounted·순수 수학) — `_guide`/`_revealed`/`_ink`/`_dev_sum` +
    `coverage`/`accuracy`/`piece_score`/`get_analysis`/`_grade`. **채점 바꿀 땐 여기만 연다.**
  - **`ring_board.gd`** (Control) — 기하(`_area_center`/`_slot_pos`/`_build_guide`) + `_draw` + `_gui_input`,
    위 둘에 위임.
  - `_locked` 항목을 typed inner class(또는 `Array[Dictionary]`)로.
- 🔴 **분할 전에 테스트를 먼저 써라** — 지금 `test_ring_trace_auto`는 **추적·점수 중심이고 조립
  상태기계를 검증하지 않는다.** `get_assembly`/`can_commit`/`set_template` 계약 테스트 없이 쪼개면 조용히 깨진다.

### 7. I5 + M1 — 책 **껍데기만** 씬으로

- **무엇**: `ring_forge_panel.gd`가 `_build()`(`:426-514`)·`_build_report()`(`:520-546`)로 UI 전부를
  `.new()`한다. 좌표 상수 14개(`:33-43`) + `_draw_report`(`:550`)·`_report_row`(`:579`)에 매직넘버가
  흩어져 있다(`:28` 주석이 스스로 *"일일이 고치면 반드시 뭘 빠뜨린다"*고 인정).
- ⚠ **전부 씬으로 옮기는 건 틀린 처방이다** — `RingBoard`·`RingBook`은 `_draw()` 커스텀 렌더라
  에디터에서 드래그할 게 없다. 씬이 이득인 건 **책 껍데기**(종이 ColorRect·라벨 4·버튼 2·리포트 카드)뿐이고,
  그 "느낌"이야말로 그리는 재미를 좌우해서 계속 만질 곳이다.
- **어떻게**: `src/drawing/ring_forge_panel.tscn`에 껍데기만 담고 앵커·컨테이너로. `RingBoard`·`RingBook`은
  그 씬의 노드로 배치(스크립트는 코드 유지). `_build()` 소멸, `@onready var _next_btn: Button = $...`.
  `:33-43` 상수 대부분과 `:621` `_label()` 헬퍼가 증발.
  **`_fit_stage()`(`:100`)는 남겨라** — `stretch/aspect=expand` 대응으로 정당하다.
- **M1**: 씬이 생기면 `base.gd`의 preload를 `@export var forge_scene: PackedScene`으로 → preload 자체가
  없어져 규칙 논쟁이 사라진다(I5와 공짜로 묶임).

### 8. 마무리

- **I3 🔴 실제 버그** — `_nearest_open_slot`(`ring_board.gd:384-392`)에 **거리 컷오프가 없다.** 문양 단계에서
  판 아무 데나 클릭하면 최근접 열린 칸이 잡히고, `:623-626`이 무조건 `select_slot(k)`을 부른다.
  `select_slot`(`:363`)은 `:366-367`에서 현재 칸 coverage가 `COMMIT_COVER`(0.15)를 넘었으면 **자동
  확정**한다 → **칸 0을 그리다 획을 칸 2 쪽에 조금 가깝게 시작하면 칸 0이 멋대로 확정되고 넘어간다.**
  *"마음에 들 때까지 다시 그린다"*(`:276` 주석) 설계와 정면 충돌.
  → 최대 거리(예: `_outer_radius() * 0.18` — `:723`의 칸 표시 `ro*0.05`·강조 `ro*0.11`과 맞춤) 밖이면
  `-1` 반환, `-1`이면 칸 전환 없이 현재 칸을 계속 그린다.
- **I2 침묵한 리스너** — `extraction_success`(`game_state.gd:37` 가방 정산·`save_manager.gd:19` 자동저장)·
  `bag_lost`(`:38`·`:20`)는 connect돼 있는데 **emit이 0**이다. 필드를 붙이는 순간 **조용히 안 도는 채로**
  시작한다(CLAUDE.md가 경고하는 "조용히 죽은 테스트"와 같은 실패 모양).
  → **시그널·핸들러는 남기고**(익스트랙션 루프의 진짜 계약) `event_bus.gd`에 *"발신자 없음 = 필드 미구현"*
  주석으로 의도를 못 박아라. `design_created`·`codex_unlocked` connect는 C3에서 삭제.
- **M4 `clock.gd`** — 죽지 않았다. `_process`(`:17`)가 하루를 넘기며 `day_started`(`:56`) →
  `save_manager.gd:21-23` **자동저장**. 지금 게임에서 **자동저장을 유발하는 유일한 경로**다.
  → **남기고** 최상단에 *"실질 역할 = 자동저장 틱. 낮밤 소비자는 필드 구현 후"*를 명시.
- **M5** `base.gd:16` `@onready var _desk = $Desk` 타입 누락 → `const Desk := preload(...)` 후
  `: Desk`. `:40` 주석 *"본 게임 base.gd와 동일"* — **그 본 게임은 이제 없다.** 삭제.
- **M6** `ring_board.gd:346` `finish()`가 `_slots`를 바꾸는데(`:349`) `assembly_changed`를 안 쏜다
  (`advance()` `:336`과 불일치). 지금은 증상 없지만 구독자가 늘면 [맺기] 경로만 갱신을 놓친다. `:353` 근처에 emit.

## 예상 효과

1~5 = **약 900줄 삭제 + 규칙 위반 3건 해소.** 6~7 = 심장 정비.
각 단계 후 테스트 4종(ring_design·ring_trace·ring_spell·save)으로 회귀를 잡는다 — **단 C4는 예외**(위 경고).
