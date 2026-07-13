# TECH_SPEC — 탁본 (TAKBON) 기술 명세 v1.0

> 2026-07-12 · 병렬 개발용 아키텍처·계약 문서. **모듈 간 인터페이스(스키마·시그널)는 이 문서가 유일한 진실.**
> 스키마/시그널 변경은 리드(메인 세션)만 수행하고, 변경 시 이 문서를 먼저 갱신한다.

## 1. 엔진·프로젝트 설정

- Godot **4.6.1** · GDScript (typed) · 렌더러 **Compatibility** (2D 픽셀 게임, 저사양 PC 호환)
- 뷰포트 **640×360**, 창 기본 1280×720, stretch mode `viewport`, aspect `keep`
- 픽셀아트: 텍스처 필터 **Nearest** (프로젝트 기본값으로 설정)
- 태블릿: `display/window/handheld/orientation` 무관 · **Windows Ink 설정 확인** (`display/window/ime` 아님 — `input_devices/pen_tablet/driver`), 필압은 `InputEventMouseMotion.pressure`
- 물리 레이어: 1=world, 2=player, 3=enemy, 4=player_projectile, 5=enemy_projectile, 6=pickup, 7=interaction

## 2. 폴더 구조 (모듈 소유권 = 수정 권한 경계)

```
res://
  docs/               # 기획·기술 문서 (리드만)
  src/
    core/             # [리드 전용] 오토로드·공용 스키마 — Phase 0에서 확정
    drawing/          # [모듈 A] 드로잉 캔버스·인식기·필체 라이브러리
    spell/            # [모듈 B] 도안→발사 컴파일·투사체·룬 효과
    field/            # [모듈 C] 플레이어·적·맵·낮밤·익스트랙션
    base/             # [모듈 D] 거점·경제·제작·수리·연구·탁본 해독
    ui/               # [모듈 E] HUD·게시판·도감·장착·메뉴
    quest/            # [모듈 Q] 선형 목표 스택 — quest.tscn을 Main UILayer에 통합 (튜토리얼과 동일 패턴)
  assets/
    sprites/  audio/  fonts/  palettes/
  data/               # .tres 데이터 리소스 (룬·적·아이템 정의) — 스키마는 core, 인스턴스는 담당 모듈
  tests/              # 모듈별 단독 실행 테스트 씬: test_drawing.tscn, test_spell.tscn ...
```

**규칙:** 각 모듈은 자기 폴더 + `tests/` 내 자기 씬만 수정한다. `src/core/`·`project.godot`·공용 씬은 리드만 만진다. 다른 모듈 기능이 필요하면 코드를 직접 부르지 말고 EventBus 시그널 또는 core 스키마를 통한다.

## 3. 오토로드 (Phase 0에서 리드가 생성)

| 이름 | 파일 | 역할 |
|---|---|---|
| `EventBus` | `src/core/event_bus.gd` | 모듈 간 시그널 허브 (아래 §5) |
| `GameState` | `src/core/game_state.gd` | 자원(잉크·마나), 장착 4장, 가방, 도감, 하루 상태 |
| `Clock` | `src/core/clock.gd` | 게임 내 시간·낮밤 페이즈 진행 |
| `Db` | `src/core/db.gd` | `data/` 리소스 레지스트리 (룬·적·아이템 정의 조회) |

## 4. 핵심 리소스 스키마 (`src/core/schemas/`)

```gdscript
# stroke_data.gd — 원본 획 (렌더링·수리·재편집용)
class_name StrokeData extends Resource
@export var points: PackedVector2Array   # 캔버스 정규 좌표 (0..1)
@export var pressures: PackedFloat32Array
@export var role: int                    # StrokeRole.CIRCLE / RUNE / ARROW / TAIL / DECOR

# spell_design.gd — 도안 (게임의 중심 데이터. A가 만들고 B가 소비하고 D가 수리하고 E가 표시)
class_name SpellDesign extends Resource
@export var id: StringName
@export var display_name: String
@export var circle_type: int             # CircleType.FIXED(고정진) / AIMED(조준진)
@export var circle_radius: float         # 정규화 0..1 (캔버스 대비)
@export var aim_axis: float              # 조준진 꼬리 방향(rad). FIXED면 무시
@export var rune_type: int               # RuneType.FIRE / IMPACT / WATER / WIND
@export var rune_accuracy: float         # 0..1, 인식 정확도 → 위력 보정 (스탬프 시 보존)
@export var arrows: Array[ArrowData]
@export var strokes: Array[StrokeData]   # 원본 전체 획
@export var paper_grade: int             # 1..3
@export var ink_cost: Dictionary         # {ink_id: amount} — 제작 시 소모량 (수리비 산정 기준)
@export var mana_cost: float             # 캐스팅 비용 (룬+발수 축)
@export var durability_max: int
@export var durability: int

# arrow_data.gd
class_name ArrowData extends Resource
@export var direction: float             # rad. FIXED=절대각 / AIMED=aim_axis 기준 상대각
@export var magnitude: float             # 0..1 → 투사체 위력·크기
@export var origin: Vector2              # 발사 기점. 진 중심 기준·진 반지름=1.0 정규화 (가장자리=1.0)
                                         # 월드 px = origin × circle_radius × balance.circle_radius_px
                                         # circle_radius: 캔버스 꽉 채우는 원(캔버스 반지름 0.5) = 1.0

# rune_def.gd — 룬 정의 (data/runes/*.tres, 인스턴스는 B 소유)
class_name RuneDef extends Resource
@export var type: int
@export var display_name: String
@export var base_damage: float
@export var status: int                  # Status.BURN / KNOCKBACK / WET / FLOW
@export var status_power: float
@export var projectile_scene: PackedScene

# enemy_def.gd — 적 정의 (data/enemies/*.tres, 인스턴스는 C 소유)
class_name EnemyDef extends Resource
@export var id: StringName
@export var display_name: String
@export var hp: float
@export var counter_rune: int            # 약점 룬 (게시판·도감 표기용)
@export var has_counter: bool            # false = 약점 없음 (counter_rune 무시)
@export var params: Dictionary           # 전투 수치 자유 파라미터 (속도·피해·사거리)
@export var is_elite: bool
@export var drops: Array[DropEntry]      # 재료·탁본 조각
@export var night_buff: float            # 밤 강화 배율

# item_def.gd — 잉크·종이·장비·재료 공통 (data/items/*.tres, 인스턴스는 D 소유)
class_name ItemDef extends Resource
@export var id: StringName
@export var kind: int                    # ItemKind.INK / PAPER / WAND / ROBE / CHARM / MATERIAL / FRAGMENT
@export var grade: int
@export var display_name: String
@export var params: Dictionary           # kind별 자유 파라미터
```

**enum은 전부 `src/core/enums.gd`(class_name Enums)에 정의** — 모듈이 매직 넘버를 각자 만들지 않는다.

### 4.1 ItemDef.params 키 규약 (kind별)

| kind | 키 | 의미 |
|---|---|---|
| WAND | `attack_cooldown_mult` | 기본 완드 약공격 쿨다운 배율 (0.9 = 10% 빠름) |
| WAND | `wand_damage_add` | 약공격 피해 가산 |
| WAND | `aim_assist` | (예약 — 미구현) |
| ROBE | `mana_max_add` / `hp_max_add` | 마나·HP 상한 가산 |
| CHARM | `dash_cooldown_mult` | 대시 쿨다운 배율 (기본 부적. 이후 특수 부적은 자유 키) |
| PAPER | `ink_capacity` | 캔버스 잉크 상한 (24/32/48) — 초과 획 무효 |
| PAPER | `mana_discount` | 도안 mana_cost 감면율 (0/0.1/0.2) |
| PAPER | `durability_bonus` | durability_max 가산 (0/5/12) |

### 4.2 GameState 장비·파생 스탯 API (v1.2)

```gdscript
GameState.equipment: Dictionary        # {Enums.ItemKind.WAND: StringName, ROBE:…, CHARM:…} — 착용 중 id, 미착용 키 없음
GameState.equip_gear(item_id) -> bool  # 창고에 있는 장비만. 착용 시 창고에서 1개 차감, 기존 착용품은 창고 반환
GameState.unequip_gear(kind) -> void   # 해제 → 창고 반환
GameState.gear_param(kind, key, default) -> float  # 착용 장비의 params 조회 (미착용이면 default)
GameState.mana_max() -> float          # balance.mana_max + 로브 mana_max_add — balance 직접 참조 금지, 전부 이 getter
GameState.hp_max() -> float            # balance.player_hp_max + 로브 hp_max_add
```

### 4.3 도안 자동 장착 (v1.4)

`design_created` 수신 시 GameState가 `designs`에 추가하고 **빈 슬롯이 있으면 즉시 장착**한다.
그린 직후 바로 쏴볼 수 있어야 온보딩이 끊기지 않기 때문 (첫 도안 = 슬롯 1 = `cast_slot_1`).
슬롯 4장이 다 차면 자동 장착하지 않는다 — 교체는 아침 게시판에서 (GDD §4.4 필드 교체 불가는 그대로).

- **착용 장비는 가방이 아니다** — 사망(bag_lost)에도 보존된다 (GDD §5: 가방 소지품만 손실)
- 변경 시 EventBus.equipment_changed 발신. 로브 교체로 상한이 줄면 현재 hp·mana는 새 상한으로 클램프
- `GameState.ui_modal_open: bool` — UI 모달(게시판·장착·도감) 열림 플래그. ui_root(E)가 설정, 플레이어 이동 계열(C·D)이 폴링해 입력 잠금

## 5. EventBus 시그널 계약

```gdscript
# ── 드로잉/도안 (A → B·D·E)
signal design_created(design: SpellDesign)
signal design_updated(design: SpellDesign)
signal recognition_result(role: int, matched: bool, score: float)  # UI 피드백용

# ── 캐스팅 (C → B, B → C·E)
signal cast_requested(design: SpellDesign, origin: Vector2, aim_dir: Vector2)  # C의 플레이어가 발신
signal cast_executed(design: SpellDesign, mana_spent: float)                   # B가 발신. 내구 차감은 spell_system이 직접 수행 (수신 측 중복 차감 금지)
signal cast_failed(design: SpellDesign, reason: int)                           # 검사 순서: INVALID → BROKEN → NO_MANA (손상 도안에 마나 낭비 방지)

# ── 전투 (B ↔ C)
signal enemy_hit(enemy: Node2D, damage: float, rune_type: int)  # 발신 주체: 적 take_hit 내부 1곳 (약점 반영 최종 피해 기준). 투사체 측 발신 금지
signal enemy_died(enemy_def: EnemyDef, position: Vector2)
signal player_damaged(amount: float)                 # 피격 이벤트 (FX용)
signal player_hp_changed(hp: float, hp_max: float)   # HP 원장 변경 — GameState가 발신 (v1.1: HP는 GameState.hp)
signal player_died

# ── 탁본·익스트랙션 (C → D·E)
signal rubbing_started(fragment_id: StringName)     # 1~2초 무방비 모션 시작
signal rubbing_completed(fragment_id: StringName)   # 가방에 추가
signal extraction_success                            # 살아서 귀환 — 가방 → 창고 확정
signal bag_lost                                      # 사망 — 가방 손실

# ── 시간 (Clock → 전체)
signal phase_changed(phase: int)                     # Phase.MORNING / DAY / EVENING / NIGHT
signal day_started(day: int)

# ── 도감 해금 (범용 — GameState가 수신해 codex 등록)
signal codex_unlocked(unlock_id: StringName)         # C: 적 첫 처치 시 enemy_<id> 발신

# ── 거점 (D → E·A)
signal research_completed(unlock_id: StringName)     # 룬 해금·제법 해금 → 도감 등록
signal design_repaired(design: SpellDesign)
signal resources_changed                             # 잉크·재료 증감 → HUD 갱신

# ── 장비 (GameState → C·D·E) — v1.2
signal equipment_changed                             # 착용/해제 시 GameState가 발신 (상한·쿨다운 재계산 트리거)

# ── 씬 전환 (v1.2)
signal scene_changed(scene_id: StringName)           # Main이 전환 완료 후 발신 (요청은 scene_change_requested)

# ── 온보딩 (v1.4) — 거점 시험장 ↔ 튜토리얼
signal training_hit(rune_type: int, damage: float)   # D: 거점 허수아비 명중. enemy_hit은 발신하지 않는다
signal tutorial_focus(target_id: StringName)         # 튜토리얼 → D: 유도 마커 대상. &"" = 해제
```

### 5.2 온보딩 계약 (v1.4)

- **`training_hit`**: 거점 허수아비(`src/base/training_dummy.gd`)가 `take_hit` 안에서 발신한다.
  적 노드 계약(그룹 `enemies` + `take_hit`)은 구현하지만 **`enemy_hit`·`enemy_died`는 발신하지 않는다** —
  도감 첫 처치 해금과 퀘스트 단계가 거점에서 오작동하기 때문
- **`tutorial_focus`**: 유효 `target_id`는 Interactable의 `facility_id`(`easel`·`door`·`workbench`…)와
  `&"dummy"`(허수아비). 거점(D)이 수신해 대상 위에 마커를 단다. 튜토리얼은 거점 노드에 직접 접근하지 않는다
- **거점 캐스팅**: `base_player`도 필드 플레이어와 같은 `cast_requested` 계약을 쓴다. base.tscn에
  `spell_system.tscn` 인스턴스가 있다. **시험 발사도 마나·내구를 실제로 소모한다** (GDD §5 — 공짜면
  "쓸 때마다 닳는다"를 배울 자리가 없다). `cast_failed`는 거점이 수신해 수리·회복을 안내한다

### 5.1 unlock_id (도감 해금 키) 규약 — 전 모듈 공통

| 종류 | 형식 | 예 | 발신 주체·시그널 |
|---|---|---|---|
| 룬 | `rune_<룬명>` | `rune_water`, `rune_wind` | D · research_completed |
| 제법 | `recipe_<id>` | `recipe_paper_2`, `recipe_paper_3` | D · research_completed |
| 적 도감 | `enemy_<EnemyDef.id>` | `enemy_beetle` | C · codex_unlocked (첫 처치 시) |
| 퀘스트 진행 | `quest_<n>` | `quest_1` (완료된 단계) | Q · codex_unlocked — SaveManager가 자동 커버 |
| 연출 1회 시청 | `cut_<id>` | `cut_gale_intro` | C · codex_unlocked (컷 재생 직후 — 재진입 시 스킵 판정) |
| 튜토리얼 완료 | `tutorial_done` | — | 튜토리얼 · codex_unlocked (첫 출격 순간 또는 스킵) |

시작 해금: `rune_fire`, `rune_impact`는 GameState 초기값으로 등록 (`_ready`).
**새 게임의 시작 도안은 0장이다** — 첫 도안은 튜토리얼에서 플레이어가 직접 그린 불(파이어볼)이다.
`main.gd _seed_new_game()`은 세이브가 없을 때만 잉크·종이·장비를 지급하고, 도안은 지급하지 않는다.
`SampleDesigns`는 이제 **테스트 전용**이다 (게임 시작 경로에서 제거됨).

## 6. 인식기 설계 (모듈 A)

획 하나가 끝날 때마다(마우스 업) 3단 분기:

1. **원 판정 (기하)**: 시작-끝 거리 < 임계 && 원형도(반지름 분산) 통과 → 진. $1을 쓰지 않는다.
2. **꼬리 판정**: 기존 원 경계 근처에서 시작해 바깥으로 나가는 짧은 획 → 조준진 승격, 방향 = `aim_axis`.
3. **룬 판정 ($1 유니스트로크)**: 템플릿 = 불△·충격>·물~·바람◎ (각 다중 샘플). 회전 불변 정규화 허용. 물~ vs 바람◎ 구분: 리샘플 64pt + **총 회전각(감김 횟수) 피처**를 별도 게이트로.
4. **화살표 (파라미터 추출)**: 인식기 없이 — 방향 = 시작→끝 벡터, 크기 = 획 길이 정규화, 기점 = 시작점. "화살표스러움" 최소 판정(직진성)만.

- 정확도 점수 = $1 매칭 스코어 → `rune_accuracy` (하한 0.6 보장, 자동보정 버튼 = 템플릿 형태로 스냅하되 accuracy는 현재값 유지)
- 잉크 소모 = Σ(획 길이 × 획 폭) — 그린 총량 비례

## 7. 씬 구조

```
Main.tscn (리드)
 ├─ CurrentScene (교체 슬롯)
 │   ├─ Field.tscn        [C] 낮/밤 필드 — 출격
 │   ├─ Base.tscn         [D] 거점 오두막 — 이동·상호작용
 │   └─ DrawingRoom.tscn  [A] 드로잉 캔버스 (작업대에서 진입, Base 위 오버레이 가능)
 └─ UILayer (CanvasLayer)  [E] HUD·게시판·도감·장착·메뉴
     ├─ Tutorial.tscn      [튜토리얼] 필사 수업 (1회성)
     └─ Quest.tscn         [Q] 목표 1줄 표시 — 기존 시그널 수신만, 신규 시그널 불요
```

- 씬 전환은 `Main`이 담당, 모듈은 `EventBus`로 전환 요청 (`signal scene_change_requested(scene_id)` — Phase 0에 포함)
- 각 모듈은 통합 전까지 `tests/test_<module>.tscn`에서 단독 실행 (F6)으로 개발·검증

## 8. 입력 맵 (Phase 0에서 리드가 project.godot에 등록)

`move_up/down/left/right` (WASD) · `dash` (Space) · `attack_basic` (LMB) · `cast_slot_1..4` (1~4 또는 QER+RMB — 프로토에서 결정, 일단 1~4) · `interact` (E) · `draw` (LMB, DrawingRoom 컨텍스트) · `ui_codex` (Tab)

## 9. 저장

- `user://save/` 에 JSON — 영구부(도감·거점·창고·제법)와 하루 상태(장착·가방) 분리
- `SpellDesign`은 `ResourceSaver`로 `user://designs/*.tres` 저장 (strokes 포함 — 재편집·수리 렌더링에 필요)
- Phase 0에서는 스텁(인터페이스만), 3개월차 마일스톤에서 구현
- 저장 구현 시 이관 목록: 연구 진행 상태(현재 src/base/research_service.gd의 static var — 씬 전환은 생존하나 세이브 대상 아님)

## 10. 코딩 컨벤션

- typed GDScript 강제 (`var x: float`), 파일·노드 snake_case / 클래스 PascalCase
- 모듈 간 직접 참조 금지 — EventBus·core 스키마만. `get_node("/root/...")`로 타 모듈 노드 찾기 금지
- 매 프레임 할당 회피 (`PackedVector2Array` 재사용), 인식기는 획 종료 시 1회만 실행
- 수치 밸런스 값은 코드에 박지 말고 `data/balance.tres` (Phase 0 스텁)에 모은다 — 프로토 손맛 튜닝 대비
