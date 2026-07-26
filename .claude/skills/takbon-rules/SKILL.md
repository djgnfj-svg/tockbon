---
name: takbon-rules
description: 탁본(TAKBON) 프로젝트의 아키텍처 규칙·모듈 지도·하드 계약. 탁본 코드를 쓰거나·읽거나·리뷰하거나·서브에이전트에 위임하기 전에 반드시 이 스킬을 읽어라. typed GDScript 강제·class_name 금지(에이전트)·모듈 간은 EventBus+core 스키마만·수치는 data/balance.tres·발사 계약·물리 레이어·씬 연결 규칙을 담는다. "새 X = 파일 한 장"이 어디까지 성립하는지, 어떤 함수가 단일 소스인지가 여기 있다.
---

# 탁본 아키텍처 규칙

게임 = `src/base/base.tscn`(마법사 학교 마을) + 고리 조립 책 + **챕터(보스방) 루프** + 온보딩 레일. 2D 탑다운 익스트랙션 로그라이트, Godot 4.7.1, 뷰포트 960×540, 렌더러 Compatibility.
⚠ **숲 원정은 세58-B에 은퇴했다** — 메인 루프는 마을 → 챕터 패널 → `boss_room` → 클리어 → 창고다.

**정본은 역할별로 갈려 있다:**

| 문서 | 역할 |
|---|---|
| 📖 `docs/GDD.md` | **「게임이 무엇인가」 단일 진실원**(세71 신설). 🔒 **읽기만 — 수정엔 사용자 허락이 필요하다**(settings.json `ask`) |
| 이 스킬 | 아키텍처·모듈 지도·하드 계약 |
| `CLAUDE.md` 최상단 + `docs/STATUS.md` | 직전 세션·살아있는 함정 |
| `docs/PROGRESSION.md` | 진행 관문표 |
| `docs/takbon-design/` | 확정·대기 설계 문서 |

⚠ **세39에 삭제된 건 옛 자유드로잉 세대의 TRUTH·TECH_SPEC·CHANGELOG 등이다** — 지금의 `docs/GDD.md`는 **그 뒤(세71)에 새로 만든 다른 문서**이고 살아 있다. 「docs/는 전부 아카이브」는 거짓이니 그렇게 배우지 마라.
⚠ **세83 이후 GDD의 「그리기」 서술만 낡았다**(그리기 폐지 — 개정은 허락 대기 중). 나머지 서술은 유효하다.
충돌하면 CLAUDE.md가 이긴다.

## 0. 절대 규칙 (어기면 조용히 깨진다)

- **typed GDScript 강제.** 모든 변수·인자·반환에 타입.
- **서브에이전트 새 스크립트에 `class_name` 선언 금지** → `const X := preload(...)`. 전역 클래스 캐시는 리드의 `--import` 때만 갱신된다. (리드는 core에서 class_name을 쓸 수 있다.)
- **모듈 간 통신은 EventBus 시그널 + core 스키마만.** 타 모듈 직접 preload/get_node 금지. (정당한 예외: `base.gd`가 책 씬을 무는 것 = 진입 씬이 조합 루트라서.)
- **수치는 전부 `data/balance.tres`(BalanceData).** 코드에 밸런스 상수 금지. ⚠ 예외 = **연출값(손맛: 넉백·히트스톱·팝 등)은 스크립트 const**다 — 사용자가 직접 때려 조이는 값이라 밸런스가 아니다.
- 🔴🔴 **생명체·프롭 시각 = 도형 플레이스홀더 금지** (사용자 확정, 세54). 새 적·캐릭터·아이템·프롭의 겉모습을 `Polygon2D`·`ColorRect` 같은 기하 도형으로 임시로 때우지 마라 — **`takbon-art`로 진짜 도트 스프라이트를 만들어 배선한다**(적/머리 = `params.sprite`+`_setup_frames` 스트립, 그 외 = Sprite2D). "아트는 병렬이니 도형으로 먼저 돌린다"(drop_pickup 마름모 선례)는 **각하됐다** — 사용자가 도형 스탠드인을 싫어한다(세54 뱀 보스가 팔각형 마디로 나가 밟았다). 설계·구현은 **도형으로 시작하지 말고 art부터 태운다**. ⚠ **예외 = 절차적 VFX·이펙트**(`death_puff`·`vfx.gd` Line2D·진/문양 가이드선)는 애초에 스프라이트가 아니라 그림이라 도형이 맞다. 판별 = "이건 도트로 그려야 할 물건인가?"
- **git 커밋은 리드(메인 세션)만.** 서브에이전트는 자기 모듈 폴더 + `tests/` 자기 접두사 파일만 수정.
- 서브에이전트는 `mcp__godot__*` 도구 사용 금지 (에디터는 리드가 관리).
- 스키마·시그널 추가가 필요하면 서브에이전트는 **보고만** 하고 리드가 core에 반영한다.

## 1. 오토로드 (전역 상태)

| 오토로드 | 역할 |
|---|---|
| `EventBus` | 시그널 허브 (모듈 간 유일 통신로) |
| `GameState` | 자원·HP·장착·가방·도감(codex)·퀘스트 |
| `Clock` | 낮밤 시간 → 실질 역할 = 자동저장 틱(`day_started` → SaveManager) |
| `Db` | data/ 레지스트리 + **id→배수 리졸버**(`ink_mult`·`get_rune` 등) |
| `SaveManager` | user://save, 자동 저장. `_ready`→`load_game()`로 부팅 시 이어받음 |
| `Audio` | EventBus 9종 구독 → SFX 재생 |

⚠ EventBus의 일부 시그널은 수신자만 있고 발신자가 상황에 따라 붙는다 — 필드를 붙이는 쪽이 emit해야 하며 안 그러면 조용히 안 돈다.

## 2. 모듈 지도

- **`src/base`** — 마법사 학교 마을(진입점, `run/main_scene`). 탁본 책상·연습장·**정제대**(`refine_panel`)·**공방**(`workshop_panel`)·**상점**(`shop_panel`)·길잡이 NPC·챕터 패널.
  ⚠ **해독대는 세85에 은퇴했다**(q05와 한 세트로 삭제 — `decode_panel`은 없다).
  ⚠ **건설도 세66에 은퇴했다 — 스테이션은 짓는 게 아니라 마을에 이미 있다**(§4 끝의 정정 참조).
- **`src/field`** — **챕터 보스방**. `boss_room.gd`/`.tscn`(단칸방 — 클리어 시 codex·상자·포탈) · `forest_enemy`(범용 적 몸 — 쫓아와 접촉 피해) · `enemy_projectile` · `snake_body`/`snake_boss.tscn`.
  ⚠ **`forest.tscn`·`forest.gd`는 세58-B에 삭제됐다**(되살리려면 git 이력). 이름만 남은 `forest_enemy`는 **범용 적 몸**이라 살아 있다.
  🔴 **적 수치는 전부 `data/enemies/*.tres`(EnemyDef) — 새 적 = .tres 한 장**(외형 color·size까지 `_apply_look`이 반영).
  🔴 **출격 = 만HP/만마나는 `boss_room.gd _ready`가 한다**(마을이 아니다 — forest.gd 계약을 이관받았다. 다른 진입 경로를 만들면 조용히 달라진다).
- **`src/actors`** — **공용 배우**(마을·보스방 공용): `player.tscn`(WASD·그룹 `"player"`) · `player_caster.gd`(조준·발사·슬롯) · `floating_wand.gd`(떠있는 지팡이 — 🔴 발사 총구 단일 소스 `muzzle_position()`) · `interact_zone.gd`(책상·포탈·귀환이 같은 물건, `zone_id`로 구분) · `juice.gd`(피격 손맛 통제소) · `vfx.gd`·`shadow.gd`·`dust.gd`.
- **`src/hud`** — **공용 HUD**(`hud.gd`, 마을·보스방 공용). 🔴 **세64부터 씬별 차이가 하나도 없다** — `hint_text`(조작 안내문)는 **통째로 제거**됐고(온보딩 대사가 조작을 가르친다) `show_hp`도 폐지돼 **HP를 늘 그린다**. 즉 `hud.gd`에 @export가 **0개**다.
  🔴 **모달은 `tab_panel`(Tab) 하나로 합쳐졌다.** 🔴 **탭 목록의 정본은 `TAB_NAMES` 하나다**(지금 **4탭** = 소지품·퀘스트·마법진·**캐릭터**(세64) — ⚠ 이 문서가 세86까지 「3탭」이라 적고 있었다. **개수를 여기 베끼지 말고 그 상수를 읽어라**). 옛 `inventory_panel`(I)·`quest_panel`(Q)은 세40에 **흡수돼 파일이 없다**(`tab_panel.gd` 머리말이 그렇게 적어 뒀다). 그 밖 = `chapter_panel`·`dialogue_box`·`damage_number`.
  ⚠ 안내 문구는 `hud.say(text, warn, sticky)`다 — **없는 조작을 적지 마라**(보스방엔 책상이 없다). 🔴 `sticky := true`는 **목표·유효한 지시만**(안 그러면 경고 한 줄이 목표를 덮고 씬 끝까지 상주한다 — 세84 #36, 그물 = `test_ui_text_auto`).
- **`src/drawing`** — 고리 조립. `ring_forge_panel`(🔴 **조립 상태의 실소유자**) · `ring_board`(기하·렌더·입력 — 문양/진/룬 밑그림의 단일 소스) · `ring_book`(책 셀·아이콘) · `trace_scorer`(탁본 채점·순수 수학 — 휴면) · `ring_assembly`(상수·순수 데이터).
  ⚠ **`ring_assembly`는 「조립 상태기계」가 아니다** — per-piece 흐름이 세70·85에 은퇴해 지금 남은 역할은 상수 표(`SLOTS`·`GLYPH_NONE`·`STAGE_*`·`RUNE_FIRE`)다. **`ring_board.gd`가 아직 `RingAssembly.new()`로 인스턴스를 들고 그 상수 6개를 재노출한다** — 「쓰는 데가 0곳」이 아니니 지우려면 그 의존부터 걷어라.
- **`src/spell`** — 발사. `ring_spell_system`(유일한 발사 경로) · `ring_carrier`(+`carrier_trail`) · `projectile` · `pillar` · `blast` · `dummy_target`.
- **`src/core`** — **리드 전용.** 스키마·`ring_power.gd`(펑/위력/등급).
- **`src/menu`** — `title.tscn`(새 main_scene, 이어하기/새로하기).

## 3. 하드 계약 (단일 소스 — 복사하면 갈라진다)

🔴🔴 **먼저 읽어라 — 세83에 그리기(탁본)가 폐지됐고 조립만으로 마법이 맺힌다.** `balance.skip_drawing`이 **기본 `true`**다(`balance_data.gd`의 `@export var skip_drawing` 선언 + 바로 위 「스위치다」 주석). 지금 위력은 `RingPower.assembled_score(문양수, 층수)`가 낸다.

- 🔴 **코드는 한 줄도 안 지웠다 — 스위치다.** `skip_drawing = false`로 되돌리면 손 긋기가 **그대로** 살아난다(채점기·펜·잉크가 전부 제자리에 있다). → 아래 **채점(`trace_scorer`)·펜 보정 계약은 「휴면」이지 죽은 게 아니다.**
- 🔴 **그래서 청소할 때 두 가지를 갈라라**: ⓐ **되돌릴 수 있어야 하는 것**(`enter_combined_trace`·`coverage`/`accuracy`·펜 보정) = 남긴다 · ⓑ **세70에 은퇴한 per-piece**(조각별로 하나씩 긋기) = 스위치와 무관하니 걷는다. 세85가 이 구분으로 청소했다.
- 🔴 **라이브 트레이스 진입점은 `enter_combined_trace` 하나다.** per-piece API 13종(`advance`/`finish`/`select_slot`/`choose_jin`/`choose_rune`/`ring_summary` 등)은 **없다** — 찾다 헤매지 마라. 이름이 돌아오면 `test_ring_assembly_auto`가 **재발까지 감지해 빨개진다.**
- ⚠ `docs/GDD.md`의 「그리는 것 = 심장」 서술은 **아직 개정 전이다**(허락 대기) — 현재 상태가 아니다.

- 🔴 **점수 → 펑/위력/등급 = `src/core/ring_power.gd`.** 조립 리포트(UI)와 발사가 **같은 함수**를 부른다. 복사해 두면 한쪽만 고쳐도 아무도 못 알아채고 갈라진다(리포트는 "위력 140" 적고 130으로 때린다). `grade_of`의 최하단 「사용 불가」는 `is_stable()`을 **그대로 부른다** — 65를 상수로 베끼지 마라. 등급 이름을 `==`로 비교하지 말고 `is_perfect()`를 써라.
- 🔴 **발사는 `to_assembly()`를 거쳐라.** 직접 Dictionary를 만들면 손그림 `score`가 빠져 **조용히 기준 위력**으로 나간다. 그래서 `player_caster`를 공용으로 뽑았다 — 발사를 복사하지 말고 caster를 써라.
- 🔴 **채점(완성도·정밀도·펜 보정) 변경은 `trace_scorer.gd`만 연다.** (휴면 축 — 위 폐지 문단 참조.)
- 🔴 **발사 계약 = `Enums.GlyphCode`** — **9값**이다: `GATHER=0 · RADIATE=1 · PIERCE=2 · HOMING=3 · BOUNCE=4 · THRUST=5 · SPREAD=6 · EXPLODE=7 · CONDENSE=8`(0~8 연속). 조립 UI·발사·`data/glyphs/*.tres`가 이 값을 공유 — 밀면 저장된 고리 도안이 깨진다.
  🔴 **계열(전개형/변형형)은 enum의 성질이 아니라 데이터에 딸린 성질이다** — 단일 소스는 `GlyphRules.BEHAVIORS`(= `GlyphDef.behavior`)이고, **code 목록이 필요하면 `Db.modifier_codes()`를 불러라**. 옛 `Enums.MODIFIER_GLYPHS`·`is_modifier_glyph()` 배열은 **세82에 은퇴했다 — 되살리지 마라**(`enums.gd`의 `GlyphCode` enum 바로 아래 주석이 그렇게 못 박아 뒀다).
  ⚠ **`Enums.RuneType`은 반대로 값이 연속이 아니다**: `FIRE=0 · WATER=2 · WIND=3 · BOLT=4 · EARTH=5 · GRASS=6`(**1은 옛 IMPACT의 은퇴 자리** — `LEGACY_IMPACT`). **인덱스로 착각하면 「없는 룬」이 만들어진다 — enum은 값을 먼저 확인해라**(세85 실측). 🔴 순회는 `range()`/`size()` 말고 **`Enums.RUNE_TYPES` 명시 리스트**로 해라.
- 🔴 **id→배수 리졸버는 전부 `Db`.** 스키마(.gd)에 두면 `-s` 컴파일 함정을 밟는다. 데미지 조합은 `ring_power.power_of` 한 곳.
- 🔴 **cast 마나 비용 = `RingPower.cast_mana_cost()` 단일 소스.**
- 🔴 **룬 타입은 조립본이 쥔다 — 하드코딩(`RUNE_FIRE`) 금지**(세34에 물을 그려도 불로 맞던 버그의 원인). 해금 판정은 **패널이 한다**(책·보드는 오토로드를 안 본다).
  🔴🔴 **룬은 복수다** — 세81 M2 융합진이 `rune_slots = 2`를 연다. **읽을 땐 `RingDesign.runes_of(runes, fallback_rune)`를 거쳐라.** `design.rune` **단수만 읽으면 두 번째 룬이 조용히 사라진다** — 발사부는 계약을 지키는데 표시부만 뒤처져 **「쏘는 것 ≠ 보이는 것」**이 됐던 자리다(세84 #12, 그물 = `test_ui_text_auto`).
- 🔴 **보정은 펜이 판다**: `ItemKind.PEN` → `pen_*.tres`의 `params.correction` → `GameState.stroke_correction()`. 맨손 = 보정 0 = 그린 대로(정체성은 기본 상태가 지킨다).

## 4. "새 X = 파일 한 장" (데이터 주도)

- 새 적 = `data/enemies/*.tres` (수치·드롭·외형)
- 새 펜/아이템 = `data/items/*.tres`
- 새 레시피 = `data/recipes/*.tres` (`station`으로 정제대⇔공방 분리)
- 새 퀘스트 = `data/quests/*.tres` (KILL/EXTRACT/UNLOCK, `requires`로 사슬)
- 새 룬 = `data/runes/*.tres` (`unlock_id`=`rune_<명>`)
- 새 진 = `data/jin/*.tres` (`band_count`·`rune_slots`가 진의 개성 — ⚠ `glyph_slots`는 세85에 은퇴, 되살리면 **거짓 손잡이**가 된다)
- 새 챕터 = `data/chapters/*.tres`
- **새 문양 = 2곳**(세82 데이터화 뒤) — `data/glyphs/*.tres`(`behavior` + `params`) + `Enums.GlyphCode`에 값 하나. 그전엔 5곳이었다.
- 새 소리 = `assets/audio/sfx/<id>.wav` (파일명=id)
- 새 스테이션 = `src/props/` 씬 하나(`zone_id`) + `base.gd`가 그 `zone_id`에서 여는 패널
  ⚠ **세85 정정: `balance.station_build_costs`는 은퇴했다**(세66에 건설이 은퇴한 뒤 소비자 0곳이었다).
  스테이션은 이제 **짓는 게 아니라 마을에 이미 있다** — 「건설 비용 한 줄」은 더는 존재하지 않는 단계다.

## 5. 조용히 깨지는 함정 (에러 없이)

- 🔴 **물리 레이어**: Player=2·Desk=64. 틀리면 진이 총구에서 죽는다(에러 없이). 적 레이어 4=enemy가 아니면 부딪히기만 하고 `take_hit`이 안 불린다.
- 🔴 **화면 덮는 Control의 `mouse_filter`**: 기본값 STOP이 클릭을 다 먹는다 → `mouse_filter=2`(IGNORE). **헤드리스가 절대 못 잡는다** → `takbon-verify` 참조.
- 🔴 **씬끼리 PackedScene으로 물지 마라**: 씬 간 순환 preload가 껍데기 노드를 만들어 귀환 불가(세26에 base⇄forest로 밟았다). `@export_file` 경로 + `change_scene_to_file`을 써라. 헤드리스는 못 잡고 실게임 부팅에서만 드러난다.
- 🔴🔴 **`.tres`는 두 가지로 다르게 죽는다** (세50에 밟고 세85에 실측 정정):
  ⓐ **스키마에 없는 프로퍼티 *이름*은 조용히 무시되고 리소스는 산다** — 필드를 스키마에서 걷어도 `.tres`의 남은 줄이 호환을 깨지 않는다.
  ⓑ 🔴 ***값* 파싱이 실패하면 리소스가 통째로 죽고 `Db`가 말없이 건너뛴다** — `Color`를 3인자로 쓴 바람 룬이 **두 세션 내내 죽어 있었는데 전 스위트가 그린이었다**(검출력 0).
  → ⚠ **"파일을 만들었다"를 완료로 치지 마라 — `Db`를 거쳐 실제로 로드되는지 확인해라.** 개수 합계만 재면 하나 죽고 하나 살아도 같은 수가 나온다(개별 확인이 필요하다).
- 🔴 **배선이 맞아도 「반경 밖」이면 아무 일도 안 일어난다** (세50): 허수아비 간격 102px vs 감전 연쇄 반경 90px라 연쇄가 **한 번도 안 터졌다**. 반경을 쓰는 기능을 붙였으면 **좌표를 실측해라.**
- 🔴 **엔진 ERROR·`push_warning`은 `SCRIPT ERROR` grep에 안 걸린다** (세84 T6) — 실패를 로그 없이 삼키는 자리가 이 프로젝트의 단골 침묵사다.
- ⚠ 씬(`.tscn`)의 `;` 주석은 **에디터가 저장하면 날아간다** — load-bearing한 설명은 코드에 둬라.
- 🔴 **`wipe_save()`는 새로하기가 아니다**: 파일만 지우고 GameState·Clock은 오토로드라 메모리에 남아 귀환 한 번에 옛 진행이 도로 써진다. 진짜 새로하기 = `GameState.new_game()`(+ `_seed_starting_unlocks()`).

## 6. 위임 라우팅 (리드용)

- 구현 위임 = `takbon-dev` · 기술 설계·설계 리뷰 = `takbon-architect` · 코드 리뷰 = `takbon-reviewer` · 패널/HUD = `takbon-ui` · 도트 = `takbon-art` · 입체화 = `takbon-relight` · 셰이더 = `takbon-shader` · 애니 배선 = `takbon-animator`.
- 🔴 **기획(무엇을·왜·어떻게 재밌게)은 위임하지 마라** — 리드가 `takbon-design` 스킬로 **사용자와 대화하며** 확정한다(세71: 서브에이전트는 대화를 못 해 혼자 정한다).
- 🔴🔴 **기본이 위임이다** (세48 사용자 확정 — **옛 예외 목록은 걷어냈다**). 그전엔 *"회귀 위험이 크고 tight한 검증 루프가 필요한 작업·core 스키마 변경·mcp__godot·커밋은 리드가 직접"*이라 적혀 있었는데, **이 프로젝트의 재밌는 작업은 죄다 발사·저장·core에 닿아서 거의 매번 예외에 걸렸다** — 위임 대상이 주변부뿐이라 하네스가 안 굴러갔다. 위임은 손을 던다기보다 **설계·리뷰 단계를 강제해 품질을 올리는 장치**다.
- 🔴 **리드가 안 놓는 것 = 검증·`--import`·커밋**(→ `takbon-verify`). **에이전트의 "그린 나왔습니다"를 근거로 쓰지 마라** — 리드가 직접 돌리고 뮤테이션으로 검출력을 확인한다.
- ⚠ **서브에이전트의 `mcp__godot__*` 금지는 유효하다**(에디터는 리드가 관리). 단 **리드는 세85부터 F5·MCP를 직접 확인한다** — 「리드는 에디터를 켜지 마라」(세71~84)는 뒤집혔다.
- 🔴 **에이전트에게 「보고서를 파일로 써라」고 지시해라** — **채팅으로 낸 최종 보고는 리드에게 안 온다**(세48~49에 4건이 idle 알림만 남기고 증발했다). 특히 `takbon-architect`·`takbon-reviewer`는 **산출물이 보고서뿐**이라 파일로 안 시키면 작업 전체가 사라진다.
- ⚠ **뮤테이션을 시킬 땐 원상복구까지가 지시다** — `src/`를 되돌린 채 두면 기능이 조용히 죽은 채 커밋된다.
