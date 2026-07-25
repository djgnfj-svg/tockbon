---
name: takbon-rules
description: 탁본(TAKBON) 프로젝트의 아키텍처 규칙·모듈 지도·하드 계약. 탁본 코드를 쓰거나·읽거나·리뷰하거나·서브에이전트에 위임하기 전에 반드시 이 스킬을 읽어라. typed GDScript 강제·class_name 금지(에이전트)·모듈 간은 EventBus+core 스키마만·수치는 data/balance.tres·발사 계약·물리 레이어·씬 연결 규칙을 담는다. "새 X = 파일 한 장"이 어디까지 성립하는지, 어떤 함수가 단일 소스인지가 여기 있다.
---

# 탁본 아키텍처 규칙

게임 = `src/base/base.tscn`(베이스캠프) + 고리 조립 책 + 숲 원정. 2D 탑다운 익스트랙션 로그라이트, Godot 4.7.1, 뷰포트 960×540, 렌더러 Compatibility.

**정본은 항상 `CLAUDE.md` 최상단 + `docs/STATUS.md`다.** ⚠ 옛 자유드로잉 문서(TRUTH·GDD·TECH_SPEC·CHANGELOG 등)는 세션 39에 삭제됐다 — 삭제된 시스템 설명이라 지웠다(필요하면 git 이력). 이 스킬은 정본의 규칙만 압축한 것이고, 충돌하면 CLAUDE.md가 이긴다.

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

- **`src/base`** — 베이스캠프(진입점, `run/main_scene`). 바닥·탁본 책상·연습장·왼쪽 숲길·정제대·공방·해독대·길잡이 NPC. 스테이션은 **재료로 건설**(건설 상태=codex `station_*`).
- **`src/field`** — 숲 원정. `forest.tscn` · `forest_enemy`(쫓아와 접촉 피해). 🔴 **적 수치는 전부 `data/enemies/*.tres`(EnemyDef) — 새 적 = .tres 한 장**(외형 color·size까지 `_apply_look`이 반영). **출격=만HP는 `forest.gd _ready`가 한다**(베이스가 아니다).
- **`src/actors`** — **공용 배우**(base·field 공용): `player.tscn`(WASD·그룹 `"player"`) · `player_caster.gd`(조준·발사·슬롯) · `interact_zone.gd`(책상·숲출구·귀환이 같은 물건, `zone_id`로 구분) · `juice.gd`(피격 손맛 통제소).
- **`src/hud`** — **공용 HUD**(`hud.gd`). 씬 차이는 `hint_text`·`show_hp` @export 둘뿐. `inventory_panel`(I 토글)·`quest_panel`(Q 토글) 모달. ⚠ 안내문에 **없는 조작을 적지 마라**(숲엔 책상이 없다).
- **`src/drawing`** — 고리 조립. `ring_assembly`(상태기계·순수 데이터) · `trace_scorer`(탁본 채점·순수 수학) · `ring_board`(기하·렌더·입력) · `ring_book` · `ring_forge_panel`.
- **`src/spell`** — 발사. `ring_spell_system`(유일한 발사 경로) · `ring_carrier` · `projectile` · `pillar` · `dummy_target`.
- **`src/core`** — **리드 전용.** 스키마·`ring_power.gd`(펑/위력/등급).
- **`src/menu`** — `title.tscn`(새 main_scene, 이어하기/새로하기).

## 3. 하드 계약 (단일 소스 — 복사하면 갈라진다)

- 🔴 **점수 → 펑/위력/등급 = `src/core/ring_power.gd`.** 조립 리포트(UI)와 발사가 **같은 함수**를 부른다. 복사해 두면 한쪽만 고쳐도 아무도 못 알아채고 갈라진다(리포트는 "위력 140" 적고 130으로 때린다). `grade_of`의 최하단 「사용 불가」는 `is_stable()`을 **그대로 부른다** — 65를 상수로 베끼지 마라. 등급 이름을 `==`로 비교하지 말고 `is_perfect()`를 써라.
- 🔴 **발사는 `to_assembly()`를 거쳐라.** 직접 Dictionary를 만들면 손그림 `score`가 빠져 **조용히 기준 위력**으로 나간다. 그래서 `player_caster`를 공용으로 뽑았다 — 발사를 복사하지 말고 caster를 써라.
- 🔴 **채점(완성도·정밀도·펜 보정) 변경은 `trace_scorer.gd`만 연다.**
- 🔴 **발사 계약 = `Enums.GlyphCode`**(GATHER=0/RADIATE=1). 조립 UI·발사·`data/glyphs/*.tres`가 이 값을 공유 — 밀면 저장된 고리 도안이 깨진다.
- 🔴 **id→배수 리졸버는 전부 `Db`.** 스키마(.gd)에 두면 `-s` 컴파일 함정을 밟는다. 데미지 조합은 `ring_power.power_of` 한 곳.
- 🔴 **cast 마나 비용 = `RingPower.cast_mana_cost()` 단일 소스.**
- 🔴 **룬 타입은 `assembly.rune`이 쥔다** — 하드코딩(`RUNE_FIRE`) 금지(세션 34에 물을 그려도 불로 맞던 버그의 원인). 해금 판정은 **패널이 한다**(책·보드는 오토로드를 안 본다).
- 🔴 **보정은 펜이 판다**: `ItemKind.PEN` → `pen_*.tres`의 `params.correction` → `GameState.stroke_correction()`. 맨손 = 보정 0 = 그린 대로(정체성은 기본 상태가 지킨다).

## 4. "새 X = 파일 한 장" (데이터 주도)

- 새 적 = `data/enemies/*.tres` (수치·드롭·외형)
- 새 펜/아이템 = `data/items/*.tres`
- 새 레시피 = `data/recipes/*.tres` (`station`으로 정제대⇔공방 분리)
- 새 퀘스트 = `data/quests/*.tres` (KILL/EXTRACT/UNLOCK, `requires`로 사슬)
- 새 룬 = `data/runes/*.tres` (`unlock_id`=`rune_<명>`)
- 새 소리 = `assets/audio/sfx/<id>.wav` (파일명=id)
- 새 스테이션 = `src/props/` 씬 하나(`zone_id`) + `base.gd`가 그 `zone_id`에서 여는 패널
  ⚠ **세85 정정: `balance.station_build_costs`는 은퇴했다**(세66에 건설이 은퇴한 뒤 소비자 0곳이었다).
  스테이션은 이제 **짓는 게 아니라 마을에 이미 있다** — 「건설 비용 한 줄」은 더는 존재하지 않는 단계다.

## 5. 조용히 깨지는 함정 (에러 없이)

- 🔴 **물리 레이어**: Player=2·Desk=64. 틀리면 진이 총구에서 죽는다(에러 없이). 적 레이어 4=enemy가 아니면 부딪히기만 하고 `take_hit`이 안 불린다.
- 🔴 **화면 덮는 Control의 `mouse_filter`**: 기본값 STOP이 클릭을 다 먹는다 → `mouse_filter=2`(IGNORE). **헤드리스가 절대 못 잡는다** → `takbon-verify` 참조.
- 🔴 **씬끼리 PackedScene으로 물지 마라**: base⇄forest 순환 preload가 껍데기 노드를 만들어 귀환 불가. `@export_file` 경로 + `change_scene_to_file`을 써라. 헤드리스는 못 잡고 실게임 부팅에서만 드러난다.
- 🔴 **`wipe_save()`는 새로하기가 아니다**: 파일만 지우고 GameState·Clock은 오토로드라 메모리에 남아 귀환 한 번에 옛 진행이 도로 써진다. 진짜 새로하기 = `GameState.new_game()`(+ `_seed_starting_unlocks()`).

## 6. 위임 라우팅 (리드용)

- 구현 위임 = `takbon-dev` · 설계/계획 = `takbon-architect` · 리뷰 = `takbon-reviewer`.
- **언제 직접 하나**: 인식률·저장 등 회귀 위험 크고 tight한 검증 루프가 필요한 작업, core 스키마 변경, `mcp__godot` 필요 작업, 커밋.
- 위임해도 검증·`--import`·커밋은 리드가 직접(→ `takbon-verify`).
