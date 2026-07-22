extends Control
## 고리 조립 보드 — forge 왼쪽 페이지에 얹히는 **조립 판**.
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
const COMMIT_COVER := TraceScorer.COMMIT_COVER

# ── 어휘 2종 (사용자 확정 2026-07-16) ──
## 🔴 값은 **core가 쥔다**(Enums.GlyphCode = 발사 계약). 여기서 다시 정의하면 언젠가 갈라진다.
const G_GATHER := Enums.GlyphCode.GATHER    # 응집 ← — 안쪽(룬) 방향 화살표
const G_RADIATE := Enums.GlyphCode.RADIATE  # 발산 → — 바깥(진) 방향 화살표
const G_PIERCE := Enums.GlyphCode.PIERCE    # 관통 ↠ — 바깥 방향(발산 계열) + 뚫음 효과 (세션44 B)
const G_HOMING := Enums.GlyphCode.HOMING    # 유도 ∿ — 휘어서 쫓아간다 (세션47)
const G_BOUNCE := Enums.GlyphCode.BOUNCE    # 팅김 ⚡ — 벽에 튕긴다 (세션47)
const G_THRUST := Enums.GlyphCode.THRUST    # 추진 ↑ — 빠르게 날아간다 (세션47)
## 인덱스 = GlyphCode 값 (세션44: 관통 · 세션47: 유도·팅김·추진 = 어휘 배증)
const GLYPH_NAMES := ["응집←", "발산→", "관통↠", "유도∿", "팅김⚡", "추진↑"]
## ⚠ **`GLYPH_KEYS`는 지웠다** (세션 25). 문양은 오른쪽 셀을 **클릭해서** 고른다 —
## 진·룬 선택이 전부 클릭인데 문양만 키(Q·W)를 광고했다 (사용자: "q w 이런게 아니라
## 똑같이 마우스로 선택하는걸로해줘"). 죽은 상수를 남기면 다음 세션이 키를 되살린다.

# ── 색 (먹·양피지 톤) ──
const RING_LINE := Color(0.42, 0.30, 0.12, 0.55)
const SLOT_OPEN := Color(0.42, 0.30, 0.12, 0.5)    # 열린 빈 칸 — 여기 채워라
const FIRE_HI := Color(0.95, 0.55, 0.15)
## ⚠ **`data/glyphs/*.tres`의 `ui_color`를 그대로 베낀 폴백이다** — 정본은 .tres고
## `_glyph_color`가 그걸 읽는다. 여기 값은 defs 주입 전(순수 단위 테스트)에만 쓰인다.
## 🔴 그래도 **길이와 값을 .tres에 맞춰 둔다** (세션47):
##   • 길이 — `ring_book`은 `_glyph_color`를 안 거치고 `RingBoard.GLYPH_COLORS[g]`를 **직접**
##     인덱싱한다. 어휘보다 짧으면 책이 터진다. 즉 길이는 폴백이 아니라 계약이다.
##   • 값 — 갈라져 있으면 "책이랑 판이랑 색이 다르네"가 어디서 오는지 못 찾는다.
## **새 문양을 늘릴 땐 .tres·GLYPH_NAMES·여기 셋을 같이 늘려라.**
const GLYPH_COLORS := [
	Color(0.16, 0.34, 0.55),   # 응집 = 남색
	Color(0.72, 0.28, 0.12),   # 발산 = 주홍
	Color(0.30, 0.72, 0.85),   # 관통 = 하늘
	Color(0.35, 0.78, 0.42),   # 유도 = 초록
	Color(0.95, 0.82, 0.25),   # 팅김 = 노랑
	Color(0.68, 0.38, 0.85),   # 추진 = 보라
]
const RUNE_COLOR := Color(0.62, 0.22, 0.12)   # 불
const TRACE_INK := Color(0.20, 0.14, 0.09, 0.95)    # 그린 먹선
## 숨은 가이드 (아직 안 드러남). 🔴 세션 25에 0.18 → 0.32: 0.18은 진(큰 원)에서나 보였고
## 문양처럼 작은 밑그림은 **사실상 안 보였다** (사용자: "문양을 선택했을때 밑그림이 그려져야지").
## ⚠ 더 진하게 하면 "숨은 선"이 아니라 그냥 답이 된다 — 따라 그을 만큼만 보여야 한다.
const GUIDE_HIDE := Color(0.42, 0.30, 0.12, 0.32)
const GUIDE_SHOW := Color(0.80, 0.50, 0.16, 0.55)   # 드러난 가이드 강조

const RING_RADIUS_FRAC := 0.60
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

# ── 마우스 휠 크기 조절 (진·룬, 세션 14c) ──
const JIN_SCALE_MIN := 0.72
const JIN_SCALE_MAX := 1.16
const RUNE_SCALE_MIN := 0.55
const RUNE_SCALE_MAX := 1.70
const SCALE_STEP := 0.06
# ── 문양 개별 크기 (칸마다, 세션 15 — 사용자: "문양 모양이 주된 과제 · 각각으로") ──
const GLYPH_SCALE_MIN := 0.55
const GLYPH_SCALE_MAX := 1.85

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
const GLYPH_SIZE_FRAC := 0.17
const ARROW_BACK_FRAC := 0.5
const ARROW_SIDE_FRAC := 0.62

## 🔴 칸을 고르는 **최대 거리** (세션 22, I3 버그 수정). 이 밖을 클릭하면 칸을 안 바꾼다.
## 예전엔 컷오프가 없어서 판 아무 데나 클릭해도 최근접 열린 칸이 잡혔고, select_slot이
## 현재 칸 coverage > COMMIT_COVER면 **자동 확정**해 버렸다 → **칸 0을 그리다 획을 칸 2 쪽에
## 조금 가깝게 시작하면 칸 0이 멋대로 확정되고 넘어갔다.** *"마음에 들 때까지 다시 그린다"*
## 설계와 정면 충돌. 값은 아래 칸 표시(ro*0.05)·강조(ro*0.11)와 맞췄다.
const SLOT_PICK_FRAC := 0.18

## 지금 손으로 그릴 대상. NONE=그릴 것 없음(열린 빈 칸 없음 / 다 그림)
enum TraceTarget { NONE, JIN, RUNE, GLYPH }

signal assembly_changed
## 단계가 넘어갔다 — 바깥(패널)이 오른쪽 탭·안내문을 맞춘다. (STAGE_*)
signal stage_advanced(stage: int)
## 지금 그리는 조각의 점수가 갱신됐다 (실시간) — 패널이 현재 점수를 보여준다.
signal score_changed(score: float)
## 한 조각을 [다음]으로 잠갔다 — 패널이 손맛 피드백을 준다. (TraceTarget·칸·그 조각 점수)
signal piece_locked(target: int, slot: int, score: float)
## 마법진을 다 그렸다 — 패널이 분석 리포트를 띄운다. (get_analysis 결과)
signal finished(analysis: Dictionary)
## 🔴 한 획을 뗐다 (마우스 릴리스) — 패널이 **획이 끝난 뒤에** 잉크 팔레트를 다시 그리게 한다.
## 특별잉크가 그리는 도중 소모돼 팔레트가 재빌드되면 활성 잉크가 획 중간에 바뀌기 때문이다.
signal stroke_ended

var _asm := RingAssembly.new()
var _scorer := TraceScorer.new()

# ── 데이터 정의 (세션 13 구조화) — 바깥(패널)이 Db에서 읽어 주입한다. 없으면 const 폴백. ──
var _jin_def: JinDef = null
var _rune_defs: Dictionary = {}         # {Enums.RuneType: RuneDef} — 색·이름 조회 (세션 34: 룬 여러 종)
var _glyph_defs: Array[GlyphDef] = []

var _active := G_RADIATE            # 활성 문양 코드 (바깥이 set_active_glyph으로 정한다)
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

var _trace := TraceTarget.NONE          # 지금 그릴 대상
var _trace_slot := -1                   # GLYPH일 때 채울 칸
## 🔴 **고른 진·룬** (세션 25). -1 = 아직 안 골랐다 = 밑그림이 안 뜬다 — 문양 칸(`_trace_slot`)과
## 같은 규약이다. 예전엔 단계에 들어가는 순간 밑그림이 저절로 서 있었다
## (사용자: "이게 눌러야 뜨게 해줘").
##
## ⚠ **bool이 아니라 인덱스인 이유** (사용자: "룬이 나중에는 추가된다는 것을 전제로 작업해야지"):
## bool은 "골랐나"만 알고 **"어느 룬인가"를 못 담는다**. 룬이 불·물·바람으로 늘면 그때 bool을
## 인덱스로 바꾸느라 호출부를 전부 다시 건드려야 한다 — 지금은 종류가 하나씩이라 0만 유효하지만
## API는 이미 인덱스를 받는다. 늘릴 때 `set_defs`가 배열을 받게 하면 여기는 그대로다.
var _jin_idx := -1
var _rune_idx := -1
var _drawing := false                   # 마우스 버튼 누른 채 긋는 중
var _stroke_counted := false            # 🔴 이 획을 잉크 정산에 넣었나 (최초 유효점에서 1회만)
var _jin_scale := 1.0                   # 진 크기 (마우스 휠)
var _rune_scale := 1.0                  # 룬 크기 (마우스 휠)
var _glyph_scale: Dictionary = {}       # slot(int) → float, 문양 개별 크기 (마우스 휠, 세션 15)

# ── 착지 펄스 ("탁") — 조각이 놓인 자리에서 퍼지는 고리 ──
var _pulse_t := -1.0
var _pulse_at := Vector2.ZERO
var _pulse_color := FIRE_HI             # ⓒ 잠근 조각의 색으로 펄스를 물들인다 (_start_pulse가 받는다)
const PULSE_DUR := 0.35

# ── 그리기 연출 (세션62 ⓐⓑⓒⓓⓕ — 렌더 전용, 채점·조립 무관) ─────────────────────
# ⚠ 전부 연출값(손맛)이라 스크립트 const다 — 사용자가 F5로 조인다. balance.tres 아님.
const GLOW_WIDTH := 7.0                 # ⓐ 먹선 밑 글로우 패스 폭 (먹선 2.6~2.8px보다 넓게)
const GLOW_ALPHA_DRAWING := 0.12        # ⓐ 그리는 중 획 글로우 알파 (잉크색)
const GLOW_ALPHA_LOCKED := 0.10         # ⓐ 잠긴 조각 글로우 알파 (조각색)
const SPARK_DUR := 0.25                 # ⓑ 반짝임 수명(초)
const SPARK_R0 := 1.2                   # ⓑ 광점 시작 반지름
const SPARK_R1 := 4.5                   # ⓑ 광점 끝 반지름 (커지며 사라진다)
const SPARK_ALPHA := 0.8                # ⓑ 광점 시작 알파 ((1-t)×이 값)
const SPARK_COLOR := Color(1.0, 0.88, 0.55)   # ⓑ 광점 색 (따뜻한 금빛)
const PULSE_BLOOM_FRAC := 0.10          # ⓒ 중심 블룸 반지름 (판 반지름 비례)
const FINISH_GLOW_DUR := 0.8            # ⓓ 완성 발광 시간(초)
const FINISH_GLOW_ALPHA := 0.5          # ⓓ 발광 시작 알파 ((1-t)×이 값)
const FINISH_ARC_SPAN := TAU * 0.22     # ⓓ 바깥 반경을 훑는 밝은 호의 길이(라디안)
const FINISH_ARC_COLOR := Color(1.0, 0.92, 0.6)   # ⓓ 훑는 호의 색
## ⓕ 붓끝 발광 — 동심원 3장, 바깥(크고 흐림)부터 그려 안쪽(작고 밝음)이 위에 얹힌다.
## ⚠ 무타입 Array인 이유: GDScript는 const에 PackedFloat32Array(...) 생성자를 상수식으로 안 받는다
## (세62 실측 — 파스 에러). 소비처가 float() 캐스트로 받는다.
const BRUSH_GLOW_RADII := [10.0, 6.0, 3.0]
const BRUSH_GLOW_ALPHA := [0.06, 0.14, 0.30]

## ⓑ 렌더 전용 — 가이드 점의 드러남을 지난 프레임과 비교해 false→true 순간을 잡는다.
## 🔴 채점기(`_scorer`)는 `is_revealed(i)` 공개 조회만 쓴다 — 채점 상태를 복사하는 게 아니라
## "언제 드러났나"라는 렌더만의 관심사를 따로 든다. `_reset_reveal_fx`가 가이드와 크기를 맞춘다.
var _was_revealed := PackedByteArray()
var _sparks: Array[Dictionary] = []     # ⓑ {pos: Vector2, t: float} — 광점들
var _finish_glow_t := -1.0              # ⓓ 완성 발광 타이머 (-1 = 꺼짐)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_process(false)
	resized.connect(_on_resized)


## 판 크기가 바뀌면 채점기의 길이 기준과 가이드를 다시 세운다 (거리 임계값이 전부 반지름 비례다).
func _on_resized() -> void:
	_scorer.set_reference_radius(_outer_radius())
	_set_trace(_trace, _trace_slot)
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


# ─────────────────── 손그림 탁본 — 무엇을 그릴지 정하고 가이드를 세운다 ───────────────────

## 🔴 지금 단계에 맞는 가이드를 세운다 — 무엇을 그릴지 정하고 문지름 상태를 리셋한다.
func _refresh_trace() -> void:
	match _asm.stage():
		STAGE_JIN:
			# 🔴 진도 **오른쪽에서 골라야** 밑그림이 뜬다 (세션 25) — 문양 칸과 같은 규약이다.
			# 안 골랐으면 `_jin_idx = -1` → 빈 가이드. (`_build_guide` 참조)
			if not _asm.has_jin():
				_set_trace(TraceTarget.JIN, -1)
				return
		STAGE_RUNE:
			if not _asm.has_rune():
				_set_trace(TraceTarget.RUNE, -1)
				return
		STAGE_GLYPH:
			# 🔴 칸은 **사용자가 클릭해서 고른다** (세션 25). 예전엔 첫 빈 칸을 멋대로 잡아
			# 아무것도 안 골랐는데 주황 강조가 떠 있었다 (사용자: "8방 했을때 이미 주황색으로
			# 선택되어있어 그거 지워주고"). 칸 미선택(-1) = 빈 가이드 = 그릴 게 아직 없다.
			if _asm.next_open_slot() >= 0:
				_set_trace(TraceTarget.GLYPH, -1)
				return
	_set_trace(TraceTarget.NONE, -1)   # 그릴 것 없음 (열린 빈 칸 없음 / 다 그림)


## 가이드 대상을 세우고 숨은 선 점을 만든 뒤 문지름 상태를 비운다.
## 🔴 여기서 **장착한 펜의 보정도**도 물려 준다 (세션 23) — 조각을 새로 잡을 때마다 다시 읽어,
## 그리는 도중에 펜을 갈아 껴도 다음 조각부터 반영된다. 채점기는 아이템을 모른다(숫자만 받는다).
func _set_trace(target: int, slot: int) -> void:
	_trace = target
	_trace_slot = slot
	_scorer.set_reference_radius(_outer_radius())
	_scorer.set_correction(_pen_correction())
	_scorer.set_guide(_build_guide(target, slot))
	_reset_reveal_fx()   # ⓑ 가이드가 바뀌었다 — 옛 가이드의 유령 반짝임을 남기지 않는다


## ⓑ 드러남 반짝임의 렌더 상태를 지금 가이드에 맞춰 비운다 (렌더 위생 — 채점 무관).
## 가이드가 바뀌거나(_set_trace) 먹선을 지울 때(clear_stroke·clear_all) 부른다.
func _reset_reveal_fx() -> void:
	_sparks.clear()
	_was_revealed = PackedByteArray()
	_was_revealed.resize(_scorer.guide_points().size())   # resize는 0으로 채운다


## 장착한 펜의 보정도. 오토로드가 없는 환경(순수 단위 테스트)에서도 죽지 않게 0으로 폴백한다.
func _pen_correction() -> float:
	var gs := get_node_or_null(^"/root/GameState")
	return float(gs.stroke_correction()) if gs != null else 0.0


## 대상별 숨은 정답 선 (조밀, 로컬 좌표). 이 위를 문지르면 드러난다.
func _build_guide(target: int, slot: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ctr := _area_center()
	var ro := _outer_radius()
	match target:
		TraceTarget.JIN:
			# 🔴 안 골랐으면 밑그림이 없다 (세션 25) — 오른쪽 진 셀을 클릭해야 뜬다.
			if _jin_idx < 0:
				return pts
			# 🔴 진 종류별 **닫힌 도형** (세션48) — 휠 크기 반영. 예전엔 종류와 무관하게 원 하나라
			# 진을 8종으로 늘려도 **손 궤적이 똑같았다**(색만 다른 8지선다).
			pts = jin_guide_pts(_jin_shape(), ctr, _jin_radius())
		TraceTarget.RUNE:
			if _rune_idx < 0:
				return pts
			# 🔴 룬 종류별 밑그림 (세션 34) — 닫힌 다각형의 꼭짓점을 변마다 촘촘히 잇는다.
			# 렌더는 먹선 그대로라(_draw_locked) 이 밑그림 모양이 곧 "따라 그리는 룬"이다.
			var v := rune_guide_verts(_rune_idx, ctr, _rune_size())
			var seg := v.size() - 1
			for e in seg:
				for t in 12:
					pts.append(v[e].lerp(v[e + 1], float(t) / 12.0))
			pts.append(v[seg])
		TraceTarget.GLYPH:
			# 🔴 문양 = **방향을 가진 화살표** (세션 25). 예전엔 방향 없는 짧은 **작대기**였다:
			# 책의 셀은 화살표(↑↓←→)를 그려 놓고 판의 밑그림은 작대기라, 응집과 발산이
			# **똑같이 보였다** (GlyphDef.inward를 아무도 안 읽었다). 사용자가 화살표를 그리려다
			# 막힌 것도, 결과물이 "작대기"인 것도 여기서 나왔다.
			# ⚠ 칸을 안 골랐으면(-1) 빈 가이드다 — 칸은 사용자가 클릭해서 고른다.
			if slot >= 0:
				pts = glyph_guide_pts(_active, _slot_pos(slot),
					Vector2.from_angle(_slot_angle(slot)),
					ro * GLYPH_SIZE_FRAC * _glyph_scale_of(slot))
	return pts


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
			# 커야 **몸통을 그어도 꺾쇠가 안 드러난다**(파일 머리 GLYPH_SIZE_FRAC 주석의 그 비율).
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


## 지금 고른 진의 밑그림 도형 (`Enums.JinShape`). def가 없으면(순수 단위 테스트·폴백) 원.
func _jin_shape() -> int:
	return int(_jin_def.guide_shape) if _jin_def != null else Enums.JinShape.CIRCLE


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
## 🔴 **static · public인 이유**: 책의 진 셀 아이콘(`ring_book.jin_icon_marks`)이 이 함수를 그대로
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


## 🔴 칸 k의 각도 — **"칸 0=위, 시계방향" 규약의 단일 소스** (세션60 리뷰). 판의 칸 위치
## (`_slot_pos`)와 책 다이어그램(`jin_slot_dots`)이 같이 부른다 — 한쪽에 식을 베끼면
## 규약이 바뀔 때 책과 판이 조용히 어긋난다. 착탄 전개 각도(ring_spell_system의
## `TAU*k/8`)와도 같은 회전 방향이다(기준 0이 진행 방향이냐 위냐만 다르다).
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
func trace_target() -> int:
	return _trace

func trace_slot() -> int:
	return _trace_slot

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

## 잠긴 손그림 조각 수 = 화면에 남아 있는 먹선 줄 수. 재편집이 **덮어쓰는지**(중복 추가가
## 아닌지) 보는 관측점 — 테스트가 쓴다.
func locked_count() -> int:
	return _scorer.locked_pieces().size()


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


# ─────────────────────────── [다음] 수동 진행 · 분석 ───────────────────────────

## 🔴 지금 조각을 잠그고(점수 저장) 다음으로 넘어간다 ([다음]). 반환:
##   "advanced" = 다음 조각 · "finished" = 마지막이라 다 그림(분석) · "none" = 그릴 게 없음
func advance() -> String:
	if _trace == TraceTarget.NONE:
		return "none"
	# 🔴 아직 안 골랐다 (세션 25의 미선택 상태) — 잠글 조각이 없다.
	# 문양: 그냥 넘기면 `_piece_key(GLYPH, -1)`이라는 유령 키에 점수가 저장된다.
	# 진·룬: 그냥 넘기면 **그린 적 없는 진이 0점으로 잠긴다** (밑그림도 안 떴는데).
	if _trace == TraceTarget.GLYPH and _trace_slot < 0:
		return "none"
	if _trace == TraceTarget.JIN and _jin_idx < 0:
		return "none"
	if _trace == TraceTarget.RUNE and _rune_idx < 0:
		return "none"
	var done := _trace
	var slot := _trace_slot
	var sc := _lock_current()
	match done:
		TraceTarget.JIN:
			_asm.lock_jin()
			_start_pulse(_area_center(), _jin_color())
			stage_advanced.emit(_asm.stage())
		TraceTarget.RUNE:
			_asm.lock_rune()
			_start_pulse(_area_center(), _rune_color())
			stage_advanced.emit(_asm.stage())
		TraceTarget.GLYPH:
			if slot >= 0:
				_asm.place_glyph(slot, _active)
				_start_pulse(_slot_pos(slot), _glyph_color(_active))
	_refresh_trace()
	piece_locked.emit(done, slot, sc)
	assembly_changed.emit()
	queue_redraw()
	if _trace == TraceTarget.NONE:
		# ⓓ 완성 발광 — 렌더 타이머 시작만 (로직 분기 불변).
		_finish_glow_t = 0.0
		set_process(true)
		finished.emit(get_analysis())
		return "finished"
	return "advanced"


## 🔴 지금 그리던 문양 칸까지 잠그고 마법진을 **끝낸다** (맺기 — 남은 칸은 비운 채). 분석을 낸다.
## 진·룬이 잠겨 있어야 한다(can_commit) — 바깥(패널)이 게이트한다.
func finish() -> Dictionary:
	if _trace == TraceTarget.GLYPH and _trace_slot >= 0 and _scorer.coverage() > 0.0:
		_lock_current()
		_asm.place_glyph(_trace_slot, _active)
		_start_pulse(_slot_pos(_trace_slot), _glyph_color(_active))
	_trace = TraceTarget.NONE
	_trace_slot = -1
	# ⓓ 완성 발광 — 렌더 타이머 시작만 (로직 분기 불변).
	_finish_glow_t = 0.0
	set_process(true)
	queue_redraw()
	# 🔴 M6 (세션 22): 여기서 _slots가 바뀌는데 예전엔 assembly_changed를 안 쏴서 advance()와
	# 불일치였다. 지금은 증상이 없지만 구독자가 늘면 [맺기] 경로만 갱신을 놓친다.
	assembly_changed.emit()
	var a := get_analysis()
	finished.emit(a)
	return a


## 마법진 분석 리포트 — 조각별 점수 + 종합 + 등급 (채점기가 계산, 열린 칸은 조립기가 안다).
func get_analysis() -> Dictionary:
	return _scorer.get_analysis(_asm.get_open())


# ─────────────────── 문양 칸 자유 편집 (칸 클릭 → 골라 다시 그림, 세션 15) ───────────────────
## 🔴 문양 단계에서 **아무 칸이나 골라** 편집한다 (사용자 확정: "칸클릭 문양 선택하고 내가 다시그림").
## 그리던 칸을 충분히 그렸으면 먼저 자동으로 잠그고 넘어간다. 이미 채운 칸도 다시 골라 덮어 그린다.
## public — 보드 입력(_gui_input)과 헤드리스 테스트가 부른다.
func select_slot(k: int) -> void:
	if _asm.stage() != STAGE_GLYPH or not _asm.is_open_slot(k) or k == _trace_slot:
		return
	if _trace == TraceTarget.GLYPH and _trace_slot >= 0 and _scorer.coverage() > COMMIT_COVER:
		_commit_glyph_slot(_trace_slot)         # 그리던 칸을 먼저 확정
	_set_trace(TraceTarget.GLYPH, k)            # 고른 칸에 화살표 가이드를 세운다(그 칸 크기로)
	queue_redraw()
	score_changed.emit(_scorer.piece_score())


## 문양 칸 하나를 잠근다 (그린 먹선·문양·점수 저장). advance()의 문양 확정과 같되 단계는 안 넘긴다.
func _commit_glyph_slot(slot: int) -> void:
	var sc := _lock_current()
	_asm.place_glyph(slot, _active)
	_start_pulse(_slot_pos(slot), _glyph_color(_active))
	piece_locked.emit(TraceTarget.GLYPH, slot, sc)
	assembly_changed.emit()


## 지금 조각의 점수·먹선을 채점기에 잠근다. 반환 = 그 조각 점수.
func _lock_current() -> float:
	return _scorer.lock(_piece_key(_trace, _trace_slot), _trace, _trace_slot,
		_active if _trace == TraceTarget.GLYPH else -1)


func _piece_key(target: int, slot: int) -> String:
	match target:
		TraceTarget.JIN:
			return TraceScorer.KEY_JIN
		TraceTarget.RUNE:
			return TraceScorer.KEY_RUNE
		TraceTarget.GLYPH:
			return TraceScorer.glyph_key(slot)
	return "?"


## 🔴 클릭 위치에서 가장 가까운 열린 칸 — **너무 멀면 -1** (I3 버그 수정, 세션 22).
## -1이면 칸을 안 바꾸고 현재 칸을 계속 그린다.
func _nearest_open_slot(pos: Vector2) -> int:
	var best := -1
	var best_d2 := INF
	for k in _asm.get_open():
		var d2 := pos.distance_squared_to(_slot_pos(k))
		if d2 < best_d2:
			best_d2 = d2
			best = k
	var max_d := _outer_radius() * SLOT_PICK_FRAC
	if best_d2 > max_d * max_d:
		return -1
	return best


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


func _jin_color() -> Color:
	return _jin_def.ui_color if _jin_def else RING_LINE

func _rune_color() -> Color:
	var rd := _rune_defs.get(_rune_idx) as RuneDef   # _rune_idx = 고른 룬 타입 (세션 34)
	return rd.ui_color if rd else RUNE_COLOR

func _glyph_def_by_code(code: int) -> GlyphDef:
	for d in _glyph_defs:
		if d.code == code:
			return d
	return null

func _glyph_color(code: int) -> Color:
	var d := _glyph_def_by_code(code)
	if d:
		return d.ui_color
	return GLYPH_COLORS[clampi(code, 0, GLYPH_COLORS.size() - 1)]


# ─────────────────────────── 바깥이 주입하는 선택 ───────────────────────────

func set_active_glyph(g: int) -> void:
	_active = clampi(g, 0, GLYPH_NAMES.size() - 1)
	# 🔴 고른 문양이 **밑그림을 정한다** (세션 25) — 응집←과 발산→은 화살표 방향이 반대다.
	# 예전엔 여기서 가이드를 안 세워, Q·W를 눌러도 판의 밑그림이 그대로였다
	# (사용자: "문양을 선택했을때 밑그림이 그려져야지"). 어차피 방향 없는 작대기라 티도 안 났다.
	# ⚠ 그리던 획은 사라진다 (`set_guide` → `reset_stroke`). 밑그림이 통째로 바뀌었으니
	# 남겨 봐야 **다른 문양을 겨눈 획**이다 — 휠로 크기를 바꿀 때와 같은 이유다.
	if _trace == TraceTarget.GLYPH and _trace_slot >= 0:
		_set_trace(_trace, _trace_slot)
	queue_redraw()


## 지금 긋는 획의 색 = 고른 잉크 색 (세션28). 패널이 잉크를 고를 때마다 부른다.
func set_trace_ink(c: Color) -> void:
	_trace_ink = c
	queue_redraw()


## 🔴 고른 잉크 id (세션29) — get_assembly가 실어 발사·저장에 등급 배수를 태운다.
## ⚠ clear_all은 이걸 안 지운다 — 잉크는 판 기하가 아니라 **지속되는 선택**이다
## (색도 그대로 남는다). 새로 그려도 골라 둔 잉크가 유지된다.
func set_ink(id: StringName) -> void:
	_ink_id = id


## 🔴 진 확대 상한 (세션29, 종이=규모) — 종이 등급이 정한다. 패널이 종이를 고를 때마다 부른다.
## 현재 크기가 새 상한을 넘으면 끌어내린다(상급→기본 종이로 바꿨을 때 진이 상한 밖에 안 남게).
func set_jin_scale_max(v: float) -> void:
	_jin_scale_max = maxf(v, JIN_SCALE_MIN)
	_jin_scale = minf(_jin_scale, _jin_scale_max)
	if _trace == TraceTarget.JIN:
		_set_trace(_trace, _trace_slot)   # 상한이 줄어 크기가 바뀌었으면 밑그림 다시
	queue_redraw()


## 🔴 **진을 고른다** (오른쪽 진 셀 클릭) → 왼쪽에 밑그림이 선다 (세션 25).
## idx = 진 종류 (지금은 0만 — Db에 일반진 하나뿐이다. 늘어나면 그대로 인덱스가 는다).
## ⚠ 진 단계가 아니면 무시한다 — 이미 잠근 진을 다시 고르는 건 [다시 그리기]의 일이다.
func choose_jin(jin_def: JinDef = null) -> void:
	if _asm.stage() != STAGE_JIN or _asm.has_jin():
		return
	# 🔴 고른 진(세션44, 진=형태) — 색·형태가 이 def에서 온다. 무인자(테스트·폴백)면 기본 진 유지.
	if jin_def != null:
		_jin_def = jin_def
	_jin_idx = 0
	_asm.set_jin(StringName(_jin_def.id) if _jin_def != null else &"")   # 🔴 발사·저장 계약에 진 담기
	# 🔴 **진이 칸을 연다** (세션60 — JinDef.glyph_slots). 진 선택에 원자적으로 붙어야
	# "진은 골랐는데 칸은 옛것"인 순간이 없다. null(무인자 테스트·폴백)이면 현 칸 유지.
	if jin_def != null:
		_asm.set_open_slots(jin_def.glyph_slots)
	_set_trace(TraceTarget.JIN, -1)     # 고른 진으로 밑그림을 세운다
	queue_redraw()
	score_changed.emit(_scorer.piece_score())


## 🔴 **룬을 고른다** (오른쪽 룬 셀 클릭) → 중심에 룬별 밑그림이 선다 (세션 25·34).
## rune_type = Enums.RuneType (불0·물2·바람3·번개4·흙5·풀6 — 세션49에 3→6종). `_build_guide`가 type별 모양을 그리고
## `_asm.set_rune`이 발사·저장 계약에 담는다 — 세션 34 전엔 밑그림만 바뀌고 발사는 늘 불이었다.
func choose_rune(rune_type: int = Enums.RuneType.FIRE) -> void:
	if _asm.stage() != STAGE_RUNE or _asm.has_rune():
		return
	_rune_idx = rune_type
	_asm.set_rune(rune_type)             # 🔴 발사·저장에 실제 룬 타입을 담는다 (밑그림뿐이 아니다)
	_set_trace(TraceTarget.RUNE, -1)
	queue_redraw()
	score_changed.emit(_scorer.piece_score())


## 고른 진·룬 (테스트·UI의 관측점). -1 = 아직 안 골랐다.
func jin_idx() -> int:
	return _jin_idx

func rune_idx() -> int:
	return _rune_idx


## 🔴 열린 칸을 지정한다 — 이 칸들만 열린다. 닫힌 칸의 문양은 걷어낸다.
## 보통은 `choose_jin`이 내부에서 부른다(진이 칸을 연다, 세션60) — 이 공개 래퍼는
## 테스트·미래 경로(중첩진 등)의 직접 주입구다.
func set_open_slots(open_slots: Array) -> void:
	_asm.set_open_slots(open_slots)
	_refresh_trace()                     # 새로 열린 칸의 첫 빈 칸에 문양 유령을 세운다
	queue_redraw()
	assembly_changed.emit()


func clear_all() -> void:
	_asm.clear()
	_scorer.clear()
	_jin_idx = -1                        # 빈 판 = 아무것도 안 고른 상태 (밑그림 없음)
	_rune_idx = -1
	_jin_scale = 1.0
	_rune_scale = 1.0
	_glyph_scale = {}
	_pulse_t = -1.0
	_finish_glow_t = -1.0                # ⓓ 새 판에 옛 완성 발광이 남지 않게 (렌더 위생)
	_reset_reveal_fx()                   # ⓑ 반짝임도 — 아래 _refresh_trace가 다시 세우지만 명시가 계약이다
	# 🔴 잉크 소모·비율은 새 진마다 리셋 (세션29). ⚠ _ink_id·_jin_scale_max(종이 상한)은 **안** 지운다 —
	# 잉크·종이 선택은 지속된다(다시 그려도 유지). 여기서 지우는 건 "이번 진에 얼마나 썼나"뿐.
	_special_ink_used = &""
	_special_strokes = 0
	_total_strokes = 0
	_refresh_trace()                     # 진 가이드부터 다시 세운다
	queue_redraw()
	stage_advanced.emit(_asm.stage())
	assembly_changed.emit()


func ring_summary() -> String:
	# 🔴 **어휘 전체**로 센다 (세션 47). 예전엔 {응집, 발산} 둘만 세워 놨는데 세션 44에 관통이
	# 늘면서 관통을 놓은 진을 요약하면 `counts[2] += 1`이 **없는 키**라 런타임 에러였다 —
	# 어휘를 늘릴 때 여기를 같이 안 늘리면 조용히 깨진다. GLYPH_NAMES에서 세운다.
	var counts := {}
	for g in GLYPH_NAMES.size():
		counts[g] = 0
	var open := _asm.get_open()
	for k in open:
		var g := _asm.glyph_at(k)
		if g != GLYPH_NONE:
			counts[g] += 1
	var parts: Array[String] = []
	for g in GLYPH_NAMES.size():
		if counts[g] > 0:
			parts.append("%s×%d" % [GLYPH_NAMES[g], counts[g]])
	if parts.is_empty():
		return "빈 진" if open.is_empty() else "빈 칸 %d" % open.size()
	return " ".join(parts)


# ─────────────────────────── 기하 ───────────────────────────

func _area_center() -> Vector2:
	return size * 0.5

func _outer_radius() -> float:
	return minf(size.x, size.y) * 0.44

## 진 반지름 — 마우스 휠 크기 반영. 룬·고리·칸은 기준(_outer_radius)에 고정된다.
func _jin_radius() -> float:
	return _outer_radius() * _jin_scale

## 룬 삼각 크기 — 마우스 휠 반영.
func _rune_size() -> float:
	return _outer_radius() * 0.16 * _rune_scale

## 문양 칸 하나의 개별 크기 배율 (휠, 기본 1.0). 세션 15.
func _glyph_scale_of(slot: int) -> float:
	return float(_glyph_scale.get(slot, 1.0))

func _ring_radius() -> float:
	return _outer_radius() * RING_RADIUS_FRAC

## 각도 식의 정본은 static `slot_angle`(세션60) — 여기는 편의 별칭이다.
func _slot_angle(k: int) -> float:
	return slot_angle(k)

func _slot_pos(k: int) -> Vector2:
	return _area_center() + Vector2.from_angle(_slot_angle(k)) * _ring_radius()


# ─────────────────────────── 입력 (손으로 숨은 선 문지르기) ───────────────────────────
## 🔴 좌클릭 드래그로 가이드를 문지르면 먹선이 남는다. 누를 때마다 = 다시 그리기(덮어씀).
## 확정은 자동이 아니다 — 패널의 [다음]이 advance()를 부른다.

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# 🔴 문양 단계 — 누른 자리의 칸을 골라 편집한다 (세션 15). 다른 칸이면 이전 칸 자동 확정.
			# ⚠ 칸에서 멀면 _nearest_open_slot이 -1을 준다 → 칸을 안 바꾸고 현재 칸을 계속 그린다
			#   (세션 22 I3: 컷오프가 없어서 획 시작점이 옆 칸에 조금 가까우면 현재 칸이 멋대로 확정됐다).
			if _asm.stage() == STAGE_GLYPH:
				var k := _nearest_open_slot(mb.position)
				if k >= 0 and k != _trace_slot:
					select_slot(k)
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
	# 🔴 마우스 휠 — 지금 그릴 조각(진/룬/문양 칸)의 크기 조절 (세션 14c·15)
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_resize_current(SCALE_STEP)
		accept_event()
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_resize_current(-SCALE_STEP)
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _drawing:
		trace_stroke(mm.position)
		accept_event()


## 지금 그리는 조각의 크기를 바꾼다 — 가이드를 새 크기로 다시 세운다(현재 획은 지워짐).
func _resize_current(delta: float) -> void:
	match _trace:
		TraceTarget.JIN:
			# 🔴 상한은 종이 등급이 정한다 (세션29) — const가 아니라 _jin_scale_max (set_jin_scale_max).
			_jin_scale = clampf(_jin_scale + delta, JIN_SCALE_MIN, _jin_scale_max)
		TraceTarget.RUNE:
			_rune_scale = clampf(_rune_scale + delta, RUNE_SCALE_MIN, RUNE_SCALE_MAX)
		TraceTarget.GLYPH:
			# 🔴 문양은 **칸마다 개별** 크기 (세션 15). 지금 고른 칸의 화살표만 키운다.
			if _trace_slot < 0:
				return
			_glyph_scale[_trace_slot] = clampf(_glyph_scale_of(_trace_slot) + delta,
				GLYPH_SCALE_MIN, GLYPH_SCALE_MAX)
		_:
			return   # 없음 단계(열린 빈 칸 없음/완성)에선 휠 무시
	_set_trace(_trace, _trace_slot)   # 새 크기로 가이드 재생성
	queue_redraw()


# ─────────────────────────── 발사 스윕 · 착지 펄스 ───────────────────────────

func play_cast() -> void:
	_cast_t = 0.0
	set_process(true)


## ⓒ 색 인자 (세션62) — 잠근 조각의 색(진/룬/문양색)으로 펄스가 물든다. 내부 함수라
## (tests 미참조 — 설계에서 그렙 확인) 시그니처 변경이 안전하다. 기본값 = 옛 주홍.
func _start_pulse(at: Vector2, col: Color = FIRE_HI) -> void:
	_pulse_at = at
	_pulse_color = col
	_pulse_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	var busy := false
	if _cast_t >= 0.0:
		_cast_t += delta / _cast_dur
		if _cast_t >= 1.0:
			_cast_t = -1.0
		else:
			busy = true
	if _pulse_t >= 0.0:
		_pulse_t += delta / PULSE_DUR
		if _pulse_t >= 1.0:
			_pulse_t = -1.0
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
	# ⓓ 완성 발광 타이머
	if _finish_glow_t >= 0.0:
		_finish_glow_t += delta / FINISH_GLOW_DUR
		if _finish_glow_t >= 1.0:
			_finish_glow_t = -1.0
		else:
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

	# 🔴 잠근 조각들 — **그린 먹선을 그대로** 유지한다 (정답 모양으로 안 바꾼다).
	# 단, 지금 다시 그리는 칸/조각은 아래 '지금 그리는 조각'이 새 먹선으로 보여주니 건너뛴다.
	for L in _scorer.locked_pieces():
		if L.target == _trace and L.slot == _trace_slot:
			continue
		_draw_locked(L)

	# 구조 힌트 — 룬까지 그렸으면(문양 단계) 1차 고리 + 열린 빈 칸 위치만 연하게 안내
	if _asm.has_rune():
		draw_arc(ctr, _ring_radius(), 0.0, TAU, 64, RING_LINE, 1.0, true)
		for k in _asm.get_open():
			if _asm.glyph_at(k) == GLYPH_NONE:
				draw_arc(_slot_pos(k), ro * 0.05, 0.0, TAU, 16, SLOT_OPEN, 1.5, true)
		# 🔴 지금 고른(편집 중인) 문양 칸을 강조한다 — 어느 칸을 그리는지 보이게 (세션 15)
		if _trace == TraceTarget.GLYPH and _trace_slot >= 0:
			draw_arc(_slot_pos(_trace_slot), ro * 0.11, 0.0, TAU, 24, Color(FIRE_HI, 0.7), 1.5, true)

	# 🔴 지금 그리는 조각 — 숨은 정답 선(연하게) + 드러난 점(주황) + **그린 먹선 그대로**
	var guide := _scorer.guide_points()
	if _trace != TraceTarget.NONE and guide.size() >= 2:
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

	# ⓓ 완성 발광 — 잠긴 획 전체에 추가 글로우 + 바깥 반경을 훑는 밝은 호.
	# 기존 play_cast 스윕(_cast_t)과 별개다 — 그건 발사 연출, 이건 "다 그렸다" 연출.
	if _finish_glow_t >= 0.0:
		var fa := (1.0 - _finish_glow_t) * FINISH_GLOW_ALPHA
		for L in _scorer.locked_pieces():
			for s in L.strokes:
				if s.size() >= 2:
					draw_polyline(s, Color(_locked_color(L), fa), GLOW_WIDTH * 1.4, true)
		var a0 := _finish_glow_t * TAU - PI / 2.0
		draw_arc(ctr, ro, a0, a0 + FINISH_ARC_SPAN, 24, Color(FINISH_ARC_COLOR, fa), 3.0, true)

	# ⓒ 착지 펄스 ("탁") — 조각색 이중 고리(r·0.7r) + 중심 블룸 페이드
	if _pulse_t >= 0.0:
		var pa := (1.0 - _pulse_t) * 0.85
		var pr := maxf(_pulse_t * (ro * 0.34), 1.0)
		draw_arc(_pulse_at, pr, 0.0, TAU, 28, Color(_pulse_color, pa), 2.5, true)
		draw_arc(_pulse_at, maxf(pr * 0.7, 1.0), 0.0, TAU, 24,
			Color(_pulse_color, pa * 0.55), 1.8, true)
		draw_circle(_pulse_at, ro * PULSE_BLOOM_FRAC * (1.0 - _pulse_t),
			Color(1.0, 0.95, 0.8, pa * 0.35))


## 잠근 조각의 렌더 색 (조각 종류색). ⓓ 완성 발광도 같은 색을 쓴다 — 베끼면 갈라진다.
func _locked_color(L: TraceScorer.LockedPiece) -> Color:
	match L.target:
		TraceTarget.JIN:
			return _jin_color()
		TraceTarget.RUNE:
			return _rune_color()
		TraceTarget.GLYPH:
			return _glyph_color(L.glyph)
	return TRACE_INK


## 🔴 잠근 조각 = **그린 먹선 그대로** 렌더 (정답 모양 교체 없음). 색은 조각 종류로 구분.
## ⓐ 먹선마다 밑에 조각색 저알파 글로우 패스를 먼저 깐다 (정적 — process 부담 0).
func _draw_locked(L: TraceScorer.LockedPiece) -> void:
	var col := _locked_color(L)
	for s in L.strokes:
		if s.size() >= 2:
			draw_polyline(s, Color(col, GLOW_ALPHA_LOCKED), GLOW_WIDTH, true)
	for s in L.strokes:
		if s.size() >= 2:
			draw_polyline(s, col, 2.8, true)
