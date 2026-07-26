# 탁본 (TAKBON) — Godot 4.7.1 · 2D 탑다운 익스트랙션 로그라이트

2D 탑다운 로그라이트. **마법진을 조립해 원소 마법을 쏜다** — 마을(`src/base`)에서 고리 조립 책으로 도안을 맺고, 챕터(보스방)에서 쓴다. 1인 개발(사용자) + Claude 리드 세션 + 서브에이전트 팀.
⚠ GDD §1~2의 「손으로 그린다 = 심장」은 세83에 폐지된 서술이다(스위치 `balance.skip_drawing`으로 되돌릴 수 있어 코드는 살아 있다). GDD 개정은 🔒 사용자 허락 대기.

## 새 세션이 먼저 읽을 것

> 📖 **진실원 = `docs/GDD.md`** (게임이 무엇인가) — 🔴🔴 **사용자 허락 없이 수정 금지**(settings.json `ask`).
>   ⚠ GDD는 「그리기」에 관해 낡았다(세83 폐지, 개정 대기) — 그 절만 현재 상태가 아니다.
> 역할: **이 파일**=아키텍처·함정·검증 · `docs/STATUS.md` 최상단=세션 서사 정본 · `docs/PROGRESSION.md`=관문표 · `docs/takbon-design/`=진행 중 설계 · `docs/HARNESS_LOG.md`=하네스 이력 · memory=세부.
> 지금 게임 = `src/base`(마법사 학교 마을) + 고리 조립 책 + 챕터(보스방) 루프 + 온보딩 레일.
> 🔴 **세션 서사를 여기 쓰지 마라 — STATUS로 간다.** 이 파일에 남는 건 「다음 세션이 잃으면 버그를 다시 밟는 것」뿐이다.

🔴 **직전 세션 = STATUS.md 최상단**(세86 「신설 4건 + 층 = 띠」). 서사·이월·검증 기록은 전부 거기다.
**지난 세션**: 정본 = `docs/STATUS.md`(세41~86 절 전부 있다) + memory 인덱스. 여기 요약본을 두지 마라 — 세 벌로 갈라진다. ⚠ 이 파일이 나르는 건 **역사가 아니라 계약**이다: 단일 소스 지정과 함정은 아래 절에, 테스트가 무엇을 재는지는 검증 절에 있다.

## 🔴 지금 게임이 무엇인가 (은퇴한 것 포함)

- 🔴 **그리기(탁본)는 세83에 폐지됐다 — 단, 「스위치」다.** `balance.skip_drawing`(기본 true)을 false로 되돌리면 손 긋기·채점기·펜 보정이 그대로 살아난다. **묻는 건 `RingPower.skip_drawing()` 하나로**(직접 `BAL`을 읽으면 한 곳을 되돌릴 때 갈라진다). 청소할 땐 「되돌릴 수 있어야 하는 것」(`enter_combined_trace`·coverage/accuracy·펜)과 **「세70에 은퇴한 per-piece」**를 갈라라. 지금 위력 = `RingPower.assembled_score(문양수, 층수)`.
- ⚠ **숲 원정은 세58-B에 은퇴했다** — `forest.gd`/`forest.tscn`은 **삭제됐고** 챕터 보스방이 대신한다(`forest_enemy`는 이름만 옛 것이고 지금도 **범용 적 몸**으로 산다).
- ⚠ **은퇴 목록**(되살리려다 헤매지 마라): per-piece 조립 상태기계(세70·85) · `JinDef.glyph_slots`(세85) · 지팡이의 「발사 형태」 축(세85) · 해독대·조각(세85) · 허기(세58) · 매직볼(세59) · 문양본 축(세60).

## 🔴 남은 빚 · 미결 결정 (전부 「사용자 결정 대기」)

- **`rune_fill`(룬 농도) 소비자가 0곳** — 살릴지 접을지 미정(`ring_spell_system._fire_hit` 위 주석이 그 사실을 명시).
- 🔴 **BOLT·EARTH·GRASS 전용 피격음이 없다** — `audio._on_enemy_hit`의 `match rune_type`이 FIRE·WATER·WIND 세 줄뿐이라 나머지 셋은 무음이다. 한 세트 = wav 3장 + match 3줄(세33 「새 소리 = wav 한 장」). ✅ **볼 애니는 이미 6종 전원 배선됐다**(`ring_carrier.BALL_ANIM` — 옛 「fireball 폴백이라 번개를 쏴도 불덩이가 난다」 서술은 낡았다).
- **취약 이중 증폭** — 반응 산물에 배수가 두 번 곱해 DoT가 의도의 2배(초당 13.5)이고 clamp가 없다(`status_holder`의 `apply_incoming` → `_resolve_reaction` → `add`가 배수를 각각 얹는다). 감속은 상한 포화라 레버가 이미 죽었다. 수정 = 곱하는 자리를 하나로.
- **반응 VFX 스테이지3~4** 보류 · **미결 결정**(D3 문양 게이트·D5 진 카탈로그·D6 흙/번개 네임드·잡몹 공급원 무대 0곳) = `docs/PROGRESSION.md` 「미결」절.
- ⚠ **임시 시드가 누적돼 있다**(M1 재료 3종·융합진·응축·룬 6종) — 관문을 붙이는 세션은 **해당 시드 줄을 같이 지워야** 관문이 조용히 안 죽는다(세58). 정본 = `docs/PROGRESSION.md`.
- **세86 이월**(상세 = STATUS 최상단): 문양 모티프를 예쁘게(🔴 판·아이콘·책 셀이 **전부 `RingBoard.glyph_guide_pts` 한 곳**에서 나온다 — 그 함수만 고치면 셋이 같이 바뀐다) · Tab 마법진 탭 머리글이 탭 버튼과 겹침 · 완성 연출이 은은함(`FINISH_*`) · 무성함이 감속으로 차별화 안 됨(상한 포화 — 답은 `status_overgrowth_sec`) · 접힌 보관 도안을 UI로 못 만짐.

## 🔴 살아있는 함정 (전부 실제로 밟은 것 — 서사는 지워도 이건 유지)

🔴 **먼저 구조적 테마 8개** (세84 전면 감사 — 개별 버그가 아니라 **왜 이 종류가 자꾸 생기나**. 아래 함정들은 대개 이 여덟 갈래 중 하나에서 나온다): **T1** 모드 분기를 일부 자리에만 넣고 **소비 지점 목록을 안 만든다** · **T2** **은퇴를 선언 없이 두어 죽은 몸이 살아있는 그물을 갖는다**(= 「전 스위트 그린」이 라이브 경로의 근거로 **과대평가**된다) · **T3** 소비자가 사라진 데이터 필드가 **거짓 손잡이**로 남는다 · **T4** **주석이 계약인데 코드와 함께 안 늙는다**(세87에 `src/` 주석을 전량 정비하며 거짓 주석을 실측 정정했다 — 그래도 다시 늙는다) · **T5** 파생 대신 복제(**문구·좌표는 사본이 아니라는 무의식 예외**) · **T6** 실패를 로그 없이 삼킨다(🔴 **엔진 ERROR·`push_warning`은 `SCRIPT ERROR` grep에 안 걸린다** — 세50 바람 룬이 두 세션 죽어 있던 이유) · **T7** **「임시 시드」 딱지가 그물을 안 세우는 면허로 쓰인다** · **T8** 축이 1→N으로 늘 때 **표시부가 뒤처져 「쏘는 것 ≠ 보이는 것」**이 된다.

- 🔴🔴 **생명체·프롭은 도형 플레이스홀더로 때우지 마라 — 진짜 도트 아트를 만든다** (세54, 사용자 확정): 새 적·캐릭터·아이템·프롭을 `Polygon2D`·`ColorRect` 같은 기하 도형으로 임시로 채우지 마라. **반드시 `takbon-art`로 도트 스프라이트를 만들어 배선한다**(적 = `params.sprite`+`_setup_frames` 스트립, 그 외 = Sprite2D). "아트는 병렬이니 플레이스홀더로 먼저"는 **각하됐다**(세54에 뱀 보스가 팔각형 마디로 나가 실제로 밟았다). ⚠ **예외 = 절차적 VFX**(`death_puff`·`vfx.gd` Line2D·진/문양 가이드선)는 애초에 그림이라 도형이 맞다. 판별 = "이건 도트로 그려야 할 물건인가?" → 그렇다면 **art부터 태운다**.
- 🔴🔴 **`.tres`는 두 가지로 다르게 죽는다** (세50 발견 · 세85 실측 정정): **ⓐ 스키마에 없는 프로퍼티 *이름*은 조용히 무시되고 리소스는 산다.** **ⓑ *값* 파싱 실패는 리소스를 통째로 죽인다**(`Color`를 **3인자**로 쓰면 `Db`가 말없이 건너뛴다 — 룬 6→5로 실증). 그래서 필드를 스키마에서 걷을 때 `.tres`의 남은 줄은 **호환을 안 깨지만**, 값 문법을 틀리면 그 파일이 통째로 증발한다. 바람 룬이 두 세션 내내 그렇게 죽어 있었고 **전 스위트가 그린이었다**(검출력 0). ⚠ **"파일을 만들었다"를 완료로 치지 마라 — `Db`를 거쳐 실제로 로드되는지 확인해라**(`test_rune_unlock_auto`의 「룬 6종 로드」가 그 그물이다).
- **`Enums.RuneType`은 값이 연속이 아니다** — `[0, 2, 3, 4, 5, 6]`(1은 은퇴한 IMPACT 구멍). 인덱스로 착각하면 「없는 룬」이 생긴다. 순회는 반드시 `Enums.RUNE_TYPES` 상수로(`RuneType.size()`/`range()` 금지). **enum은 값을 먼저 확인해라.**
- 🔴 **문서에 `파일.gd:숫자`를 적지 마라 — 이름으로 가리켜라**(세87 실측): 주석 한 줄만 늘어도 통째로 밀린다. 세87에 주석 정비 갈래가 `src/`를 손대자 **같은 세션에 측정된 인용 8건이 그 자리에서 어긋났다**(`boss_room:210,237`→212,239 · `audio.gd:139`→141 · `ring_board.gd:625`→631·`:789`→800 …). 함수·상수 이름은 `grep`으로 바로 찾히고 안 늙는다.
- 🔴 **배선이 맞아도 「반경 밖」이면 아무 일도 안 일어난다** (세50) — 연습장 허수아비 간격 102px vs 감전 연쇄 90px라 연쇄가 **한 번도 안 터졌다**. 반경을 쓰는 기능을 붙였으면 **좌표를 실측해라**. ⚠ 씬(`.tscn`)의 `;` 주석은 **에디터가 저장하면 날아간다** — load-bearing한 설명은 코드에 둬라.
- ⚠ **없는 문제를 막다가 진짜 함정을 심지 마라** (세50) — `_exit_tree`로 콜백을 끊어 "참조 순환"을 막으려 했는데 **그 순환이 애초에 없었고**(Callable은 Node를 강참조 안 함), 대신 **리페어런팅 시 콜백이 영구히 죽는** 침묵을 새로 만들었다.
- **화면 덮는 Control엔 `mouse_filter = 2`** (세25) — 없으면 바닥이 좌클릭을 다 먹어 발사가 **에러 없이 죽는다**. 1차 방어선 = `test_scene_contract_auto`(정적 스캔) · 닿는지 자체는 **실게임 `push_input`으로만** 확인된다.
- **씬끼리 PackedScene preload 금지** → `@export_file` + `change_scene_to_file` (세26) — 순환 preload가 껍데기 노드를 만들어 귀환·사망 시 못 돌아옴. 헤드리스 절대 못 잡음.
- **등급/펑 경계는 `is_stable()`을 그대로 부른다** — 65를 상수로 베끼면 갈라진다 (세24, `src/core/ring_power.gd`).
- **발사는 caster의 `to_assembly()`로만** — 직접 Dictionary를 만들면 손그림 점수가 빠져 **조용히 기준 위력**으로 나간다 (세26).
- **`wipe_save()`는 새로하기가 아니다** — 오토로드(GameState·Clock)가 메모리에 남아 귀환 한 번에 옛 진행이 되살아난다. 진짜 새로하기 = `GameState.new_game()` (세37).
- **초록불을 근거로 쓰지 마라** — 헤드리스는 클릭 도달·렌더·시간 경과를 못 잡고 `-s`는 런타임 에러가 나도 "OK"를 찍는다. **뮤테이션으로 검출력 증명 + 실게임 확인** (세22·23·25, skill `takbon-verify`).
- 🔴🔴 **뮤테이션 되돌리기에 `git checkout <file>`을 쓰지 마라 — 남의 미커밋 작업까지 날아간다** (세85에 리드가 실제로 밟았다). 그 명령은 「뮤테이션만」이 아니라 **워킹트리를 통째로 HEAD로 되돌린다** — 병렬 갈래가 도는 세션에선 그 한 줄이 에이전트 3갈래의 성과를 지운다(실제로 3파일이 날아가 재작업했다). 반드시 **`cp f f.bak` → 뮤테이션 → `cp f.bak f` → `rm f.bak`** + md5 대조. ⚠ 더 무서운 건 **복구 뒤 전 스위트가 그대로 그린이라는 것**이다 — 날아간 게 「아직 그물이 없는 신규 기능」이면 초록불이 소실을 덮는다.

- **docs/GDD.md** 🔒(정체성 진실원, 수정 허락 필요) · **docs/STATUS.md**(세션 로그 — 종료 시마다 갱신) · BACKLOG.md(E4·E5) · ART_SPEC.md(960×540·48px) · PROGRESSION.md(관문표·미결) · ONBOARDING_FLOW.md · takbon-design/(설계) · HARNESS_LOG.md(하네스 이력)

## 아키텍처 요약

- **부팅 = `src/menu/title.tscn`**(`run/main_scene` — 타이틀 메뉴, 세37). 이어하기/새로하기가 여기서 갈린다.
- **본 무대 = `src/base/base.tscn`**(마법사 학교 마을): 책상 **E** → 고리 조립 책 · **숲길 게이트 E → 챕터 선택 모달** → 고른 챕터가 `GameState.pending_chapter`에 실려 `src/field/boss_room.tscn`으로 간다(`change_scene_to_file`은 인자를 못 실어 오토로드가 나른다).
- **오토로드**: EventBus(시그널 허브) / GameState(자원·HP·장착·가방·도감) / Clock(낮밤 — 실질 역할은 **자동저장 틱**, 죽은 코드 아님) / Db(data/ 레지스트리) / SaveManager(user://save) / **Audio**(세33 — EventBus 9종 구독). ⚠ MCPGameBridge는 애드온이다.
- **모듈**: `src/menu`(타이틀) · `src/base`(마을·상점·공방·정제대) · `src/field`(챕터 보스방·적) · `src/actors`·`src/hud`(**공용** — 마을과 보스방이 같이 쓴다) · `src/props`(프롭 씬) · `src/drawing`(고리 조립) · `src/spell`(발사) · `src/core`(스키마·규칙 — 리드 전용)
  - 🔴 **`src/actors` = 공용 배우**: `player.tscn`(WASD·그룹 `"player"`) · **`player_caster.gd`**(조준·발사·슬롯) · **`floating_wand.gd`**(세65 — `equipment[WAND]` 있을 때만 표시, 옆에 둥둥+조준 회전. 🔴 **발사 총구 = 지팡이 끝 `muzzle_position()`** 단일 소스, caster가 부른다 — 없으면 몸 중심 폴백) · `interact_zone.gd`(책상·게이트·귀환 지점이 **같은 물건** — 문구는 씬의 `Prompt.text`, 찾기는 `zone_id`).
    🔴 **발사를 복사하지 마라 — caster를 써라**: 직접 Dictionary를 만들면 `to_assembly()`가 빠져 **손그림 점수가 조용히 사라지고 기준 위력으로 나간다**. 그래서 뽑은 것이다
  - 🔴 **`src/hud/hud.gd` = 공용 HUD 한 장**(씬별 분기 없음 — 세64에 `hint_text`·`show_hp` @export를 둘 다 걷었다. 조작은 온보딩 대사가 가르치고 HP 막대는 늘 그린다). ⚠ **안내문에 있지도 않은 조작을 적지 마라** — 그 자체가 버그다(`test_ui_text_auto`가 잰다)
  - 🔴 **`src/field`**: `boss_room.tscn`(챕터 단칸방 — 유일한 원정 무대) · `forest_enemy`(범용 적 몸, 이름만 옛 것) · `enemy_projectile` · `snake_body`/`snake_boss.tscn`. **적 수치는 전부 `data/enemies/*.tres`(EnemyDef) — 새 적 = .tres 한 장**이고 드롭은 `forest_enemy._die`가 굴린다.
    🔴 **출격 = 만HP는 무대(`boss_room._ready`)가 한다** — 다른 진입 경로를 뚫으면 조용히 달라진다.
    🔴 `extraction_success`·`bag_lost`를 **emit하는 곳도 여기뿐**이다(`boss_room`의 `_extract`·`_die`) — 새 무대를 붙이는 쪽이 쏴야 정산·자동 저장이 돈다(수신자는 이미 셋 다 살아 있다)
  - `src/drawing` = **ring_assembly**(조립 상태기계·순수 데이터 — `ring_board`가 preload해 상수·인스턴스로 쓴다) · **trace_scorer**(탁본 채점·순수 수학) · **ring_board**(기하·렌더·입력) · ring_book · ring_forge_panel(+`.tscn` 껍데기)
    🔴 **채점(완성도·정밀도·펜 보정)을 바꿀 땐 `trace_scorer.gd`만 연다** (세22 분할의 이유)
    🔴🔴 **per-piece(조각별로 하나씩 긋기) 경로는 세70에 은퇴했고 세85에 걷어냈다** — 라이브 진입점은 **`enter_combined_trace` 하나**다. `advance`/`finish`/`select_slot`/`choose_jin`/`choose_rune`/`ring_summary`를 찾다 헤매지 마라(없다. `test_ring_assembly_auto`가 **재발까지 감지**한다)
  - 🔴 **점수 → 펑/위력/등급 규칙 = `src/core/ring_power.gd`** (세23·24). 조립 리포트(UI)와 발사가 **같은 함수를 부른다** — core에 둔 이유가 이것이다. 복사해 두면 한쪽만 고쳐도 갈라진다(리포트는 "위력 140" 적고 130으로 때리는 식). 수치는 balance.tres
    - `grade_of`도 여기다. **최하단 「사용 불가」는 `is_stable()`을 그대로 부른다** — 65를 상수로 베끼면 기준선과 갈라진다(세23의 「무난인데 터진다」가 정확히 그거였다). `is_perfect()`로 UI가 퍼펙트를 강조한다 — **등급 이름을 `==`로 비교하지 마라**
  - 🔴 **보정은 펜이 판다**: `ItemKind.PEN` → `data/items/pen_*.tres`의 `params.correction` → `GameState.stroke_correction()` → `ring_board.enter_combined_trace` → `trace_scorer.set_correction`. **새 펜 = .tres 한 장.** 맨손 = 보정 0 = 그린 대로
  - `src/spell` = **ring_spell_system(유일한 발사 경로)** · ring_carrier(+carrier_trail) · projectile · pillar(`ring_spell_system._spawn_pillar`가 직접 생성) · **blast**(폭발·응축) · dummy_target
- 모듈 간 통신은 **EventBus 시그널 + core 스키마만**. 타 모듈 직접 preload/get_node 금지
  - 🔴 **발사 계약 = `Enums.GlyphCode`**(지금 **9값**: GATHER=0/RADIATE=1/PIERCE=2/HOMING=3/BOUNCE=4/THRUST=5 + 수식자 3). 조립 UI·발사·`data/glyphs/*.tres`의 `code`가 이 값을 공유한다 — **밀면 저장된 도안이 조용히 깨진다. 끝에만 덧붙여라.**
  - ⚠ 예외로 정당한 것: `base.gd`가 책 씬을 무는 것(진입 씬 = 조합 루트)
- 밸런스 수치는 전부 **data/balance.tres** (BalanceData) — 코드에 수치 금지
- typed GDScript 강제. 렌더러 Compatibility, **뷰포트 960×540**(세18에 640×360에서 올림, aspect=expand)

## 개발 규칙 (병렬 에이전트 운영 시)

- **git 커밋은 리드(메인 세션)만.** 에이전트는 자기 모듈 폴더 + tests/ 자기 접두사 파일만 수정
- 에이전트 새 스크립트에 **class_name 선언 금지** → `const X := preload(...)` (전역 클래스 캐시는 리드의 `--import` 때만 갱신됨)
- 에이전트는 mcp__godot__* 도구 사용 금지 (에디터는 리드가 관리) · 스키마·시그널 추가 요청은 에이전트가 보고 → 리드가 core에 반영
- 🔴 **하네스는 자립형이다**(godot-prompter 플러그인 없이 돈다). `.claude/skills/`의 제네릭 스킬은 한국어로 번역된 **탁본 로컬 포크**라 상류를 안 따라간다 — 영어 원본이 필요하면 상류 github. 구성 이력·삭제 사유 = `docs/HARNESS_LOG.md`.
- 🔴 **기획은 리드가 한다** — `takbon-design` 스킬로 **사용자와 대화하며** 확정(질문 하나씩·2~3안+추천·섹션 승인·`docs/takbon-design/` 착지). 서브에이전트는 대화를 못 해 혼자 정한다 — **기획을 위임하지 마라.**
- **위임 대상**(`.claude/agents/`): `takbon-dev` · `takbon-architect`(확정 설계 리뷰 — 방향은 안 정함) · `takbon-reviewer` · `takbon-ui` · `takbon-art` · `takbon-relight` · 가끔 `takbon-shader`·`takbon-animator`. 다들 `takbon-rules`·`takbon-verify`를 읽고, 제네릭 Godot 지식은 `.claude/skills/`의 제네릭 스킬(`gdscript-patterns`·`animation-system`·`physics-system`·`godot-ui` 등)을 Skill 도구로 부른다. **규칙 충돌 시 탁본이 이긴다.** (개수는 적지 마라 — 늘 낡는다.)
- 🔴🔴 **기본이 위임이다** — 위임은 손을 던다기보다 **설계·리뷰 단계를 강제해 품질을 올리는 장치**다(세48 사용자 의도). 파이프라인: `architect`(설계) → `dev`/`ui`/`art`(구현) → `reviewer`(커밋 전). **코드부터 얹지 마라.**
- 🔴🔴 **에이전트에게 「보고서를 `scratch_<이름>.md`로 써라」고 지시해라** — **채팅 최종 보고는 리드에게 안 온다**(idle 알림만 온다). 특히 architect·reviewer는 산출물이 보고서뿐이라 파일로 안 시키면 작업 전체가 사라진다. 읽고 나면 리드가 지운다.
- 🔴 **리드가 절대 안 놓는 것 = 검증·`--import`·커밋.** **에이전트의 「그린 나왔습니다」를 근거로 쓰지 마라** — 리드가 직접 돌리고 뮤테이션으로 검출력을 확인한다.
- ⚠ **뮤테이션을 시킬 땐 원상복구까지가 지시다** — 되돌린 채 두면 기능이 조용히 죽은 채 커밋된다. 리드는 커밋 전 `git diff`로 본다.

## 검증 명령 (반드시 Bash에서 — PowerShell은 자식 프로세스 stdout을 안 보여줌)

**전 스위트를 다 돌려라** — 목록에서 빠진 테스트는 낡아 죽는다(실제로 두 번 겪었다).

```bash
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_save_auto.gd            # 저장/로드 (고리 라운드트립) · 🔴**부팅만으로 자동 저장이 준비되나**(세션 26 F3 — 이 확인은 `load_game()` **호출 전**에 있어야 한다. 순서가 곧 검출력이다) · 🔴🔴**세86 ⑫ `inventory_changed` = 저장 트리거**(창고 증감만 저장을 걸고 **`add_to_bag`은 안 건다** — 드롭마다 세이브 전량 재작성은 세84가 각하한 낭비다) · 🔴**세86 ⑥ 로드가 codex를 clear하고 시드를 다시 심는다**(clear만 넣으면 **빌드가 시작 해금을 늘려도 옛 세이브에서만 사라진다** — 세이브에서 시드 키를 떼어 그 순서를 잰다). ⚠ **GDScript 람다는 로컬을 값으로 캡처한다** — 신호 카운터를 `var n := 0`으로 세면 안 와도 그린이다(리드가 밟았다, 참조 타입으로)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_assembly_auto.gd   # **고리 조립 계약** (세85 ⑦⑨ 재편 — per-piece 상태기계와 「진이 칸을 여는 규칙」이 **은퇴해** 이 파일의 절반이 사라졌다): assembly 스냅샷 모양(발사·저장이 읽는 dict) · `clear_all` · 🔴**진 3종 Db 로드 + band_count·rune_slots 실값 표**(.tres 파싱 침묵사 그물, 세50) · JinDef 기본값 + 🔴**`glyph_slots` 부재 확인**(필드만 되살리면 거짓 손잡이가 된다) · 🔴`jin_slot_dots` 기하 = `slot_angle` 정본(HUD·Tab 미니 다이어그램의 라이브 소비자 — 베끼면 셋이 조용히 어긋난다) · 🔴**은퇴 API 13종 재발 감지**(`advance`/`choose_jin`/`select_slot`… 이름이 돌아오면 빨개진다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_trace_auto.gd      # **손그림 탁본** (🔴 세83 **폐지 스위치를 되돌리면 살아나는 축의 유일한 상시 그물**): [0]🔴**합성 밑그림 계약**(진 윤곽·룬·밴드 0.42R/0.68R·빈 밴드·룬 센티넬·`rune_subpath` 정본·**융합진 축소 룬** — 세85 ⑪에 F6 벤치에서 **이관**) · 완성도/정밀도·획 누적·우클릭 리셋 · **정밀도 이빨(⑨⑩)·펜 보정(⑪⑫)·ACC_TOL 조임(㉔)·piece_score 바닥(㉕)** · 진·룬 밑그림이 **책 패널 실경로**로 판까지 오나(㉑㉓ — in-memory 진 주입·원상복구) · 문양 9종 궤적 구분(⑱) · 🔴🔴**세86 「층 = 띠」**: 문양이 층 선을 **안 밟는다**(`band_lane` — 띠 경계를 모티프 크기에서 파생) + **실제로 그리는 선은 `band_edge`(층을 가르는 칸막이 하나씩)**가 문양 범위 밖에 있다 + 띠끼리·진 윤곽·중심 룬과 안 겹친다. ⚠ **값을 하나도 안 박고 전부 관계식**이라 여백(`BAND_LANE_PAD`)·문양 크기를 튜닝해도 거짓 빨강이 안 난다(세79 교훈). 🔴 선의 **개수**는 헤드리스가 못 센다 — 「어디 놓이나」로 잰다
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_spell_auto.gd      # **고리 발사**: 진→투사체·착탄 전개(발산 탄환·응집 기둥)·실제 적 take_hit
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd     # **고리 도안 통합**: RingDesign 라운드트립·ring_design_committed→GameState 자동 장착 · **등급⇔펑 경계·퍼펙트⇔화면100** (세션 24) · 🔴🔴**세86 ① 슬롯 교체**: `GameState.equip_design`(중복 장착 정리·보관 밖 도안 거부·null 해제) + **`to_assembly()`가 바꾼 도안을 내놓나**(= 발사가 실제로 바뀐다) + 저장 라운드트립 + `tab_panel`의 좌표→행 판정·고르기→지정 한 바퀴 · 🔴**`equipment_changed` 발신 횟수를 센다** — 이게 없으면 `ring_equipped`에 **직접 대입해도 값이 같아 보여 그린이다**(세86 실측: 「결과 값이 같다」는 「같은 길로 왔다」가 아니다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_base_auto.gd            # **베이스캠프 발사 배선** (세션 24 · 세83): 과녁 사거리 · 🔴**물리 레이어 계약**(내 몸/책상이 world면 진이 총구에서 죽는다 — 에러 없이 조용히) · [8] 숲길 · 🔴**[6]은 `balance.skip_drawing` 모드로 갈린다**(세56 「두 몸 복제 계약은 그물도 두 개」): 그리기 모드=미달 거부가 침묵 아님 · **폐지 모드=조립만으로 맺힘·펑 없음·부품 점수가 기준선 위** + 🔴**버튼 경로**([마법진 완성 ✦]이 리포트를 띄우나 — close() 자동 맺기만 재면 **버튼이 조용히 죽은 것**을 못 잡는다, 세83 뮤테이션 실측)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chapter_auto.gd        # **챕터 보스방 루프** (세션58-B — 옛 test_forest_auto의 그물을 이식·계승): 챕터 3장 Db 로드+order+클리어 키 파생 · 🔴**보스 스폰 두 경로**(범용 forest_enemy·전용 씬 — 두 경로 각각 뮤테이션 검출 확인, 세56 교훈) · 출격 만HP · 🔴**적 레이어 계약**(4=enemy) · 처치→chapter_clear codex+포탈 스폰(처치 전 부재) · 포탈 연타 1회 extraction+가방→창고 · 사망→bag_lost+창고 보존 · 🔴**잠금 판정 = chapter_panel 공개 `is_chapter_open`을 직접**(복사 금지) · 미등록 챕터→빈 방 금지·베이스 복귀(⚠ [8]의 USER ERROR 한 줄은 의도된 것 — SCRIPT ERROR와 다르다) · 끝에 wipe_save() 뒷정리 · 🔴**Ground 클릭 도달·패널 카드 클릭·포탈/상자 렌더는 헤드리스가 못 잡는다**(새 씬+새 패널 = 세25 함정 정확히 그 자리 — 실게임 MCP 필수)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_workshop_auto.gd      # **공방 장비 제작** (세션 32): 레시피 station 분리(정제대⇔공방) · 펜 제작(spend→add) · 장착 라운드트립(equip→correction 0.35→소비, unequip→반환) · 🔴**패널 클릭은 헤드리스가 못 잡는다**(실게임 push_input로 별도 검증)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_audio_auto.gd         # **사운드 배선** (세션 33): 17 SFX 로드·길이>0 · Audio가 EventBus 9종에 연결 · 발신→올바른 스트림(부작용 순간은 연결만) · 🔴**소리가 실제로 나는지는 헤드리스가 못 잡는다**(오디오 드라이버 없음 — 버스 라우팅·playing은 에디터 실게임 exec로 별도 검증)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_rune_unlock_auto.gd        # 🔴 **룬 해금** (세션 34 E4 · 세61 수술 · 세83 룬 복원 · **세85에 `test_decode_auto`에서 개명** — 해독대가 은퇴해 「해독」이 이름으로 거짓이 됐다): 조각 소비+룬 해금(codex_unlocked)·안 닳림 — **조각이 은퇴해 in-memory RuneDef+ItemDef 주입으로 기계를 잰다**(뮤테이션 검출 확인) · 🔴**룬 로드 = 정확히 6종 + 6종 개별 확인**(세50 침묵사 그물 — Color 3인자면 여기서만 빨개진다. 합계만 재면 하나 죽고 하나 살아도 6이다) · 🔴**주입은 원본을 보관했다 되돌린다** — 세83에 흙이 실데이터가 되자 옛 `erase`가 **진짜 룬을 지워** 6→5가 됐다(「빈 자리를 빌려 쓰는」 수법은 이제 못 쓴다) · ⚠ unlock_id 오타·순수확률 조각 스캔 그물은 지금 자명 통과 — 조각 복원 시 자동 가동(뮤테이션 재점화 확인) · 🔴**룬 탭 렌더·클릭은 헤드리스가 못 잡는다**(실게임 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_quests_auto.gd        # **진행 목표(퀘스트)** (세션 36): KILL/EXTRACT/UNLOCK 배선(enemy_died·extraction·codex_unlocked → advance_quests) · 🔴**requires 사슬 게이트**(잠긴 퀘스트는 이벤트로도 안 진행) · 보상 지급 · 🔴**소급 완료**(이미 해금된 룬 노리는 UNLOCK은 열리는 순간 완료 — 안 하면 사슬이 막힌다) · 저장 라운드트립 · 🔴**Q 패널 렌더·클릭 차단은 헤드리스가 못 잡는다**(전체화면 Control — 닫힘=발사 도달·열림=차단을 실게임 push_input으로 별도 확인, 액션 주입으론 못 잡는다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_dialogue_box_auto.gd  # **온보딩 대사 상자** (세션41): open(lines)→줄 넘김→finished · 빈 배열 즉시 finished · ESC 건너뛰기 · ui_modal_open 토글 · 🔴**클릭 진행·하단 밴드 렌더는 헤드리스가 못 잡는다**(실게임 push_input·스샷으로 별도 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_hud_toast_auto.gd     # **HUD 획득 토스트** (세션51): 같은 id 합치기(수량+수명 리셋) · 🔴**합친 줄은 맨 뒤로 이동**(안 하면 FIFO가 **방금 주운 줄**을 밀어낸다 — 시각이 아니라 버그) · 최대 3줄 FIFO · 수명 만료 · 🔴**보이는지·슬롯/막대와 겹치는지는 헤드리스가 못 잡는다**(MCP 스샷으로 별도 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_drop_pickup_auto.gd   # **바닥 드롭 픽업 + 자석 흡수** (세션46·51): setup→그룹 · 줍기 지연(지연 중 무시) · body_entered→add_to_bag+queue_free · 🔴**layer0/mask2 계약**(캐리어가 픽업에 안 부딪히게) · 🔴**자석**(반경 안이면 거리 단조감소·밖이면 정지·지연 뒤에만·**켜지면 취소불가**·도착 1회 뱅킹·item_collected 1회) · 🔴**null 가드 없으면 SCRIPT ERROR 36줄 내면서 OK 찍힌다**(grep 필수) · 🔴**반경 72px가 체감되는지·속도가 "빨려온다"로 읽히는지는 헤드리스가 못 잡는다**(실게임 좌표 실측 — 세50 감전연쇄 재발 자리)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_ai_auto.gd      # **몬스터 AI** (세션46): 방어(armor_reduction→enemy_hit dealt 경감) · 재생(regen_per_sec, 상한 _def.hp) · 분산 경감 · 🔴**돌진/부유 움직임 "느낌"은 헤드리스가 못 잰다**(실게임 runtime_state로 속도파형·거리유지 별도 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_status_auto.gd        # **룬 상태이상·원소 반응** (세션49): 화상 DoT·젖음 감속·🔴**반응**(젖음+흙=진흙·젖음+번개=감전연쇄·화상+물=꺼짐·화상+풀=산불)·🔴**바람=확산**(자기 상태 안 남기고 옆 적에게 옮김)·중첩=갱신(누적 아님)·취약 증폭 · 🔴**DoT는 enemy_hit을 안 쏜다**(쏘면 피해숫자·히트스톱 도배) · 🔴**색으로 보이는지는 헤드리스가 못 잡는다**(실게임 _visual.modulate로 별도 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_snake_boss_auto.gd    # **뱀 보스** (세션54 A): Db 로드(hp600·boss_snake) · take_hit→약점배율 · hp절반→페이즈2 전이(공개 `phase()`) · 세그먼트 몸통(마디 12==SEGMENT_COUNT·머리 이동→마디 추종) · 위브 추격 전진 · 🔴**세그먼트 물결·러시 채찍·머리 회전 "느낌"은 헤드리스가 못 잡는다**(실게임 확인) · 🔴**뮤테이션(페이즈·위브·추종) 검출력 확인됨**(세54)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_progression_auto.gd   # **진행 관문** (세션58, 정본 docs/PROGRESSION.md · 세61 수술): 적 Db 로드(세50 파싱 침묵사 그물) · 🔴**미해금=확정 드롭·해금=중단 — 관문 데이터가 은퇴해 in-memory DropEntry를 slime_elite에 주입해 기계를 잰다**(뮤테이션 검출 확인·[4]의 관문 수==0이 주입 누수 감지기 겸용) · 🔴**불변식(순수 확률 fragment 0곳·관문 수==표 줄 수)은 스캔형 유지 — 지금 관문 0줄이라 자명 통과, 관문 복원 시 자동 가동**(그 세션에서 뮤테이션 재점화 확인 + 관문 수 기대치 갱신) · 허기 잔재 0 · ⚠[2] 확정드롭은 chance 1.0이라 관문 판정 뮤테이션을 못 잡는다 — 검출자는 [3](해금=중단)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_gale_boss_auto.gd     # **gale 보스** (세션56): Db 로드+**params 17키 전수**(세50 그물) · 페이즈2 전이(`phase()`) · 돌풍(플레이어 hp 감소+`apply_push` 밀림 거리≈gust_push_dist) · 볼리(그룹 `"enemy_projectiles"` 수 ==volley_count — 초과도 잡음) · 적탄(히트→hp 감소+free·수명 만료 free — mask2 침묵 함정 그물) · 🔴**반응 룬**(연쇄=BOLT·증기=WATER — FIRE 하드코딩 청산 직접 그물. 연습장 몸 쪽은 test_status_auto [11]ⓑ가 잰다 — **두 몸은 따로 갈라진다**, 세56에 dummy만 되돌려도 전 스위트 그린이었다) · 🔴**링·탄 렌더·밀림 손맛·hover 거리감은 헤드리스가 못 잡는다**(세56 실게임 MCP로 링·탄 렌더 확인, 손맛=사용자 F5) · 🔴**뮤테이션 4/4 검출력**(페이즈·rune 두 몸 각각·볼리)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_spell_vfx_auto.gd     # **마법 연출 배선** (세션59): vfx가 `ring_cast_requested`·`spell_impact`에 연결(배선 침묵사 그물) · 트레일 형제 스폰 + 🔴**`player_projectiles` 그룹 무가입**(트레일이 가입하면 탄 수 세는 테스트 4곳이 거짓으로 는다) · 트리 밖 setup 무에러(null 가드 — ⚠ 이 항목의 진짜 검출자는 **SCRIPT ERROR grep**이다, 테스트는 가드가 없어도 OK를 찍는다) · 🔴**빈 진 착탄 = emit 정확히 1**(캐리어 emit 전용 그물 — 발산 탄이 있으면 캐리어 emit 부재가 가려진다, 뮤테이션으로 실증) · 발산 진 착탄 ≥2(탄 emit) · 🔴**볼 코어·자전·펄스·트레일·머즐/착탄 렌더는 헤드리스가 못 잡는다**(실게임 MCP 필수)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_book_jin_auto.gd # **책 진 셀 격자·아이콘** (세61에 목록 편입 · 세83 계약 교체): Db 진 ≥1종 · 격자 계약 = 합성 8개(순수 함수 `jin_cell_rects`) · 🔴**아이콘 구분 축이 pattern×motion → `jin_icon_paths(shape, rune_slots)`로 바뀌었다**(세83: 셀 = 진 모양 + 룬 자리만) — 도형×자리수 조합 순회 + 자리 수(윤곽1+룬n) + 흐림 플래그 + 🔴**룬 자리가 판의 `rune_slot_positions`와 같은 좌표인가**(세83 뮤테이션이 잡은 그물 구멍: 자리를 전부 중심에 포개도 개수·지문은 그대로라 전부 그린이었다) · 🔴🔴**세86 층 탭 미리보기 아이콘이 판 정본에서 나오나**(`ring_icon_geom` — 옛 아이콘은 판을 **베끼고 있었다**: 각도 루프 사본 + 모티프 크기 `radius*0.42`(판의 3배) + 선을 모티프 중심에. 계약 = ⓐ**모양**이 `glyph_ring_subpaths`와 같다(정규화 비교 — 아이콘은 판의 픽셀 축소판이 **아니다**, `ICON_MOTIF_ZOOM`으로 모티프와 띠를 같은 배로 벌린다) ⓑ🔴**모든 모티프 점이 두 띠선 사이**(사용자가 눈으로 지적한 그것) ⓒ바깥 띠선 == 아이콘 반지름) · 🔴**실제 셀 겉보기·클릭은 헤드리스가 못 잡는다**(실게임 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_floating_wand_auto.gd    # **떠있는 지팡이 + 발사 총구 계약** (세션65 — 세피리아식): 미장착→FloatingWand 숨김+발사 origin 몸중심 폴백(맨손 캐스팅 보존) · 장착→표시+🔴**발사 origin == 지팡이 끝 muzzle_position** + 몸과 뚜렷이 떨어짐(총구가 몸이 아니라 지팡이 끝이라는 계약 자체 — 뮤테이션 `_muzzle`→몸중심 되돌리면 [2] 2건 빨감) · 총구 기하 단일 소스(원점·무회전에서 tip==MUZZLE_LEN) · 🔴**둥둥·회전·flip·머즐 연출·지팡이 겉보기는 헤드리스가 못 본다**(실게임 MCP — 세65에 4방향 조준·발사 tip 스폰·bob 실측)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_feel_auto.gd            # **손맛 개편** (세션63): player_hurt 발신 단일 소스+🔴사망 가드(hp 0 뒤 무발신) · 🔴히트 플래시 material **per-instance**(공유=전원 플래시) · 텔레그래프=셰이더 uniform+**modulate 불가침**(rgb=상태 틴트·a=분산 2축 계약) · hurt 애니 굽기(있으면 비루프/없으면 무변경) · 보스 2종 hurt_sprite 로드(세50 침묵사 그물) · 그림자(z≥0·그룹 무가입·첫 자식·뱀 마디 수 일치) · dust 구르기 엣지 버스트 · 카메라 킥 방향(발사=조준 반대·피격=가해자 반대) · 플레이어 hurt 애니 가드 · 🔴허수아비 파리티(세56 두 몸 그물) · 🔴**플래시가 실제로 하얗게 보이나·그림자/먼지 겉보기·수치 손맛은 헤드리스가 못 잡는다**(세63에 그림자 가림·먼지 뭉개짐을 실게임이 잡았다 — 전 그물 그린이었다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_jin_layers_auto.gd       # 🔴 **진별 해석 M1 — 층(밴드) 순서 = 연산 순서** (세79, 정본 `docs/takbon-design/jin_interpretation_design.md`): M1 콘텐츠 3종 Db 로드(gr_spread3·gr_explode1·jin_plain_g2 band_count=2 — 파싱 침묵사 그물, 세50) · `layer_rings` 계약(밴드→층, 칸 0부터 count개, 🔴**빈 밴드도 층 자리를 지킨다**=건너뛰면 감쌈 깊이가 조용히 밀린다) · 🔴**회귀: 밴드 1개면 층0 == `flatten_bands`**(지금 살아있는 진은 전부 band_count=1이라 이 동치가 곧 「저장 도안 발사 무변경」의 증명) · `_as_layers` 정규화(옛 8칸 한 겹→층 1개 승격·멱등) · 🔴🔴**[4] 심장 = 순서가 결과를 바꾼다**: `폭발(확산(불))`=융합 폭발 **1개**(큰 반경) vs `확산(폭발(불))`=복제 폭발 **3개**(작은 반경·자리 벌어짐) — ⚠**balance 수치를 안 박고 개수·대소 관계로만 잰다**(손맛 튜닝 한 번에 거짓 빨강이 되지 않게) · 옛 도안 무회귀(층 1개+전개형만 = 탄 8발·기둥 1개·폭발 0, **빈 진은 여전히 전개 0**=씨앗 누출 감지) · 씨앗(감쌀 게 없으면 문양이 **룬 자체**를 감싼다) · 세기 = 그 층의 칸 수 · [7] 🔴**조립 UI→발사 계약**(`build_assembly`가 rings를 다겹으로 싣나 + score 동승 — 끊기면 M1이 게임에서 통째로 안 보인다) · 🔴**뮤테이션 5/5 검출력 확인**(폭발을 「각각 터뜨림」으로·층 루프를 rings[0]만·씨앗 제거·빈 밴드 건너뜀·build_assembly를 flatten으로 — 전부 원상복구 확인) · 🔴**폭발이 실제로 「크게 터졌다」로 보이나·확산 부채가 넓어 보이나·따라 긋는 손맛은 헤드리스가 못 잡는다**(F5)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_jin_fusion_auto.gd       # 🔴 **진별 해석 M2 — 룬 2개 + 융합진** (세81, 정본 `docs/takbon-design/jin_interpretation_design.md`「M2 확정 설계」): jin_fuse Db 로드+`rune_slots==2`(파싱 침묵사 그물, 세50) · `runes_of` 승격·멱등+저장 라운드트립(옛 도안 `{rune}`→`[rune]`) · `RingAssembly` 다중 룬 계약(set_rune_slots·set_rune(type,slot)·runes_ready 게이트) · [4] `_fire_hit` **합산 = 0.7×(두 룬 단독 합)**(base_damage 무관 불변식)+rune_hits 2개+정렬(primary=WET 바탕) · 🔴🔴[5] **심장 = 융합 발사 → 한 발이 두 상태 → 반응(SHOCK) + 자리 순서 무의존**(물·번개 뒤집어도 감전) · 🔴[6] **도배 방지 = 융합 한 발 enemy_hit 발신 == 1**(보조 0-피해 히트가 안 쏨 — dummy `hits[]`엔 담겨도 발신 수로 잼) · [7] 기둥·폭발도 반응(rune_hits 이식 그물) · [8] 🔴**회귀 = 룬 1개 share 1.0·rune_hits=[primary] 하나라 옛 계산 완전 동일** · 🔴**뮤테이션 7/7 검출**(0-피해 가드 dummy·forest_enemy 각각·rune_hits·정렬·share·pillar/blast·runes_of) · 🔴**룬 소켓 2칸 클릭·룬 2개 밑그림·반응 가시성은 헤드리스가 못 잡는다**(F5) · ⚠**게임 UI 반응은 물+불=증기뿐**(번개·흙·풀 룬 데이터 없음 — 세61 리셋)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_glyph_data_auto.gd     # 🔴 **문양 효과·표현 데이터화 + 응축** (세82 M3, 정본 `docs/takbon-design/glyph_data_design.md`): [1] `Enums.GlyphCode` **전 9값**이 Db 로드 + `behavior`가 `BEHAVIORS`의 키 + `params` 실제 파싱(세50 침묵사 자리 — **예외 목록 없음**이 곧 자명통과 방지) · [2] `modifier_codes()==[6,7,8]` 명시 기대 · [3] 🔴**회귀 = 수치가 balance→.tres로 이사했는데 관계식 동일**(값을 박지 않는다) · [4] 🔴🔴**심장 = 응축은 폭발의 반대, 단조성으로 잰다**(갈래↑→응축 좁아짐·폭발 넓어짐 — ⚠**대소 비교만으론 부호 뒤집기를 못 잡는다**: 54×1.24=66.96 < 폭발 73.44라 그린이 된다) · [5] `merge_mult_per_count`가 count≥2 경로에 걸린다(고리를 count=2로 낸 이유) · [6] **응축이 새 알고리즘 없이 돈다**(behavior==blast·알고리즘 4종 유지) · [7] 미등록 code=건너뜀 + 🔴**빈 칸(-1)은 경고 대상 아님**(발사마다 경고 폭탄) + 🔴**계열 분기가 실제로 `_apply_layer`를 지난다**(없으면 behavior를 통째로 bolt로 돌려도 전부 그린 — 실측) · [8] code 중복=**결정적 승자**(id 사전순 — ⚠주입 순서를 사전순과 갈리게 넣어야 검출) · [9] 주입 후 `reindex_glyphs()` 갱신(세61 주입 관행) · [10] **같은 층 내 배치 순서 무관** · [11] 반경 부호 구멍 · [12] UI 이름·색·선택이 .tres에서(옛 `clampi`가 응축→폭발로 누르던 자리) · 🔴**뮤테이션 9/9 검출+원상복구** · 🔴**응축 나선을 손으로 그을 만한가·「집중 한 방」으로 보이나는 헤드리스가 못 잡는다**(F5)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ui_text_auto.gd          # 🔴 **표시부 계약** (세84 감사 #12·#21·#35·#36 — **그전엔 이 넷 전부 그물이 0건이었다**): 🔴**융합진 룬 표시**(표시부 셋이 `design.rune`만 읽어 **두 번째 룬이 조용히 사라지던** 자리 — `RingDesign.runes_of()` 경유 + 씨앗 문자열 `물+번개` 합침. 발사부는 계약을 지키는데 표시부만 뒤처져 **「쏘는 것 ≠ 보이는 것」**이 됐다 = 감사 T8) · 🔴**룬 점 좌표는 `RingBoard.rune_slot_positions` 정본 호출**(각도를 베끼면 판·책 셀·HUD 셋이 조용히 어긋난다) · **`ItemText`(core) 단일 소스** + 🔴**사본 재발 감지 스캔**(문구가 세 벌로 갈라져 있던 자리 — 스캔이라 앞으로 네 번째 사본이 생기면 빨개진다) · 퀘스트/소지품 **행 캡 관계식**(6행이 화면 밖으로 나가던 자리) · **say 수명**(경고 한 줄이 목표를 덮고 씬 끝까지 상주하던 자리 — `sticky`는 **목표·유효한 지시만**: boss_room 2곳·base 온보딩 1곳) · 🔴**겉보기·클릭은 헤드리스가 못 잡는다**(F5)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_scene_contract_auto.gd   # 🔴🔴 **씬 계약 — `mouse_filter` 정적 그물** (세84 감사 #14): 게임플레이 씬을 **스캔**해 「보이는 채로 화면을 덮는 Control이면 `mouse_filter == IGNORE(2)`」를 잰다. 🔴 **이 프로젝트가 두 번 밟은 최다 재발 버그**(세25 base·세26 forest — 바닥이 좌클릭을 다 먹어 **발사가 에러도 경고도 없이 죽는데 전 스위트 그린**)가 **처음으로 헤드리스에 걸린다**: 런타임 히트 테스트는 렌더가 없어 못 잡지만 **실패 형태가 늘 「씬에서 그 줄이 빠진다」라서 `.tscn` 프로퍼티로 잴 수 있다**. 뮤테이션 실증(세84 리드) = `base.tscn` Ground를 `mouse_filter=0`으로 되돌리면 그 노드를 이름·크기까지 지목해 빨개진다. ⚠ 씬 목록을 하드코딩하지 않았다 — **새 씬은 자동으로 그물에 든다**. 🔴 이건 **F5의 대체가 아니라 1차 방어선**이다(닿는지 자체는 여전히 실게임)
```

🔴 **세션 종료 전 기계 대조**(경고문 말고 명령으로 — 경고문은 세 세션 연속 실패했다). ⚠ **두 파일을 한 명령으로 돌려라** — "스킬에도 같이 돌려라"는 괄호 안내로 두면 그게 바로 갈라지는 자리다(세87에 실제로 그 형태였다):
```bash
for d in CLAUDE.md .claude/skills/takbon-verify/SKILL.md; do
  for t in $(ls tests/*_auto.gd); do grep -q "$(basename $t)" "$d" || echo "누락 $d: $(basename $t)"; done
  grep -oE 'test_[a-z_]+_auto\.gd' "$d" | sort -u | while read n; do [ -f "tests/$n" ] || echo "유령 $d: $n"; done
done   # 출력이 비어야 한다 (누락 = 목록 뒤처짐 · 유령 = 삭제·개명된 테스트)
```

✅ **`-s` 부팅은 세이브 뿌리를 `user://save_test`로 가른다**(세59) — 스위트가 실제 플레이 세이브를 덮어 「이어하기」를 지우던 사고의 수정. 테스트의 `wipe_save()`는 테스트 세이브만 지우는 뒷정리다. 그물 = `test_save_auto [0]`(격리 로직이 지워지면 빨개진다). ⚠ 실게임(F5·에디터·익스포트)은 `-s`가 없어 예전 경로 그대로 = 세이브 호환 무변경.

🔴 **`-s` 테스트는 런타임 에러가 나도 「OK」를 찍는다**(세22·23에 두 세션 연속 밟았다 — 함수가 에러로 중단돼도 `failures=0`). → **grep을 `_OK`만 하지 말고 `SCRIPT ERROR`도 같이 봐라.** ⚠ **엔진 ERROR·`push_warning`은 그 grep에 안 걸린다**(세84 T6 — 세50 바람 룬이 두 세션 죽어 있던 이유). → **테스트는 공개 API로만 검증해라**(내부 필드는 리팩터 때 옮겨 다녀 계약이 아니다). ⚠ 실패할 때만 출력하는 `_check`는 **침묵이 곧 통과**다.

🔴🔴 **그래서 초록불을 근거로 쓰지 마라 — 뮤테이션으로 검출력을 증명해라.** 고친 코드를 일부러 되돌려 **정확히 몇 개가 실패하는지** 확인한다. 세션 22·23이 전부 이 방식으로 잡았다. 실제로 세션 23의 기존 테스트 하나(`정밀도 < 0.8`)는 **옛 관대한 판정도 통과**해 검출력이 0이었다.

🔴 **static 함수 안의 `const BAL.프로퍼티`는 컴파일 타임에 굳는다** — 런타임에 수치를 흔들어도 옛 값이 나와 **테스트가 조용히 거짓 통과한다**(세24 실측, 세84에 `skip_drawing()`으로 재확인 = 한 프로세스에서 두 모드를 못 돌린다). → 대신 **두 함수의 경계가 어긋나지 않는지 전 구간을 훑어라**(`test_ring_design_auto`의 「사용 불가」⇔펑).
🔴 **채점 수치는 헤드리스로 못 잰다** — 가이드 좌표를 그대로 찍으면 이탈이 0이라 판정 반경을 뭘로 바꾸든 정밀도 100이다(그린 게 아니라 아무것도 안 잰 것). 손맛은 사용자가 직접 그어야 정해진다.

눈으로 보는 시험대: `tests/test_ring_forge_panel.tscn`(F6 — 책 펼침 + 덮고 발사. 오른쪽 셀 클릭=고르기 · 우클릭=다시 그리기 · ESC=덮기 · 좌클릭=발사). ⚠ `tests/test_ring_forge.tscn`은 세16 프로토타입이고 팔레트도 다르다 — **기준 아님.**

**F5 = 타이틀(`src/menu/title.tscn`) → 이어하기/새로하기 → 마을(`src/base/base.tscn`).** 마을: 책상 **E** → 고리 조립 책(오른쪽에서 진·룬·문양을 고르면 왼쪽에 밑그림) → **[마법진 완성 ✦]** → 리포트 → 맺으면 `GameState.ring_designs`로 들어간다. 연습장(허수아비 5): 마우스=조준 · **좌클릭=발사**(Space 아님) · **1·2·3 = 슬롯**(`EQUIP_SLOTS = 3`). 숲길 게이트 **E** → 챕터 선택 → 보스방. 죽으면 `bag_lost` 후 마을 복귀.
⚠ 미달로 안 맺히면 HUD가 이유를 띄운다(`commit_rejected`) — **조용히 거부하지 마라**(슬롯이 빈 채 남으면 「맺었는데 안 나간다」가 된다).

🔴🔴 **헤드리스는 「클릭이 닿는다」를 모른다** — 화면 덮는 Control의 `mouse_filter`가 STOP이면 바닥이 좌클릭을 다 먹어 **발사가 에러도 경고도 없이 죽는데 전 스위트 그린**이다(세25 base·세26 forest에 두 번 밟았다). `_fire()` 직접 호출·액션 주입은 Control 계층을 건너뛰어 이 버그를 **못 잡는다**. → **1차 방어선** = `test_scene_contract_auto`(씬을 스캔해 정적으로 잰다 — 새 씬은 자동으로 든다). → **확정** = 실게임에서 `viewport.push_input(InputEventMouseButton)`을 밀어 0회→1회를 본다.

🔴 **헤드리스는 「존재」만 확인하고 「보인다」는 못 본다** — 렌더·레이아웃을 건드렸으면 아래 「에디터·MCP」 절차로 스샷을 봐라(세63에 그림자·먼지 버그를 실게임이 잡았다. 전 그물 그린이었다).

**알려진 함정**: `-s` SceneTree 테스트 스크립트는 오토로드 전역 등록 전에 컴파일된다 — 오토로드 식별자(EventBus 등)를 컴파일 타임 참조하면 에러. `root.get_node("/root/EventBus")` 런타임 조회 + 모듈 스크립트는 첫 프레임 후 `load()` 지연 로드로 우회 (기존 테스트 파일들 참고).

**Godot 에디터 노이즈**: 에디터 자체의 split_container.cpp 인덱스 에러는 Godot 4.6 에디터 버그 — 게임 문제 아님, 무시.

## 에디터·MCP

🔴🔴 **리드가 F5·MCP를 직접 확인한다** (세85 사용자 확정 — *"mcp로 니가 확인해 앞으로도 니가 확인해 내가 나중에 한번에 볼 수 있도록"*). **1차 방어선은 여전히 헤드리스 + 뮤테이션** — 겉보기·클릭 도달·시간 경과만 MCP로 넘어간다.
- **절차** (세85에 실제로 통한 것): 에디터 실행(약 20초) → `godot_editor_edit run frozen=true`
  (**내 지연 사이에 게임이 안 흘러간다**) → `godot_game_time step`으로 `_ready` 한 번 → `godot_exec`로
  **상태를 만든다**(도안 주입·패널 열기·함수 직접 호출) → `screenshot_game`(겉보기 판정에만) → `stop`.
- **결과는 모아서 한 번에 보고한다** (사용자 요청 — 확인할 때마다 부르지 않는다).
- 🔴 **실측 함정 다섯** (세85에 전부 밟았다):
  ① **frozen 중 `push_input`은 안 먹는다**(`just_pressed` 엣지를 놓친다) → `thaw` 후에 밀어라.
  ② **`InputEventMouseButton`은 `position`과 `global_position`을 둘 다** 채워야 닿는다(하나만이면 조용히 무시).
  ③ **적 그룹은 `"enemies"`(복수)** — `"enemy"`로 세면 0이 나와 「스폰 실패」로 오독한다.
  ④ **`boss_room`은 `pending_chapter`가 비면 베이스로 되돌린다**(설계대로) — 씬만 띄우면 마을이 뜬다.
  ⑤ 🔴🔴 **OS 수준 창 캡처를 쓰지 마라** — 세85에 `SetForegroundWindow`가 **사용자가 쓰던 창을 찍었다**.
     `screenshot_game`은 창을 앞으로 안 가져와 사용자 화면을 안 건드린다.
- ⚠ 게임만 독립 실행(에디터 없이)은 `--path .`만: `Start-Process .\Godot_v4.7.1-stable_win64.exe -ArgumentList "--path","."`.
  🔴 **종료 훅 검증엔 이쪽이 낫다** — 실행 중 세이브를 지우고 `CloseMainWindow()`(=X 버튼의 `WM_CLOSE`)를
  보내 **파일이 재생성되는지 + 프로세스가 실제로 죽는지**를 조작 없이 잰다(세85에 이렇게 확인했다).
  ⚠ **세이브를 건드리기 전엔 무조건 백업**(`%APPDATA%/Godot/app_userdata/tockbon`).
- project.godot을 파일로 수정한 후에는 (에디터가 켜져 있을 때) `godot_project check_stale` → 필요시 에디터 restart
