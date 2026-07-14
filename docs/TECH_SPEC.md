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

### 4.0-a v1.9 축 — **문양은 구현됨 ✅ · 진 모양·룬 N개는 미구현 ⚠**

**섞지 말 것.** 아래 표의 ✅는 **지금 코드에 있다**. ⚠는 **확정됐지만 아직 안 짠 것**이다.

GDD v1.6~v1.9에서 축이 재배분돼 **세 축이 전부 찼다.** 문양(v1.9)은 세션 10에 구현됐고,
남은 것은 **진 모양·룬 N개**이며 **둘 다 `$P` 인식기를 전제**한다.

| 대상 | 지금 코드 | v1.9 목표 | 상태 |
|---|---|---|---|
| **문양 글자** | `ArrowData.glyph` (BASIC/BOUNCE/HOMING/PIERCE) | 발동 방식 축 | **✅ 구현** |
| **문양 세기** | `ArrowData.reach` (획 길이 ÷ 진 반지름) | 사거리 배율 + 글자별 세기 | **✅ 구현** |
| **`ArrowData.path`** | **먹선 렌더 전용**(비주얼) | ~~궤적~~ **폐기** — 궤적은 `glyph`가 정한다 | **✅ 반영** |
| **인식기** | `$1` 유니스트로크 — **한붓그리기 전용** | **`$P` 포인트 클라우드** — 다획 | ⚠ **미구현 — 아래 둘의 전제** |
| **진** | `circle_radius` 하나 (원 고정, `detect_circle` 기하 판정) | **모양 종류 + 크기.** 닫힌 도형이면 원이 아니어도 된다 | ⚠ 미구현 |
| **룬** | `rune_type`·`rune_fill`·`rune_accuracy` — **스칼라 3개** | **`Array[RuneInstance]`** + **`angle` = 배선** | ⚠ 미구현 |
| **피격 계약** | `take_hit(damage, rune_type, status, status_power)` | **현행 시그니처가 그대로 성립한다** (탄 1발 = 룬 1개 — 룬을 섞지 않기로 한 덕분) | ✅ 변경 불필요 |

> 🔴 **문양을 먼저 구현한 이유** (GDD의 "$P 먼저"를 뒤집었다): $P를 먼저 갈라는 근거는
> *"1획용으로 구부린 글자는 다획에서 다시 그려야 한다"*인데, **팅김(지그재그)·유도(호)·관통(창)은
> 애초에 1획이 자연스럽다.** 구부릴 게 없다. **다획이 진짜로 필요한 건 진(별·용)뿐이다.**

#### 구현된 문양 축 (v1.9) — 지금 코드

```gdscript
# arrow_data.gd
@export var glyph: Enums.GlyphType = Enums.GlyphType.BASIC
    # BASIC = **어느 글자도 아닌 획 = 폴백**. 인식 실패는 거부가 아니다 (GDD §4.5).
    # 구세이브·샘플 도안·튜토리얼 첫 도안이 전부 여기로 — 기본값이 곧 하위 호환이다
@export var reach: float = 1.0
    # 획 길이 ÷ 진 반지름. **rune_fill과 정확히 대칭.** 기본 1.0 = 기준 배율 (구세이브 사거리 불변)
    # 소비: 사거리 배율(공통) + BOUNCE→반사 횟수 / HOMING→추적 지속 / PIERCE→뚫는 수
```

**소비 지점 (t = `inverse_lerp(glyph_reach_min, glyph_reach_max, reach)` 하나가 전부의 입력)**
- `projectile.reach_t()` / `range_mult()` — **공식은 여기 하나뿐이다.** spell_system과 투사체가 같은 t를 쓴다
- `spell_system.compute_arrow_lifetime()` = `compute_lifetime(진 축)` × `range_mult(문양 축)`.
  🔴 **사거리만 탄마다 갈라진다.** 위력·크기·상태이상은 **도안당 1회** — 문양이 안 건드리는 축이다
- `design_builder`: 마나에 `glyph_reach_mana_mult × Σt` (공짜면 "문양은 언제나 최대한 길게"가 정답이 된다)

**인식 (recognizer.gd)**
- `recognize_glyph()` — $1 매칭 + 피처. **점수 미달이면 BASIC** (`GLYPH_MIN_SCORE`)
- 🔴 **`GLYPH_MIN_BOW = 0.08` (현 이탈도)가 BASIC을 가르는 진짜 잣대다. 직진성으로는 못 가른다** —
  실측상 BASIC(0.868~1.000)과 유도∿(0.673~0.909)가 **겹친다**. 현 이탈도는
  BASIC(0.003~0.059) vs 글자(0.112~0.443)로 **빈 구간이 통째로 비어 있다**
- 🔴 **룬·문양 템플릿 배열은 분리돼 있다** — 두 enum의 정수값이 겹친다 (`FIRE=0=BASIC`).
  한 배열에 섞으면 조용히 서로를 먹는다
- 🔴 **U턴 형태의 글자는 금지** — 끝점이 시작점 근처로 오면 `detect_escape`가 "진을 안 뚫었다"로
  읽어 **룬으로 오인**한다 (§6.1). 모든 문양 글자는 **전진하며 끝난다**

#### 미구현 스키마 (v1.9 목표 — 진 모양 · 룬 N개)

```gdscript
# rune_instance.gd — 룬 하나 (SpellDesign.runes 의 원소)
class_name RuneInstance extends Resource
@export var type: int        # RuneType.FIRE / IMPACT / WATER / WIND
@export var fill: float      # 0..1 — 농도 (v1.7 rune_fill 과 동일 정의: 외접 반경 ÷ 진 반지름)
@export var accuracy: float  # 0..1 — 순도
@export var angle: float     # rad. **v1.9 배선 축** — 룬 무게중심의 **진 중심 대비 방위각**.
                             # 🔴 글리프의 회전각이 아니다. 회전각을 쓰면 불△(3회 대칭)이
                             # 120도 돌려도 눈에 똑같아 플레이어가 영원히 알 수 없다.
                             # **위치는 눈에 보인다.** 캔버스 절대각 (direction·origin 과 같은 좌표계)
```

⚠ `ArrowData.glyph`·`reach`는 **위에 이미 구현돼 있다** — 여기 다시 적지 않는다.
(계약 문서에 같은 값을 두 번 적으면 언젠가 갈라진다)

#### 배선 규칙 (v1.9) — 룬 N개 × 문양 N개

```
탄의 속성 = argmin_i | angdiff(RuneInstance[i].angle, ArrowData.direction) |
```

- **룬이 1개면 모든 문양이 그 룬을 받는다** → v1.8 이하 도안과 **완전히 하위 호환**
- **위력 계수는 `fill` 가중 평균** (룬 1개일 때 지금과 **정확히 같다**)
- 두 방향 계산 모두 **캔버스 절대각**이다 (`direction`·`origin`·`angle` 동일 좌표계).
  ⚠ 세션 7의 "90도 틀어짐" 버그가 상대각/절대각 혼용에서 나왔다 — **좌표계를 섞지 말 것**

#### 남은 정합성 항목

- **적의 `_statuses`는 이미 Dictionary라 상태이상을 여러 개 동시에 갖는다** — 안 바꿔도 된다
- **세이브 마이그레이션 1회 필요** (`rune_fill` 스칼라 → `runes` 배열). v1.7에서 이미 세이브에 들어갔다.
  ✅ `arrows`는 **필드 추가라 기본값으로 흡수됐다** (`glyph=BASIC`, `reach=1.0`) — 마이그레이션 불필요.
  구세이브 도안이 **예전과 똑같이** 날아간다 (`test_spell_auto`가 실측으로 못 박음)
- 🔴 **중첩 진이 오면 `circle_radius`도 배열이어야 한다** (BACKLOG §1-6, 사용자 아이디어).
  **어차피 룬 N개로 마이그레이션을 한 번 하므로 그때 진도 함께 열면 공짜다.**
  **진 1개를 코드 곳곳에 하드코딩하지 말 것**
- ✅ **`magnitude`는 되살아났다** — v1.6에서 "소비 금지"로 묶어 둔 필드다. 다만 `reach`는
  **`magnitude ÷ circle_radius`가 아니다**: 둘은 정규화 기준이 달라(전자는 `arrow_full_length`,
  후자는 캔버스 반지름 0.5) 나누면 틀린 값이 나온다.
  **`reach = 원시 획 길이(캔버스 단위) ÷ 진 반지름(캔버스 단위)`** — `design_builder`가 계산한다.
  `magnitude`는 잉크·렌더·기록용으로 남는다
- **남은 순서**: **인식기($P) → 진 모양 → 룬 N개(+배선)**. 문양(v1.9)은 이미 끝났다.
  ⚠ $P는 **진 모양·룬 N개의 전제**다 — 별·용의 진은 한붓그리기로 원리적으로 못 그린다 (GDD §4.4)

---

### 4.0 역할 축 계약 (v1.7 — **현행 코드**) — **그리기는 조준이 아니라 조합이다**

**도안의 세 부품은 서로 다른 질문에 답한다. 한 부품이 남의 축을 먹으면 그 부품은 의미를 잃는다.**

| 부품 | 답하는 질문 | 정하는 값 | 소비처 |
|---|---|---|---|
| **진** (원) | **얼마나 큰 마법인가** | `circle_radius` → **위력 · 탄 크기 · 사거리** | `spell_system` |
| **룬** | **무엇으로 때리는가 · 얼마나 진하게** | `rune_type` → 피해 계수 · 상태이상 종류 / **`rune_fill` → 상태이상 세기** / `rune_accuracy` → 순도 | `RuneDef`, `spell_system` |
| **문양** (화살표) | **어떻게 나가는가** | `direction`(발사각) · `origin`(기점) · 개수(발수) · `path`(궤적) | `spell_system`, `projectile` |

- **규모는 진의 것이다.** 큰 진 = 크고 아프고 멀리 가는 마법. 문양을 길게 그어도 세지지 않는다
- **`ArrowData.magnitude`는 v1.6에서 전투 스탯과 분리됐다.** 필드는 남지만 **위력·크기 어디에도
  물리지 않는다.** 소비하지 말 것 — **⚠ v1.9에서 되살아난다** (`reach = magnitude ÷ circle_radius`
  → 사거리 배율. §4.0-a). **위력이 아니라 사거리**라는 점에서 v1.5의 축 위반과 다르다

#### v1.7 — 룬의 축: **속성의 농도** (`rune_fill`)

v1.6까지 룬은 **형태만 봤다.** $1 인식기가 크기·회전을 정규화하므로 크게 그리든 작게 그리든 같은
룬이었고, 잉크만 더 먹었다 — **룬 그리기는 기계적으로 "4지선다 찍기"였다.** 유일한 변수인
`rune_accuracy`는 **위력**에 물려 있었는데, 위력은 진의 축이다 (**축 위반**).

- **`rune_fill` (0..1) = 룬이 진을 얼마나 채우는가** — 룬 획의 bbox 반경 ÷ 진 반지름.
  인식기가 "룬은 진 안에 머문다"로 가르므로(§6.1, `ARROW_ESCAPE_R = 1.05`) 이 비율은
  **자연히 0..1에 갇힌다** — 인위적 밴드가 필요 없다
- **소비: 상태이상 세기** — 화상 초당 피해 · 젖음 둔화율 · 넉백 거리 · 흐름 세기.
  `status_power = RuneDef.status_power × density(rune_fill) × rune_accuracy`
- **`rune_accuracy`는 위력에서 떼어냈다 → 속성 순도**로 이동. 위력은 이제 **순수하게 진 × 룬 계수**다
- **비용 축** (GDD §5 갱신): **잉크 = 통에서 나온 양** (∫ 굵기 ds — 구간 길이 × 그 구간 붓 굵기.
  **할증 없음**. v1.8에서 진 크기 할증을 **이중 과금**으로 판명해 제거 — 큰 진은 둘레가 길어 이미 더 먹는다.
  `design_builder.stroke_ink_units()`가 **유일한 지점**이고, 종이 상한과 제작 비용이 **같은 값**을 쓴다) /
  **마나 = 룬 + 진 규모 + 발수 + 룬 농도**.
  진이 규모를, 룬이 농도를 주므로 **둘 다 시전 비용에 붙는다** — 안 그러면 "룬은 항상 최대한 크게"가
  유일한 정답이 된다. 같은 축을 세 번 처벌하진 않는다(제작 1회 · 시전 1회)
- **왜 이게 조합을 만드나**: 종이의 잉크 상한 안에서 **진(규모) · 룬(농도) · 문양(발수)이 서로
  경쟁**한다. 크게 때리지만 안 물드는 마법 vs 약하지만 깊이 물드는 마법 — 적 5종이 약점 설계
  문제(GDD §7)이므로 **상대에 따라 최적 배분이 달라진다**. 갑주 갑충은 젖음이 갑주를 무력화해야
  피해가 들어가고(`enemy_beetle._apply_defense`), 재생 덩굴은 화상 지속딜이 재생을 넘겨야 죽는다

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
@export var circle_radius: float         # 정규화 0..1 (캔버스 대비). **v1.6: 규모 축** —
                                         # 위력·탄 크기·사거리를 전부 이 값이 정한다 (§4.0)
@export var aim_axis: float              # 조준진 꼬리 방향(rad). FIXED면 무시
@export var rune_type: int               # RuneType.FIRE / IMPACT / WATER / WIND
@export var rune_fill: float             # 0..1 룬 반경 ÷ 진 반경. **v1.7: 속성 농도 축** —
                                         # 상태이상 세기를 이 값이 정한다 (§4.0). 구세이브 기본 0.5
@export var rune_accuracy: float         # 0..1, 인식 정확도 → **속성 순도** (v1.7: 위력에서 분리됨.
                                         # 위력은 진의 축이다). 스탬프 시 저장 시점 값 보존
@export var arrows: Array[ArrowData]
@export var strokes: Array[StrokeData]   # 원본 전체 획
@export var paper_grade: int             # 1..3
@export var ink_cost: Dictionary         # {ink_id: amount} — 제작 시 소모량 (수리비 산정 기준)
@export var mana_cost: float             # 캐스팅 비용 (v1.6: 룬 + **진 규모** + 발수 축)
@export var durability_max: int
@export var durability: int

# arrow_data.gd
class_name ArrowData extends Resource
@export var direction: float             # rad. **캔버스 절대각** — strokes·origin과 같은 좌표계.
                                         # 발사 시 spell_system이 (aim_angle - aim_axis)만큼 **한 번만**
                                         # 통째로 회전시킨다. 여기에 aim_axis를 미리 빼면 발사 때 또
                                         # 빠져서 **90도 틀어진다** (세션 7에 실측으로 잡힌 버그)
@export var magnitude: float             # 획 길이 0..1. **v1.6: 전투 스탯과 분리됨** —
                                         # 규모는 진이 정한다(§4.0). 소비 금지.
                                         # 문양 종류 도입 시 재사용 예약 (BACKLOG §1)
@export var origin: Vector2              # 발사 기점. 진 중심 기준·진 반지름=1.0 정규화 (가장자리=1.0)
                                         # 월드 px = origin × circle_radius × balance.circle_radius_px
                                         # circle_radius: 캔버스 꽉 채우는 원(캔버스 반지름 0.5) = 1.0
@export var path: PackedVector2Array     # v1.5 — 그린 화살표 획의 곡선 경로
                                         # 좌표계: 획 시작점=원점, +X=발사 방향(direction)인 로컬 공간.
                                         #        단위는 캔버스 단위 (월드 px = ×InkRender.unit_px(balance))
                                         # **비어 있으면 직선 폴백** — 샘플 도안·구세이브·직선 화살표 호환
                                         # 🔴 v1.9: ~~곡선 궤적용~~ **폐기 → 먹선 렌더 전용**(비주얼).
                                         #    궤적은 `glyph`가 정한다 (GDD §4.3). "내가 그린 획이
                                         #    날아간다"는 연출은 유지되지만 **날아가는 길은 글자가 정한다**

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

### 4.4 먹선 렌더 계약 (v1.5) — "그린 대로 나간다"

**`src/core/ink_render.gd` (리드 소유)가 도안 렌더의 유일한 지점이다.** 드로잉룸·캐스팅 마법진·
투사체·UI 썸네일이 전부 이 파일 하나를 preload해 쓴다 (GDD §10.5: 드로잉한 그대로가 이펙트).
`SpellDesign.strokes`(원본 획)는 이미 저장·로드되므로 **새 에셋 없이** 플레이어의 획을 그대로 렌더한다.

```gdscript
const InkRender := preload("res://src/core/ink_render.gd")

InkRender.unit_px(balance) -> float          # 캔버스 단위 1.0 → 월드 px (= circle_radius_px × 2)
InkRender.circle_center(design) -> Vector2   # CIRCLE 획의 중심 (캔버스 단위). 진 = 도안의 앵커
InkRender.build_design(design, px_per_unit, opts) -> Node2D  # 도안 → 먹선 Line2D 트리 (진 중심 = 원점)
InkRender.design_bbox(design, roles) -> Rect2     # 그려질 경계 (진 중심 원점·캔버스 단위, 굵기 제외)
InkRender.tail_line(path, pressures, px, opts) -> Line2D  # 투사체 먹선 — **머리가 노드 원점**, 꼬리는 뒤로
InkRender.arrow_line(stroke, px_per_unit, opts) -> Line2D # 화살표 획 → 시작=원점·+X=발사방향
InkRender.resample_pressures(pressures, n) -> PackedFloat32Array   # path와 인덱스 맞추기
InkRender.rune_color(rune_type, bright) -> Color  # bright=필드 발광 / false=종이 위 먹
InkRender.CIRCLE_ROLES / ALL_ROLES                # 진용(화살표 제외) / 전체(썸네일용)
```

**도안 썸네일은 `src/core/design_thumb.gd` (Control) 하나뿐이다.** UI(장착·HUD)와 거점(작업대
수리·장착)이 둘 다 도안을 그림으로 보여줘야 하는데, 모듈 간 직접 preload는 금지이므로 core가 소유한다.

```gdscript
const DesignThumb := preload("res://src/core/design_thumb.gd")
thumb.set_design(d) · thumb.width_mult · thumb.roles · thumb.has_ink() · thumb.ink_rect()
thumb.fallback_builder = func(design, size) -> Control   # strokes 없는 도안의 대체 표시
```
- **폴백 모양은 호출자가 주입한다** — core가 모듈 스타일(`src/ui/ink_style.gd`)을 preload하면
  의존 방향이 뒤집힌다. core는 먹선만 그리고, 글리프 폴백의 생김새는 알지 않는다
- 칸에 맞추는 피팅(스케일·중앙 정렬)은 위젯이 하고, bbox는 `design_bbox`가 점 계산만으로 준다
  (렌더를 두 번 하지 않는다 — 스무딩이 선형이라 bbox × 배율 = 최종 bbox가 정확히 성립)

- **캔버스→월드 스케일은 상수다**: `unit_px = balance.circle_radius_px × 2`. 진 반지름(캔버스
  `circle_radius × 0.5`) × `unit_px` = `circle_radius × circle_radius_px` — 즉 **기존 ArrowData.origin
  월드 공식과 자동으로 같은 스케일**이 된다. 도안을 통째로 월드에 얹어도 화살표 기점이 어긋나지 않는다.
  두 값의 관계를 깨지 말 것 (깨면 마법진과 발사 기점이 따로 논다)
- `build_design` 기본 필터는 **CIRCLE·RUNE·TAIL·DECOR** — 화살표는 제외한다 (화살표는 투사체로 날아가므로)
- 조준진(AIMED) 회전: 호출자가 반환된 Node2D의 `rotation`에 `aim_angle - design.aim_axis`를 넣는다
  (spell_system의 발사각 회전과 동일한 양 — 진과 투사체가 같이 돈다)
- `strokes`가 비어 있으면(샘플 도안) `build_design`은 **null을 반환**한다 — 호출자는 기존 스프라이트로 폴백

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
   **진은 한 종류다** — v1.5에서 꼬리 판정(조준진 승격)은 **삭제됐다**. `StrokeRole.TAIL` enum 값은
   구세이브 도안의 렌더를 위해 남아 있지만 **인식기는 어떤 컨텍스트에서도 TAIL을 생산하지 않는다**
2. **룬 판정 ($1 유니스트로크)**: 템플릿 = 불△·충격>·물~·바람◎ (각 다중 샘플). 회전 불변 정규화 허용. 물~ vs 바람◎ 구분: 리샘플 64pt + **총 회전각(감김 횟수) 피처**를 별도 게이트로.
3. **화살표 (파라미터 추출)**: 인식기 없이 — 방향 = 시작→끝 벡터, 크기 = 획 길이 정규화, 기점 = 시작점,
   **곡률 = `path`** (§6.1). 룬과의 구별은 직진성이 아니라 **탈출 판정**이다.

- 정확도 점수 = $1 매칭 스코어 → `rune_accuracy` (하한 0.6 보장, 자동보정 버튼 = 템플릿 형태로 스냅하되 accuracy는 현재값 유지)
- 잉크 소모 = Σ(획 길이 × 획 폭) — 그린 총량 비례

### 6.1 곡선 화살표 판정 (v1.5) — 룬과의 구별

곡선 궤적("그린 대로 날아간다")을 지원하려면 화살표가 더 이상 직선이 아니다. 그런데 룬 물~·바람◎도
곡선 1획이라 **직진성 게이트만으로는 화살표와 룬이 충돌한다.** 구별자는 직진성이 아니라 **기하 위치**다:

> **룬은 진 안에 머무른다. 화살표는 진을 뚫고 바깥으로 나간다.**

판정 순서(획 종료 시):
1. 원 → 2. **탈출 판정** → 3. 룬($1) → 4. 직진성 폴백  *(v1.5: 꼬리 판정 삭제)*

**탈출 판정 = 아래 3조건 전부 충족** (직진성 무관 — 곡선 허용). 조건 3개는 각각 **다른 룬의 실패
모드**를 막는다. 하나라도 빼면 그 룬이 화살표로 도둑맞는다 (실측 근거는 아래):

| 조건 | 상수 | 막는 대상 |
|---|---|---|
| 끝점이 진 밖 | `ARROW_ESCAPE_R = 1.05` (끝점 중심거리 ÷ 진 반지름) | 물~·불△·충격> — 진 안에 머문다 |
| 끝점이 시작점보다 진 중심에서 **충분히** 멀다 | `ARROW_ESCAPE_GAIN = 0.12 × radius` | 물~·불△ — 시작·끝이 진 중심에서 등거리(gain≈0)라 구조적으로 탈출 불가 |
| 감김이 1.5바퀴 미만 | `ARROW_ESCAPE_MAX_WINDING` (= `WINDING_WIND_MIN` 재사용) | **바람◎ 전용** — 나선은 중심에서 출발해 밖으로 감기므로 앞의 두 조건을 자연히 만족해버린다 |

- **`ARROW_ESCAPE_R = 1.05`은 실측값이다.** 탈출비 분포: 룬 최댓값 0.91(타이트한 진 안의 물~ 최악
  케이스) vs 진을 뚫는 화살표 1.21 → 빈 구간의 한가운데. 곡선 화살표는 직진성 0.62까지 인식된다
- 진이 없으면(첫 획) 탈출 판정을 못 하므로 기존 직진성 게이트(`ARROW_STRAIGHT_PRE` 0.90)를 그대로 쓴다
- 화살표 `direction`은 곡선이어도 **시작→끝 벡터** 그대로 (발사 초기각·에임 회전 기준축). 곡률은 `path`에 담긴다
- 남은 트레이드오프: **1.5바퀴 미만으로 감기면서 진을 크게 뚫고 나가는 룬**은 여전히 화살표로 오인된다.
  진 = 도안의 경계라는 GDD §4.1 규칙을 인식기가 강제하는 셈 — 의도된 동작이다

### 6.2 작성 순서 강제 (v1.5) — 진 → 룬 → 문양

**순서는 규칙이 아니라 문법이다.** §6.1이 보여주듯 인식기는 **진의 안/밖**으로 룬과 화살표를 가른다 —
진이 없으면 그 판정 자체가 불가능해서 룬이 화살표로, 화살표가 장식으로 오분류된다. 지금까지는 순서가
사실상 필요한데도 강제되지 않았고 플레이어에게 안내되지도 않았다. 캔버스가 문법을 강제한다.

`Enums.DrawStage` — 현재 단계는 **부품 보유 상태에서 파생**된다 (별도 상태 변수 없음):

| 단계 | 조건 | 받는 획 | 거부 메시지 |
|---|---|---|---|
| `CIRCLE` | 진 없음 | **진(원)** | "진(원)을 먼저 그리세요" |
| `RUNE` | 진 있음·룬 없음 | **룬** | "룬을 그리세요" |
| `ARROW` | 진·룬 있음 | **문양(화살표)** | "문양(화살표)을 그리세요" |

**각 단계는 정확히 한 종류의 획만 받는다** (v1.5 꼬리 폐지로 예외가 사라졌다).

- 단계에 맞지 않는 획은 **무효 처리**된다 (획이 사라지고 **잉크도 소모되지 않는다** — 실수의 대가 0) —
  `stroke_rejected(&"out_of_order")`. 잉크 상한 초과(`&"ink_over"`)와 같은 처리 경로
- 인식 실패(DECOR) 획도 거부한다 — 무엇을 기대하는지 알려주는 편이 "장식으로 남았습니다"보다 낫다
- 캔버스는 `stage_changed(stage)`·`get_stage()`·`stage_hint()`를 노출한다. 체크리스트 UI가 이걸 읽는다
- **예외 — 룬 스탬프 교체**: 스탬프는 "진이 있으면" 놓을 수 있다. `ARROW` 단계에서 스탬프로 기존 룬을
  갈아끼우는 것은 **순서 위반이 아니라 편집**이다 (GDD v1.3 필체 라이브러리 = 정확도 보존 재사용)
- **조준 기준축은 캔버스 위쪽** — `design_builder`가 항상 `aim_axis = -PI/2`, `circle_type = AIMED`.
  캔버스에 **방위 가이드**(앞·뒤·좌·우)를 옅게 깔아 이 규칙을 보이게 한다 (획으로 인식되지 않는 배경 렌더)

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
