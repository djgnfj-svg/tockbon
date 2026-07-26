extends Control
## 고리 조립 보드 — forge 왼쪽 페이지에 얹히는 **조립 판**.
##
## 🔴🔴 **per-piece 경로는 세70에 은퇴했다 — 라이브는 COMBINED뿐이다** (세85 ⑨에 실제로 걷어냄).
## 세70 「조립→탁본」이 흐름을 바꿨다: 진·룬·문양 칸을 **하나씩 골라 하나씩 긋고 [다음]으로 잠그는**
## 옛 경로 대신, 조립본을 `compose_guide_paths`로 **한 장의 밑그림에 합성해 통째로** 긋는다.
## 그래서 라이브 진입점은 `enter_combined_trace` **하나**이고 `_trace`는 NONE/COMBINED만 된다.
## 세85까지 옛 갈래(`advance`/`finish`/`select_slot`/`choose_jin`/`choose_rune`/`_build_guide`의
## 진·룬·문양 세 갈래·잠근 조각 렌더·시그널 4종)가 **1673줄 안에 라이브와 섞여 남아** 있었고,
## 그물이 그 죽은 몸을 성실히 통과시켜 「전 스위트 그린」이 라이브의 근거로 과대평가됐다(감사 T2).
## ⚠ **되살리지 마라.** 이건 세83 「그리기 폐지 스위치」(`balance.skip_drawing`)와 **다른 축**이다 —
## 스위치를 false로 되돌리면 돌아오는 건 COMBINED 손 긋기(아래 보존 목록)지 per-piece가 아니다.
## 🔴 **세83 스위치가 되살리는 것 = 절대 지우지 마라**:
##   `enter_combined_trace` · `begin_stroke`/`trace_stroke`/`clear_stroke` ·
##   `coverage`/`accuracy`/`piece_score`(→`combined_total`) · 펜 보정(`_pen_correction`) · 잉크 정산.
##
## 🔴 2026-07-17 세션 22 — **3분할됐다** (예전엔 757줄에 조립·채점·기하·렌더·입력·애니가 다 있었다):
##   • `ring_assembly.gd` — 조립 상태기계 (무엇이 놓였나 · 어느 칸이 열렸나). 순수 데이터
##   • `trace_scorer.gd`  — 손그림 탁본 채점 (완성도·정밀도·분석). 순수 수학
##   • **이 파일**         — 기하(어디에 그리나) + `_draw` + `_gui_input` + 애니. 위 둘에 위임한다
## 🔴 **채점 규칙을 바꿀 땐 `trace_scorer.gd`만 연다** — 그리는 재미가 이 게임의 심장이라
## 그 규칙은 매 세션 바뀐다([[takbon-core-fun-drawing]]). 렌더·입력을 열 필요가 없어야 한다.
##
## 모델·규칙의 정본은 각 파일 머리말에 있다. 여기 남은 건 **화면 위의 일**뿐이다.
##
## 🔴 이 보드는 **선택을 스스로 쥐지 않는다.** 활성 문양·진(JinDef)은 바깥(오른쪽 탭)이
## set_*/choose_*로 주입한다. 오토로드·모듈 의존 없음.
##
## 사용: const RingBoard := preload("res://src/drawing/ring_board.gd")

const RingAssembly := preload("res://src/drawing/ring_assembly.gd")
const TraceScorer := preload("res://src/drawing/trace_scorer.gd")

# ── 조립 계약 재노출 — 바깥(패널·책·테스트)이 RingBoard.STAGE_* 등으로 읽어 왔다 ──
const SLOTS := RingAssembly.SLOTS
const GLYPH_NONE := RingAssembly.GLYPH_NONE
const STAGE_JIN := RingAssembly.STAGE_JIN
const STAGE_RUNE := RingAssembly.STAGE_RUNE
const STAGE_GLYPH := RingAssembly.STAGE_GLYPH
const RUNE_FIRE := RingAssembly.RUNE_FIRE

# ── 어휘 2종 (사용자 확정 2026-07-16) ──
## 🔴 값은 **core가 쥔다**(Enums.GlyphCode = 발사 계약). 여기서 다시 정의하면 언젠가 갈라진다.
const G_GATHER := Enums.GlyphCode.GATHER    # 응집 ← — 안쪽(룬) 방향 화살표
const G_RADIATE := Enums.GlyphCode.RADIATE  # 발산 → — 바깥(진) 방향 화살표
const G_PIERCE := Enums.GlyphCode.PIERCE    # 관통 ↠ — 바깥 방향(발산 계열) + 뚫음 효과 (세션44 B)
const G_HOMING := Enums.GlyphCode.HOMING    # 유도 ∿ — 휘어서 쫓아간다 (세션47)
const G_BOUNCE := Enums.GlyphCode.BOUNCE    # 팅김 ⚡ — 벽에 튕긴다 (세션47)
const G_THRUST := Enums.GlyphCode.THRUST    # 추진 ↑ — 빠르게 날아간다 (세션47)
## 🔴 세79 M1 — **변형형** 문양 2종. 위 6종(전개형)과 계열이 다르다: 착탄에서 스스로 전개하는 게
## 아니라 **안쪽 층의 결과를 받아 바꾸는 연산자**다(계열 판별의 단일 소스 = `GlyphRules.BEHAVIORS`, 즉 그 문양 `.tres`의 `behavior` — 세82).
## 여기(보드)에선 계열을 안 가른다 — 판이 하는 일은 **밑그림 한 갈래**뿐이라 전개형과 똑같이 다룬다.
const G_SPREAD := Enums.GlyphCode.SPREAD    # 확산 ⋔ — 안쪽 결과를 여러 갈래로 편다 (세79)
const G_EXPLODE := Enums.GlyphCode.EXPLODE  # 폭발 ∗ — 안쪽 결과를 한 점에서 터뜨린다 (세79)
const G_CONDENSE := Enums.GlyphCode.CONDENSE # 응축 ◈ — 안쪽 결과를 한 점으로 눌러 담는다 (세82)
## ⚠ **옛 `GLYPH_NAMES` 배열은 세82에 은퇴했다.** 이름의 정본은 `GlyphDef.display_name`이고
## 보드는 주입된 `_glyph_defs`에서 읽는다(`_glyph_color`). 배열이던 시절엔 **길이가 계약**이라
## (`ring_summary`가 그 크기로 카운터를 세웠다) 어휘를 늘릴 때 여기를 같이 안 늘리면 **런타임
## 에러**였고, `set_active_glyph`의 `clampi`가 어휘 밖 코드를 **조용히 눌렀다**. 되살리지 마라.
## ⚠ **`GLYPH_KEYS`는 지웠다** (세션 25). 문양은 오른쪽 셀을 **클릭해서** 고른다 —
## 진·룬 선택이 전부 클릭인데 문양만 키(Q·W)를 광고했다 (사용자: "q w 이런게 아니라
## 똑같이 마우스로 선택하는걸로해줘"). 죽은 상수를 남기면 다음 세션이 키를 되살린다.

# ── 색 (먹·양피지 톤) ──
const RING_LINE := Color(0.42, 0.30, 0.12, 0.55)
const FIRE_HI := Color(0.95, 0.55, 0.15)
## 룬 색 폴백 — RuneDef가 없을 때. 🔴 소비자는 **책의 룬 셀**(`ring_book`)이다(세85 ⑨ 이후
## 판에는 룬 렌더가 없다) — 책이 `RingBoard.RUNE_COLOR`로 부르므로 여기가 그 단일 소스다.
const RUNE_COLOR := Color(0.62, 0.22, 0.12)   # 불
## ⚠ **옛 `GLYPH_COLORS` 배열은 세82에 은퇴했다.** 색의 정본은 `data/glyphs/*.tres`의
## `ui_color` 하나뿐이고, 보드·책이 주입된 defs에서 읽는다(`_glyph_color`).
## 사본이던 시절엔 "책이랑 판이랑 색이 다르네"가 어디서 오는지 못 찾는 위험을 안고 있었다.
const TRACE_INK := Color(0.20, 0.14, 0.09, 0.95)    # 그린 먹선
## 숨은 가이드 (아직 안 드러남). 🔴 세션 25에 0.18 → 0.32: 0.18은 진(큰 원)에서나 보였고
## 문양처럼 작은 밑그림은 **사실상 안 보였다** (사용자: "문양을 선택했을때 밑그림이 그려져야지").
## ⚠ 더 진하게 하면 "숨은 선"이 아니라 그냥 답이 된다 — 따라 그을 만큼만 보여야 한다.
const GUIDE_HIDE := Color(0.42, 0.30, 0.12, 0.32)
const GUIDE_SHOW := Color(0.80, 0.50, 0.16, 0.55)   # 드러난 가이드 강조

const GUIDE_CIRCLE_N := 72            # 진 가이드 밀도 (도형이 뭐든 이 등분 수에 맞춘다 — 아래 주석)

# ── 🔴 진 밑그림 도형의 기하 상수 (세션48) ────────────────────────────────────────
# ⚠ 셋 다 **룬 자리를 남기는 하한**에 걸려 있다. 진은 룬을 담는 **그릇**이라, 도형이 중심을
# 향해 파고들면 안쪽에 그릴 룬(최대 `_outer_radius()*0.16*RUNE_SCALE_MAX` ≈ 0.27R)과 겹친다.
# 가장 깊이 파고드는 도형은 정삼각(내접원 = 반지름의 0.5)이고, 그 아래로 내려가는 값을 주면
# **밑그림끼리 겹쳐도 에러가 안 난다** — 그려 보고서야 안다.
const JIN_ELLIPSE_X := 0.68           # 세로 긴 타원의 가로 반지름 비 (최소 거리 0.68R)
const JIN_FLOWER_PETALS := 6
const JIN_FLOWER_DEPTH := 0.13        # 물결 골의 깊이 = 반지름의 13% (얕게 — 골이 깊으면 룬 자리를 먹는다)
const JIN_LENS_X := 0.60              # 렌즈 허리의 가로 반지름 비 (최소 거리 0.60R)

# ── 진 크기 상한 (종이 등급 — 세71d에 축이 은퇴해 지금은 1.0 고정) ──
## ⚠ 세85 ⑨ 은퇴: 룬·문양 휠 크기 상수(`RUNE_SCALE_*`·`GLYPH_SCALE_*`·`SCALE_STEP`) —
##   조각을 하나씩 그리며 휠로 키우던 per-piece 조작이 통째로 걷혔다.
const JIN_SCALE_MIN := 0.72
const JIN_SCALE_MAX := 1.16

# ── 🔴 문양 화살표의 크기·생김새 (세션 25) ────────────────────────────────────────
# 사용자: *"문양 부분이 좀 별로인게 한 획만 검증하니? 여러획쓸꺼같아서 화살표는"*
#
# **화살촉이 그릴 값어치를 가지려면 붓보다 커야 한다.** 세션 25 초에 실측한 옛 수치
# (0.12 / 0.5 / 0.34)는 이랬다: 판 반지름 118px → 문양 반길이 14px인데 **붓의 드러남
# 반경이 9.4px**(REVEAL_RADIUS_FRAC 0.08)라, 화살촉 점 전체가 몸통 끝에서 **최대 8.6px** —
# 즉 몸통을 긋는 순간 화살촉이 통째로 드러났다. 화살표가 **붓 한 자국 크기**였던 것이다.
# 화살촉은 못 그리는 게 아니라 **그릴 이유가 없었다**.
#
# 새 수치의 근거 (반지름 118px 기준):
#   • 반길이 = 118 × 0.17 ≈ 20px → 전체 40px. 8칸 고리의 이웃 간격은 54px이라 안 겹친다
#   • 깃 벌어짐 = 20 × 0.62 ≈ 12.4px > 9.4px → **몸통을 그어도 깃은 안 드러난다**
#     (깃이 몸통에서 옆으로 이만큼 떨어져 있다 — 이 값이 드러남 반경보다 작으면 옛 문제가 그대로다)
#   • 깃 ~ 머리 거리 = 20 × √(0.5²+0.62²) ≈ 16px > 9.4px → 머리를 찍어도 안 드러난다
# ⚠ 셋 중 하나라도 만지면 `REVEAL_RADIUS_FRAC`(붓)과의 비율을 다시 재라. 테스트가
#   「한 획으로는 문양이 안 끝난다」를 못 박지만, 이유는 여기 적힌 비율이다.
## ⚠ 세85 ⑨ 은퇴: `GLYPH_SIZE_FRAC`(판의 문양 칸 하나를 그릴 때의 크기) — 통째 밑그림에서
## 낱개 모티프 크기는 `MOTIF_SIZE_FRAC`(밴드 반경 비)가 정한다. 아래 두 비율은 **살아 있다**.
const ARROW_BACK_FRAC := 0.5
const ARROW_SIDE_FRAC := 0.62

## ⚠ 세85 ⑨ 은퇴: `SLOT_PICK_FRAC`(판에서 문양 칸을 클릭해 고르는 최대 거리) —
## 통째 밑그림엔 「고를 칸」이 없다(조립 단위가 문양-고리이고 책이 밴드에 끼운다).

## 지금 손으로 그릴 대상. NONE=그릴 것 없음(열린 빈 칸 없음 / 다 그림)
## 🔴 COMBINED (세68 조립→탁본) = 진+룬+밴드 문양-고리를 **한 장의 가이드로 합성**해 통째로
## 긋는 슬라이스 모드. 기존 JIN/RUNE/GLYPH 경로는 손 안 댄다 — COMBINED는 `enter_combined_trace`가
## 가이드를 직접 넣고, `_draw`·`_gui_input`의 per-piece 잠금 분기(_asm.stage()·has_rune)를 안 타
## 자동으로 그리기·입력이 정상 처리된다(가산일 뿐).
enum TraceTarget { NONE, JIN, RUNE, GLYPH, COMBINED }

# ── 🔴 세68 조립→탁본 합성 상수 (연출/레이아웃 → 스크립트 const, 밸런스 아님) ──
const RUNE_GUIDE_FRAC := 0.18        # 합성 가이드에서 룬(중심)의 크기 (판 반지름 비)
## 🔴 세81 M2 융합진 — 룬 자리가 여럿일 때의 배치(손맛/레이아웃 const, 밸런스 아님·시작값·F5 튜닝).
## 자리 1개(일반진·M1까지 전부)는 이 상수를 **안 탄다** → 룬은 중심 하나로 픽셀 무회귀.
const RUNE_SPLIT_FRAC := 0.28        # 융합진 룬 자리를 중심에서 벌리는 거리 (판 반지름 비)
const RUNE_MULTI_SIZE_FRAC := 0.68   # 자리 2개 이상일 때 룬 하나를 이만큼 줄인다 (겹침 방지)
const BAND_RADII := [0.42, 0.68]     # 동심원 밴드 반경 비 목록 (안쪽부터). 진은 앞 band_count개만 쓴다
const MOTIF_SIZE_FRAC := 0.14        # 밴드 반경 대비 문양-고리 낱개 모티프 크기

# ── 🔴 세71c 조립→탁본 빈 층/룬 자리 가이드 (연출값 — 절차 렌더라 도형금지 예외, 손맛 F5) ──
# COMBINED 모드에서만 그린다(per-piece 경로 무변경). band_count만큼 흐린 동심원 + 룬 미선택 시 중앙 마커.
const BAND_GUIDE_COLOR := Color(0.42, 0.30, 0.12, 0.22)   # 빈 층 흐린 동심원 톤 (따라 그을 만큼만, 답 아님)
const BAND_GUIDE_WIDTH := 1.5
## 🔴🔴 세86: 층 선을 **문양 바깥으로 밀어 「띠」를 만든다** (사용자 확정: *"그 선에 문양이 있는 게
## 아니라 선 사이에 있었으면"*). 전엔 선 **하나**가 문양 중심 반경을 지나 **모티프를 가로질렀다** —
## 세81에도 같은 지적이 있었고(*"문양이 선에 걸쳐 지저분하다"*) 그땐 **그릴 때 선을 끄는 것**으로
## 피했다. 이건 그 근본 해결이라 선을 켜 둔 채로 안 겹친다.
## 🔴 여백만 상수다 — 띠 경계는 `band_lane`이 **모티프 크기에서 파생**한다(값을 베끼면 문양 크기를
## 바꿀 때 선이 따라오지 않아 다시 겹친다 = 감사 T5 「좌표 사본」). 판 반지름 비.
const BAND_LANE_PAD := 0.02
const RUNE_SLOT_COLOR := Color(0.42, 0.30, 0.12, 0.28)    # 룬 미선택 자리 마커(중앙 링)
const RUNE_SLOT_WIDTH := 1.5

## 지금 그리는 조각의 점수가 갱신됐다 (실시간) — 패널이 현재 점수를 보여준다.
signal score_changed(score: float)
## ⚠ **`assembly_changed`·`stage_advanced`·`piece_locked`·`finished`는 세85 ⑨에 은퇴했다** —
## 넷 다 per-piece 잠금이 쏘던 신호이고 **src 구독자가 0**이었다(패널 `_ready`가 *"stage machine
## 시그널은 안 구독한다"*고 명시한다). 통째 흐름에 남은 판→패널 신호는 아래 둘뿐이다.
## 🔴 한 획을 뗐다 (마우스 릴리스) — 패널이 **획이 끝난 뒤에** 잉크 팔레트를 다시 그리게 한다.
## 특별잉크가 그리는 도중 소모돼 팔레트가 재빌드되면 활성 잉크가 획 중간에 바뀌기 때문이다.
signal stroke_ended

var _asm := RingAssembly.new()
var _scorer := TraceScorer.new()

# ── 데이터 정의 (세션 13 구조화) — 바깥(패널)이 Db에서 읽어 주입한다. 없으면 const 폴백. ──
var _jin_def: JinDef = null
var _rune_defs: Dictionary = {}         # {Enums.RuneType: RuneDef} — 색·이름 조회 (세션 34: 룬 여러 종)
var _glyph_defs: Array[GlyphDef] = []

## 지금 긋는 획의 색 = 고른 잉크 색 (세션28 — "잉크를 골라 그린다"의 즉각 피드백).
## 잠근 조각은 종류색(진/룬/문양)으로 되므로 이 색은 **그리는 중에만** 보인다. 기본 = 먹.
var _trace_ink := TRACE_INK
## 🔴 고른 잉크 id (세션29) — 색과 달리 **assembly에 실려** 발사·저장까지 간다(등급=데미지).
var _ink_id: StringName = &""
## 🔴 특별잉크 소모·비율 (세션29). 특별잉크로 그으면 획당 소모하고 _special_strokes를 센다.
## 완성 시 비율(_special_strokes / _total_strokes)이 화상 증폭 세기를 정한다.
var _special_ink_used: StringName = &""
var _special_strokes := 0
var _total_strokes := 0
## 🔴 진 확대 상한 (세션29, 종이=규모). 종이 등급이 이 상한을 올린다(set_jin_scale_max). 기본 = 종이 없음.
var _jin_scale_max := JIN_SCALE_MAX
var _cast_t := -1.0
var _cast_dur := 1.3

## 🔴 지금 그릴 대상. 세85 ⑨ 이후 **NONE 아니면 COMBINED뿐**이다(per-piece 은퇴).
var _trace := TraceTarget.NONE
var _drawing := false                   # 마우스 버튼 누른 채 긋는 중
var _stroke_counted := false            # 🔴 이 획을 잉크 정산에 넣었나 (최초 유효점에서 1회만)
var _jin_scale := 1.0                   # 진 규모 (종이 축 — 세71d 은퇴 후 1.0 고정)

# ── 그리기 연출 (세션62 ⓐⓑⓒⓓⓕ — 렌더 전용, 채점·조립 무관) ─────────────────────
# ⚠ 전부 연출값(손맛)이라 스크립트 const다 — 사용자가 F5로 조인다. balance.tres 아님.
const GLOW_WIDTH := 7.0                 # ⓐ 먹선 밑 글로우 패스 폭 (먹선 2.6~2.8px보다 넓게)
const GLOW_ALPHA_DRAWING := 0.12        # ⓐ 그리는 중 획 글로우 알파 (잉크색)
const SPARK_DUR := 0.25                 # ⓑ 반짝임 수명(초)
const SPARK_R0 := 1.2                   # ⓑ 광점 시작 반지름
const SPARK_R1 := 4.5                   # ⓑ 광점 끝 반지름 (커지며 사라진다)
const SPARK_ALPHA := 0.8                # ⓑ 광점 시작 알파 ((1-t)×이 값)
const SPARK_COLOR := Color(1.0, 0.88, 0.55)   # ⓑ 광점 색 (따뜻한 금빛)
## ⚠ 세85 ⑨ 은퇴: ⓒ 착지 펄스·ⓓ 완성 발광의 상수(`PULSE_*`·`FINISH_*`·`GLOW_ALPHA_LOCKED`) —
## 트리거가 per-piece 잠금이라 통째 흐름에선 한 번도 안 떴다(`_draw` 주석 참조).
## ⓕ 붓끝 발광 — 동심원 3장, 바깥(크고 흐림)부터 그려 안쪽(작고 밝음)이 위에 얹힌다.
## ⚠ 무타입 Array인 이유: GDScript는 const에 PackedFloat32Array(...) 생성자를 상수식으로 안 받는다
## (세62 실측 — 파스 에러). 소비처가 float() 캐스트로 받는다.
const BRUSH_GLOW_RADII := [10.0, 6.0, 3.0]
const BRUSH_GLOW_ALPHA := [0.06, 0.14, 0.30]

# ── 🔴 세86 ⑭ 「마법진 완성」 연출 (연출값 = 스크립트 const, 밸런스 아님 — 규칙 §0 예외) ──
## 🔴 **되살린 게 아니라 새로 붙인 훅이다.** 옛 ⓒ 착지 펄스·ⓓ 완성 발광은 트리거가 **per-piece
## 잠금**이라 세70 통째 흐름에선 한 번도 안 떴고 세85 ⑨에 상수째 걷혔다 — 그래서 세70 이후
## **15세션째 「완성」 순간에 판이 아무 말도 안 했다**. 진입점은 공개 `play_finish()` 하나이고
## 패널 `_finish()`가 부른다(파일 끝 주석이 지정한 그 한 줄. per-piece 부활 아님).
## 🔴 **안(룬)에서 바깥(진 윤곽)으로 훑는 게 이 연출의 뜻이다** — 층 순서 = 연산 순서(M1 정본
## `docs/takbon-design/jin_interpretation_design.md`)라, 맺히는 순간에 그 순서를 한 번 더 보여 준다.
## ⚠ **순수 오버레이**다: 입력을 막지 않고(패널이 이미 RESULT로 잠근다) 리포트 표시를 늦추지 않는다.
const FINISH_DUR := 0.85              # 전체 수명(초)
const FINISH_SWEEP_T := 0.60          # 파도가 바깥 테두리에 닿는 정규 시점(0~1)
const FINISH_BAND_W := 0.22           # 파도 뒤 「방금 지나갔다」 꼬리의 두께 (반지름 비)
const FINISH_TAIL := 0.35             # 지나간 조각이 끝까지 남기는 은은한 빛
const FINISH_GOLD := Color(1.0, 0.86, 0.45)
const FINISH_SWEEP_ALPHA := 0.5
const FINISH_GLOW_W := 6.0            # 훑고 지나간 조각의 발광 패스 폭 (먹선 2.6px보다 넓게)
const FINISH_LINE_W := 2.0
const FINISH_POP_T := 0.22            # 룬 자리 팝 고리 한 장의 수명(정규 시간)
const FINISH_POP_SCALE := 2.4         # 팝 고리가 룬 크기의 몇 배까지 퍼지나
const FINISH_FLASH_T := 0.66          # 바깥 테두리 플래시가 시작되는 정규 시점

## ⓑ 렌더 전용 — 가이드 점의 드러남을 지난 프레임과 비교해 false→true 순간을 잡는다.
## 🔴 채점기(`_scorer`)는 `is_revealed(i)` 공개 조회만 쓴다 — 채점 상태를 복사하는 게 아니라
## "언제 드러났나"라는 렌더만의 관심사를 따로 든다. `_reset_reveal_fx`가 가이드와 크기를 맞춘다.
var _was_revealed := PackedByteArray()
var _sparks: Array[Dictionary] = []     # ⓑ {pos: Vector2, t: float} — 광점들

## 🔴 세86 ⑭ 완성 연출 진행도 — **-1 = 안 돎**, 0~1 = 도는 중. `_process`가 민다.
var _finish_t := -1.0
## ⑭ 서브패스별 **정규 반지름**(0=중심 · 1=바깥 테두리) — `play_finish`에서 한 번만 잰다.
## 매 프레임 수백 점을 다시 훑지 않으려는 캐시고, **렌더 전용**이라 채점·발사와 무관하다.
var _finish_radii: PackedFloat32Array = PackedFloat32Array()

## 🔴 세71c 조립→탁본 이음선 제거 — COMBINED 서브패스(진·룬·밴드 각각)를 **별도 폴리라인**으로 그린다.
## 비었으면 옛 동작(flat 가이드를 한 줄로). `enter_combined_trace`의 선택 인자로 들어온다.
## 🔴 채점기(`_scorer`)는 flat만 본다 — 이 멤버는 **렌더 전용**이라 채점·발사와 무관(이음선은 draw 아티팩트).
var _combined_subpaths: Array = []
## 🔴 세81: COMBINED에서 층 구분 동심원을 그릴까 (ASSEMBLE 미리보기=true·DRAW=false). 기본 true=무회귀.
var _combined_show_bands := true
## COMBINED에서 그릴 흐린 동심원(빈 층 자리) 개수 = 진 band_count. 0 = 안 그림(옛 동작).
var _combined_band_count := 0
## 🔴 세84 #22: COMBINED의 **룬 자리 상태** — 자리 순서대로 룬 타입, 음수(RUNE_NONE)=미선택.
## 미선택 자리 마커를 이걸로 그린다. 예전엔 서브패스 **개수를 유추**해서(`size() <= band_count + 1`)
## 「룬이 하나도 없다」를 판정하고 마커를 **중심 하나**만 찍었는데, 세81에 밴드가 모티프마다 append로
## 바뀌면서 그 유추가 깨졌다: 융합진(자리 2·밴드 2)은 고른 직후 3 ≤ 3이라 **엉뚱한 중심**에 마커가
## 뜨고(실제 자리는 좌우 ±`RUNE_SPLIT_FRAC`), 한 자리를 채우면 판별식이 거짓이 되어 **아직 빈 나머지
## 자리의 표식이 통째로 사라졌다**. 개수 유추는 밴드 모티프 수에 오염되므로 **상태를 받는다**.
## 비었으면 = 호출자가 안 넘겼다(1~4인자 옛 호출) → 아래 `_draw`가 옛 유추 폴백을 쓴다(무회귀).
var _combined_runes: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_process(false)
	resized.connect(_on_resized)


## 판 크기가 바뀌면 채점기의 길이 기준을 다시 세운다 (거리 임계값이 전부 반지름 비례다).
## 🔴 세85 ⑨: 예전엔 여기서 `_set_trace`로 가이드를 다시 **만들었는데**, per-piece 가이드 생성기가
## COMBINED를 모르는 탓에 **리사이즈 한 번에 합성 밑그림이 통째로 지워졌다**(빈 가이드로 교체 —
## 에러도 경고도 없다). 합성 가이드의 소유자는 패널(`recompose`)이므로 판이 재생성할 수 없다 —
## 여기서는 길이 기준만 갱신하고, 새 좌표가 필요하면 **패널이 다시 넘긴다**.
func _on_resized() -> void:
	_scorer.set_reference_radius(_outer_radius())
	queue_redraw()


# ─────────────────────────── 단계 조회 (조립 상태기계에 위임) ───────────────────────────

func stage() -> int:
	return _asm.stage()

func has_jin() -> bool:
	return _asm.has_jin()

func has_rune() -> bool:
	return _asm.has_rune()

func get_open() -> Array[int]:
	return _asm.get_open()

func get_rune() -> int:
	return _asm.get_rune()

func filled_count() -> int:
	return _asm.filled_count()

func can_commit() -> bool:
	return _asm.can_commit()

## 🔴 발사 계약 + **손그림 점수**. 조립기(무엇이 놓였나)와 채점기(얼마나 잘 그렸나)를 합치는
## 유일한 자리 — 둘 다 쥔 게 보드뿐이다 (조립기는 채점을 모르고, 채점기는 칸을 모른다).
## `score`가 여기서 안 실리면 발사도 저장도 점수를 알 길이 없다 (세션 22까지가 그랬다).
## ⚠ 그리는 도중에 불리면 그때까지의 부분 점수다 — 소비자는 맺을 때만 읽는다.
func get_assembly() -> Dictionary:
	var a := _asm.get_assembly()
	a["score"] = float(get_analysis().get("total", 0.0))
	a["ink"] = _ink_id      # 🔴 고른 잉크(세션29) — 등급 배수가 발사·저장에 실린다
	# 🔴 특별잉크(화상 증폭)·크기(종이=규모)도 여기서 싣는다 (세션29) — score를 싣는 그 자리.
	a["special_ink"] = _special_ink_used
	a["special_ratio"] = float(_special_strokes) / float(maxi(_total_strokes, 1))
	a["size"] = _jin_scale
	return a


# ─────────────────── 🔴 세68 조립→탁본: 합성 가이드 통째 트레이스 ───────────────────
## 합성된 조립본 가이드를 통째로 긋는 모드로 들어간다 — **라이브 유일 진입점**이다(세85 ⑨:
## per-piece 가이드 생성기 `_set_trace`/`_build_guide`가 은퇴해 이제 대안이 없다).
## 조립 상태가 바뀔 때마다 패널(`ring_forge_panel.recompose`)이 부른다.
## 🔴 세71c 선택 인자 확장 — `flat`은 지금처럼 scorer에(채점 무변경). `subpaths`가 오면 `_draw`가
## flat 한 줄 대신 **서브패스별 별도 폴리라인**으로 그린다(이음선 제거). `band_count`는 빈 층 흐린
## 동심원 개수. **둘 다 옛 기본값이면(subpaths=[]·band_count=0) 옛 동작 그대로** — 슬라이스 패널·
## test의 1인자 호출이 무변경으로 산다(회귀 그물). subpaths flatten = flat이라는 계약은 **호출자(패널)가**
## 한 소스(compose_guide_paths)에서 만들어 지킨다(制약 flat=flatten(subpaths)).
## 🔴 세84 #22 `runes` — `compose_guide_paths`에 넘긴 **그 자리별 룬 목록을 그대로** 한 번 더 넘긴다
## (자리 순서 유지·음수=미선택). 미선택 자리 마커를 개수 유추가 아니라 **상태**로 그리기 위한 것이고,
## 채점·발사와는 무관한 **렌더 전용**이다(`_combined_runes` 주석 참조). ⚠ 안 넘기면(옛 4인자 호출)
## 마커가 세81에 깨진 옛 유추 폴백으로 떨어진다 — 융합진을 쓰는 호출자는 **반드시 넘겨라**.
func enter_combined_trace(flat: PackedVector2Array, subpaths := [], band_count := 0,
		show_band_lines := true, runes := []) -> void:
	_trace = TraceTarget.COMBINED
	_scorer.set_reference_radius(_outer_radius())
	_scorer.set_correction(_pen_correction())
	_scorer.set_guide(flat)
	_combined_subpaths = subpaths
	_combined_band_count = band_count
	# 🔴 스냅샷(duplicate)이다 — 호출자의 배열을 물면 룬을 골라도 recompose를 안 부른 경우에 마커만
	# 몰래 갱신돼 「가이드는 옛것, 마커는 새것」이 된다. 마커는 가이드와 같은 시점을 봐야 한다.
	_combined_runes = runes.duplicate()
	# 🔴 세81: 층 구분 동심원을 그릴까 — 조립 미리보기(ASSEMBLE)엔 켜 층 구조를 보여주고, **실제로
	# 그릴 때(DRAW)는 끈다**(사용자 지적: 문양이 층 나눈 선에 걸쳐 지저분하다). 층은 문양 반경으로 읽힌다.
	_combined_show_bands = show_band_lines
	_reset_reveal_fx()   # ⓑ 옛 가이드의 유령 반짝임을 남기지 않는다
	queue_redraw()


## 합성 가이드를 통째로 그은 종합 점수 (완성도×정밀도). 슬라이스 리포트·발사가 이 값을 쓴다.
## per-piece 평균(get_analysis)이 아니라 한 조각 점수 — 조립본을 한 번에 그은 것이라 통째다.
func combined_total() -> float:
	return _scorer.piece_score()


## ⓑ 드러남 반짝임의 렌더 상태를 지금 가이드에 맞춰 비운다 (렌더 위생 — 채점 무관).
## 가이드가 바뀌거나(enter_combined_trace) 먹선을 지울 때(clear_stroke·clear_all) 부른다.
func _reset_reveal_fx() -> void:
	_sparks.clear()
	_was_revealed = PackedByteArray()
	_was_revealed.resize(_scorer.guide_points().size())   # resize는 0으로 채운다


## 장착한 펜의 보정도. 오토로드가 없는 환경(순수 단위 테스트)에서도 죽지 않게 0으로 폴백한다.
func _pen_correction() -> float:
	var gs := get_node_or_null(^"/root/GameState")
	return float(gs.stroke_correction()) if gs != null else 0.0


## ⚠ **`_build_guide`(대상별 per-piece 가이드 생성기)는 세85 ⑨에 은퇴했다.** 진·룬·문양 세 갈래를
## 각각 따로 긋던 시절의 함수인데, 세70부터 밑그림은 `compose_guide_paths`가 **한 장으로 합성**해
## 패널이 `enter_combined_trace`로 통째로 넣는다. 세 갈래의 기하는 사라지지 않았다 —
## 진 = `jin_guide_pts` · 룬 = `rune_subpath` · 문양 = `glyph_guide_pts`(전부 static·public)를
## **합성 쪽이 그대로 부른다**. 즉 「셀에서 본 모양 = 손으로 그을 모양」 규약은 그대로다.
## 🔴 룬 갈래는 삭제만 한 게 아니다 — 여기 있던 12등분 루프가 `compose_guide_paths`의 사본이었고
## **크기 식이 이미 갈라져 있었다**(0.16R 고정 vs 0.18R + 다중 자리 축소, 감사 #26).
## 산 쪽(합성)을 `rune_subpath`로 뽑아 단일 소스로 만들었다.


## 🔴 **문양 코드별 밑그림** (세션 47 — "새 문양 = 여기 한 갈래"). `rune_guide_verts`와 같은 규약이다.
##
## 왜 갈랐나: 세션 44까지 이 갈래는 `inward` 하나만 보고 화살표 **방향**만 뒤집었다. 새 문양
## (유도·팅김·추진)은 전부 `inward = false`라 발산·관통과 **똑같은 화살표**가 떠, 6개 문양이
## 색·라벨만 다른 4지선다가 될 참이었다 — memory `takbon-glyph-design-principle`이 경고하는 그것.
## **그리는 궤적이 달라야 손이 문양을 기억한다.**
##
## 공통 규율:
##   • **한붓그리기** — 가이드가 한 줄이어야 채점기가 이탈을 잰다 (손은 여러 획으로 나눠 그어도 된다).
##   • 꺾쇠·깃은 기준점 q로 **되돌아와서** 다음 구간으로 이어진다 — 끊기면 그 구간이 유령 선이 된다.
##   • 획수는 화살표(몸통+꺾쇠 2)를 넘지 않는다 — 넘으면 못 그린다.
##   • ⚠ 총 길이는 이웃 칸 간격(반지름 118px 기준 54px)을 넘지 마라. 추진의 1.1배(≈44px)가 상한선이다.
##
## 모양과 이유 — **손으로 긋는 궤적**이 서로 달라야 한다(눈으로만 다른 건 라벨과 같다):
##   응집← / 발산→  화살표. 방향만 반대 (**세션 25 그대로** — 여기만 점 생성이 verbatim이다)
##   관통↠         꺾쇠 **2개**(중간·머리)가 겹친 이중 화살표 — 뚫고 나간다
##   유도∿         S자 물결(사인) — 꺾이지 않고 **휘어서** 쫓아간다. 유일하게 꺾쇠가 없다
##   팅김⚡        지그재그 — 벽에 튕기는 궤적 그대로. 유일하게 **날카롭게 되꺾인다**
##   추진↑         긴 직선 + 뒤쪽 **가로 깃 2개**(속도선). 깃이 축과 **직각**이라 관통의 꺾쇠와 손이 다르다
##   확산⋔         줄기 하나가 **뒤쪽 뿌리 한 점**에서 앞으로 3갈래로 갈라지는 부채(삼지창). 세79
##                 손 = "뿌리를 축으로 앞쪽으로 펴 나간다". 갈래가 **앞으로** 뻗어 화살촉·관통 꺾쇠
##                 (머리에서 **뒤로** 접히는 깃)와 반대이고, 팅김 지그재그처럼 전진하지 않고
##                 **한 뿌리로 되돌아온다**. 의미(안쪽 결과를 여러 갈래로 편다)가 궤적 그대로다.
##   폭발∗         중심에서 사방으로 뻗는 **방사 살 5개**. 세79 — 유일하게 **한 점(중심)을 반복해 지나며**,
##                 유일하게 **dir 축이 아니라 사방으로** 퍼진다(중심이 곧 p라 앞뒤 대칭). 나머지 7종이
##                 전부 dir 방향 진행형이라 손이 확실히 갈린다. 확산과도 갈린다: 확산은 앞쪽 부채,
##                 폭발은 360°(뒤쪽에도 살이 간다) — 🔴 이 둘이 손으로 안 갈리면 층 순서가 안 읽힌다.
## 🔴 **static · public인 이유** (세션47): 책의 문양 셀 아이콘(`ring_book._draw_glyph_icon`)이
## **이 함수를 그대로 부른다**. 예전엔 책이 자기만의 화살표를 직접 그려서, 판의 밑그림을 6종으로
## 갈라 놔도 **고를 때 보는 셀은 전부 같은 화살표**였다 — 고르는 순간에 구분이 안 되면
## 밑그림을 가른 의미가 절반 날아간다. `ring_power`가 리포트와 발사에 같은 함수를 주는 것과
## 같은 이유다: **복사해 두면 한쪽만 고쳐도 아무도 못 알아채고 갈라진다.**
## ⚠ 그래서 인스턴스 상태를 쓰면 안 된다 — 파라미터와 클래스 상수만 본다.
static func glyph_guide_pts(code: int, p: Vector2, outward: Vector2, sz: float) -> PackedVector2Array:
	var dir := -outward if code == G_GATHER else outward   # 응집만 안쪽(룬), 나머지는 바깥
	var side_u := dir.orthogonal()
	match code:
		G_PIERCE:
			# 몸통을 지나며 중간·머리에서 각각 꺾쇠. 꺾쇠는 q로 되돌아와 다음 구간으로 이어진다.
			var back := -dir * (sz * ARROW_BACK_FRAC)
			# ⚠ 0.9배까지만 좁힌다 — 깃 벌어짐 20×0.62×0.9 ≈ 11.2px가 붓의 드러남 반경 9.4px보다
			# 커야 **몸통을 그어도 꺾쇠가 안 드러난다**(파일 머리 ARROW_SIDE_FRAC 주석의 그 비율).
			# 더 좁히면 세션 25의 "화살촉이 그릴 이유가 없다" 문제가 관통에서 되살아난다.
			var side := side_u * (sz * ARROW_SIDE_FRAC * 0.9)
			var v := PackedVector2Array([p - dir * sz])
			for q in [p, p + dir * sz]:
				v.append_array(PackedVector2Array([q, q + back + side, q, q + back - side, q]))
			return _densify(v, sz * 0.24)
		G_HOMING:
			# 사인 한 주기 = S자. 꺾쇠가 없어 한 획으로 이어지지만 **궤적이 휘어** 화살표와 안 겹친다.
			var pts := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0 * 2.0 - 1.0
				pts.append(p + dir * (t * sz) + side_u * (sin(t * PI) * sz * 0.6))
			return pts
		G_BOUNCE:
			var w := sz * 0.55
			return _densify(PackedVector2Array([
				p - dir * sz,
				p - dir * (sz * 0.5) + side_u * w,
				p - side_u * w,
				p + dir * (sz * 0.5) + side_u * w,
				p + dir * sz]), sz * 0.24)
		G_THRUST:
			# 긴 직선을 머리→꼬리로 긋고, **지나는 길에** 가로 깃 2개 (되돌아가는 구간이 없다).
			var lng := sz * 1.1
			var bar := side_u * (sz * 0.5)
			var v2 := PackedVector2Array([p + dir * lng])
			for q in [p - dir * (sz * 0.45), p - dir * lng]:
				v2.append_array(PackedVector2Array([q, q + bar, q - bar, q]))
			return _densify(v2, sz * 0.24)
		G_SPREAD:
			# 뒤쪽 뿌리로 짧은 줄기가 들어오고, 거기서 앞으로 3갈래(±FAN·정면)가 펴진다.
			# 갈래마다 뿌리로 **되돌아와** 다음 갈래로 이어진다(꺾쇠 규약과 같은 한붓그리기).
			# ⚠ 갈래 벌어짐 = 뿌리에서 d만큼 나간 지점에서 이웃 갈래와 2·d·sin(FAN) ≈ 1.16d 떨어진다 —
			# 붓 드러남 반경(≈9.4px)을 넘으려면 d ≳ 8px. 즉 **뿌리 근처만** 서로 드러나고
			# 갈래 몸통(26px 중 바깥 18px)은 각각 그어야 드러난다.
			var fan := 0.62                       # 갈래 벌어짐(rad) ≈ 35.5°
			var arm := sz * 1.3                   # 뿌리→갈래 끝
			var root := p - dir * (sz * 0.7)      # 뿌리 = 뒤쪽 한 점 (여기가 손의 축이다)
			var v3 := PackedVector2Array([p - dir * (sz * 1.1)])   # 줄기 꼬리 (추진과 같은 1.1sz 상한)
			for a in [-fan, 0.0, fan]:
				v3.append_array(PackedVector2Array([root, root + dir.rotated(float(a)) * arm]))
			return _densify(v3, sz * 0.24)
		G_EXPLODE:
			# 중심(p)에서 사방 5방향으로 뻗는 살. 살마다 중심으로 되돌아오므로 **한 점을 5번 지난다** —
			# 이 파일의 어떤 갈래도 안 하는 손이다. 이웃 살과 72°라 2·d·sin36° ≈ 1.18d 떨어진다.
			# ⚠ 연속 살이 72°(중심에서 108° 꺾임)라 **중심을 곧게 통과하는 구간이 없다** —
			# 180°짜리(살 짝수 개, 마주보는 순서)로 만들면 두 살이 한 직선이 돼 손이 뭉개진다.
			var spokes := 5
			var ray := sz * 0.95
			var v4 := PackedVector2Array()
			for i in spokes:
				if i > 0:
					v4.append(p)
				v4.append(p + dir.rotated(TAU * float(i) / float(spokes)) * ray)
			return _densify(v4, sz * 0.24)
		G_CONDENSE:
			# 🔴 **안으로 감기는 나선** (세82). 바깥에서 시작해 반지름이 줄며 중심으로 빨려 든다 —
			# 의미(안쪽 마법을 한 점으로 눌러 담는다)가 손 궤적 그대로다.
			# 🔴 **폭발과 손이 갈리는 게 이 모양의 존재 이유다**: 폭발은 중심을 **5번 지나는** 직선
			# 살이고, 응축은 중심을 **한 번만** 지나며 **꺾임 없이 계속 휜다**. 폭발 살을 방향만
			# 뒤집는 안은 각하했다 — 손이 지나는 자리가 거의 같아 두 문양이 안 갈린다(세79 기준).
			# ⚠ 유도(사인 한 주기 S자)와도 갈린다: 저건 축을 따라 **전진**하고 이건 **감긴다**
			#   (반지름이 단조 감소 = 같은 자리를 두 번 지나지 않으면서 회전한다).
			# ⚠ extent = 2·sz로 추진(2.2·sz)보다 작아 이웃 칸 간격 안에 든다.
			var turns := 1.25                     # 감는 바퀴 수 — 1보다 커야 "감긴다"로 읽힌다
			var v5 := PackedVector2Array()
			for i in 29:
				var t := float(i) / 28.0          # 0(바깥) → 1(중심)
				var ang := t * TAU * turns
				var rad := sz * (1.0 - t * 0.88)  # 완전히 0으로 보내지 않는다 (끝점이 뭉개진다)
				v5.append(p + (dir * cos(ang) + side_u * sin(ang)) * rad)
			return v5
	# 응집←/발산→ — 🔴 **세션 25 원본 그대로**. 점 생성 순서가 곧 관측점이다:
	# `test_ring_trace_auto._test_arrowhead_must_be_drawn`이 "앞 9점 = 몸통"으로 읽는다.
	var pts2 := PackedVector2Array()
	var tail := p - dir * sz
	var head := p + dir * sz
	for t in 9:                                   # 몸통
		pts2.append(tail.lerp(head, float(t) / 8.0))
	# 화살촉 — **한붓그리기**(머리→왼깃→머리→오른깃)라 가이드 한 줄로 화살표가 된다.
	# 손은 몇 획으로 나눠 그어도 된다 (세션 25에 획 누적을 고쳤다).
	var back2 := -dir * (sz * ARROW_BACK_FRAC)
	var side2 := side_u * (sz * ARROW_SIDE_FRAC)
	for w2 in [head + back2 + side2, head + back2 - side2]:
		for t in range(1, 5):
			pts2.append(head.lerp(w2, float(t) / 4.0))
		for t in range(1, 5):
			pts2.append(w2.lerp(head, float(t) / 4.0))
	return pts2


## 폴리라인 꼭짓점을 `step`px 간격으로 촘촘히 채운다 (마지막 꼭짓점 포함).
## 🔴 이 간격이 곧 **채점 밀도**다 — 채점기는 점 하나하나의 드러남으로 완성도를 잰다.
## 화살표 몸통 간격(반길이 20px에 9점 ≈ 5px)에 맞췄다. 성기면 붓 한 자국에 여러 점이 통째로
## 드러나 "그릴 이유가 없는" 구간이 생긴다 — 세션 25 화살촉 사건이 정확히 그 원리였다.
static func _densify(verts: PackedVector2Array, step: float) -> PackedVector2Array:
	if verts.size() < 2:
		return verts
	var out := PackedVector2Array()
	for i in verts.size() - 1:
		var a := verts[i]
		var b := verts[i + 1]
		var n := maxi(1, int(ceil(a.distance_to(b) / maxf(step, 0.5))))
		for t in n:
			out.append(a.lerp(b, float(t) / float(n)))
	out.append(verts[verts.size() - 1])
	return out


# ─────────────────── 🔴 세68 조립→탁본: 조립본 → 한 장의 합성 가이드 ───────────────────
## 조립본(진 + 룬 + 밴드별 문양-고리)을 **한 장의 따라긋기 가이드**로 합성한다.
## 🔴 기존 static 팩토리만 불러 이어 붙인다 — **새 기하 규칙 0**. 그래서 "셀에서 본 모양 =
## 손으로 그을 모양" 규율이 자동 유지된다(문양·진 셀이 같은 함수를 쓰는 것과 같은 이유).
## band_defs[i] = 그 밴드의 GlyphRingDef(or null). ro = 판 바깥 반지름(_outer_radius()).
## ⚠ static·인스턴스 상태 금지 — 헤드리스 테스트가 이 함수를 관측점으로 쓴다.
## 🔴 세81 M2 융합진 룬 자리 좌표 (static·순수 = 헤드리스 관측점). 룬을 어디에 그리(고 감싸)나.
## count ≤ 1 = **[중심]** — M1까지 룬은 늘 중심 하나였다. 🔴 이 경로가 곧 룬 1개 무회귀의 보장이다
##   (아래 compose는 size도 자리 1개면 안 줄여 픽셀 동일).
## count 2 = 중심 좌우로 `RUNE_SPLIT_FRAC` 벌린 두 점. count ≥ 3 = 위(−90°)부터 균등 원배치.
static func rune_slot_positions(count: int, ctr: Vector2, ro: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 1:
		out.append(ctr)
		return out
	if count == 2:
		var dx := ro * RUNE_SPLIT_FRAC
		out.append(ctr + Vector2(-dx, 0.0))
		out.append(ctr + Vector2(dx, 0.0))
		return out
	var r := ro * RUNE_SPLIT_FRAC
	for i in count:
		var a := TAU * float(i) / float(count) - PI / 2.0
		out.append(ctr + Vector2.from_angle(a) * r)
	return out


## 🔴 합성 가이드에서 **룬 하나의 크기**. `compose_guide_paths`(그을 것)와 미선택 자리 마커(볼 것)가
## 반드시 같은 값을 써야 「본 것 = 그을 것」이 유지된다 — 식을 두 벌로 두면 자리 2개일 때 마커만
## 0.18R로 커져 실제 룬(0.1224R)과 어긋난다. static·순수 = 헤드리스 관측점.
static func combined_rune_size(ro: float, slot_count: int) -> float:
	var s := ro * RUNE_GUIDE_FRAC
	if slot_count >= 2:
		s *= RUNE_MULTI_SIZE_FRAC   # 자리 여럿이면 겹치지 않게 룬을 줄인다 (1개면 무변경)
	return s


## 🔴 룬 하나의 **밑그림 점열** — 꼭짓점(`rune_guide_verts`)을 변마다 12등분해 이어 붙인 폴리라인.
## 🔴 세85 ⑨(감사 #26): 이 루프가 **두 벌**이었다 — per-piece `_build_guide`의 RUNE 갈래(401-405)와
## `compose_guide_paths`(639-643). 624줄 주석이 *"…와 **똑같이**"*라고 사본임을 자백했고,
## **크기 식은 이미 갈라져 있었다**(per-piece `_outer_radius()*0.16*_rune_scale`, 다중 자리 축소 없음
## vs 합성 `combined_rune_size`=0.18R + 자리 2개면 ×0.68). 그대로 뒀으면 융합진에서 **「본 것 ≠ 그을
## 것」**(미리보기 0.1224R · 실제 0.16R)이 됐다 — 세13·25 탁본 정체성이 깨지는 자리다.
## per-piece 갈래를 걷으며 **산 쪽(합성)을 이 함수로 뽑았다.** 크기 단일 소스는 `combined_rune_size`.
## ⚠ `if seg >= 0` 가드가 계약이다 — 꼭짓점이 1개 이하인 룬에서 마지막 점을 중복 추가하지 않는다.
## ⚠ static·인스턴스 상태 금지(관측점) — 헤드리스가 이 점열을 그대로 잰다.
static func rune_subpath(rune_type: int, at: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var v := rune_guide_verts(rune_type, at, size)
	var seg := v.size() - 1
	for e in seg:
		for t in 12:
			pts.append(v[e].lerp(v[e + 1], float(t) / 12.0))
	if seg >= 0:
		pts.append(v[seg])
	return pts


## 🔴 세84 #22 — **아직 룬을 안 고른 자리**의 마커 좌표·반지름. `runes`는 자리 순서대로의 룬 타입
## 목록이고 음수(RUNE_NONE)가 미선택이다. 반환 = `[{at: Vector2, r: float}, …]`(빈 배열 = 다 골랐다).
## 🔴 좌표는 `rune_slot_positions`, 크기는 `combined_rune_size` **정본을 그대로 부른다** — 각도·반지름을
## 베끼면 판 마커와 책 셀(`ring_book.jin_icon_paths`도 같은 두 함수를 쓴다)·HUD가 조용히 어긋난다
## (세48이 진 윤곽에서, 세83 뮤테이션이 셀 룬 자리에서 각각 밟은 자리다).
## ⚠ static·public인 이유 = 마커는 `draw_arc` 렌더라 헤드리스가 못 보지만 **이 좌표는 잴 수 있다**.
static func empty_rune_slot_marks(runes: Array, ctr: Vector2, ro: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if runes.is_empty():
		return out
	var pos := rune_slot_positions(runes.size(), ctr, ro)
	var r := combined_rune_size(ro, runes.size())
	for i in runes.size():
		if int(runes[i]) < 0:       # 🔴 음수 판정 — 타 모듈의 RUNE_NONE 상수를 참조하지 않는다
			out.append({"at": pos[i], "r": r})
	return out


## 🔴 세81 M2: `rune_type: int` → `runes: Array`(int 배열, 자리 순서). 빈 배열 = 룬 미선택(진 윤곽만).
## 목록의 음수(RUNE_NONE) 자리는 서브패스를 건너뛴다 — 자리 개수는 유지해 **위치가 안 흔들리게**.
## 자리 1개면 옛 단일 룬과 점 단위 동일(rune_slot_positions·size 무변경).
static func compose_guide(jin_shape: int, runes: Array, band_defs: Array,
		ctr: Vector2, ro: float) -> PackedVector2Array:
	# 🔴 세71c: **`compose_guide_paths`를 flatten한 단일 소스에서 파생**한다(制약③). flat과 subpaths를
	# 따로 만들면 언젠가 갈라진다 — 채점(flat)과 렌더(subpaths)가 반드시 같은 점열을 봐야 한다.
	# 시그니처·반환 점열은 리팩터 전과 **점 단위로 동일**(scratch_golden.txt로 대조).
	var out := PackedVector2Array()
	for sub in compose_guide_paths(jin_shape, runes, band_defs, ctr, ro):
		out.append_array(sub)
	return out


## 🔴 세71c 조립본을 **조각별 서브패스 배열**로 합성한다 — 이음선 제거·빈 층 렌더의 단일 소스.
## 반환 = `[진 윤곽, (룬), 밴드0, 밴드1…]`. 룬 센티넬(rune_type < 0)이면 룬 서브패스를 **생략**한다.
## 🔴 **null 밴드 = 빈 서브패스로 자리만 남긴다**(制약①) — flatten엔 무영향(빈 배열)이면서 보드가
## "빈 층 자리"를 셀 수 있게 한다. `compose_guide`(flat)가 이걸 flatten해 채점에 넣는다(둘이 한 소스).
## ⚠ static·인스턴스 상태 금지 — 헤드리스 테스트가 관측점으로 쓴다. band_defs[i] = GlyphRingDef(or null).
## 🔴 재구현 시 갈라지는 세 자리(制約②): ⓐ 룬 점열은 **`rune_subpath` 정본을 부른다**(변마다 12등분
## + `if seg >= 0` 가드 — 세85 ⑨에 사본을 청산했다. 여기서 다시 인라인하면 사본이 부활한다) ·
## ⓑ 밴드 frac은 **band_defs 원본 인덱스 i**로 BAND_RADII[i](null 건너뛴 압축 카운터 금지) · ⓒ
## flat = flatten(subpaths)(위 compose_guide). 이 세 자리를 바꾸면 골든과 어긋난다.
static func compose_guide_paths(jin_shape: int, runes: Array, band_defs: Array,
		ctr: Vector2, ro: float) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	# ① 진 윤곽 (바깥 닫힌 도형)
	paths.append(jin_guide_pts(jin_shape, ctr, ro))
	# ② 룬(들) — 점열은 `rune_subpath` **단일 소스**가 만든다(세85 ⑨: 12등분 루프 사본 청산, 감사 #26).
	# 🔴 세81 M2: 자리별 목록. 각 룬은 **자기 서브패스** — count 1이면 서브패스 하나(옛 단일 룬 무회귀),
	# count ≥ 2면 갈래마다 별도 폴리라인(이음선 없음). 음수(RUNE_NONE) 자리는 서브패스를 건너뛴다
	# (센티넬 = 그 자리 룬 미선택). 자리 좌표는 `rune_slot_positions`가 준다(위치 단일 소스).
	var rpos := rune_slot_positions(runes.size(), ctr, ro)
	# 🔴 세84 #22: 크기도 `combined_rune_size` 정본을 부른다 — 미선택 자리 마커가 같은 함수를 써야
	# 「마커 크기 = 실제로 그을 룬 크기」다(식이 두 벌이던 자리를 합쳤다. 값은 비트 동일).
	var rsz := combined_rune_size(ro, runes.size())
	for ri in runes.size():
		var rt := int(runes[ri])
		if rt < 0:
			continue                  # 미선택 자리 — 서브패스 생략 (옛 센티넬 -1과 같은 뜻)
		paths.append(rune_subpath(rt, rpos[ri], rsz))
	# ③ 밴드별 문양-고리 — 동심원 반경에 count번 깐다. null 밴드 = 빈 서브패스(자리만).
	for i in band_defs.size():
		var gr: GlyphRingDef = band_defs[i] as GlyphRingDef
		if gr == null:
			paths.append(PackedVector2Array())   # 빈 층 자리 — flatten엔 무영향, 렌더는 흐린 동심원
			continue
		var frac := float(BAND_RADII[i]) if i < BAND_RADII.size() \
			else float(BAND_RADII[BAND_RADII.size() - 1])
		# 🔴 세81: 밴드의 **각 모티프를 별도 서브패스**로 append한다(이음선/거미줄 방지 — 한 밴드를
		# 서브패스 하나로 묶으면 draw_polyline이 모티프 끝→다음 모티프 첫 점을 이어 링을 가로지르는
		# 선이 생긴다, 사용자 지적). flat은 flatten(subpaths)라 **점열 무변경**(골든 보존).
		for sub in glyph_ring_subpaths(gr, ctr, ro * frac):
			paths.append(sub)
	return paths


## 🔴 문양-고리 한 장을 밴드 둘레에 `gr.count`번 깐다 → **모티프마다 별도 서브패스** (세81 이음선 방지).
## 각 인스턴스는 기존 `glyph_guide_pts` 재사용. 회전 규약 = `slot_angle`과 같다(TAU·i/n − PI/2,
## 위=0 시계방향). 바깥방향(outward) = 발산 방향. 렌더가 서브패스마다 폴리라인을 따로 그어 모티프가 안 이어진다.
static func glyph_ring_subpaths(gr: GlyphRingDef, ctr: Vector2, band_r: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if gr == null:
		return out
	var n := maxi(gr.count, 1)
	for i in n:
		var a := TAU * float(i) / float(n) - PI / 2.0
		var p := ctr + Vector2.from_angle(a) * band_r
		var outward := Vector2.from_angle(a)
		out.append(glyph_guide_pts(gr.motif, p, outward, band_r * MOTIF_SIZE_FRAC))
	return out


## 🔴 층 i의 **띠 경계 두 반지름** = `Vector2(안쪽선, 바깥선)` (세86). 문양은 그 사이에 들어앉는다.
##
## 🔴 **모티프 크기에서 파생한다** — 반지름을 상수로 박지 않는 이유: `MOTIF_SIZE_FRAC`을 키우면
## 문양이 커지는데 선이 제자리면 **다시 선을 가로지른다**(전에 지저분했던 그 상태로 돌아간다).
## 파생이면 문양이 커질 때 띠도 같이 벌어진다.
## ⚠ **문양 중심 반경(`BAND_RADII`)은 안 건드린다** — 그건 발사 층 계약이고 저장된 도안·채점 골든이
## 그 값에 걸려 있다(세79 M1). 이 함수는 **렌더 전용**이라 계약을 스치지 않는다.
## static·순수 = 헤드리스 관측점(겹침 여부를 관계식으로 잴 수 있다 — 렌더는 못 봐도 이건 잰다).
static func band_lane(band_index: int, ro: float) -> Vector2:
	var i := clampi(band_index, 0, BAND_RADII.size() - 1)
	var band_r := ro * float(BAND_RADII[i])
	# 모티프 반경 = `glyph_ring_subpaths`가 문양 한 장을 그릴 때 쓰는 크기 그대로(사본 아님).
	var half := band_r * MOTIF_SIZE_FRAC + ro * BAND_LANE_PAD
	return Vector2(maxf(band_r - half, 0.0), band_r + half)


## 🔴🔴 층 i의 **안쪽 경계선** 반지름 — 판에 실제로 그리는 선은 이것뿐이다 (세86, 사용자 확정:
## *"선이 너무 많음"*). 층마다 띠 경계 둘을 다 그렸더니 2층 진에서 원이 **5개**가 됐다.
##
## 🔴 경계는 **띠와 띠 사이의 빈 곳**에 놓는다 — 선이 「층을 가르는 칸막이」가 되고, 문양은 어느
## 선도 안 밟는다. 층 n개 = 선 n개(+진 윤곽) = 2층이면 **3개**.
##   i == 0 → 중심 룬과 층0 띠 사이 · i > 0 → 층 i-1 띠 바깥과 층 i 띠 안쪽 사이.
## ⚠ **가장 바깥 경계는 안 그린다** — 진 윤곽이 이미 그 자리의 칸막이다(그리면 선이 도로 는다).
## static·순수 = 헤드리스 관측점(「선이 문양을 안 밟는다」를 관계식으로 잰다).
static func band_edge(band_index: int, ro: float) -> float:
	var i := clampi(band_index, 0, BAND_RADII.size() - 1)
	var lane := band_lane(i, ro)
	var inner_side := combined_rune_size(ro, 1) if i == 0 else band_lane(i - 1, ro).y
	return (inner_side + lane.x) * 0.5


## 밴드 문양-고리를 **이어붙인 한 점열** (flatten이 필요한 호출자용 — flat 채점은 compose_guide가
## compose_guide_paths를 flatten하므로 이걸 안 거친다). 🔴 렌더는 위 `glyph_ring_subpaths`를 써야
## 모티프가 안 이어진다 — 이 concat을 draw_polyline에 바로 넘기면 거미줄이 된다(세81).
static func glyph_ring_pts(gr: GlyphRingDef, ctr: Vector2, band_r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for sub in glyph_ring_subpaths(gr, ctr, band_r):
		out.append_array(sub)
	return out


## 🔴 밴드별 (motif × count)를 **층 배열**로 만든다 — 세79 M1 「진별 해석」의 발사 계약.
## 반환 = `[[8칸], [8칸], …]` (밴드 순서 = 안→밖 = **연산 순서**). 발사부(`ring_spell_system.
## _deploy_now`)가 이 순서대로 층을 훑으며 전개형은 명령을 만들고 변형형은 안쪽 결과를 감싼다.
##
## 🔴 **이게 `flatten_bands`를 대체한다.** 플래튼은 밴드들을 8칸 하나로 뭉개 **순서를 버렸다** —
## `폭발(확산(불))`과 `확산(폭발(불))`이 구분이 안 됐다(라운드로빈이라 배치만 달랐다).
## ⚠ 회귀: 밴드가 **하나뿐이면** 층 1개 = 플래튼 결과와 **점 단위로 같다**(둘 다 칸 0부터 count개).
## 지금 살아있는 진은 전부 `band_count = 1`이라 저장된 도안의 발사가 픽셀 동일하다.
## ⚠ static·인스턴스 상태 금지(관측점) — 헤드리스 테스트가 이 함수를 그물로 쓴다.
static func layer_rings(band_defs: Array) -> Array:
	var out: Array = []
	for gr_v in band_defs:
		var ring: Array = []
		for k in SLOTS:
			ring.append(GLYPH_NONE)
		var gr: GlyphRingDef = gr_v as GlyphRingDef
		if gr != null:
			# 🔴 칸 0부터 count개 — 발산 계열은 **칸 인덱스가 곧 탄 각도**다(세44 계약).
			# 빈 밴드도 층 자리를 지킨다(순서가 밴드 인덱스라 건너뛰면 감쌈 깊이가 밀린다).
			for i in mini(maxi(gr.count, 1), SLOTS):
				ring[i] = int(gr.motif)
		out.append(ring)
	# 🔴 밴드 0개(진 미선택)여도 **빈 층 하나는 돌려준다** — 옛 `flatten_bands([])`가 `[-1×8]` 한 줄을
	# 줬기 때문이다. 빈 배열을 주면 `ring_spell_system._on_ring_cast`의 `rings.is_empty()`에서 발사가
	# 통째로 접혀 **"빈 진도 날아가 몸으로 때린다"**(ring_carrier.gd 계약)가 조용히 깨진다.
	if out.is_empty():
		var empty: Array = []
		for k in SLOTS:
			empty.append(GLYPH_NONE)
		out.append(empty)
	return out


## 🔴 밴드별 (motif × count)를 **기존 8칸 링 하나로 플래튼**한다 (세68 발사 계약 — 발사부 무변경).
## ⚠ **세79에 발사 경로는 `layer_rings`로 갔다** — 층 순서를 버리기 때문이다.
## 🔴 **세85 ⑪: 유일한 라이브 호출자였던 F6 대조군(`assembly_slice_panel`)이 은퇴했다** —
## 이제 src 호출자가 **0**이고, 남은 소비자는 `test_jin_layers_auto[2]`의 회귀 그물 하나뿐이다:
## 「밴드가 하나뿐이면 층0 == flatten」이 **저장된 옛 도안의 발사가 안 바뀐다**의 증명이라
## 그 기준자로 살려 둔다. **새 코드에서 부르지 마라**(순서가 조용히 사라진다).
## 밴드 순서대로 빈 칸을 채우고(band0 먼저), 8칸 상한(넘치면 버림). 빈 칸 = GLYPH_NONE(-1).
## 예: 발산(1)×3 + 응집(0)×3 → [1,1,1,0,0,0,-1,-1]. 발사부(ring_spell_system)가 이 8칸을
## 슬롯별로 전개한다(발산→탄·응집→기둥). defs를 아는 자리(패널·테스트)가 부른다 — 순수 데이터
## RingAssembly는 Db를 몰라 여기 못 둔다. ⚠ static·인스턴스 상태 금지(관측점).
static func flatten_bands(band_defs: Array) -> Array:
	var ring: Array = []
	for k in SLOTS:
		ring.append(GLYPH_NONE)
	var idx := 0
	for gr_v in band_defs:
		var gr: GlyphRingDef = gr_v as GlyphRingDef
		if gr == null:
			continue
		var n := maxi(gr.count, 1)
		for i in n:
			if idx >= SLOTS:
				return ring
			ring[idx] = int(gr.motif)
			idx += 1
	return ring


## 🔴 **진 종류별 밑그림** (세션 48 — "새 진 = 여기 한 갈래"). `rune_guide_verts`·`glyph_guide_pts`와
## 같은 규약이다. 세션 44~47엔 진만 이 처리를 못 받아 8종이 **전부 같은 원**이었다.
##
## 공통 규율 (사용자 확정: *"진의 궤적은 원처럼 닫힌 도형이어야 함. 그 안에 룬이 들어가야 해서"*):
##   • 🔴 **반드시 닫힌다** — 마지막 점이 첫 점으로 돌아온다(`_closed`가 그 한 점을 책임진다).
##     진은 룬을 담는 **그릇**이라 터진 도형은 그릇이 아니다.
##   • 🔴 **중심을 비워 둔다** — 안에 룬이 들어갈 자리가 남아야 한다. 가장 깊이 파고드는 게
##     정삼각(내접원 0.5R)이고 룬은 최대 0.27R이라, 그 아래로 내려가는 도형을 새로 넣지 마라.
##   • 🔴 **점 밀도를 맞춘다** — 완성도는 "가이드 점 중 몇 %를 드러냈나"라 점 수가 도형마다 크게
##     다르면 **채점이 도형마다 유불리**를 갖는다. 전부 `GUIDE_CIRCLE_N` 등분(≈73점)에 맞춘다.
## 🔴 **static · public인 이유**: 책의 진 셀 아이콘(`ring_book.jin_icon_paths`)이 이 함수를 그대로
## 부른다 — 세션 47 문양과 같은 이유다. **셀에서 본 모양 = 손으로 그을 모양**이 구조적으로 못 갈라진다.
static func jin_guide_pts(shape: int, ctr: Vector2, r: float) -> PackedVector2Array:
	match shape:
		Enums.JinShape.TRIANGLE:
			return _jin_poly(3, ctr, r)
		Enums.JinShape.OCTAGON:
			return _jin_poly(8, ctr, r)
		Enums.JinShape.PENTAGON:
			return _jin_poly(5, ctr, r)
		Enums.JinShape.DIAMOND:
			return _jin_poly(4, ctr, r)
		Enums.JinShape.ELLIPSE:
			var e := PackedVector2Array()
			for i in GUIDE_CIRCLE_N:
				var a := TAU * float(i) / float(GUIDE_CIRCLE_N)
				e.append(ctr + Vector2(cos(a) * r * JIN_ELLIPSE_X, sin(a) * r))
			return _closed(e)
		Enums.JinShape.FLOWER:
			# 물결 원 — 반지름이 꽃잎 수만큼 오르내린다. 골은 얕게(0.87R) 파 룬 자리를 안 먹는다.
			var f := PackedVector2Array()
			for i in GUIDE_CIRCLE_N:
				var a2 := TAU * float(i) / float(GUIDE_CIRCLE_N)
				var rr := r * (1.0 + JIN_FLOWER_DEPTH * cos(float(JIN_FLOWER_PETALS) * a2))
				f.append(ctr + Vector2.from_angle(a2) * rr)
			return _closed(f)
		Enums.JinShape.LENS:
			return _jin_lens(ctr, r)
	# CIRCLE(0) · 모르는 도형 = 원. ⚠ 폴백이 크래시가 아니라 원인 게 계약이다 (진이 늘어도 안 죽는다).
	var c := PackedVector2Array()
	for i in GUIDE_CIRCLE_N:
		c.append(ctr + Vector2.from_angle(TAU * float(i) / float(GUIDE_CIRCLE_N)) * r)
	return _closed(c)


## 정n각형 둘레 (꼭짓점 하나가 위). 변마다 등분해 **총 점 수를 원과 맞춘다** — 밀도 규율.
static func _jin_poly(sides: int, ctr: Vector2, r: float) -> PackedVector2Array:
	var per := maxi(1, ceili(float(GUIDE_CIRCLE_N) / float(sides)))
	var pts := PackedVector2Array()
	for e in sides:
		var v0 := ctr + Vector2.from_angle(TAU * float(e) / float(sides) - PI / 2.0) * r
		var v1 := ctr + Vector2.from_angle(TAU * float(e + 1) / float(sides) - PI / 2.0) * r
		for t in per:
			pts.append(v0.lerp(v1, float(t) / float(per)))
	return _closed(pts)


## 렌즈 — 위·아래 꼭짓점(0,∓r)에서 만나고 좌우로 볼록한 **원호 2개**. 타원과 달리 꼭짓점이 뾰족해
## 손이 거기서 한 번 꺾인다 (같은 "둥근 것"인 ELLIPSE와 궤적이 갈리는 지점).
static func _jin_lens(ctr: Vector2, r: float) -> PackedVector2Array:
	var w := r * JIN_LENS_X                       # 허리 반폭
	var rad := (r * r + w * w) / (2.0 * w)        # (0,±r)과 (w,0)을 지나는 원의 반지름
	var cx := w - rad                             # 오른쪽 호의 중심 x (음수 — 중심 왼쪽에 있다)
	var phi := atan2(r, -cx)                      # 꼭짓점까지의 호 반각
	var half := maxi(2, GUIDE_CIRCLE_N / 2)
	var pts := PackedVector2Array()
	for i in half:                                # 오른쪽 호: 위 꼭짓점 → 허리 → 아래 꼭짓점
		var a := -phi + 2.0 * phi * float(i) / float(half)
		pts.append(ctr + Vector2(cx + rad * cos(a), rad * sin(a)))
	for i in half:                                # 왼쪽 호: 좌우 대칭으로 되돌아온다
		var a2 := phi - 2.0 * phi * float(i) / float(half)
		pts.append(ctr + Vector2(-(cx + rad * cos(a2)), rad * sin(a2)))
	return _closed(pts)


## 🔴 점열을 **닫는다** — 첫 점을 끝에 한 번 더. 여기가 "진 = 그릇" 계약의 유일한 집행 지점이다
## (각 도형이 저마다 닫으면 하나가 빠져도 아무도 못 알아챈다).
static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	if not pts.is_empty():
		pts.append(pts[0])
	return pts


## 🔴 진 셀의 8점 칸 다이어그램 (세션60 — 진이 칸을 연다). 칸 k(0=위, 시계방향)마다
## `{pos: Vector2, open: bool}`을 담아 SLOTS개를 돌려준다 — 책의 진 셀이 그대로 그린다.
## slots = 그 진이 여는 칸들(JinDef.glyph_slots). c = 중심 · s = 점을 얹을 원주 반지름.
## ⚠ 점은 **원주 고정**이다 — 진 윤곽이 삼각·타원이어도 판의 칸은 원 위에 있으니
## 다이어그램도 원 기준이 맞다(판과 읽는 방식 일치).
## 🔴 **static · public인 이유**: `jin_guide_pts`·`glyph_guide_pts`와 같은 규약 —
## `_draw_*` 안에 계산을 두면 헤드리스가 못 잰다(관측점). 인스턴스 상태 금지.
static func jin_slot_dots(slots: Array, c: Vector2, s: float) -> Array:
	var out: Array = []
	for k in SLOTS:
		out.append({
			"pos": c + Vector2.from_angle(slot_angle(k)) * s,
			"open": k in slots,
		})
	return out


## 🔴 칸 k의 각도 — **"칸 0=위, 시계방향" 규약의 단일 소스** (세션60 리뷰). 책 다이어그램
## (`jin_slot_dots`)·HUD 슬롯·Tab 마법진 탭·문양-고리 배치(`glyph_ring_subpaths`)가 이 규약을
## 공유한다 — 한쪽에 식을 베끼면 규약이 바뀔 때 조용히 어긋난다. 착탄 전개 각도
## (ring_spell_system의 `TAU*k/8`)와도 같은 회전 방향이다(기준 0이 진행 방향이냐 위냐만 다르다).
static func slot_angle(k: int) -> float:
	return TAU * float(k) / float(SLOTS) - PI / 2.0


## 🔴 룬 종류별 밑그림 꼭짓점 (닫힌 다각형, 마지막=처음). 세션 34 — "새 룬 = 여기 한 갈래".
## 모양은 손으로 구분해 그릴 수 있게 서로 다른 방향/꼭짓점 수를 준다:
##   불 △ 위 꼭짓점 · 물 ▽ 아래 꼭짓점(고이는 방향) · 바람 ◇ 마름모(사방으로 돈다)
##   번개 ⚡ 닫힌 지그재그(꺾임이 많다) · 흙 □ 축에 나란한 사각(무겁게 앉는다) · 풀 🍃 잎사귀(뾰족한 위 끝 + 넓은 밑동)
##
## 🔴 공통 규율 (세션 49에 3→6종으로 늘리며 명문화 — 진 `jin_guide_pts`와 같은 이유):
##   • **반드시 닫힌다** — 마지막 점 = 첫 점. 룬은 진 안에 앉는 **하나의 인장**이라 터진 획은 룬이 아니다.
##   • **서로 다른 손 궤적을 준다** — 색만 다르면 "6지선다"가 된다(memory `takbon-glyph-design-principle`).
##     그래서 흙(축 나란한 사각)과 바람(45° 돌린 마름모)처럼 **같은 변 수라도 꺾이는 자리가 다르게** 둔다.
##   • **꼭짓점 수를 3~7에 둔다** — 호출부(`_build_guide`)가 변마다 12등분하므로 꼭짓점이 많으면
##     그 룬만 가이드 점이 촘촘해져 **완성도 채점이 룬마다 유불리**를 갖는다.
## 🔴 **static · public인 이유**: 책의 룬 셀 아이콘(`ring_book._draw_rune_icon`)이 이 함수를 그대로
## 부른다 — 진(`jin_guide_pts`)·문양(`glyph_guide_pts`)과 같은 규약이다. 세션 48까지 책이 같은 모양을
## **따로 베껴** 갖고 있어, 여기만 고치면 "셀에서 본 모양"과 "손으로 그을 모양"이 갈라질 수 있었다.
static func rune_guide_verts(rune_type: int, ctr: Vector2, s: float) -> PackedVector2Array:
	match rune_type:
		Enums.RuneType.WATER:
			return PackedVector2Array([
				ctr + Vector2(-s * 0.87, -s * 0.5), ctr + Vector2(s * 0.87, -s * 0.5),
				ctr + Vector2(0, s), ctr + Vector2(-s * 0.87, -s * 0.5)])
		Enums.RuneType.WIND:
			return PackedVector2Array([
				ctr + Vector2(0, -s), ctr + Vector2(s, 0),
				ctr + Vector2(0, s), ctr + Vector2(-s, 0), ctr + Vector2(0, -s)])
		Enums.RuneType.BOLT:
			# 닫힌 번개 — 위 끝에서 왼쪽으로 꺾여 내려왔다 아래 끝에서 오른쪽으로 되꺾인다.
			# 손이 **네 번 되돌아가는** 유일한 룬이라 다른 다각형과 궤적이 확실히 갈린다.
			return PackedVector2Array([
				ctr + Vector2(s * 0.22, -s), ctr + Vector2(-s * 0.62, s * 0.06),
				ctr + Vector2(-s * 0.06, s * 0.06), ctr + Vector2(-s * 0.22, s),
				ctr + Vector2(s * 0.62, -s * 0.06), ctr + Vector2(s * 0.06, -s * 0.06),
				ctr + Vector2(s * 0.22, -s)])
		Enums.RuneType.EARTH:
			# 축에 나란한 정사각 — 바람 ◇와 변 수는 같지만 꼭짓점이 45° 어긋나 손 궤적이 다르다.
			# 위·아래 변이 수평이라 "땅에 앉은" 무게가 읽힌다.
			return PackedVector2Array([
				ctr + Vector2(-s * 0.8, -s * 0.8), ctr + Vector2(s * 0.8, -s * 0.8),
				ctr + Vector2(s * 0.8, s * 0.8), ctr + Vector2(-s * 0.8, s * 0.8),
				ctr + Vector2(-s * 0.8, -s * 0.8)])
		Enums.RuneType.GRASS:
			# 잎사귀 — 위로 길게 뽑은 오각. 뾰족한 끝(불 △와 달리 어깨가 벌어져 있다) + 넓은 밑동.
			return PackedVector2Array([
				ctr + Vector2(0, -s * 1.15), ctr + Vector2(s * 0.72, -s * 0.15),
				ctr + Vector2(s * 0.45, s * 0.85), ctr + Vector2(-s * 0.45, s * 0.85),
				ctr + Vector2(-s * 0.72, -s * 0.15), ctr + Vector2(0, -s * 1.15)])
		_:
			# 불(FIRE=0) · 모르는 룬 = △. ⚠ 폴백이 크래시가 아니라 삼각형인 게 계약이다.
			return PackedVector2Array([
				ctr + Vector2(0, -s), ctr + Vector2(s * 0.87, s * 0.5),
				ctr + Vector2(-s * 0.87, s * 0.5), ctr + Vector2(0, -s)])


## 지금 그릴 대상·현재 점수 조회 (바깥이 안내문·점수 표시에 쓴다).
## ⚠ 세85 ⑨ 은퇴: `trace_slot()`(그리던 문양 칸) — 통째 밑그림엔 칸이 없다.
func is_tracing() -> bool:
	return _trace != TraceTarget.NONE

## 지금 마우스로 획을 긋는 중인가 — 패널이 잉크 팔레트 재빌드를 획 중간에 안 하려고 읽는다.
func is_drawing() -> bool:
	return _drawing

func coverage() -> float:
	return _scorer.coverage()

func accuracy() -> float:
	return _scorer.accuracy()

func piece_score() -> float:
	return _scorer.piece_score()

## 지금 가이드 점들 (로컬 좌표) — 헤드리스 테스트가 이 위로 가짜 문지름을 태운다.
func guide_points() -> PackedVector2Array:
	return _scorer.guide_points()


## 지금 조각의 먹선 **획들**. 획이 따로 보관되는지가 계약이다 (세션 25) — 이어 붙이면
## 펜을 뗀 구간이 선이 돼 화살표가 삼각형이 된다. 테스트의 관측점.
func trace_strokes() -> Array[PackedVector2Array]:
	return _scorer.strokes()

## ⚠ 세85 ⑨ 은퇴: `locked_count()`(잠긴 조각 수) — 채점기의 조각 잠금과 함께 걷혔다.


# ─────────────────────────── 문지르기 (채점기에 위임) ───────────────────────────

## 🔴 새 획을 시작한다 (마우스 누름) — **앞서 그은 획은 남는다** (세션 25).
## 세션 24까지 여기서 전부 지웠다. "마음에 들 때까지 다시 그린다"는 의도였지만, 그 의도가
## **한 조각 = 한 획**을 강제해 화살표(선+화살촉)처럼 획이 여러 개인 모양을 못 그리게 했다
## (사용자: "획단위로 초기화되서 화살표를 그리가가 어렵네?"). 다시 그리기는 이제 `clear_stroke`다.
func begin_stroke() -> void:
	_scorer.begin_stroke()
	_stroke_counted = false   # 잉크 정산은 이 획의 최초 유효점에서 한다 (trace_stroke)


## 🔴 이 획을 잉크 정산에 넣는다 — **최초 유효점이 찍혔을 때만** 부른다 (세션31 수정, trace_stroke).
## 예전엔 begin_stroke가 무조건 불러, 가이드에서 먼 **빈 클릭(먹선이 안 남는 클릭)도** 특별잉크를
## 태우고 분모(_total_strokes)를 키웠다 — 붉은잉크가 눈에 안 보이게 샜다.
## 특별잉크면 획당 소모하고 비율에 적립한다. 다 떨어졌으면 소모·적립 없이 계속 그린다
## (기본잉크처럼 — 그만큼 비율=효과가 낮아진다). 기본잉크는 무한이라 소모가 없다.
## ⚠ **총 획수(_total_strokes)는 유효 획마다 센다** — 비율의 분모다. _trace가 NONE이면 안 센다.
func _note_stroke_ink() -> void:
	if _trace == TraceTarget.NONE:
		return
	_total_strokes += 1
	var gs := get_node_or_null(^"/root/GameState")
	var db := get_node_or_null(^"/root/Db")
	if gs == null or db == null or _ink_id == &"":
		return
	if not db.ink_is_special(_ink_id):
		return   # 기본잉크 = 무한, 소모·적립 없음
	var per := int(gs.balance.special_ink_per_stroke)
	if gs.get_count(_ink_id) < per:
		return   # 특별잉크 바닥 = 소모·적립 없이 진행 (비율만 낮아진다)
	gs.remove_item(_ink_id, per)
	_special_strokes += 1
	_special_ink_used = _ink_id


## 지금 조각의 먹선을 **전부 지운다** (다시 그리기 — 우클릭). 점수도 0으로 돌아간다.
func clear_stroke() -> void:
	_scorer.reset_stroke()
	_reset_reveal_fx()   # ⓑ 드러남이 처음부터다 — 옛 반짝임·비교 기록을 같이 지운다
	queue_redraw()
	score_changed.emit(0.0)


## 한 점을 그었다 (드래그). public — 헤드리스 테스트가 가짜 궤적을 태운다.
func trace_stroke(local_pos: Vector2) -> void:
	if _trace == TraceTarget.NONE:
		return
	if not _scorer.add_point(local_pos):
		return   # 가이드에서 너무 멀다 = 이 조각과 무관
	# 🔴 이 획에서 처음 유효점이 찍힌 순간에만 잉크를 정산한다 — 빈 클릭이 잉크를 태우지 않게.
	if not _stroke_counted:
		_stroke_counted = true
		_note_stroke_ink()
	# ⓑ 이 문지름으로 **새로 드러난** 가이드 점 → 반짝임 적립. 채점기는 is_revealed 조회만 —
	# 가이드 ≤150점이라 유효점마다 훑어도 싸다. 크기가 어긋나면(이론상 없음) 조용히 건너뛴다.
	var guide := _scorer.guide_points()
	if _was_revealed.size() == guide.size():
		var sparked := false
		for i in guide.size():
			if _was_revealed[i] == 0 and _scorer.is_revealed(i):
				_was_revealed[i] = 1
				_sparks.append({"pos": guide[i], "t": 0.0})
				sparked = true
		if sparked:
			set_process(true)
	queue_redraw()
	score_changed.emit(_scorer.piece_score())


# ─────────────────────────── 분석 리포트 ───────────────────────────

## ⚠ **세85 ⑨ 은퇴 목록** — 여기 있던 per-piece 진행이 통째로 걷혔다(파일 머리 참조):
##   `advance()`([다음]으로 한 조각 잠그고 다음 단계로) · `finish()`(그리던 칸까지 잠그고 맺기) ·
##   `select_slot()`/`_commit_glyph_slot()`/`_nearest_open_slot()`(문양 칸 클릭 편집) ·
##   `_lock_current()`/`_piece_key()`(조각 점수 잠금). 전부 src 호출자 0이었다.
## 통째 흐름의 대응물 = 패널의 `_on_start_draw` → `_finish` → `_on_inject`이고, 점수는 잠그지 않고
## `combined_total()`(현재 획의 통째 점수)을 그때그때 읽는다.

## 마법진 분석 리포트 — 종합 + 등급 (채점기가 계산, 열린 칸은 조립기가 안다).
## 🔴 **죽은 코드가 아니다** — `get_assembly()`가 `a["score"]`에 쓰고, 그 `get_assembly()`를 라이브
## `ring_forge_panel.build_assembly()`가 특별잉크 집계 창구로 부른다(감사 「손대지 말 것」 1번).
## ⚠ per-piece 잠금이 은퇴해 조각별 점수(`_scores`)는 늘 비어 있다 → total 0 = **폐지 전에도 통째
## 흐름에서 이미 그랬다**(COMBINED는 조각을 안 잠근다). 실제 점수는 패널 `_score_now()`가 쥔다.
func get_analysis() -> Dictionary:
	return _scorer.get_analysis(_asm.get_open())


# ─────────────────────────── 데이터 주입 (Db → 보드) ───────────────────────────

## 진·룬·문양 정의를 주입한다 (색·이름을 여기서 읽는다). 슬롯은 여전히 int code로 저장 —
## 발사 계약(assembly의 정수)은 그대로다. defs 없으면 아래 색 헬퍼가 const로 폴백한다.
func set_defs(jin: JinDef, runes: Array, glyph_defs: Array) -> void:
	_jin_def = jin
	_rune_defs.clear()
	for r in runes:
		var rd := r as RuneDef
		if rd:
			_rune_defs[rd.type] = rd
	_glyph_defs.clear()
	for d in glyph_defs:
		var gd := d as GlyphDef
		if gd:
			_glyph_defs.append(gd)
	queue_redraw()


## ⚠ 세85 ⑨ 은퇴: `_jin_color()`/`_rune_color()` — **잠근 조각 먹선의 종류색**을 내던 자리다.
## 진·룬 색의 라이브 소비자는 책 셀(`ring_book`)이고 거기는 자기 `set_defs`로 받는다.

func _glyph_def_by_code(code: int) -> GlyphDef:
	for d in _glyph_defs:
		if d.code == code:
			return d
	return null

## 🔴 세82: 색의 **정본은 `GlyphDef.ui_color`**다(옛 `GLYPH_COLORS` 배열 은퇴).
## 보드는 오토로드를 안 보므로 패널이 주입한 `_glyph_defs`에서 읽는다(`ring_forge_panel:384`).
## ⚠ defs 주입 **전**(부팅 직후·일부 테스트)엔 defs가 비어 있다 — 그땐 중립 먹선으로 떨어진다.
## 옛 배열 폴백을 되살리지 마라: 그게 `clampi`와 만나 **8을 7로 눌러 응축을 폭발색으로** 그리던 자리다.
func _glyph_color(code: int) -> Color:
	var d := _glyph_def_by_code(code)
	return d.ui_color if d else RING_LINE


## 🔴 **헤드리스 관측점** (세82) — 문양 색의 정본이 `.tres`인지 재는 자리. 테스트가 `_glyph_defs`
## 같은 private을 더듬으면 리팩터 때 **조용히 죽는다**(세22·23에 실제로 두 번 겪었다).
## ⚠ 세85 ⑨ 은퇴: `active_glyph()` — 짝인 `set_active_glyph()`가 걷히며 같이 나갔다.
func glyph_color_of(code: int) -> Color:
	return _glyph_color(code)


## ⚠ 세85 ⑨ 은퇴: `_glyph_name()` — 유일 소비자가 `ring_summary()`였다. 이름의 정본은 여전히
## `GlyphDef.display_name`이고, 라이브 요약은 패널 `_compose_summary()`가 Db에서 직접 읽는다.


# ─────────────────────────── 바깥이 주입하는 선택 ───────────────────────────

## ⚠ **세85 ⑨ 은퇴 목록** (전부 src 호출자 0 — 파일 머리 참조):
##   `set_active_glyph()`/`active_glyph()`(지금 그릴 문양 코드) — 통째 흐름에선 문양을 낱개로 고르지
##     않는다. 조립 단위가 **문양-고리**(`GlyphRingDef` = motif × count)이고 책이 밴드에 끼운다.
##     ⚠ 옛 `clampi`가 어휘 밖 코드를 조용히 누르던 함정은 배열(`GLYPH_NAMES`)이 세82에 은퇴하며
##     구조적으로 사라졌고, 지금 그 자리는 `test_glyph_data_auto[1]`(전 9값 Db 로드)이 지킨다.
##   `choose_jin()`/`choose_rune()`/`jin_idx()`/`rune_idx()` — 진·룬 선택의 정본은 **패널**이다
##     (`_sel_jin`·`_sel_runes` → `recompose()` → `enter_combined_trace`). 판은 점열만 받는다.
##   `set_open_slots()` — 「진이 칸을 연다」축이 세85 ⑦에 은퇴했다(`JinDef.glyph_slots`).
##   `ring_summary()` — `_asm`에 놓인 문양을 세던 요약. 라이브 요약은 패널 `_compose_summary()`다.

## 지금 긋는 획의 색 = 고른 잉크 색 (세션28). 패널이 잉크를 고를 때마다 부른다.
func set_trace_ink(c: Color) -> void:
	_trace_ink = c
	queue_redraw()


## 🔴 고른 잉크 id (세션29) — get_assembly가 실어 발사·저장에 등급 배수를 태운다.
## ⚠ clear_all은 이걸 안 지운다 — 잉크는 판 기하가 아니라 **지속되는 선택**이다
## (색도 그대로 남는다). 새로 그려도 골라 둔 잉크가 유지된다.
func set_ink(id: StringName) -> void:
	_ink_id = id


## 🔴 진 확대 상한 (세션29, 종이=규모) — 종이 등급이 정한다.
## ⚠ **종이 축은 세71d에 은퇴했다** — 패널이 진 규모를 1.0으로 굳혀(`_size_mult`) 이 함수의 src
## 호출자는 0이다. `get_assembly()["size"]`가 아직 이 값을 싣기에 남겨 뒀다(스키마 계약).
## 🔴 세85 ⑨: 옛 본문의 「밑그림 다시 세우기」 한 줄은 per-piece 가이드 생성기(`_set_trace`)를
## 부르던 것이라 같이 걷었다 — 통째 밑그림의 크기는 패널이 `recompose()`로 정한다.
func set_jin_scale_max(v: float) -> void:
	_jin_scale_max = maxf(v, JIN_SCALE_MIN)
	_jin_scale = minf(_jin_scale, _jin_scale_max)
	queue_redraw()


## 🔴 판을 비운다 — 조립 상태·채점·연출 타이머를 처음으로 돌린다.
## ⚠ 여기서 가이드를 **다시 세우지 않는다**(세85 ⑨): 합성 밑그림의 소유자는 패널이고, 라이브
## `open()`·`clear_board()`가 이 호출 **직후 `recompose()`**로 COMBINED를 다시 넣는다.
## 예전엔 `_refresh_trace()`가 per-piece 진 가이드를 세워 그 사이에 잠깐 다른 가이드가 서 있었다.
func clear_all() -> void:
	_asm.clear()
	_scorer.clear()
	_trace = TraceTarget.NONE            # 빈 판 = 그릴 것 없음 (패널의 recompose가 다시 넣는다)
	_combined_subpaths = []
	_combined_band_count = 0
	_combined_runes = []
	_jin_scale = 1.0
	_reset_reveal_fx()                   # ⓑ 반짝임도 — 명시가 계약이다
	# ⑭ 완성 연출도 멈춘다 — 판을 비웠는데(펑·[다시]) 옛 마법진의 금빛이 계속 도는 건 거짓말이다.
	_finish_t = -1.0
	_finish_radii = PackedFloat32Array()
	# 🔴 잉크 소모·비율은 새 진마다 리셋 (세션29). ⚠ _ink_id·_jin_scale_max(종이 상한)은 **안** 지운다 —
	# 잉크·종이 선택은 지속된다(다시 그려도 유지). 여기서 지우는 건 "이번 진에 얼마나 썼나"뿐.
	_special_ink_used = &""
	_special_strokes = 0
	_total_strokes = 0
	queue_redraw()


# ─────────────────────────── 기하 ───────────────────────────
## ⚠ 세85 ⑨ 은퇴: `_jin_radius`/`_rune_size`/`_glyph_scale_of`(휠 크기 조절) ·
##   `_ring_radius`/`_slot_angle`/`_slot_pos`(1차 고리 위 8칸 좌표). 전부 **per-piece 판 기하**였다 —
##   문양을 칸 하나씩 그리던 시절에 "이 칸이 어디냐"를 답하던 자리다. 통째 밑그림의 좌표는
##   `compose_guide_paths`(합성·static)가 쥔다. 🔴 static `slot_angle`은 **살아 있다**(HUD·Tab
##   미니 다이어그램이 「칸 0=위, 시계방향」 규약의 단일 소스로 부른다) — 내리지 마라.

func _area_center() -> Vector2:
	return size * 0.5

func _outer_radius() -> float:
	return minf(size.x, size.y) * 0.44


# ─────────────────────────── 입력 (손으로 숨은 선 문지르기) ───────────────────────────
## 🔴 좌클릭 드래그로 가이드를 문지르면 먹선이 남는다. 우클릭 = 다시 그리기.
## ⚠ 확정은 판이 안 한다 — 패널의 [분석 ▶]이 `combined_total()`을 읽어 리포트를 낸다.
## ⚠ 세85 ⑨ 은퇴: 누른 자리의 **문양 칸 고르기**(`_nearest_open_slot`→`select_slot`)와
##   **휠 크기 조절**(`_resize_current`). 통째 밑그림은 칸이 없고 크기는 패널이 정한다.
##   ⚠ 휠은 하단 안내(`HINT_DRAW`)가 광고하지 않는다 — 「없는 조작을 적지 마라」는 이미 지켜져 있었다.

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_drawing = true
			begin_stroke()                # 펜을 댔다 = 새 획 (앞 획은 남는다 — 세션 25)
			trace_stroke(mb.position)
		else:
			_drawing = false
			stroke_ended.emit()           # 🔴 획 끝 — 패널이 미뤄 둔 잉크 팔레트 재빌드를 여기서 흘린다
		accept_event()
		return
	# 🔴 우클릭 = **다시 그리기** (세션 25). 획 누적으로 바뀌면서 "지우고 처음부터"가 갈 곳이
	# 없어졌다 — 예전엔 좌클릭이 그 역할을 겸했다(그래서 여러 획을 못 그렸다).
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		clear_stroke()
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _drawing:
		trace_stroke(mm.position)
		accept_event()


# ─────────────────────────── 발사 스윕 · 착지 펄스 ───────────────────────────

func play_cast() -> void:
	_cast_t = 0.0
	set_process(true)


## 🔴 세86 ⑭ **「마법진 완성」 훅** — 패널 `_finish()`가 부르는 공개 진입점.
## ⚠ 부르는 자리를 늘리지 마라: 「완성」의 정의는 패널의 `_finish()` **하나**다(그리기 모드는
## [분석 ▶], 폐지 모드는 [마법진 완성 ✦]이 같은 함수로 모인다). 여기서 상태를 안 건드리므로
## 도중에 다시 불려도 연출만 처음부터 다시 돈다.
func play_finish() -> void:
	_finish_t = 0.0
	_finish_radii = _subpath_radii(_area_center(), _outer_radius())
	set_process(true)
	queue_redraw()


## 🔴 ⑭ 완성 연출 진행도 — **헤드리스 관측점**(-1 = 안 돎, 0~1 = 도는 중).
## 연출 자체(빛·색·타이밍)는 헤드리스가 못 보지만 **훅이 실제로 불렸나**는 이 값으로 잰다 —
## 15세션 동안 벌어진 일이 정확히 「훅이 조용히 안 불린다」였다.
func finish_progress() -> float:
	return _finish_t


## ⑭ 각 서브패스의 정규 반지름 — 중심에서의 평균 거리 ÷ 바깥 반지름. 룬(≈0) → 층(0.42·0.68) →
## 진 윤곽(≈1) 순서가 그대로 나온다 = 파도가 훑는 순서가 곧 연산 순서다.
func _subpath_radii(ctr: Vector2, ro: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var inv := 1.0 / maxf(ro, 1.0)
	for sub_v in _combined_subpaths:
		var sub := sub_v as PackedVector2Array
		var acc := 0.0
		for p: Vector2 in sub:
			acc += p.distance_to(ctr)
		out.append(acc / float(maxi(sub.size(), 1)) * inv)
	return out


## ⑭ 파도의 정규 반지름 (0=중심 → 1=바깥). `FINISH_SWEEP_T`에 바깥에 닿고 그 뒤엔 1에 머문다.
## ease-out이라 안쪽(룬·1층)이 빠르게 지나가고 바깥(진 윤곽)에서 느려진다 — 마지막이 클라이맥스.
## static·순수 = 헤드리스 관측점(아래 `finish_t_at_radius`가 이 식의 역함수다 — 둘이 갈라지면
## 룬 팝이 파도와 어긋난 시점에 튄다).
static func finish_wave_frac(t: float) -> float:
	var u := clampf(t / FINISH_SWEEP_T, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


## ⑭ 파도가 정규 반지름 r에 닿는 시점 — `finish_wave_frac`의 역함수(u = 1 − √(1−r)).
static func finish_t_at_radius(r_frac: float) -> float:
	return (1.0 - sqrt(1.0 - clampf(r_frac, 0.0, 1.0))) * FINISH_SWEEP_T


## ⑭ 정규 반지름 r인 조각이 지금 얼마나 밝나 (0~1). 파도가 **지나가기 전엔 0**(아직 제 차례가
## 아니다 = 순서가 눈에 보이는 자리), 지난 직후가 가장 밝고, 그 뒤엔 은은한 꼬리로 남는다.
static func finish_glow_at(r_frac: float, t: float) -> float:
	if t < 0.0:
		return 0.0
	var wave := finish_wave_frac(t)
	if wave < r_frac:
		return 0.0
	var head := 1.0 - clampf((wave - r_frac) / FINISH_BAND_W, 0.0, 1.0)
	return maxf(head, FINISH_TAIL * (1.0 - clampf(t, 0.0, 1.0)))


func _process(delta: float) -> void:
	var busy := false
	# ⑭ 완성 연출 — 수명이 다하면 스스로 꺼진다(순수 오버레이라 끝나도 남는 상태가 없다).
	if _finish_t >= 0.0:
		_finish_t += delta / FINISH_DUR
		if _finish_t >= 1.0:
			_finish_t = -1.0
		else:
			busy = true
	if _cast_t >= 0.0:
		_cast_t += delta / _cast_dur
		if _cast_t >= 1.0:
			_cast_t = -1.0
		else:
			busy = true
	# ⓑ 반짝임 — 수명이 다한 광점을 걷어내고, 남아 있으면 계속 돈다.
	if not _sparks.is_empty():
		var alive: Array[Dictionary] = []
		for sp in _sparks:
			var t := float(sp["t"]) + delta / SPARK_DUR
			if t < 1.0:
				sp["t"] = t
				alive.append(sp)
		_sparks = alive
		if not _sparks.is_empty():
			busy = true
	if not busy:
		set_process(false)
	queue_redraw()


# ─────────────────────────── 렌더 ───────────────────────────

func _draw() -> void:
	var ctr := _area_center()
	var ro := _outer_radius()

	if _cast_t >= 0.0:
		draw_arc(ctr, maxf(_cast_t * (ro * 1.12), 1.0), 0.0, TAU, 64,
			Color(FIRE_HI, 0.5), 3.0, true)

	# ⚠ 세85 ⑨ 은퇴: **잠근 조각 먹선 렌더**(`_draw_locked`/`_locked_color`)와 **per-piece 구조 힌트**
	# (1차 고리 + 열린 빈 칸 점 + 편집 중인 칸 강조). 둘 다 「조각을 하나씩 잠근다」가 전제였고,
	# 통째 흐름엔 잠금이 없어 `_scorer.locked_pieces()`가 늘 비고 `_asm.has_rune()`이 늘 거짓이라
	# **한 번도 안 그려졌다**(라이브 코드 사이에 끼어 있던 죽은 갈래 — 감사 #25).

	# 🔴 세71c COMBINED 빈 층/룬 자리 가이드. band_count만큼 흐린 동심원(빈 층도 늘 보여
	# "여기가 1층" 구조가 읽힌다) + 룬 미선택 자리 마커.
	# subpaths가 없으면(빈 진·1인자 호출) 건너뛴다 — band_count=0이라 아무것도 안 그린다.
	if _trace == TraceTarget.COMBINED and not _combined_subpaths.is_empty():
		# 🔴 세81: 층 구분 동심원은 **미리보기(ASSEMBLE)에서만** — 그릴 때(DRAW)는 문양이 선에 걸쳐
		# 지저분하다는 지적으로 끈다. 룬 미선택 중앙 마커는 조립 안내라 계속 둔다.
		if _combined_show_bands:
			# 🔴 세86: 선은 **층을 가르는 칸막이 하나씩**뿐이다(사용자 확정 *"선이 너무 많음"*).
			# 층마다 띠 경계 둘을 다 그렸더니 2층 진에서 원이 5개가 됐다 — 지금은 층 수 + 진 윤곽.
			# 좌표는 `band_edge` 정본이 준다(여기서 반지름을 계산하면 그게 곧 사본이다).
			for bi in _combined_band_count:
				draw_arc(ctr, band_edge(bi, ro), 0.0, TAU, 48,
					BAND_GUIDE_COLOR, BAND_GUIDE_WIDTH, true)
		# 🔴 세84 #22 룬 미선택 자리 마커 — **상태(`_combined_runes`)로** 자리마다 그린다.
		# 좌표·크기는 `empty_rune_slot_marks`가 정본(`rune_slot_positions`·`combined_rune_size`)에서 뽑는다.
		if not _combined_runes.is_empty():
			for m: Dictionary in empty_rune_slot_marks(_combined_runes, ctr, ro):
				draw_arc(m["at"], float(m["r"]), 0.0, TAU, 24, RUNE_SLOT_COLOR, RUNE_SLOT_WIDTH, true)
		# ⚠ 하위 호환 폴백 = 룬 목록을 **안 넘긴** 호출자용. 서브패스 개수 유추라 세81 이후 밴드 모티프
		# 수에 오염된다(위 상태 경로가 정본) — 이 갈래에 남는 건 「자리가 하나」인 진에서만 옳다.
		# 🔴 융합진을 띄우는 호출자(`ring_forge_panel.recompose`)가 `runes`를 넘기면 이 갈래를 안 탄다.
		# 넘기기 전까지는 융합진 마커가 옛 버그 그대로다 — 걷어야 하는 폴백이지 목표 상태가 아니다.
		elif _combined_subpaths.size() <= _combined_band_count + 1:
			draw_arc(ctr, combined_rune_size(ro, 1), 0.0, TAU, 24, RUNE_SLOT_COLOR, RUNE_SLOT_WIDTH, true)

	# 🔴 지금 그리는 조각 — 숨은 정답 선(연하게) + 드러난 점(주황) + **그린 먹선 그대로**
	var guide := _scorer.guide_points()
	if _trace != TraceTarget.NONE and guide.size() >= 2:
		# 🔴 세71c 이음선 제거 — COMBINED에서 서브패스가 있으면 조각마다 별도 폴리라인(진 끝→룬 첫 점을
		# 잇는 연결선이 안 생긴다). 없으면(옛 1인자 호출·per-piece) flat 한 줄 그대로. 드러난 점·먹선은 불변.
		if _trace == TraceTarget.COMBINED and not _combined_subpaths.is_empty():
			for sub_v in _combined_subpaths:
				var sub := sub_v as PackedVector2Array
				if sub.size() >= 2:
					draw_polyline(sub, GUIDE_HIDE, 2.0, true)
		else:
			draw_polyline(guide, GUIDE_HIDE, 2.0, true)
		for i in guide.size():
			if _scorer.is_revealed(i):
				draw_circle(guide[i], 1.6, GUIDE_SHOW)
		# ⓐ 먹선 마법 글로우 — 먹선마다 밑에 넓은 저알파 패스 한 장(잉크색). 정적 렌더.
		# 🔴 획마다 따로 긋는다 — 한 줄로 이으면 펜을 뗀 구간이 선이 돼 화살표가 삼각형이 된다
		for s in _scorer.strokes():
			if s.size() >= 2:
				draw_polyline(s, Color(_trace_ink, GLOW_ALPHA_DRAWING), GLOW_WIDTH, true)
		for s in _scorer.strokes():
			if s.size() >= 2:
				draw_polyline(s, _trace_ink, 2.6, true)
		# ⓕ 붓끝 발광 — 현재 획의 마지막 유효점에서 "마법 먹"이 손끝에 고이는 느낌. 정적 렌더.
		if _drawing:
			var strokes := _scorer.strokes()
			if not strokes.is_empty():
				var last := strokes[strokes.size() - 1]
				if not last.is_empty():
					var tip := last[last.size() - 1]
					for j in BRUSH_GLOW_RADII.size():
						draw_circle(tip, float(BRUSH_GLOW_RADII[j]),
							Color(_trace_ink, float(BRUSH_GLOW_ALPHA[j])))

	# ⓑ 가이드 드러남 반짝임 — 커지며 사라지는 광점 (수명·제거는 _process가 든다)
	for sp in _sparks:
		var st := float(sp["t"])
		var spos := sp["pos"] as Vector2
		draw_circle(spos, lerpf(SPARK_R0, SPARK_R1, st),
			Color(SPARK_COLOR, (1.0 - st) * SPARK_ALPHA))

	# ⚠ 세85 ⑨ 은퇴: ⓒ **착지 펄스**("탁" — 조각을 놓은 자리에서 퍼지는 고리)와 ⓓ **완성 발광**
	# (잠긴 획 전체 글로우 + 바깥을 훑는 호). 둘 다 **per-piece 잠금이 트리거**였고(`advance`/
	# `finish`/`_commit_glyph_slot`), 세70 통째 흐름엔 잠금이 없어 이미 한 번도 안 떴다.
	# ✅ **세86 ⑭에 그 자리를 새로 채웠다** — 죽은 트리거를 되살린 게 아니라 공개 훅
	# `play_finish()`(패널 `_finish()`가 부른다)로 새로 붙였다. 아래가 그 렌더다.
	if _finish_t >= 0.0:
		_draw_finish(ctr, ro)


## 🔴 세86 ⑭ 「마법진 완성」 렌더 — **순수 오버레이**(가이드·먹선 위에 얹기만 한다. 지우거나
## 가리지 않아 리포트로 넘어간 뒤에도 판이 그대로 읽힌다).
## 순서: ① 조각이 안→밖으로 차례로 빛나고 ② 파도 고리가 그 경계를 보여 주고 ③ 룬 자리가 팝 하고
## ④ 마지막에 바깥 테두리가 한 번 번쩍한다(= 다 맺혔다).
func _draw_finish(ctr: Vector2, ro: float) -> void:
	var t := _finish_t
	var wave := finish_wave_frac(t)
	# ① 조각(룬 → 층 → 진 윤곽)이 파도에 닿는 순간 밝아진다 = **안에서 밖 = 연산 순서**(M1).
	# ⚠ `_combined_subpaths`가 없으면(빈 진) 아무것도 안 그린다 — 완성 자체가 불가한 상태다.
	for i in _combined_subpaths.size():
		if i >= _finish_radii.size():
			break
		var sub := _combined_subpaths[i] as PackedVector2Array
		if sub.size() < 2:
			continue
		var a := finish_glow_at(float(_finish_radii[i]), t)
		if a <= 0.01:
			continue
		draw_polyline(sub, Color(FINISH_GOLD, a * 0.35), FINISH_GLOW_W, true)
		draw_polyline(sub, Color(FINISH_GOLD, a), FINISH_LINE_W, true)
	# ② 파도 자체 — 얇은 금빛 고리가 바깥으로 퍼지며 옅어진다.
	if wave < 1.0 and wave * ro > 1.0:
		draw_arc(ctr, wave * ro, 0.0, TAU, 64,
			Color(FINISH_GOLD, FINISH_SWEEP_ALPHA * (1.0 - wave)), 2.0, true)
	# ③ 룬 자리 팝 — 파도가 그 자리를 지나는 순간 고리 하나가 튄다(융합진이면 자리마다).
	# 🔴 좌표·크기는 `rune_slot_positions`·`combined_rune_size` **정본**을 그대로 부른다 —
	# 각도를 베끼면 팝이 실제 룬에서 어긋난 자리에 뜬다(세48·세83이 밟은 그 함정).
	var rn := maxi(_combined_runes.size(), 1)
	var rsz := combined_rune_size(ro, rn)
	for p: Vector2 in rune_slot_positions(rn, ctr, ro):
		var u := (t - finish_t_at_radius(p.distance_to(ctr) / maxf(ro, 1.0))) / FINISH_POP_T
		if u < 0.0 or u > 1.0:
			continue
		draw_arc(p, rsz * lerpf(0.5, FINISH_POP_SCALE, u), 0.0, TAU, 24,
			Color(FINISH_GOLD, (1.0 - u) * 0.8), 2.0, true)
	# ④ 마지막 플래시 — 바깥 테두리가 굵어졌다 잦아든다 + 판 전체에 아주 옅은 금빛 한 겹.
	if t >= FINISH_FLASH_T:
		var f := 1.0 - (t - FINISH_FLASH_T) / maxf(1.0 - FINISH_FLASH_T, 0.001)
		draw_circle(ctr, ro, Color(FINISH_GOLD, f * 0.06))
		draw_arc(ctr, ro, 0.0, TAU, 72, Color(FINISH_GOLD, f * 0.55), 1.0 + 3.0 * f, true)
