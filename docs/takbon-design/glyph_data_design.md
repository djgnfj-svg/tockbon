# 문양 효과·표현 데이터화 + 응축 — 설계 (세82)

> 상태 = 🟢 **구현 완료 (세82).** 대화 확정 → architect 리뷰 전량 반영 → 6단계 구현 → 뮤테이션 9/9.
> ⚠ **F5 미확인**(사용자 손): 응축 나선을 손으로 그을 만한가 · 「집중 한 방」으로 보이나 · 책에서 폭발과 구분되나.
> 상위 맥락 = `jin_interpretation_design.md`(진별 해석 M1·M2 완료)의 **M3 첫 조각**.
> M3 세 덩어리 중 「문양 어휘 확장」에 들어가면서, 사용자가 **어휘를 늘리기 전에 토대부터** 깔자고 확정했다.
>
> 🔴 **v2 (리뷰 반영)** — takbon-architect가 **치명 3 / 중요 10 / 사소 7**을 라이브 코드 실측으로 잡았고
> 전부 반영했다. 반영 내역은 §⑮에 남긴다(무엇이 왜 바뀌었는지 = 다음 세션의 지도).

---

## ① 왜 하나 (사용자 확정)

사용자: *"토대를 깔고 싶은거긴한데 **그래야 니가 하드코딩을 안해서** 문양도 하나씩 생각해서 추가하고
싶고, 아직 머리에서 확정된건 **확산이랑 폭발 응축**밖에 없음"*

🔴 **논거는 「추가 비용 절감」이 아니라 「작업 규율」이다.** 리드가 처음 낸 비용 계산(새 문양 =
5곳 → 3곳이라 이득이 작다)은 **각도를 잘못 잡았다**. 진짜 문제는 토대가 없으면 문양을 늘릴 때마다
리드·서브에이전트가 **코드 여기저기에 분기를 흩뿌린다**는 것이고, 그건 이 프로젝트가 반복해 밟은
실패 방식이다(계열 판별 사본·수치 복사·`ring_power` 복사 금지 주석이 전부 그 흉터다).

### 🔴 응축이 그 논거를 즉시 실증했다

사용자가 확정한 세 문양 중 **응축**을 실측하니, 지금 구조로 만들면 **코드 중복이 실제로 발생한다**:

| | 폭발(`_explode`) | 응축 |
|---|---|---|
| 안쪽 갈래 위력 합산 | O | **똑같다** |
| 위치를 평균내 한 점으로 | O | **똑같다** |
| 반경 | 갈래 수에 **비례**(넓게) | 갈래 수에 **반비례**(좁게) |
| 융합 배율 | 0.85 (손실) | 1.0 초과 (집중 이득) |

→ 지금 구조면 `_apply_modifier`에 분기 하나 + **`_explode`를 거의 복사한 `_condense`**가 생긴다.
토대를 깔면 **`.tres` 한 장 + 파라미터 부호 뒤집기**로 끝난다.

**결론: 응축은 새 알고리즘을 요구하지 않는다.** 이 설계의 알고리즘 4종이 응축을 담을 수 있음이
착수 전에 검증됐다(= 첫 문양부터 토대가 안 맞는 사태를 피했다).

## ② 정직한 한계 — 밑그림은 데이터로 안 뺀다

`RingBoard.glyph_guide_pts`는 `match code` 하드코딩이고, **그대로 둔다.**

문양마다 **손으로 긋는 궤적이 달라야** 손이 문양을 기억한다(세47 주석·memory
`takbon-glyph-design-principle`). 궤적은 bespoke인 게 **코어 재미 그 자체**라 절차적 파라미터로
뭉개면 안 된다.

🔴 그래서 데이터화 후에도 **새 문양 = `.tres` + 밑그림 갈래 하나**다. "새 문양 = 파일 한 장"은
**성립하지 않는다** — 설계가 이걸 숨기지 않는다. 데이터화가 없애는 건 **효과 로직과 표시 어휘의
산개**지 밑그림이 아니다.

## ③ 확정된 것 (대화 요약)

1. **데이터화 범위 = 「행동 + 수치」** — `GlyphDef`가 `behavior`(코드에 있는 알고리즘 이름)와
   `params`(수치)를 든다. 원자 연산 시퀀스까지 가는 안은 **과설계로 각하**.
2. 🔴 **UI 표현(이름·색)도 데이터화한다** (사용자 추가 확정 — *"UI나 진 미리보기 이미지 + 스킬창에
   등록된 이미지 등 직접적으로 디테일을 잡을 수 있게 되어있니?"*에 대한 답이 **"문양은 아니다"**였다).
   `RingBoard.GLYPH_NAMES`·`GLYPH_COLORS` 배열 상수를 은퇴시키고 `GlyphDef.display_name`·`ui_color`가
   정본이 된다. **§⑨ 참조.**
3. **잠든 4종 `.tres` 4장을 「데이터만」 낸다** (관통·유도·팅김·추진). 문양-고리도 해금도 안 만들어
   **획득 경로 0 = 게임에 안 나온다** → 사용자의 *"부활은 이번에 안 한다"*와 어긋나지 않는다
   (부활 = 획득 경로를 여는 것). **필요한 이유는 둘**: ⓐ `test_ring_spell_auto`가 그 넷을 실제로
   발사해 검증한다(치명②) ⓑ ②의 UI 데이터화가 **모든 살아있는 code에 `.tres`를 요구**한다.
4. **응축 = 좁게 모아 세게 — 폭발의 반대.** 폭발↔응축이 「넓게 얕게 vs 좁게 세게」 대비축이 된다.
5. **응축 밑그림 = 안으로 감기는 나선.** 폭발(중심에서 뻗는 직선 살)을 방향만 뒤집으면 **손이 지나는
   자리가 거의 같아** 두 문양이 안 갈린다 — 나선은 유일하게 감기는 곡선이라 유도(사인 한 주기)와도 다르다.
6. **`GlyphRingDef`에 수치 오버라이드는 안 넣는다**(YAGNI) — 고리는 이미 `count`로 세기를 정해 역할이 겹친다.

---

## ④ 스키마 — `GlyphDef` (`src/core/schemas/glyph_def.gd`)

기존 필드(`id`·`display_name`·`code`·`inward`·`ui_color`·`desc`·폐기된 `key_hint`)는 **전부 그대로 두고**
두 필드를 **덧붙인다**:

```gdscript
## 🔴 이 문양이 쓰는 **알고리즘** — `GlyphRules.BEHAVIORS`의 키 중 하나.
## 계열(전개형/변형형)도 이 값이 답한다 — 별도 상수를 두지 않는다.
## ⚠ 기본값이 **빈 값**인 건 의도다: 갱신을 빠뜨린 .tres가 "직진탄으로 잘못 동작"하는 대신
## 미등록으로 **시끄럽게** 걸린다(세50 「파일을 만들었다 ≠ 완료」와 같은 결).
@export var behavior: StringName = &""
## 알고리즘에 넘길 **수치**. 키는 알고리즘마다 다르다(§⑤ 표). 없는 키는 알고리즘 기본값.
@export var params: Dictionary = {}
```

🔴 **`code`는 저장 계약이라 불변**이다(`Enums.GlyphCode`). 도안은 여전히 정수 배열로 저장되고,
발사가 그 정수로 `GlyphDef`를 찾아 `behavior`를 읽는다.

🔴 **`params` 키 표기 — ⚠구현에서 `String`으로 확정됐다** (초안은 `StringName`. 둘 다 파싱되지만
로드 후 타입이 갈려 하나로 굳혔다. 실측: String↔StringName은 Dictionary 키로 상호 조회된다. §⑯-5)
원래 문구: `GlyphRules.param(key: StringName)`
시그니처와 타입을 맞춘다. ⚠ **`.tres` 파서가 `&"..."` 사전 키를 실제로 받는지 구현 1단계에서
반드시 확인**하고, 안 받으면 String 키로 통일한다 — 문법이 틀리면 **리소스 전체가 조용히 사라지고
`Db`가 말없이 건너뛴다**(세50에 바람 룬이 `Color` 3인자로 두 세션 죽어 있었고 전 스위트가 그린이었다).
§⑫ 그물 [1]이 그 자리다.

## ⑤ 알고리즘 목록 (`behavior`) — 지금 코드가 실제로 하는 일 그대로

| behavior | 하는 일 | 계열 | params (기본값) |
|---|---|---|---|
| `bolt` | 그 칸 방향으로 탄 1발 | 전개형 | `effect`(`&""`) · `reach`(`balance.glyph_reach_max`) |
| `pillar` | 착탄점에 기둥 (칸 수만큼 굵게) | 전개형 | **없음** ※ |
| `spread` | 안쪽 각 갈래를 복제해 부채꼴 산개 | **변형형** | `fan_deg`(46.0) · `branch_mult`(0.6) · `offset_px`(44.0) · `min_branches`(2) |
| `blast` | 안쪽을 하나로 융합한 광역 | **변형형** | `base_radius_px`(54.0) · `radius_per_branch`(0.18) · `radius_per_count`(0.25) · `min_radius_px`(12.0) · `merge_mult`(0.85) · `merge_mult_per_count`(0.0) |

※ `pillar`의 굵기는 `PILLAR_SCALE_PER_GATHER` — **연출 상수라 balance가 아니다**(takbon-rules §0 예외).
다음 세션이 "왜 얘만 params가 없지"로 흔들지 않게 근거를 여기 남긴다.

- **`bolt.effect`** = `&""`(순수 직진탄) · `&"pierce"` · `&"homing"` · `&"bounce"` · `&"thrust"`.
  → `ring_spell_system.BOLT_EFFECTS` 상수를 **은퇴**시키고 문자열 → `Enums.GlyphType` 매핑만
  `GlyphRules`에 남긴다.
  🔴 **`&""`는 반드시 `effects = {}`(빈 사전)로 떨어져야 한다.** 지금 `_apply_layer:264-266`이
  RADIATE에 빈 사전을 준다. `&""`를 `GlyphType.BASIC`(=0)으로 매핑해 `{BASIC: reach}`를 실으면
  `projectile._setup_effects`는 BASIC을 안 읽어 **지금은 무해하지만** 향후 소비자가 생기면 새는 씨앗이다.

- 🔴 **`blast`에 파라미터 훅 둘을 새로 뚫는다** — `min_radius_px`(반경 하한 클램프)와
  `merge_mult_per_count`(칸 수가 위력에도 붙게). **둘 다 기본값이 지금 동작과 같아 폭발은 무회귀**
  (실측 대조: 지금 식의 최솟값이 `54.0`이라 `min_radius_px = 12.0`은 **절대 안 걸리고**,
  `merge_mult_per_count = 0.0`은 항등).

- 🔴 **식 형태를 못박는다** (구현자가 고르게 두면 응축 위력이 의도와 달라진다):
  ```
  radius = base_radius_px
         × maxf(1.0 + radius_per_branch × (branches − 1), 0.0)
         × maxf(1.0 + radius_per_count  × (count    − 1), 0.0)
  radius = maxf(radius, min_radius_px)
  mult   = total × (merge_mult + merge_mult_per_count × (count − 1))
  ```
  🔴 **각 인자를 `maxf(..., 0.0)`으로 먼저 클램프하는 게 핵심이다.** 응축은 두 계수가 **둘 다 음수**라,
  안 하면 두 인자가 동시에 음수일 때 곱이 **양수로 되살아나** 최종 클램프를 통과한다
  (지금 값에선 안 터지지만 **F5 튜닝 한 번**이면 뒤집힌다 — `radius_per_count`를 −0.15로 조이는 순간
  `count=8`에서 인자가 −0.05가 되고 갈래가 많을수록 반경이 **거꾸로 커진다**).
  기본값(양수 계수)에선 **무변경이라 회귀 0**이고 부호 함정만 구조적으로 막힌다.

- ⚠ **바닥이 둘이 된다** — `blast.gd`의 `radius_px = maxf(p_radius_px, 1.0)`은 **노드의 안전 바닥**,
  `min_radius_px`(12.0)는 **게임 규칙**이다. 역할이 다르니 둘 다 남기고, 이 문장을 코드 주석에도 남긴다
  (안 적으면 다음 세션이 하나를 지운다).

- **새 알고리즘이 필요할 때만 코드를 연다.** 그때는 이 표에 줄 하나 + 함수 하나 + `BEHAVIORS`에 이름 하나.

## ⑥ 계열 판별 단일 소스 — `Db`가 소유, `GlyphRules`는 순수 표

🔴 **v1의 「`GlyphRules`가 `Db`를 런타임 조회」 안은 폐기했다.** 리뷰가 두 가지 실제 어긋남을 잡았다:
takbon-rules §3(*"id→리졸버는 전부 `Db`. 스키마(.gd)에 두면 `-s` 컴파일 함정을 밟는다"*)의 **반대 방향**이고,
static 캐시가 **테스트의 in-memory 주입 관행**(`db.runes[...] =` 등 실측 3곳, 아무도 `reload()`를 안 부른다)과
충돌해 **다음 세션이 조용히 자명 통과할 자리**를 만든다.

### `Db`가 역인덱스를 소유한다 (`src/core/db.gd`)

`ink_mult`·`status_mult_of`·`chapter_clear_id` 선례 그대로.

```gdscript
var _glyph_by_code: Dictionary = {}          # int code → GlyphDef
func reindex_glyphs() -> void                # 🔴 공개 — 주입 테스트가 부를 수 있어야 한다
func glyph_by_code(code: int) -> GlyphDef
func modifier_codes() -> Array[int]          # 치명①(A)가 쓴다
# ⚠ 초안의 `glyph_behavior(code)`는 **내지 않았다** — 소비자 0이 될 함수였다(§⑯-2).
```

- `_load()`가 `reindex_glyphs()`를 부른다.
- 🔴 **같은 `code`를 두 `.tres`가 쓰면 결정적 승자**(먼저 로드된 쪽 유지) + 두 def 모두 `Db.glyphs`
  (id 키)엔 남는다. 조용히 덮으면 어느 쪽이 이겼는지 아무도 모른다.
  ⚠ 경고만으로는 `-s`가 못 재므로 **관측 가능한 성질(결정적 승자)로** 못박고 그물이 그걸 잰다.

### `GlyphRules` (`src/core/glyph_rules.gd`) — `Db` 무참조 순수 static 표

```gdscript
const BEHAVIORS := {
    &"bolt":   {"modifier": false},
    &"pillar": {"modifier": false},
    &"spread": {"modifier": true},
    &"blast":  {"modifier": true},
}
static func is_modifier_behavior(b: StringName) -> bool
static func effect_of(name: StringName) -> int              # &"pierce" → Enums.GlyphType.PIERCE
static func param(def: GlyphDef, key: StringName, fallback: Variant) -> Variant
```

🔴 **`int code`가 아니라 `GlyphDef`를 받는다.** 이러면 컴파일 함정·캐시·수명 문제가 **전부 사라진다**.
호출부는 이미 `Db`를 직접 본다(`ring_spell_system`이 `Db.get_rune`·`Db.ink_mult`·`Db.get_jin`을
컴파일 타임에 그냥 쓴다) — 런타임 조회가 애초에 필요 없는 자리였다.

### 🔴 `Enums.MODIFIER_GLYPHS` 은퇴 — 소비자는 **4곳**이다

| 소비자 | 파일:줄 | 이행 |
|---|---|---|
| 발사 층 해석기 | `ring_spell_system.gd:270,276` | `Db.glyph_behavior()` 직접 |
| 🔴 **`RingDesign.has_modifier_glyph()`** | `src/core/schemas/ring_design.gd:158` | **주입형으로**(아래) |
| `tab_panel.has_modifier()` | `src/hud/tab_panel.gd:872` | `Db.modifier_codes()` |
| `ring_forge_panel._has_modifier_glyph()` | `src/drawing/ring_forge_panel.gd:900` | `Db.modifier_codes()` |

🔴 **`RingDesign`이 핵심 함정이다.** core `class_name` Resource이고, **자기 주석에 "Db를 참조하면
`-s` 테스트가 오토로드 등록 전에 컴파일하다 터진다"고 세 번 적어 두었다**(`:26`·`:40-41`·`:101-102`).
지금은 의존성 0의 순수 함수인데 `Db`를 더듬게 만들면 에디터 인스펙터·리소스 프리로드 문맥에서
**조용히 `false`**를 반환한다 → HUD가 "갈래당 위력"을 "위력"으로 거짓 표기
(**세79가 정확히 그 거짓말을 잡으려고 이 함수를 core로 뽑았다**).

**→ 채택 = (A) 주입형.** `has_modifier_glyph(modifier_codes: Array[int]) -> bool`로 바꾸고 호출부
(`hud.gd:330`·`ring_forge_panel`·`tab_panel`)가 `Db.modifier_codes()`를 넘긴다. 이 프로젝트의 기존
관용구와 같은 결이다(takbon-rules §3 *"책·보드는 오토로드를 안 본다 → 패널이 해금 판정을 한다"*).
단일 소스는 `Db` 한 곳에 유지되고 컴파일 함정도 없다. ⚠ `test_jin_layers_auto.gd:333,340`도 갱신 대상.

### 🔴 미등록 code 정책 — 경고 + 건너뜀, 단 **빈 칸은 제외**

**코드에 기본표를 남기지 않는다.** 남기면 소스가 둘이 되어 갈라진다(`ring_power` 복사 금지와 같은 이유).

- `glyph_by_code(code)`가 null이면 `push_warning` + 그 칸을 전개에서 건너뛴다.
- 🔴 **`-1`(`GLYPH_NONE`, 빈 칸)은 경고 대상이 아니다.** `layer[k]`의 **가장 흔한 값이 `-1`**이라
  그대로 두면 **발사 1회마다 `빈칸 수 × 층 수 × 캐리어 수`**만큼 경고가 쏟아진다(NOVA 진 = 캐리어 6~12개).
  진짜 경고가 그 소음에 묻힌다.

### ⚠ 역인덱스가 둘이 된다 — 정당한 중복이다

`ring_board._glyph_def_by_code()`(`:1164`)가 **주입된 defs 위의** code→GlyphDef 선형 조회다.
보드는 오토로드를 안 보는 게 규약이라 `Db.glyph_by_code`와 **형제로 공존한다**. 복사가 아니라
**모듈 경계 때문**임을 여기 남긴다 — 안 적으면 다음 세션이 둘을 합치려 든다.

### 🔴 누락 발견 — `gather.tres`가 없다

`data/glyphs/`에 `radiate`(1)·`spread`(6)·`explode`(7) **3장뿐**이고 응집(code 0)의 낱개 `GlyphDef`가
없다(`gr_gather3` 고리만 살아 있어 **실제로 쓰인다**). `.tres`를 단일 소스로 만들면 **응집이 죽으므로**
이번에 `gather.tres`를 반드시 보충한다.

## ⑦ 발사 경로 변경 (`src/spell/ring_spell_system.gd`)

지금 `_apply_layer`는 정수를 **하드코딩으로** 가른다:

```gdscript
if g == Enums.GlyphCode.RADIATE or BOLT_EFFECTS.has(g):   # 발산 계열
elif g == Enums.GlyphCode.GATHER:                          # 응집
elif Enums.is_modifier_glyph(g):                           # 변형형
```

→ **`Db.glyph_behavior(g)`로 가른다**:

```gdscript
match Db.glyph_behavior(g):
    &"bolt":   ...   # params.effect → Enums.GlyphType, params.reach
    &"pillar": gather += 1
    &"spread", &"blast": mod_counts[g] += 1
```

- `_apply_modifier`의 `match code`(SPREAD/EXPLODE) → **`match behavior`**(spread/blast). 분기가
  **문양 개수가 아니라 알고리즘 개수**만큼만 늘어난다 — 이게 데이터화의 실체다.
- `_spread`·`_explode`는 **파라미터를 인자로 받는다**(지금은 `balance.*`를 직접 읽는다).
  함수 본문(복제 산개·융합 광역)은 **그대로**.
- ⚠ **`_spawn_cmd`의 폴백도 같이 이사한다** — `cmd.get("radius", balance.blast_base_radius_px)`
  (`:381`). `blast_base_radius_px`를 `BalanceData`에서 빼면 이 폴백이 깨진다.
- 🔴 **변형형 적용 순서** — 지금은 `Enums.MODIFIER_GLYPHS` 배열 순서로 고정한다. 이 계약의 진짜 목적은
  *"같은 층 안에서 확산·폭발을 **어느 칸에 놨느냐**가 결과를 바꾸지 않는다"*이다
  (GDScript `Dictionary`는 삽입 순서를 유지하고 슬롯을 0→7로 순회하므로 "실행마다 다르다"는 애초에
  일어나지 않는다 — v1의 서술이 틀렸다). `GlyphRules`/`Db`가 **결정적 순서**(code 오름차순)를 주고,
  §⑫ 그물이 **배치 순서 무관**을 잰다.

## ⑧ `balance.tres` 수치 이사

문양 `.tres`의 `params`로 **값 그대로 복사**해 옮기고 `BalanceData`에서 필드를 제거한다:

`spread_fan_deg` · `spread_branch_mult` · `spread_offset_px` ·
`blast_base_radius_px` · `blast_radius_per_branch` · `blast_radius_per_count` · `blast_merge_mult`

🟢 **`data/balance.tres`는 실제로 비어 있다** — 오버라이드가 한 줄도 없고(`script = ExtResource("1")`뿐)
값은 전부 `balance_data.gd`의 기본값이다(`:76-96`). 즉 **복사 원본은 `.tres`가 아니라 `.gd` 기본값**이고,
`@export` 필드 7개 제거가 **깨끗하다**(고아 프로퍼티 0).

**남기는 것**: `glyph_reach_min/max`(마나 계산 등 다른 소비자) · `max_deploy_cmds`(전역 상한) ·
`pillar_*`(기둥 자체의 수치라 문양 축이 아니다).

⚠ 손맛 튜닝 자리가 문양 `.tres` 여러 장으로 흩어진다. **그게 목적**이다. 수치는 전부 **시작값이고 F5로 조인다**.

## ⑨ 🔴 UI 표현 데이터화 (사용자 추가 확정)

**문제**: `.tres`에 `display_name`·`ui_color`가 **버젓이 있는데 UI가 안 본다.** 실제 소스는
`RingBoard.GLYPH_NAMES`·`GLYPH_COLORS` **배열 상수**이고, `ring_board.gd:61`이 스스로 인정한다 —
*"새 문양을 늘릴 땐 .tres·GLYPH_NAMES·여기 셋을 같이 늘려라."*

**빠뜨리면 조용히 깨진다**(리뷰 치명③):
- `GLYPH_NAMES` 미갱신 → `ring_summary`의 `counts[g] += 1`이 **없는 키**라 런타임 에러
- `GLYPH_COLORS` 미갱신 → `ring_book`이 직접 인덱싱해 **책이 터진다**
- `set_active_glyph`의 `clampi(g, 0, size-1)`가 **8을 7로 눌러 응축을 골랐는데 폭발 밑그림이 뜬다**(에러 없음)

**🟢 절반은 이미 배선돼 있다** — `ring_board._glyph_color(code)`는 주입된 `_glyph_defs`를 **먼저 보고**
없을 때만 배열로 폴백한다(세47). §③-3으로 **모든 살아있는 code에 `.tres`가 생기므로** 폴백이 영영
안 걸리게 되고, 배열 은퇴 조건이 처음으로 갖춰진다.

**이행**

| 대상 | 지금 | 바꿀 것 |
|---|---|---|
| `ring_board._glyph_color` | defs 우선 + 배열 폴백 | 배열 폴백 제거(미등록은 중립색 + 경고) |
| `ring_board.ring_summary` | `GLYPH_NAMES.size()`로 카운터 순회 | **주입된 `_glyph_defs`로 순회**(이름도 def에서) |
| `ring_board.set_active_glyph` | `clampi(g, 0, GLYPH_NAMES.size()-1)` | 🔴 **주입 defs에 있는 code만 허용**, 없으면 거부+경고(조용히 다른 문양으로 눌리지 않게) |
| `ring_book:695` · `assembly_slice_panel:355` | `RingBoard.GLYPH_NAMES` 인덱싱 | 주입 defs / `Db.glyph_by_code` |
| `tab_panel:766,879` | `RingBoard.GLYPH_COLORS/NAMES` | `Db.glyph_by_code`(HUD는 오토로드 접근 가능) |
| `GLYPH_NAMES` · `GLYPH_COLORS` | const 배열 | **은퇴** |

⚠ **모듈 경계 유지** — `ring_board`·`ring_book`은 **오토로드를 안 본다**(주입받는다). `Db`를 직접
보는 건 HUD(`tab_panel`)와 발사뿐이다. 이 경계를 데이터화가 무너뜨리지 않는다.

⚠ **`tab_panel`의 수식 표기 규약 유지** — 지금 `GLYPH_NAMES`에서 꼬리 기호(⋔·∗)를 떼어 쓴다(`:818`).
`display_name`으로 옮겨도 **같은 처리를 유지**한다(수식에 기호까지 들어가면 읽기 어렵다).

### 진(`JinDef`)은 이미 잘 되어 있다 — 손대지 않는다

사용자 질문에 대한 실측 답: **진의 표시는 전부 절차 생성이라 `.tres` 한 장이면 UI가 알아서 그린다.**
책 진 셀 아이콘(`jin_icon_marks(pattern, motion, shape)`) · HUD 슬롯 미니 다이어그램 ·
Tab 「마법진」 탭(전부 `jin_slot_dots` 단일 소스) · 밑그림(`jin_guide_pts(shape)`).
**이번 조각의 범위 밖이다.**

## ⑩ 응축 — 첫 증명 문양

**콘텐츠 (`.tres` 2장)**

```
data/glyphs/condense.tres
  id = &"condense" · display_name = "응축◈" · code = 8
  behavior = &"blast"
  params = { &"radius_per_branch": -0.12, &"radius_per_count": -0.10,
             &"merge_mult": 1.10, &"merge_mult_per_count": 0.10 }
  inward = true · ui_color = (응축용 색) · desc = "안쪽 마법을 한 점으로 눌러 담는다"

data/glyph_rings/gr_condense2.tres   (motif = 8 · count = 2 · unlock_id = &"gr_condense2")
```

🔴 수치는 **전부 시작값**이다. "좁게 세게"의 체감은 F5에서 사용자가 조인다.
⚠ **고리 `count = 2`인 이유**: `merge_mult_per_count` 훅이 `count = 1`이면 **경로에 아예 안 걸려**
그물이 자명 통과한다(리뷰 중요⑩). 콘텐츠 자체가 그 훅을 밟게 둔다.

**코드에 필요한 것** — §⑨의 UI 데이터화 덕분에 **2곳**으로 줄었다(안 했으면 5곳):
1. `Enums.GlyphCode.CONDENSE = 8` — **끝에만 덧붙인다**(중간 삽입은 저장 도안을 깬다).
2. `RingBoard.glyph_guide_pts`에 갈래 하나 — **안으로 감기는 나선**.
   - 손 규율: 한붓그리기 · 총 길이가 이웃 칸 간격(반지름 118px 기준 54px)을 넘지 않게 ·
     획수는 화살표(몸통+꺾쇠 2)를 넘지 않게.
   - 🔴 **폭발과 손이 갈려야 한다** — 폭발은 중심에서 사방 직선 살, 응축은 바깥에서 안으로 **감긴다**.
     방향만 뒤집은 직선 살은 **손이 지나는 자리가 거의 같아 각하**(세79가 확산·폭발을 가른 그 기준).
   - 책 셀 아이콘이 같은 함수를 부르므로 고르는 순간에도 구분된다.

**데이터·시드**: `.tres` 2장 + `GameState._seed_starting_unlocks`에 `gr_condense2` 한 줄
(M1·M2 임시 시드와 같은 자리 — **획득 경로 설계는 여전히 미결**이며 경로를 붙이는 세션이 이 줄들을 지운다).

## ⑪ 회귀 안전 근거

**기존 4종(응집·발산·확산·폭발)의 `params`를 지금 `balance_data.gd` 기본값과 똑같이 채운다** →
같은 리터럴이라 부동소수 결과가 **비트 동일**하다. M1의 *"밴드 1개면 층0 == `flatten_bands`"*,
M2의 *"룬 1개면 share 1.0"*과 **같은 자리의 증명**이다.

저장된 도안은 여전히 정수 배열이고 `code`도 불변이라 **저장 라운드트립 무변경**. `GlyphDef`에
`@export`를 덧붙여도 옛 `.tres`는 기본값으로 로드된다.

🔴 **정정(리뷰 지적)**: *"무엇이 계산되나"*는 같지만 ***"어디까지 도달하나"*는 좁아진다** —
`.tres` 없는 code가 **전개에서 빠지기** 때문이다. §③-3이 4장을 내는 이유가 정확히 이것이고,
그래서 **`Enums.GlyphCode`의 모든 값에 `.tres`가 있다**가 이 설계의 전제 조건이다.

## ⑫ 검증 계획

**갱신해야 할 기존 그물** (🔴 "전부 그린" 전제가 아니다)
- `test_ring_spell_auto:388,412` — 코드 2~5 발사 검증. §③-3의 `.tres` 4장이 **이걸 살린다**.
- `test_ring_trace_auto:284-303` — 코드 0~7 밑그림이 서로 다른 점 집합인지 재고 `seen.size() == 8`로
  못박는다. 🔴 **`range(8)`→`range(9)`로 안 올리면 응축 나선이 폴백 화살표로 떨어져도, 폭발과 같은
  궤적이어도 아무도 안 잡는다** — 이 테스트가 존재하는 이유 그 자체다.
- `test_jin_layers_auto:333,340` — `has_modifier_glyph` 시그니처 변경(치명①A).

**그대로 그린이어야 할 것**: 나머지 전 스위트, 특히 `test_jin_fusion_auto`(융합·반응·도배) ·
`test_ring_design_auto`(등급⇔펑) · `test_ring_trace_auto`(**flatten·밑그림 기하**).
⚠ **세87 정정**: 원래 여기 적혀 있던 `test_assembly_slice_auto`는 **더 이상 없다** —
밑그림 기하 그물은 세85에 F6 벤치에서 `test_ring_trace_auto`로 **이관**됐다(없는 파일을 찾지 마라).

**신설 그물** — `tests/test_glyph_data_auto.gd`
1. 🔴 **`Enums.GlyphCode` 전 값이 `Db`에 로드된다**(응집0·발산1·관통2·유도3·팅김4·추진5·확산6·폭발7·응축8
   = **9종, 예외 목록 없음**) + `behavior`가 `BEHAVIORS`의 키다 + `params`가 실제로 파싱됐다
   (세50 침묵사 자리 — §④의 `&"key"` 표기가 살아 있는지가 여기서 판가름난다).
2. **계열 판별 기대 집합을 명시로 박는다** — `modifier_codes()` == `[6, 7, 8]`, 나머지는 전개형.
   (은퇴시킬 함수와 대조하지 않는다 — v1의 자기모순.)
3. 🔴 **회귀 = 파라미터 이사 무변경**: 기존 4종만으로 짠 도안의 명령 목록(개수·각도·반경·mult)이
   이사 전과 **정확히 같다**. ⚠ balance 수치를 테스트에 박지 말고 **관계식으로** 잰다(세79 교훈).
4. 🔴🔴 **심장 = 응축이 폭발의 반대다 — 단조성으로 잰다**:
   - `응축 반경(갈래 3) < 응축 반경(갈래 1)` — 갈래가 늘수록 **좁아진다**
   - `폭발 반경(갈래 3) > 폭발 반경(갈래 1)` — 대조군
   - `응축 위력 > 폭발 위력`(같은 안쪽)
   ⚠ **대소 비교만으로는 부호 뒤집기를 못 잡는다**(리뷰가 계산으로 증명: 뮤테이션 후에도
   `66.96 < 73.44`라 그린). **방향(단조성)을 재야** 즉시 빨개지고, F5 튜닝에도 안 부서진다.
5. **`merge_mult_per_count`가 경로에 걸린다** — `count ≥ 2`인 응축(gr_condense2)으로 잰다.
6. **응축이 새 알고리즘 없이 돈다** — `condense.tres`의 `behavior == &"blast"`이고 `_explode` 본문이
   분기 없이 그대로 쓰인다(= 데이터화가 실제로 작동함의 증명).
7. **미등록 code = 건너뜀**(SCRIPT ERROR 0) + 🔴 **`-1` 빈 칸은 경고 대상이 아니다**.
8. **code 중복 = 결정적 승자** — in-memory로 중복 code를 주입하고 「먼저 로드된 쪽 유지 + 두 def 모두
   `Db.glyphs`엔 남는다」를 잰다(경고는 `-s`가 못 재므로 관측 가능한 성질로).
9. **주입 후 `reindex_glyphs()`가 역인덱스를 갱신한다** — 세61 주입 관행이 이 설계에서도 살아 있는지.
10. **같은 층 내 배치 순서 무관** — 확산·폭발을 슬롯 위치만 바꿔 두 번 전개해 plan이 동일한지.
11. `min_radius_px` 클램프 + **인자별 `maxf(...,0.0)`** — 계수를 음수로 크게 줘도 반경이 거꾸로 커지지 않는다.
12. **UI 표현 데이터화** — `ring_summary`가 응축을 **이름으로** 표기한다(「?」가 아니라) +
    `set_active_glyph(8)`이 8로 남는다(🔴 clampi가 7로 누르던 자리).

**🔴 뮤테이션 (초록불을 근거로 쓰지 않는다)**
① `glyph_behavior`를 항상 `&"bolt"` 반환 → 변형형이 통째로 죽는지
② 응축 `radius_per_branch` 부호를 양수로 → **[4] 단조성**이 빨개지는지(대소만 재면 안 잡힌다)
③ `merge_mult_per_count` 훅 무력화 → **[5]**(count≥2)가 잡는지
④ 인자별 `maxf` 제거 후 계수를 음수로 → **[11]**이 잡는지
⑤ code 중복 시 "덮어쓰기"로 → **[8]**이 잡는지
⑥ `reindex_glyphs`를 `reload()`에서만 → **[9]**가 잡는지
⑦ `set_active_glyph`에 옛 `clampi` 복원 → **[12]**가 잡는지
⑧ 배치 순서 의존(정렬 제거) → **[10]**이 잡는지
**전부 원상복구까지가 지시다**(세48 교훈 — 되돌린 채 커밋되면 기능이 조용히 죽는다).

⚠ **`push_warning`은 `-s`가 못 잰다** — 미등록·중복의 *경고 자체*는 헤드리스 검증 대상이 아니다.
그래서 위 그물은 전부 **관측 가능한 성질**(건너뜀·결정적 승자·역인덱스 갱신)로 세웠다.

**🔴 헤드리스가 못 잡는 것 (F5 필수)**
- 응축 나선을 **손으로 그을 만한가** — 폭발·유도와 손이 실제로 갈리는가(눈이 아니라 손)
- 응축이 **"좁게 세게"로 보이는가** — `blast` 연출을 공유하므로 작은 반경이 「집중 한 방」으로 읽히는지,
  아니면 그냥 「약한 폭발」로 보이는지. **후자면 연출 분기가 필요하다는 신호다.**
- 책 셀에서 응축 아이콘이 폭발과 구분되는가 · 이름·색이 `.tres`에서 제대로 나오는가

## ⑬ 구현 순서 (회귀를 층으로 가른다)

**각 단계 끝에서 전 스위트를 돌릴 수 있어야 한다.**

1. **데이터 보충 (기계 무변경)** — `gather.tres` + `pierce/homing/bounce/thrust.tres` 4장.
   전부 `behavior`·`params`를 **지금 `balance_data.gd` 기본값 그대로** 채운다.
   🔴 **여기서 `&"key"` 사전 표기가 실제로 파싱되는지 확인한다**(안 되면 String 키로 통일).
   → 순수 추가라 소비자 0, 전 스위트 그린이어야 한다.
2. **`Db` 역인덱스 + `GlyphRules` 순수 표 신설** — 아직 아무도 안 쓴다. 그물 [1][2][8][9] 먼저 세운다.
3. **`_apply_layer`/`_apply_modifier` 전환** — `BOLT_EFFECTS` 은퇴, `balance.*` → `params`,
   `_spawn_cmd` 폴백 이사. 그물 **[3](관계식 무변경)이 유일한 회귀 증명**이다.
   ⚠ `-1` 예외와 인자별 `maxf` 클램프를 이 커밋에 같이 넣는다.
4. **계열 판별 이행** — `RingDesign` 주입형(치명①A) + 소비자 4곳 정리 + `test_jin_layers_auto` 갱신.
5. **UI 표현 데이터화** — `GLYPH_NAMES`/`GLYPH_COLORS` 은퇴, 소비자 6곳 이행. 그물 [12].
6. **응축** — `Enums`+`glyph_guide_pts`+`.tres` 2장+시드, `test_ring_trace_auto` `range(8)`→`range(9)`,
   그물 [4][5][6][11] + 뮤테이션 전량.

🔴 **위임 경계**: core 스키마(`glyph_def`·`enums`·`db`·`glyph_rules`·`ring_design`·`balance_data`)는
**리드가 직접** 반영한다(takbon-rules §0). UI 이행(5)·밑그림 갈래(6)는 `takbon-dev`/`takbon-ui` 위임 가능.

## ⑭ 안 하는 것 (YAGNI · 이월)

- **잠든 4종의 획득 경로**(문양-고리·해금) — `.tres`는 내지만 **게임에 안 나온다**. 부활은 사용자가
  문양을 하나씩 확정하는 흐름에서.
- **밑그림 데이터화** — §② 참조. 코어 재미라 bespoke가 맞다.
- **밑그림 커스텀 편집기 부활** — `stash@{0}`에 살아 있다(세57 보류). 이번 범위 밖.
- **`GlyphRingDef` 수치 오버라이드** — `count`와 역할 중복.
- **진(`JinDef`) 표현** — 이미 절차 생성이라 손댈 게 없다(§⑨ 말미).
- **문양 해금 게이트** — `GlyphDef`엔 `unlock_id`가 없고 책이 무필터로 띄운다(세61). D3 대기.
  응축은 **고리 쪽 `unlock_id` + 임시 시드**로 낸다(기존 관행).
- **`rune_fill`(룬 농도)** — 소비자 0곳. 이번에도 일부러 안 켠다.
- **연출 분기** — 응축이 `blast` 연출을 공유한다. F5에서 구분이 안 되면 그때 문양 색을 연출에 싣는다.

## ⑮ 리뷰 반영 내역 (v1 → v2)

takbon-architect 리뷰(치명 3 / 중요 10 / 사소 7) **전량 반영**.

| # | 무엇이 틀렸나 | 어떻게 고쳤나 |
|---|---|---|
| 치명① | `MODIFIER_GLYPHS` 소비자를 1/4만 셌다. core `RingDesign`은 `Db`를 못 본다(자기 주석이 세 번 경고) | §⑥ — **주입형 시그니처**(A안) + 소비자 4곳 표 |
| 치명② | 코드 2~5 `.tres` 부재 → `test_ring_spell_auto`가 빨개진다. "26종 그린" 전제가 거짓 | §③-3 — **`.tres` 4장 「데이터만」**(획득 경로 0) |
| 치명③ | "코드 2곳"이 실제 5곳. 배열 미갱신 = 런타임 에러 + **응축 골랐는데 폭발 밑그림** | §⑨ **UI 데이터화로 구조적 해소** → 다시 2곳 |
| 중요④ | 빈 칸 `-1`까지 경고 → 발사마다 경고 폭탄 | §⑥ — `-1` 명시 예외 |
| 중요⑤ | `GlyphRules`의 `Db` 런타임 조회 = 하드 계약 역행 + 주입 테스트와 충돌 | §⑥ — **`Db` 소유 + `GlyphRules` 순수화**(`GlyphDef`를 받는다) |
| 중요⑥ | `behavior` 기본 `&"bolt"` = 조용한 오작동 | §④ — 기본값 `&""` |
| 중요⑦ | `params` 키 따옴표 없음 = 세50 침묵사 | §④ — `&"key"` 못박음 + 1단계에서 파싱 확인 |
| 중요⑧ | 반경식 부호 불안정(두 음수 인자가 곱해져 클램프 통과) | §⑤ — **인자별 `maxf(...,0.0)`** |
| 중요⑨ | 🔴 심장 그물이 심장 뮤테이션을 못 잡는다(`66.96 < 73.44`) | §⑫[4] — **단조성**으로 교체 |
| 중요⑩ | `merge_mult_per_count`가 `count=1`이라 경로에 안 걸림 | §⑩ 고리 `count=2` + §⑫[5] |
| 중요⑪ | 뮤테이션 ④⑤가 관측 불가/자명 통과 | §⑫[7][8] — **관측 가능한 성질**로 재작성 |
| 중요⑫ | 뮤테이션⑥ 전제 오류(`Dictionary`는 삽입 순서 유지) | §⑦·§⑫[10] — **「배치 순서 무관」**으로 |
| 중요⑬ | [2]가 은퇴시킨 함수와 대조 | §⑫[2] — 기대 집합 명시 |
| 중요⑭ | `test_ring_trace_auto` `range(8)` 미갱신 시 응축 커버리지 0 | §⑫ — **갱신 대상**으로 승격 |
| 사소⑮~㉑ | `balance.tres` 실제로 비어 있음 · 빈 `effects` · 바닥 이중 · 역인덱스 2개 · `_spawn_cmd` 폴백 · 이름/색 사본 · `pillar` 근거 | §⑤·⑥·⑦·⑧에 각각 반영 |

**리뷰가 승인한 것**(뒤집지 마라): `gather.tres` 누락 진단 · `blast` 훅 둘의 기본값 무회귀 ·
저장 라운드트립 무변경 · 도형 플레이스홀더 규칙 위반 없음(절차적 가이드선 예외) ·
`GlyphRules`·`Db` 역인덱스가 실재하지 않음(신설 정당) · **신설 EventBus 시그널 없음**.


---

# ⑯ 🟢 구현 완료 기록 (세82)

설계대로 **6단계로 갈라** 각 단계 끝에서 전 스위트를 돌렸다. 최종 = **27종 그린 · SCRIPT ERROR 0 ·
뮤테이션 9/9 검출 + 전부 원상복구 확인.**

| 단계 | 한 일 | 결과 |
|---|---|---|
| 1 | `GlyphDef.behavior`/`params` 신설 + `.tres` 8장(`gather` 보충 · 잠든 4종 데이터만 · 기존 3장 이관) | 26종 그린 |
| 2 | `Db._glyph_by_code`/`reindex_glyphs`/`modifier_codes` + `GlyphRules` 순수 표 | — |
| 3 | `_apply_layer`/`_apply_modifier`가 `behavior`로 분기 · `_spread`/`_explode`가 `params`를 받음 · `BOLT_EFFECTS` 은퇴 · balance 7필드 제거 | 26종 그린 = **회귀 증명** |
| 4 | `Enums.MODIFIER_GLYPHS`·`is_modifier_glyph` 은퇴 · `RingDesign.has_modifier_glyph` 주입형 · 소비자 4곳 | 26종 그린 |
| 5 | `GLYPH_NAMES`·`GLYPH_COLORS` 은퇴 · 소비자 6곳이 `.tres`를 읽음 · `ring_summary` 재작성 | 26종 그린 |
| 6 | `CONDENSE=8` · 나선 밑그림 · `.tres` 2장 · 시드 · 신설 그물 12항목 | **27종 그린** |

## 🔴 구현이 설계를 정정한 것 (다음 세션이 알아야 할 것)

1. **`RingAssembly.GLYPH_NONE`을 발사부에서 참조하면 파일 전체가 파싱 실패한다.** `-s` 테스트가
   전역 클래스 캐시 갱신 전에 컴파일하기 때문 — 실제로 밟아 **스위트 7종이 한 번에 빨개졌다**.
   → 빈 칸은 **`g < 0` 음수 판정**으로(문양 code는 늘 0 이상이라 안전한 계약).
2. 🔴 **`Db.glyph_behavior()`는 내지 않았다 — 소비자 0이 될 함수였다.** 설계엔 있었지만 호출부가
   `params`도 함께 필요해 전부 `glyph_by_code(g).behavior`를 쓴다. **뮤테이션이 이걸 드러냈다**:
   그 함수를 통째로 뒤집어도 아무 그물이 안 빨개졌다(= 아무도 안 쓴다는 뜻).
3. 🔴 **그물 구멍 하나를 뮤테이션이 잡았다** — 초안 그물이 `_spread`/`_explode`를 **직접** 부르느라
   `_apply_layer`의 계열 분기를 한 번도 안 지났다. behavior를 통째로 `bolt`로 돌려도 **전부 그린**.
   → [7]에 「폭발 칸만 있는 층 → `blast` 명령 1개」·「응집 2칸 → `pillar` 1개」를 세워 메웠다.
4. **뮤테이션 설계도 검출력이 있다** — code 중복 뮤테이션은 **주입 순서를 사전순과 갈리게** 넣어야
   잡히고(같은 순서면 덮어써도 같은 승자), 반경 클램프는 **두 인자를 동시에** 벗겨야 부호 구멍이 뜬다
   (하나만 벗기면 남은 클램프가 0을 만들어 곱을 죽인다).
5. **`.tres` 사전 키는 String으로 통일했다.** `&"key"`도 파싱은 되지만 로드 후 타입이 갈린다
   (String↔StringName은 Dictionary 키로 상호 조회되는 걸 실측 확인 — 그래도 표기를 하나로 굳혔다).
6. **UI 데이터화가 절반 이미 배선돼 있었다** — `ring_board._glyph_color`가 세47부터 주입 defs를
   먼저 보고 배열은 폴백이었다. 모든 code에 `.tres`가 생기자 폴백이 죽은 가지가 되어 은퇴가 안전해졌다.
7. **`ring_summary`가 어휘 길이에서 해방됐다** — 놓인 코드만 세도록 재작성해, 세44의 「배열을 안
   늘리면 `counts[g] += 1`이 없는 키라 런타임 에러」 함정이 **구조적으로 사라졌다**.

## 결과 — 새 문양 추가 비용

**5곳 → 2곳** (`Enums.GlyphCode` 값 하나 + `glyph_guide_pts` 갈래 하나) + `.tres`.
밑그림이 남는 건 §②대로 **의도**다(손이 문양을 기억하는 게 코어 재미).
같은 알고리즘에 수치만 다른 문양은 **`.tres` 한 장 + 밑그림 갈래**로 끝난다.
