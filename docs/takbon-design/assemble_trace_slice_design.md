# 설계: 조립→탁본 최소 슬라이스 (코드 구조)

> 산출물 = takbon-dev/리드가 바로 받는 **구조 설계**. 게임 디자인은 확정(`scratch_takbon_model.md`) — 재논의 없음.
> 범위 = 정본의 「최소 슬라이스」 딱 그만큼: **진 1개(동그라미, 밴드 2겹) + 문양-고리 2장 조립 → 조립본이 통째로 밑그림 → 손으로 전체를 한 번에 따라 긋기 → 완성도×정밀도=위력 → 쏘기.**
> 🔴 파밍 경제·복합 룬·재귀 진·순서=수식·필드 드롭 아트는 **전부 최소 슬라이스 밖** — 각 절에 선을 그어 둔다.

---

## 목표 / 왜

세68 모델을 **손에 쥐어** 남은 질문(순서가 결과를 바꾸나·층 기하·긴 탁본 감)을 실측으로 푼다. 코드부터가 아니라 **기존 순수 조각(RingBoard 기하 static·TraceScorer·RingPower·발사 경로)을 그대로 재사용**하고, 새로 짓는 건 「밴드에 고리를 끼운다」와 「조립본을 한 장의 가이드로 합성한다」 둘뿐이다.

핵심 통찰 = **`TraceScorer`는 이미 임의 길이의 단일 가이드를 채점한다**(`set_guide(pts)` → 완성도=드러낸 점 %, 정밀도=평균 이탈). 조립본을 한 줄의 긴 가이드로 합성해 넘기면 "전체를 한 번에 따라 긋기"가 **채점기 무변경으로** 성립한다. 이게 이 슬라이스가 작은 이유다.

---

## 이미 있는 것 vs 새로 만들 것 (기존 배선 확인 결과)

### 그대로 재사용 (무변경)
| 파일 | 재사용하는 것 |
|---|---|
| `src/drawing/trace_scorer.gd` | **무변경.** 단일 가이드 채점(`set_guide`/`begin_stroke`/`add_point`/`coverage`/`accuracy`/`piece_score`). 조립본 = 그냥 더 긴 가이드. |
| `src/drawing/ring_board.gd` (static들) | `jin_guide_pts`·`rune_guide_verts`·`glyph_guide_pts`·`_densify`·`slot_angle` — 전부 static/public. 합성기가 이걸 불러 이어 붙인다. |
| `src/core/ring_power.gd` | 점수→위력·등급·펑(`grade_of`·`is_stable`·`power_of`). 무변경. |
| `src/spell/ring_spell_system.gd` | **무변경**(아래 "플래튼" 결정 덕분). 발산/응집/효과 탄 전개를 그대로. |
| `src/core/schemas/ring_design.gd`·`.to_assembly()` | 저장·발사 계약. 무변경(플래튼분은 기존 `rings`에 담긴다). `bands` 필드만 선택적 추가(아래). |
| `EventBus.ring_cast_requested`·`design_committed` 패턴 | 발사·맺음. **새 시그널 0개.** |

### 새로 만들 것
| 무엇 | 어디 | 누가 |
|---|---|---|
| `GlyphRingDef` 스키마 | `src/core/schemas/glyph_ring_def.gd` | 🔴 리드(core·class_name) |
| Db 로더+리졸버 | `src/core/db.gd` (`glyph_rings`·`all_glyph_rings`·`get_glyph_ring`) | 🔴 리드 |
| GameState 시드 2종 | `src/core/game_state.gd` (`_seed_starting_unlocks`) | 🔴 리드 |
| 조립본→가이드 합성기 | `ring_board.gd`에 **가산** static `compose_guide(...)` + 진입점 `enter_combined_trace(pts)` | dev |
| 밴드→플래튼 링 빌더 | `ring_board.gd` 또는 슬라이스 패널 (defs를 아는 자리) | dev |
| 슬라이스 조립 패널 | `src/drawing/assembly_slice_panel.gd/.tscn` (신설·병렬) | dev + takbon-ui |
| 진입 테스트 씬 | `tests/test_assembly_slice.tscn` (F6 시험대식) | dev |
| 문양-고리 2장 | `data/glyph_rings/gr_*.tres` | dev (스키마 확정 후) |
| (선택) 슬라이스 전용 진 | `data/jin/jin_ring2.tres` (밴드 2겹) — jin_single 안 건드리려고 | dev |

🔴 **핵심 선택 = 라이브 포지(`ring_forge_panel`·`ring_book`)를 건드리지 않는다.** 이유는 「회귀 위험」 절.

---

## 7개 설계 질문 답

### Q1. 문양-고리 데이터 스키마 (`GlyphRingDef`)

문양-고리 = "미리 그려진 장식 고리 한 장"(예: 파괴 ×5방향). **낱개 문양이 아니라 「모티프 × 배치」**다.

최소 슬라이스는 가이드 점열을 **.tres에 좌표로 박지 않고 절차적으로 생성**한다 — 기존 `glyph_guide_pts`(문양 화살표 생성기)를 그대로 재사용하려면 "모티프 코드 + 개수"만 있으면 된다.

```gdscript
# src/core/schemas/glyph_ring_def.gd  (리드/core, class_name)
class_name GlyphRingDef
extends Resource

@export var id: StringName = &"gr_radiate5"
@export var display_name: String = "발산 고리 ×5"
## 🔴 모티프 = 착탄 특성. **Enums.GlyphCode 재사용**(radiate/gather/pierce/...). 문양 어휘를 새로
## 만들지 않는다 — 문양-고리는 기존 GlyphDef 모티프를 "한 밴드에 count번 깐 것"이다.
@export var motif: int = 1              # Enums.GlyphCode
## 밴드 둘레에 몇 번 반복하나 (파괴 ×5의 5). 착탄 시 그 개수만큼 탄이 나간다.
@export var count: int = 5
@export var ui_color: Color = Color(0.72, 0.28, 0.12)
## 획득/소유 게이트 — RuneDef.unlock_id·JinDef.unlock_id와 같은 규약(패널이 is_unlocked로 거른다).
@export var unlock_id: StringName = &""
@export var sort: int = 0
```

**기존 스키마와의 관계:**
- `GlyphDef`(현존) = 원자 문양 어휘(code·색·이름). `GlyphRingDef.motif`가 이 **code 값**을 가리킨다 → 문양-고리 = "GlyphDef 모티프를 밴드에 count번 배치한 파밍 패키지".
- 가이드 점열은 스키마에 없다 — **`motif`+`count`에서 절차 생성**(합성기가 `glyph_guide_pts(motif,...)`를 count번 호출). 이게 "새 문양-고리 = .tres 한 장"을 지킨다.

🔴 **최소 슬라이스 밖:** 고리의 임의 커스텀 모양(좌표 박기)·고리 안 여러 모티프 혼합·희귀도/스탯 롤 — 전부 다음. 지금은 "한 고리 = 한 모티프 × count".

### Q2. 조립 상태 (`RingAssembly` 확장 + `RingDesign`)

현 `RingAssembly`는 진+룬+**8칸 개별 문양 배치**(`_open`/`_slots`)를 든다. 새 모델은 개별 칸 배치가 사라지고 **밴드에 문양-고리를 끼운다**.

`RingAssembly`(순수 데이터 유지)에 더할 것:
```gdscript
var _bands: Array[StringName] = [&"", &""]   # 밴드 idx → 문양-고리 id (&""=빈 밴드). 최소=2겹.
func set_band(i: int, ring_id: StringName) -> void   # 밴드에 끼운다/뺀다
func get_bands() -> Array[StringName]
```
- `_jin`·`_rune`은 그대로 유지(진 선택·룬 기본 fire).
- `_open`/`_slots`(옛 8칸 개별 배치)는 **최소 슬라이스에서 안 쓴다** — 라이브 포지의 옛 경로가 계속 쓰므로 지우지 말고 그대로 둔다(공존).
- `RingAssembly`는 **Db를 모른다**(순수). 그래서 밴드 id→모티프 전개는 여기서 안 한다 — defs를 아는 **보드/패널**이 한다(펜 보정을 GameState에서 읽는 기존 분담과 같은 규율).

`RingAssembly.get_assembly()`가 내는 순수 스냅샷:
```gdscript
{ "jin": _jin, "rune": _rune, "bands": _bands.duplicate() }   # 밴드 id만. rings는 defs를 아는 쪽이 채운다.
```

🔴 **발사 계약(`rings`)은 보드/패널이 완성한다** — 밴드 id들을 GlyphRingDef로 펼쳐 **8칸 링 하나로 플래튼**(아래 Q5)해 `rings:[8칸]`을 넣고 `score`/`ink`/`size`를 실어 최종 assembly를 만든다. 즉 발사부가 받는 dict는 기존과 동형이다.

**`RingDesign`(저장·발사, core — 리드):**
- **발사엔 무변경 필요 없음** — 플래튼된 8칸이 기존 `rings`에 그대로 담겨 `to_assembly()`가 그대로 흐른다.
- (선택) `@export var bands: Array = []` 한 줄 추가 = 맺은 도안이 "어느 고리로 만들었나" 출처를 보존(장착 슬롯 미니 다이어그램·후속 재편집용). **발사엔 안 쓴다.** 최소 슬라이스에 **필수 아님** — 넣으면 좋고 없어도 쏜다. 🔴 넣으려면 리드가 core에 반영.

### Q3. 밑그림 합성 (조립본 → 단일 가이드 점열)

**위치·책임 = `ring_board.gd`**(기하의 단일 소유자, 모든 `*_guide_pts` static이 여기 있다). 가산 static 하나:

```gdscript
## 조립본(진 + 룬 + 밴드별 문양-고리)을 한 장의 따라긋기 가이드로 합성한다.
## 🔴 기존 static들만 불러 이어 붙인다 — 새 기하 규칙 0. band_defs[i] = 그 밴드의 GlyphRingDef(or null).
static func compose_guide(jin_shape: int, rune_type: int, band_defs: Array,
        ctr: Vector2, ro: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    out.append_array(jin_guide_pts(jin_shape, ctr, ro))                 # ① 진 윤곽(바깥 원)
    var rv := rune_guide_verts(rune_type, ctr, ro * RUNE_GUIDE_FRAC)    # ② 룬(중심) — 변마다 densify
    # (rune_guide_verts는 꼭짓점 → _build_guide처럼 변당 12등분해 이어붙인다)
    for i in band_defs.size():                                          # ③ 밴드별 문양-고리
        var gr: GlyphRingDef = band_defs[i]
        if gr == null: continue
        out.append_array(glyph_ring_pts(gr, ctr, ro * BAND_RADII[i]))
    return out

## 문양-고리 한 장을 밴드 둘레에 count번 깐다 — 각 인스턴스는 기존 glyph_guide_pts 재사용.
static func glyph_ring_pts(gr: GlyphRingDef, ctr: Vector2, band_r: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    var n := maxi(gr.count, 1)
    for i in n:
        var a := TAU * float(i) / float(n) - PI / 2.0                   # slot_angle과 같은 회전 규약
        var p := ctr + Vector2.from_angle(a) * band_r
        var outward := Vector2.from_angle(a)                            # 반경 바깥 = 발산 방향
        out.append_array(glyph_guide_pts(gr.motif, p, outward, band_r * MOTIF_SIZE_FRAC))
    return out
```

기하 상수(연출/레이아웃 → 스크립트 const, 밸런스 아님):
```gdscript
const RUNE_GUIDE_FRAC := 0.18      # 룬 크기(중심)
const BAND_RADII := [0.42, 0.68]   # 동심원 2겹 (정본 3-(a): 동심원으로 시작). 안쪽·바깥쪽
const MOTIF_SIZE_FRAC := 0.14      # 밴드 반경 대비 모티프 크기
```

기존 `_build_guide`(낱개용)와의 연결: **대체 아니라 병렬.** 슬라이스는 `_build_guide`를 안 부르고 `compose_guide`로 만든 가이드를 새 진입점(`enter_combined_trace`)에 직접 넣는다. 라이브 포지는 계속 `_build_guide`. 두 경로가 같은 static 팩토리(`jin_guide_pts`·`glyph_guide_pts`)를 공유하므로 "셀에서 본 모양 = 손으로 그을 모양" 규율이 자동 유지된다.

🔴 **점 밀도/합성 주의(회귀 자리):** 완성도 = 드러낸 가이드 점 %라, 밴드가 촘촘하면 그 부분만 점이 몰려 채점 유불리가 생긴다. `_densify` 간격을 밴드·진·룬 통일. 동심원 간격(BAND_RADII 0.42·0.68)이 정밀도 tolerance(≈0.05R)보다 훨씬 넓어야 밴드 사이 획이 엉뚱한 밴드로 안 붙는다 — **좌표 실측**(세50 감전연쇄 재발 자리).

🔴 **최소 슬라이스 밖:** 밴드 기하가 진 실루엣을 따라가기(정본 3-(b)) — 동심원으로 먼저, 손으로 그려보고 결정.

### Q4. 채점 — `trace_scorer` 확장 필요?

**불필요 — 무변경.** 이유:
- `set_guide(pts)`가 임의 점열을 받고, `coverage()`(드러낸 %)·`accuracy()`(평균 이탈)·`piece_score()`가 그 위에서 돈다. 합성 가이드 = 그냥 긴 가이드.
- 최소 슬라이스는 **한 조각으로 통째** 긋는다 → 옛 per-piece 잠금(`lock(key,...)`·`get_analysis(open)` 평균)을 **안 쓴다**. `finish` 시 `total = piece_score()` **직접**이 종합 점수다.
- `CONSIDER_FRAC`(0.32R) 이상치 필터는 그대로 유효 — 조립본 전체에서 먼 획만 버린다(밴드 사이는 안 버린다, 위 간격 규율 지키면).

즉 채점기는 low-level API로만 쓰고 코드는 안 연다. 이게 "그리는 재미 = trace_scorer만 연다" 규율과 충돌 없음(규칙을 안 바꾸니까).

### Q5. 발사 해석 (밴드 순서 → effects)

정본이 "순서가 결과를 바꾸나"를 **쏴 보고 결정**으로 남겼다 → 최소 슬라이스는 **가장 단순 = 스탯 스택(플래튼)**.

**플래튼:** 모든 밴드의 (motif × count)를 **기존 8칸 링 하나에 합쳐** 담는다. 발사부(`ring_spell_system`)는 8칸 링을 슬롯별로 전개(발산→탄·응집→기둥·효과탄)하므로 **무변경으로 굴러간다.**
- 예: 밴드0=발산×3, 밴드1=응집×1 → 8칸 = `[radiate,radiate,radiate,gather,-1,-1,-1,-1]` → 착탄 시 발산 탄 3 + 기둥 1.
- 채우기 규칙 = 밴드 순서대로 빈 칸에 라운드로빈, **8칸 상한**(최소 슬라이스는 2고리·작은 count라 안 넘친다).
- 룬 = 기본 fire(assembly.rune=0). motif→탄 효과는 기존 `BOLT_EFFECTS`가 그대로 소비.

빌더 위치 = defs를 아는 **보드/패널**(밴드 id → GlyphRingDef → 8칸). `RingAssembly`(순수)는 안 한다.

🔴 **쏴 보고 결정 → 그때 승격:** "밴드0 파괴를 밴드1 확산 **안**에 넣은 것 vs **밖**에 넣은 것이 달라야" 수식이 된다. 그 순간의 구조 = 플래튼을 걷고 **밴드별 링 배열**(`rings: Array[Array]`)로 발사 — 스키마의 `ring_count`·`rings:Array`가 **이미 다겹을 담게 돼 있다**(RingDesign.rings = Array). 그때 `ring_spell_system._on_ring_cast`가 `rings[0]`만 보던 걸 **밴드 루프**로 넓히고 캐리어가 밴드들을 싣는다. **지금은 하지 않는다** — 최소 슬라이스의 단순함이 실측을 빠르게 한다.

### Q6. UI — 어디서 조립하나

🔴 **기존 `ring_forge_panel`/`ring_book`에 얹지 않고, 병렬 슬라이스 패널을 신설한다.** (권고 — 트레이드오프는 「회귀 위험」 절에서.)

`src/drawing/assembly_slice_panel.gd/.tscn` (신설, Control):
- **왼쪽 = RingBoard 재사용**(합성 가이드를 `enter_combined_trace`로 넣고 통째 트레이스).
- **오른쪽 = 간단 조립 UI:**
  - 진 선택(1종이면 자동 선택 — 최소 슬라이스는 jin_ring2 하나).
  - 밴드 소켓 2칸(선택된 밴드 강조).
  - 보유 문양-고리 목록(클릭 → 선택 밴드에 끼움). **셀 아이콘 = `glyph_ring_pts`를 작게 그린 도안**(기존 진/룬/문양 셀이 모티프를 draw하는 것과 동형 — 도형 플레이스홀더 아님, 절차 가이드선이라 규칙 예외에 해당).
- 하단: `[분석 ▶]`(통째 트레이스 종료 → RingPower로 리포트) → `[마력 주입]`(펑/맺음 = `is_stable` 판정) → `design_committed(assembly)`.

**RingBoard 가산(저위험):**
```gdscript
func enter_combined_trace(guide_pts: PackedVector2Array) -> void   # 단일 가이드 + TraceTarget.COMBINED
func combined_total() -> float                                     # = piece_score() (통째 점수)
```
- 새 `TraceTarget.COMBINED` 값 추가. 기존 stage 경로(JIN/RUNE/GLYPH)는 **불변**(가산일 뿐).
- `_draw`는 이미 가이드+획을 그린다 → COMBINED에서도 그대로. per-piece 잠금 분기만 안 탄다.

재사용 극대화 = 트레이스 느낌(RingBoard+TraceScorer)·발사(EventBus)·점수/펑(RingPower)·맺음 시그널을 전부 공유. 신설은 얇은 조립 UI뿐.

🔴 **최소 슬라이스 밖:** 잉크/종이/특별잉크 팔레트(포지의 경제 UI)·책 펼침 애니 챙김·per-piece 리포트 막대. 슬라이스 리포트는 종합 1줄(점수·위력·등급)이면 충분.

### Q7. 씬 트리·시그널·core 변경

**씬 트리(신설 `assembly_slice_panel.tscn`):**
```
AssemblySlicePanel (Control)         # 슬라이스 조립대 (전체화면 덮음 → mouse_filter 주의, 아래)
├─ Board (RingBoard 재사용)          # 왼쪽: 합성 가이드 통째 트레이스
├─ Assembly (Control)                # 오른쪽: 조립 UI
│  ├─ JinPick (자동/버튼)
│  ├─ BandSockets (밴드 2칸)
│  └─ RingInventory (보유 고리 목록, 셀=모티프 도안 draw)
├─ AnalyzeBtn / InjectBtn (Button)
└─ Report (Control, draw)            # 종합 점수·위력·등급 1줄
```
진입 = `tests/test_assembly_slice.tscn`(F6 시험대식)에 이 패널 + 연습장 허수아비 몇 + `ring_spell_system` 자식. **base.tscn 데스크는 안 바꾼다**(라이브 = 옛 포지 유지).

**시그널 맵:**
- 신규 EventBus 시그널 **0개.** 발사 = 기존 `EventBus.ring_cast_requested(assembly, origin, aim)` 재사용. 맺음 = 패널 로컬 `design_committed(assembly)` → 슬라이스 씬이 `GameState.ring_designs`에 넣거나(장착) 바로 발사에 연결.
- 패널 내부: `board.finished`/피드백은 기존 보드 시그널 재사용(또는 COMBINED용 얇은 콜백).

**🔴 리드가 core에 반영할 것 (에이전트가 정하지 말 것):**
1. **`GlyphRingDef` 스키마 신설**(`src/core/schemas/glyph_ring_def.gd`, class_name) — Q1.
2. **Db 로더+리졸버**: `glyph_rings` 딕셔너리 + `_load_dir("res://data/glyph_rings")` + `all_glyph_rings()`/`get_glyph_ring(id)` (기존 jins/glyphs 로드와 동형).
3. **GameState 시드**: `_seed_starting_unlocks`에 문양-고리 2종 `codex[...] = true` (rune_fire·jin_single과 같은 방식). 획득 = 기존 unlock/codex 규약 재사용(새 인벤토리 축 안 만든다).
4. **(선택) `RingDesign.bands: Array` 한 줄** — 출처 보존용. 발사 무관. 넣을지는 리드 판단.

**dev/에이전트가 하는 것(core 아님):** `compose_guide`/`glyph_ring_pts`/`enter_combined_trace`(ring_board 가산) · 밴드→플래튼 빌더 · 슬라이스 패널·씬 · `data/glyph_rings/*.tres` 2장 · (선택) `data/jin/jin_ring2.tres`.

---

## 데이터 흐름

```
[조립]  진 선택 → RingAssembly._jin
        고리 클릭 → RingAssembly.set_band(i, gr_id)     (밴드 2칸)
                          │
[합성]  패널: 밴드 id들 → Db.get_glyph_ring() → band_defs[]
        RingBoard.compose_guide(jin_shape, fire, band_defs, ctr, ro)
          → jin_guide_pts + rune_guide_verts + glyph_ring_pts×2  (전부 기존 static)
          → PackedVector2Array (한 장의 가이드)
                          │
[트레이스] board.enter_combined_trace(guide) → TraceScorer.set_guide(무변경)
        마우스 획 → add_point → coverage×precision (통째)
                          │
[분석]  board.combined_total() = piece_score()
        RingPower.grade_of / is_stable / power_of      (기존, 무변경)
                          │
[맺음]  패널: 밴드 → 플래튼 8칸 링 빌드 → assembly {jin, rune:fire, rings:[8칸], open, score, ink, size}
        (= 기존 발사 계약과 동형)  → design_committed
                          │
[발사]  EventBus.ring_cast_requested(assembly, muzzle, aim)
        ring_spell_system._on_ring_cast → rings[0] 슬롯별 전개  (무변경)
```

**신규 .tres 스키마** = `GlyphRingDef`(Q1). 그 외 스키마 신설 없음.

---

## 계약 영향 (단일 소스)

- `ring_power.gd`(점수→위력/등급/펑): **무변경**, 그대로 호출.
- `to_assembly()` 발사 계약: **무변경** — 플래튼분이 기존 `rings`에 담긴다. `score`/`ink`/`size`도 그대로 싣는다(안 실으면 조용히 기준 위력, 세션26 함정).
- `Enums.GlyphCode`(발사 계약): **무변경** — `GlyphRingDef.motif`가 이 값을 참조만.
- `trace_scorer.gd`(채점): **무변경** — 규칙 안 바꾸고 긴 가이드만 넘긴다.
- 룬 타입 = `assembly.rune`(하드코딩 금지 규율): fire를 assembly에 실어 보낸다(기본값이라도 dict에 넣는다).
- 펜 보정: 기존 `_pen_correction` 경로 그대로(보드가 GameState에서 읽음) — 슬라이스도 자동 상속.
- **건드리는 단일 소스 = 없음.** 전부 호출 재사용 + 가산.

---

## 회귀 위험 & 완화

| 위험 | 완화 |
|---|---|
| 🔴 **라이브 포지(옛 순차 조립) 회귀** | **병렬 신설로 0.** ring_forge_panel·ring_book·RingAssembly의 옛 경로(`_open`/`_slots`/`_build_guide`/stage)를 **안 건드린다**. RingBoard 변경은 전부 가산(새 static·새 TraceTarget). base.tscn 데스크 무변경. 세36 퀘스트가 순수 오버레이로 회귀 0을 만든 그 방식. |
| 🔴 화면 덮는 슬라이스 패널이 좌클릭을 먹음(세25) | 패널·바닥 Control `mouse_filter=2`(IGNORE) 확인 + **실게임 push_input**으로 발사 도달 확인(헤드리스 못 잡음). 트레이스 보드는 STOP 유지(그려야 하니까). |
| 🔴 밴드 간격 < 정밀도 tolerance → 획이 엉뚱한 밴드로 붙어 채점 뭉갬(세50) | BAND_RADII 간격을 tolerance(≈0.05R)의 수 배로. **좌표 실측** + 손으로 그려 확인. |
| 🔴 `.tres` 한 글자 틀리면 Db가 조용히 스킵(세50 바람룬) | GlyphRingDef 로드 후 **`Db.all_glyph_rings()`가 정확히 2종인지** 테스트로 못박음(파싱 침묵사 그물). Color는 4인자. |
| 🔴 합성 가이드 밀도 도형별 유불리 | `_densify` 간격 통일(진·룬·밴드 같은 step). |
| 헤드리스가 트레이스 "느낌"·"보인다"를 못 잼 | 채점 수치·손맛·합성 가이드 겉보기는 **사용자 F5/MCP 스샷**(정본이 "손에 쥐면 답이 나온다"고 한 그 실측). |

---

## 구현 단계 (takbon-dev/리드에 넘길 순서)

1. **[리드/core]** `GlyphRingDef` 스키마 + Db 로더/리졸버 + GameState 시드 2종. → 헤드리스로 `all_glyph_rings()==2` 확인(파싱 침묵사 그물, 뮤테이션으로 검출력).
2. **[dev]** `data/glyph_rings/gr_radiate5.tres`·`gr_gather3.tres`(예) + (선택) `data/jin/jin_ring2.tres`(밴드 2겹·원). 시드 unlock_id 맞춤.
3. **[dev]** `ring_board.gd` 가산: `compose_guide`·`glyph_ring_pts`·`enter_combined_trace`·`combined_total`·`TraceTarget.COMBINED`. 기존 경로 불변 확인(전 스위트 그린).
4. **[dev]** 밴드→플래튼 8칸 빌더(패널 또는 보드). → 헤드리스로 "발산×3+응집×1 → radiate 3·gather 1" 검증.
5. **[dev+ui]** `assembly_slice_panel.gd/.tscn` + `tests/test_assembly_slice.tscn`(허수아비+spell_system). mouse_filter 주의.
6. **[dev]** 신규 헤드리스 테스트 `tests/test_assembly_slice_auto.gd`: 합성 가이드 점열 계약(진+룬+밴드 클러스터 존재)·통째 채점(coverage/accuracy가 도는지)·플래튼 발사(assembly.rings에 모티프 담김)·`Db.all_glyph_rings()` 로드. 뮤테이션으로 검출력.
7. **[리드]** `--import` → 전 스위트 → **실게임 MCP**: 조립(클릭 소켓)·합성 가이드 렌더·통째로 손 트레이스·발사 도달(push_input)·펑/맺음. 사용자 F5로 손맛·순서 실측.

---

## 검증 포인트 (헤드리스 vs 실게임)

**헤드리스로 잡히는 것:**
- `Db.all_glyph_rings()` 정확히 2종 로드(파싱 침묵사 그물, 뮤테이션).
- `compose_guide` 결과에 진 윤곽+룬+밴드 클러스터가 다 들어갔나(점 수·존재).
- 밴드→플래튼: 특정 밴드 구성 → 기대 8칸 코드 배열.
- 통째 트레이스: 가짜 궤적을 가이드 위로 태워 coverage>0·accuracy>0(계약이 도는지).
- 플래튼 발사가 기존 `_deploy_now`로 실제 탄/기둥 스폰(허수아비 take_hit).
- `to_assembly()`에 score/ink/size가 실렸나.

**실게임(F5/MCP)로만:**
- 🔴 화면 덮는 패널의 좌클릭 발사 도달(push_input — 헤드리스 절대 못 잡음, 세25).
- 소켓 클릭이 밴드에 닿는지(카드 히트).
- 합성 가이드가 "따라 그을 만큼" 보이는지·밴드 겹침·룬 자리.
- 🔴 **통째 트레이스 손맛**(긴 탁본이 재밌나·지겹나 — 정본의 실측 목표) = 사용자 마우스.
- 순서/스탯스택이 충분한가, "밴드 안/밖"이 필요한가(Q5 쏴 보고 결정).

---

## 최소 슬라이스 밖 (명확히 선 긋기)

- 파밍 경제·필드 드롭(문양-고리를 원정에서 줍기) → **아트 필요**(takbon-art 도트). 슬라이스는 시드로 소유. 
- 복합 룬(진 모양=룬 슬롯 다수)·재귀 진(착탄=자식 진 배달) → `scratch_nested_design.md`.
- **순서=수식**(밴드 안/밖이 결과를 바꿈) → 플래튼을 다겹 링 발사로 승격(스키마 이미 준비됨). 쏴 보고.
- 밴드 기하가 진 실루엣 따라가기(3-(b)) → 동심원으로 먼저.
- 잉크/종이/특별잉크 UI·책 펼침 챙김·per-piece 리포트 → 라이브 포지에만.
- 진마다 밴드 수 차등(`JinDef.band_count`) → 최소는 상수 2. 진이 늘 때 데이터화(그때 core 한 줄).
