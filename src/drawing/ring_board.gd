extends Control
## 고리 조립 보드 — forge 왼쪽 페이지에 얹히는 **조립 판**.
## 기하(어디에 그리나) + `_draw` + `_gui_input` + 애니만 든다. 조립 상태는 `ring_assembly`,
## 채점은 `trace_scorer`가 쥔다 — 🔴 **채점 규칙을 바꿀 땐 `trace_scorer.gd`만 연다.**
##
## 🔴🔴 **라이브 모드는 COMBINED 하나다** — 밑그림은 `compose_guide_paths`가 한 장으로 합성하고
## 진입점은 `enter_combined_trace` 하나다. per-piece(조각을 하나씩 긋고 잠그던 경로)를
## **되살리지 마라 — 라이브와 두 몸이 된다.**
## 🔴 **그리기 폐지 스위치(`balance.skip_drawing`)가 되살리는 것 = 절대 지우지 마라**:
##   `enter_combined_trace` · `begin_stroke`/`trace_stroke`/`clear_stroke` ·
##   `coverage`/`accuracy`/`combined_total` · 펜 보정 · 잉크 정산.
##
## 🔴 이 보드는 **선택을 스스로 쥐지 않는다.** 선택의 정본은 패널이고, 판은 `set_defs`(색·이름)와
## `enter_combined_trace`(점열)만 받는다. 오토로드·모듈 의존 없음.
##
## 사용: const RingBoard := preload("res://src/drawing/ring_board.gd")

const RingAssembly := preload("res://src/drawing/ring_assembly.gd")
const TraceScorer := preload("res://src/drawing/trace_scorer.gd")

# ── 조립 계약 재노출 ──
#   `SLOTS`·`GLYPH_NONE`·`RUNE_FIRE`는 이 파일·패널·책이 쓴다. 🔴 내리면 컴파일 실패.
#   ⚠ `STAGE_*` 셋은 참조가 0곳이다(per-piece 단계기의 잔재) — 새로 쓰지 마라.
const SLOTS := RingAssembly.SLOTS
const GLYPH_NONE := RingAssembly.GLYPH_NONE
const STAGE_JIN := RingAssembly.STAGE_JIN
const STAGE_RUNE := RingAssembly.STAGE_RUNE
const STAGE_GLYPH := RingAssembly.STAGE_GLYPH
const RUNE_FIRE := RingAssembly.RUNE_FIRE

# ── 문양 어휘 ──
## 🔴 값은 **core가 쥔다**(`Enums.GlyphCode` = 발사 계약). 여기서 다시 정의하면 언젠가 갈라진다.
const G_GATHER := Enums.GlyphCode.GATHER    # 응집 ← — 안쪽(룬) 방향 화살표
const G_RADIATE := Enums.GlyphCode.RADIATE  # 발산 → — 바깥(진) 방향 화살표
const G_PIERCE := Enums.GlyphCode.PIERCE    # 관통 ↠
const G_HOMING := Enums.GlyphCode.HOMING    # 유도 ∿
const G_BOUNCE := Enums.GlyphCode.BOUNCE    # 팅김 ⚡
const G_THRUST := Enums.GlyphCode.THRUST    # 추진 ↑
## 변형형 문양 — 스스로 전개하지 않고 안쪽 층의 결과를 바꾸는 연산자다.
## ⚠ 계열 판별의 단일 소스는 그 문양 `.tres`의 `behavior`다. 판은 계열을 안 가른다(밑그림 한 갈래뿐).
const G_SPREAD := Enums.GlyphCode.SPREAD    # 확산 ⋔
const G_EXPLODE := Enums.GlyphCode.EXPLODE  # 폭발 ∗
const G_CONDENSE := Enums.GlyphCode.CONDENSE # 응축 ◈
## 🔴 문양 이름·색 배열을 여기 되살리지 마라 — 정본은 `GlyphDef.display_name`·`ui_color`다.
## 배열이던 시절엔 **길이가 계약**이라 어휘를 늘릴 때 런타임 에러가 났고, clampi가 어휘 밖
## 코드를 조용히 눌렀다. 문양 선택은 키가 아니라 오른쪽 셀 **클릭**이다(진·룬과 같은 조작).

# ── 색 (먹·양피지 톤) ──
const RING_LINE := Color(0.42, 0.30, 0.12, 0.55)
const FIRE_HI := Color(0.95, 0.55, 0.15)
## 룬 색 폴백 — 🔴 소비자는 **책의 룬 셀**이다(판엔 룬 렌더가 없다). 여기가 그 단일 소스다.
const RUNE_COLOR := Color(0.62, 0.22, 0.12)   # 불
const TRACE_INK := Color(0.20, 0.14, 0.09, 0.95)    # 그린 먹선
## 숨은 가이드 (아직 안 드러남).
## ⚠ 더 진하게 하면 "숨은 선"이 아니라 그냥 답이 된다 — 따라 그을 만큼만 보여야 한다.
const GUIDE_HIDE := Color(0.42, 0.30, 0.12, 0.32)
const GUIDE_SHOW := Color(0.80, 0.50, 0.16, 0.55)   # 드러난 가이드 강조

const GUIDE_CIRCLE_N := 72            # 진 가이드 밀도 (도형이 뭐든 이 등분 수에 맞춘다 — 아래 주석)

# ── 진 밑그림 도형의 기하 상수 ────────────────────────────────────────
# 🔴 셋 다 **룬 자리를 남기는 하한**에 걸려 있다 — 진은 룬을 담는 그릇이라, 도형이 중심을 향해
# 더 파고들면 안쪽 룬과 겹친다. 그런데 **겹쳐도 에러가 안 난다** — 그려 보고서야 안다.
# ⚠ 룬 크기를 여기 베끼지 말고 `combined_rune_size(ro, 자리수)`를 불러 재라.
const JIN_ELLIPSE_X := 0.68           # 세로 긴 타원의 가로 반지름 비
const JIN_FLOWER_PETALS := 6
const JIN_FLOWER_DEPTH := 0.13        # 물결 골 깊이 — 얕게. 깊으면 룬 자리를 먹는다
const JIN_LENS_X := 0.60              # 렌즈 허리의 가로 반지름 비

# ── 진 크기 상한 (종이 축이 은퇴해 지금은 1.0 고정) ──
const JIN_SCALE_MIN := 0.72
const JIN_SCALE_MAX := 1.16

# ── 문양 화살표의 생김새 ────────────────────────────────────────
# 🔴 **화살촉은 붓의 드러남 반경(`REVEAL_RADIUS_FRAC`)보다 멀리 있어야 한다.** 안쪽이면 몸통을
# 긋는 순간 화살촉이 통째로 드러나 화살표가 「붓 한 자국」이 되고, 그릴 이유 자체가 사라진다.
# ⚠ 이 둘을 만지면 그 비율을 다시 재라 — 테스트는 결과만 못 박고 이유는 여기 있다.
const ARROW_BACK_FRAC := 0.5
const ARROW_SIDE_FRAC := 0.62

## 지금 손으로 그릴 대상. ⚠ **라이브 값은 NONE / COMBINED뿐이다** — JIN/RUNE/GLYPH는
## per-piece 시절의 잔재로 읽는 코드가 0곳이다. 새로 쓰지 마라.
enum TraceTarget { NONE, JIN, RUNE, GLYPH, COMBINED }

# ── 합성 상수 (연출/레이아웃 → 스크립트 const, 밸런스 아님) ──
const RUNE_GUIDE_FRAC := 0.18        # 합성 가이드에서 룬(중심)의 크기 (판 반지름 비)
## ⚠ 자리 1개면 아래 둘을 **안 탄다** — 룬은 중심 하나로 남는다.
const RUNE_SPLIT_FRAC := 0.28        # 융합진 룬 자리를 중심에서 벌리는 거리 (판 반지름 비)
const RUNE_MULTI_SIZE_FRAC := 0.68   # 자리 2개 이상일 때 룬 하나를 이만큼 줄인다 (겹침 방지)
const BAND_RADII := [0.42, 0.68]     # 동심원 밴드 반경 비 목록 (안쪽부터). 진은 앞 band_count개만 쓴다
const MOTIF_SIZE_FRAC := 0.14        # 밴드 반경 대비 문양-고리 낱개 모티프 크기

# ── 빈 층/룬 자리 가이드 (연출값 — 절차 렌더라 도형 금지의 예외) ──
const BAND_GUIDE_COLOR := Color(0.42, 0.30, 0.12, 0.22)   # 따라 그을 만큼만, 답은 아니게
const BAND_GUIDE_WIDTH := 1.5
## 층 선은 문양 **바깥으로 밀어 「띠」로** 그린다 — 선 하나가 문양 중심 반경을 지나면 모티프를 가로지른다.
## ⚠ **그런데 패널이 DRAW에서 선을 아예 끄는 우회도 아직 켜져 있다**(`show_band_lines`).
##   「띠가 우회를 대체한다」인지 「미리보기에서만 보인다」인지는 미결이다 —
##   정하기 전에 이 주석과 패널 인자 중 **한쪽만** 고치지 마라.
## 🔴 여백만 상수다 — 띠 경계는 `band_lane`이 **모티프 크기에서 파생**한다. 값을 베끼면
##   문양 크기를 바꿀 때 선이 안 따라와 다시 겹친다.
const BAND_LANE_PAD := 0.02
const RUNE_SLOT_COLOR := Color(0.42, 0.30, 0.12, 0.28)    # 룬 미선택 자리 마커(중앙 링)
const RUNE_SLOT_WIDTH := 1.5

## 지금 그리는 조각의 점수가 갱신됐다 (실시간) — 패널이 현재 점수를 보여준다.
signal score_changed(score: float)
## 🔴 한 획을 뗐다 — 패널이 **획이 끝난 뒤에** 잉크 팔레트를 다시 그리게 하는 신호다.
## (그리는 도중 특별잉크가 소모돼 팔레트가 재빌드되면 활성 잉크가 획 중간에 바뀐다.)
signal stroke_ended

var _asm := RingAssembly.new()
var _scorer := TraceScorer.new()

# ── 데이터 정의 — 패널이 Db에서 읽어 주입한다. ──
# ⚠ 판이 실제로 읽는 건 `_glyph_defs`뿐이다 — 아래 둘은 채워지기만 하고 읽는 자리가 0곳이다
#   (진·룬 색의 라이브 소비자는 책이고 거기는 자기 `set_defs`로 따로 받는다).
var _jin_def: JinDef = null
var _rune_defs: Dictionary = {}         # {Enums.RuneType: RuneDef}
var _glyph_defs: Array[GlyphDef] = []

## 지금 긋는 획의 색 = 고른 잉크 색. 기본 = 먹.
var _trace_ink := TRACE_INK
## 🔴 고른 잉크 id — 색과 달리 **assembly에 실려** 발사·저장까지 간다(등급=데미지).
var _ink_id: StringName = &""
## 특별잉크 소모·비율. 완성 시 비율(_special_strokes / _total_strokes)이 화상 증폭 세기를 정한다.
var _special_ink_used: StringName = &""
var _special_strokes := 0
var _total_strokes := 0
var _jin_scale_max := JIN_SCALE_MAX
var _cast_t := -1.0
var _cast_dur := 1.3

## 🔴 지금 그릴 대상 — 라이브에선 **NONE 아니면 COMBINED뿐**이다.
var _trace := TraceTarget.NONE
var _drawing := false                   # 마우스 버튼 누른 채 긋는 중
var _stroke_counted := false            # 🔴 이 획을 잉크 정산에 넣었나 (최초 유효점에서 1회만)
var _jin_scale := 1.0                   # 진 규모 (종이 축 은퇴 후 1.0 고정)

# ── 그리기 연출 — 렌더 전용이라 채점·조립과 무관하다.
# ⚠ 전부 연출값(손맛)이라 스크립트 const다 — balance.tres 아님.
const GLOW_WIDTH := 7.0                 # ⓐ 먹선 밑 글로우 패스 폭 (먹선보다 넓게)
const GLOW_ALPHA_DRAWING := 0.12        # ⓐ 그리는 중 획 글로우 알파 (잉크색)
const SPARK_DUR := 0.25                 # ⓑ 반짝임 수명(초)
const SPARK_R0 := 1.2                   # ⓑ 광점 시작 반지름
const SPARK_R1 := 4.5                   # ⓑ 광점 끝 반지름 (커지며 사라진다)
const SPARK_ALPHA := 0.8                # ⓑ 광점 시작 알파 ((1-t)×이 값)
const SPARK_COLOR := Color(1.0, 0.88, 0.55)   # ⓑ 광점 색 (따뜻한 금빛)
## ⓕ 붓끝 발광 — 동심원 3장, 바깥(크고 흐림)부터 그려 안쪽(작고 밝음)이 위에 얹힌다.
## ⚠ 무타입 Array인 이유: GDScript는 const에 PackedFloat32Array 생성자를 상수식으로 안 받는다.
const BRUSH_GLOW_RADII := [10.0, 6.0, 3.0]
const BRUSH_GLOW_ALPHA := [0.06, 0.14, 0.30]

# ── 「마법진 완성」 연출 (연출값 = 스크립트 const, 밸런스 아님) ──
## 진입점은 공개 `play_finish()` 하나이고 패널이 맺는 순간에 부른다.
## 🔴 **안(룬)에서 바깥(진 윤곽)으로 훑는 게 이 연출의 뜻이다** — 층 순서 = 연산 순서라,
## 맺히는 순간에 그 순서를 한 번 더 보여 준다.
## ⚠ **순수 오버레이**다 — 입력을 막지 않고 리포트 표시를 늦추지 않는다.
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
## 🔴 채점 상태를 복사하는 게 아니라 "언제 드러났나"라는 렌더만의 관심사를 따로 든다.
var _was_revealed := PackedByteArray()
var _sparks: Array[Dictionary] = []     # ⓑ {pos: Vector2, t: float} — 광점들

## 완성 연출 진행도 — **-1 = 안 돎**, 0~1 = 도는 중.
var _finish_t := -1.0
## 서브패스별 정규 반지름(0=중심 · 1=바깥 테두리) — `play_finish`에서 한 번만 재는 렌더 전용 캐시.
var _finish_radii: PackedFloat32Array = PackedFloat32Array()

## COMBINED 서브패스(진·룬·밴드 각각) — **별도 폴리라인**으로 그려 이음선을 없앤다.
## 🔴 채점기는 flat만 본다 — 이 멤버는 **렌더 전용**이라 채점·발사와 무관하다.
var _combined_subpaths: Array = []
## COMBINED에서 층 구분 동심원을 그릴까 (미리보기=true·DRAW=false).
var _combined_show_bands := true
## 그릴 흐린 동심원(빈 층 자리) 개수 = 진 band_count. 0 = 안 그림.
var _combined_band_count := 0
## 🔴 **룬 자리 상태**(자리 순서대로 룬 타입, 음수=미선택) — 미선택 마커를 이걸로 그린다.
## 서브패스 **개수로 유추하지 마라**: 밴드가 모티프마다 append하므로 그 수에 오염돼,
## 융합진에선 마커가 엉뚱한 중심에 뜨거나 빈 자리 표식이 **에러 없이 통째로 사라진다**.
## 비었으면 호출자가 안 넘긴 것 → `_draw`가 옛 유추 폴백을 쓴다.
var _combined_runes: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_process(false)
	resized.connect(_on_resized)


## 판 크기가 바뀌면 채점기의 길이 기준을 다시 세운다 (거리 임계값이 전부 반지름 비례다).
## 🔴 여기서 가이드를 다시 **만들지 마라** — 합성 가이드의 소유자는 패널이라, 판이 재생성하면
## 리사이즈 한 번에 밑그림이 **에러도 경고도 없이** 빈 가이드로 갈린다.
func _on_resized() -> void:
	_scorer.set_reference_radius(_outer_radius())
	queue_redraw()


# ─────────────────────────── 단계 조회 (조립 상태기계에 위임) ───────────────────────────
## 🔴🔴 아래 위임 조회들의 src 호출자는 **0곳**이고, `_asm`은 라이브에서 아무도 안 바꾼다
## (`ring_assembly.gd` 머리말 참조) — 즉 늘 초기 상태를 돌려준다. **판정에 쓰지 마라.**

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

## 조립기(무엇이 놓였나)와 채점기(얼마나 잘 그렸나)를 합치는 유일한 자리 — 둘 다 쥔 게 보드뿐이다.
## 🔴 `score`가 여기서 안 실리면 발사도 저장도 점수를 알 길이 없다.
## ⚠ 그리는 도중에 불리면 그때까지의 부분 점수다 — 소비자는 맺을 때만 읽는다.
func get_assembly() -> Dictionary:
	var a := _asm.get_assembly()
	a["score"] = float(get_analysis().get("total", 0.0))
	a["ink"] = _ink_id      # 잉크 등급 배수가 발사·저장에 실린다
	a["special_ink"] = _special_ink_used
	a["special_ratio"] = float(_special_strokes) / float(maxi(_total_strokes, 1))
	a["size"] = _jin_scale
	return a


# ─────────────────── 합성 가이드 통째 트레이스 ───────────────────
## 합성 가이드를 통째로 긋는 모드로 들어간다 — **라이브 유일 진입점**이다.
## 조립 상태가 바뀔 때마다 패널이 부른다.
## `flat`은 채점기로 · `subpaths`는 렌더로(서브패스별 폴리라인 = 이음선 제거) · `band_count`는
## 빈 층 동심원 개수. 🔴 **`flat = flatten(subpaths)` 계약은 호출자가** 한 소스에서 만들어 지킨다.
## 🔴 `runes` = `compose_guide_paths`에 넘긴 **그 목록을 그대로** 한 번 더. 미선택 마커를 개수
## 유추가 아니라 상태로 그리기 위한 렌더 전용 인자다 —
## ⚠ 안 넘기면 깨진 유추 폴백으로 떨어진다(융합진 호출자는 **반드시 넘겨라**).
func enter_combined_trace(flat: PackedVector2Array, subpaths := [], band_count := 0,
		show_band_lines := true, runes := []) -> void:
	_trace = TraceTarget.COMBINED
	_scorer.set_reference_radius(_outer_radius())
	_scorer.set_correction(_pen_correction())
	_scorer.set_guide(flat)
	_combined_subpaths = subpaths
	_combined_band_count = band_count
	# 🔴 `duplicate()`가 계약이다 — 호출자의 배열을 물면 recompose 없이 마커만 몰래 갱신돼
	# 「가이드는 옛것, 마커는 새것」이 된다.
	_combined_runes = runes.duplicate()
	# ⚠ 이 스위치의 사연·미결은 `BAND_LANE_PAD` 주석 한 곳에 있다(여기 베끼지 마라).
	_combined_show_bands = show_band_lines
	_reset_reveal_fx()   # 옛 가이드의 유령 반짝임을 남기지 않는다
	queue_redraw()


## 합성 가이드를 통째로 그은 종합 점수 (완성도×정밀도).
## ⚠ 이걸 직접 부르지 마라 — 소비자는 패널 `_score_now()`를 거쳐야 모드가 안 갈린다.
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


## 🔴 **문양 코드별 밑그림** — 새 문양 = 여기 한 갈래.
##
## 🔴 **그리는 궤적이 서로 달라야 손이 문양을 기억한다.** 방향만 뒤집으면 여러 문양이
## 색·라벨만 다른 같은 화살표가 되고, 그리기가 사지선다로 주저앉는다.
##
## 공통 규율:
##   • **한붓그리기** — 가이드가 한 줄이어야 채점기가 이탈을 잰다(손은 여러 획으로 나눠도 된다).
##   • 꺾쇠·깃은 기준점 q로 **되돌아와서** 이어진다 — 끊기면 그 구간이 유령 선이 된다.
##   • ⚠ 총 길이는 이웃 칸 간격을 넘지 마라(추진의 1.1sz가 상한선이다).
##
## 🔴 **static · public인 이유**: 책의 미리보기 아이콘이 **이 함수를 그대로 부른다**.
## 책이 자기 화살표를 따로 그리면, 판의 밑그림을 갈라 놔도 **고를 때 보는 셀은 다 똑같아져**
## 밑그림을 가른 의미가 절반 날아간다.
## ⚠ 그래서 인스턴스 상태를 쓰면 안 된다 — 파라미터와 클래스 상수만 본다.
static func glyph_guide_pts(code: int, p: Vector2, outward: Vector2, sz: float) -> PackedVector2Array:
	var dir := -outward if code == G_GATHER else outward   # 응집만 안쪽(룬), 나머지는 바깥
	var side_u := dir.orthogonal()
	match code:
		G_PIERCE:
			# 몸통을 지나며 중간·머리에서 각각 꺾쇠. 꺾쇠는 q로 되돌아와 다음 구간으로 이어진다.
			var back := -dir * (sz * ARROW_BACK_FRAC)
			# ⚠ 0.9배까지만 좁힌다 — 더 좁히면 깃이 붓의 드러남 반경 안으로 들어와
			# 몸통을 긋는 순간 꺾쇠가 통째로 드러난다.
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
			# 뒤쪽 뿌리로 짧은 줄기가 들어오고, 거기서 앞으로 3갈래가 펴진다.
			# 갈래마다 뿌리로 **되돌아와** 다음 갈래로 이어진다(한붓그리기 규약).
			var fan := 0.62                       # 갈래 벌어짐(rad)
			var arm := sz * 1.3                   # 뿌리→갈래 끝
			var root := p - dir * (sz * 0.7)      # 뿌리 = 뒤쪽 한 점 (여기가 손의 축이다)
			var v3 := PackedVector2Array([p - dir * (sz * 1.1)])   # 줄기 꼬리 (1.1sz 상한)
			for a in [-fan, 0.0, fan]:
				v3.append_array(PackedVector2Array([root, root + dir.rotated(float(a)) * arm]))
			return _densify(v3, sz * 0.24)
		G_EXPLODE:
			# 중심에서 사방으로 뻗는 살 — 한 점을 반복해 지나는 유일한 손이다.
			# ⚠ **살 개수를 짝수로 바꾸지 마라** — 마주보는 두 살이 한 직선이 돼 손이 뭉개진다.
			var spokes := 5
			var ray := sz * 0.95
			var v4 := PackedVector2Array()
			for i in spokes:
				if i > 0:
					v4.append(p)
				v4.append(p + dir.rotated(TAU * float(i) / float(spokes)) * ray)
			return _densify(v4, sz * 0.24)
		G_CONDENSE:
			# 안으로 감기는 나선 — 의미(한 점으로 눌러 담는다)가 손 궤적 그대로다.
			# 🔴 **폭발과 손이 갈리는 게 이 모양의 존재 이유다** — 폭발은 중심을 여러 번 지나는
			# 직선 살, 이건 중심을 한 번만 지나며 꺾임 없이 계속 휜다. 방향만 뒤집은 안은
			# 손이 지나는 자리가 거의 같아 각하했다.
			var turns := 1.25                     # 감는 바퀴 수 — 1보다 커야 "감긴다"로 읽힌다
			var v5 := PackedVector2Array()
			for i in 29:
				var t := float(i) / 28.0          # 0(바깥) → 1(중심)
				var ang := t * TAU * turns
				var rad := sz * (1.0 - t * 0.88)  # 완전히 0으로 보내지 않는다 (끝점이 뭉개진다)
				v5.append(p + (dir * cos(ang) + side_u * sin(ang)) * rad)
			return v5
	# 응집←/발산→ — 🔴 **점 생성 순서가 곧 관측점이다**(테스트가 "앞 9점 = 몸통"으로 읽는다).
	var pts2 := PackedVector2Array()
	var tail := p - dir * sz
	var head := p + dir * sz
	for t in 9:                                   # 몸통
		pts2.append(tail.lerp(head, float(t) / 8.0))
	# 화살촉 — **한붓그리기**(머리→왼깃→머리→오른깃)라 가이드 한 줄로 화살표가 된다.
	var back2 := -dir * (sz * ARROW_BACK_FRAC)
	var side2 := side_u * (sz * ARROW_SIDE_FRAC)
	for w2 in [head + back2 + side2, head + back2 - side2]:
		for t in range(1, 5):
			pts2.append(head.lerp(w2, float(t) / 4.0))
		for t in range(1, 5):
			pts2.append(w2.lerp(head, float(t) / 4.0))
	return pts2


## 폴리라인 꼭짓점을 `step`px 간격으로 촘촘히 채운다 (마지막 꼭짓점 포함).
## 🔴 이 간격이 곧 **채점 밀도**다 — 성기면 붓 한 자국에 여러 점이 통째로 드러나
## "그릴 이유가 없는" 구간이 생긴다.
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


# ─────────────────── 조립본 → 한 장의 합성 가이드 ───────────────────

## 🔴 룬 자리 좌표의 **단일 소스**. 판·책·마커가 전부 이걸 불러야 자리가 안 갈린다.
## count ≤ 1 = [중심] · 2 = 좌우로 `RUNE_SPLIT_FRAC` 벌림 · ≥3 = 위(−90°)부터 균등 원배치.
## ⚠ static·인스턴스 상태 금지 — 헤드리스 관측점이다.
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


## 🔴 룬 하나의 크기 — 그을 것(가이드)과 볼 것(미선택 마커)이 **같은 값**을 써야 한다.
## 식을 두 벌로 두면 자리가 여럿일 때 마커만 커져 실제 룬과 어긋난다.
static func combined_rune_size(ro: float, slot_count: int) -> float:
	var s := ro * RUNE_GUIDE_FRAC
	if slot_count >= 2:
		s *= RUNE_MULTI_SIZE_FRAC   # 자리 여럿이면 겹치지 않게 룬을 줄인다 (1개면 무변경)
	return s


## 룬 하나의 **밑그림 점열** — 꼭짓점을 변마다 12등분해 이어 붙인 폴리라인.
## 🔴 이 루프를 호출부에 **다시 인라인하지 마라** — 예전에 두 벌이던 시절 크기 식이 갈라져
## 융합진에서 「본 것 ≠ 그을 것」이 될 뻔했다.
## ⚠ `if seg >= 0` 가드가 계약이다 — 꼭짓점이 1개 이하인 룬에서 마지막 점을 중복 추가하지 않는다.
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


## **아직 룬을 안 고른 자리**의 마커 좌표·반지름. 반환 = `[{at, r}, …]`(빈 배열 = 다 골랐다).
## 🔴 좌표·크기는 `rune_slot_positions`·`combined_rune_size` **정본을 그대로 부른다** —
## 각도·반지름을 베끼면 판 마커와 책 셀·HUD가 조용히 어긋난다.
## ⚠ public인 이유 = 마커 렌더는 헤드리스가 못 보지만 **이 좌표는 잴 수 있다**.
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


## `runes` = 자리 순서 룬 타입 배열. 빈 배열 = 룬 미선택(진 윤곽만).
## ⚠ 음수 자리는 서브패스를 건너뛰되 **자리 개수는 유지한다** — 안 그러면 나머지 룬 위치가 흔들린다.
static func compose_guide(jin_shape: int, runes: Array, band_defs: Array,
		ctr: Vector2, ro: float) -> PackedVector2Array:
	# 🔴 flat은 `compose_guide_paths`를 flatten해 **파생**한다 — 따로 만들면 채점(flat)과
	# 렌더(subpaths)가 언젠가 다른 점열을 본다.
	var out := PackedVector2Array()
	for sub in compose_guide_paths(jin_shape, runes, band_defs, ctr, ro):
		out.append_array(sub)
	return out


## 🔴 조립본을 **조각별 서브패스 배열**로 합성한다 — 밑그림의 단일 소스다.
## 반환 = `[진 윤곽, (룬…), 밴드0, 밴드1…]`. 🔴 **기존 static 팩토리만 불러 이어 붙인다 —
## 새 기하 규칙 0.** 그래야 「셀에서 본 모양 = 손으로 그을 모양」이 자동으로 유지된다.
## 🔴 **null 밴드 = 빈 서브패스로 자리만 남긴다** — flatten엔 무영향이면서 보드가 "빈 층 자리"를 센다.
## ⚠ static·인스턴스 상태 금지 — 헤드리스 테스트가 관측점으로 쓴다.
## 🔴 재구현할 때 갈라지는 세 자리: ⓐ 룬 점열은 `rune_subpath` 정본을 부른다(인라인 금지) ·
## ⓑ 밴드 frac은 **원본 인덱스 i**로 BAND_RADII[i](null을 건너뛴 압축 카운터 금지) ·
## ⓒ flat = flatten(subpaths). 셋 중 하나만 어겨도 골든과 어긋난다.
static func compose_guide_paths(jin_shape: int, runes: Array, band_defs: Array,
		ctr: Vector2, ro: float) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	# ① 진 윤곽 (바깥 닫힌 도형)
	paths.append(jin_guide_pts(jin_shape, ctr, ro))
	# ② 룬(들) — 룬마다 **자기 서브패스**(이음선 없음). 음수 자리는 건너뛴다.
	# 🔴 좌표·크기·점열은 전부 정본 함수를 부른다 — 미선택 마커가 같은 함수를 써야
	# 「마커 크기 = 실제로 그을 룬 크기」가 유지된다.
	var rpos := rune_slot_positions(runes.size(), ctr, ro)
	var rsz := combined_rune_size(ro, runes.size())
	for ri in runes.size():
		var rt := int(runes[ri])
		if rt < 0:
			continue                  # 미선택 자리 — 서브패스 생략
		paths.append(rune_subpath(rt, rpos[ri], rsz))
	# ③ 밴드별 문양-고리 — 동심원 반경에 count번 깐다. null 밴드 = 빈 서브패스(자리만).
	for i in band_defs.size():
		var gr: GlyphRingDef = band_defs[i] as GlyphRingDef
		if gr == null:
			paths.append(PackedVector2Array())   # 빈 층 자리 — flatten엔 무영향, 렌더는 흐린 동심원
			continue
		var frac := float(BAND_RADII[i]) if i < BAND_RADII.size() \
			else float(BAND_RADII[BAND_RADII.size() - 1])
		# 🔴 **각 모티프를 별도 서브패스**로 append한다 — 한 밴드를 하나로 묶으면 draw_polyline이
		# 모티프 끝→다음 첫 점을 이어 링을 가로지르는 거미줄이 생긴다.
		for sub in glyph_ring_subpaths(gr, ctr, ro * frac):
			paths.append(sub)
	return paths


## 문양-고리 한 장을 밴드 둘레에 `gr.count`번 깐다 → **모티프마다 별도 서브패스**.
## 회전 규약은 `slot_angle`과 같다(위=0 시계방향). 🔴 모티프 점열은 `glyph_guide_pts` 정본을 쓴다.
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


## 층 i의 **띠 경계 두 반지름** = `Vector2(안쪽선, 바깥선)`. 문양은 그 사이에 들어앉는다.
## 🔴 **모티프 크기에서 파생한다** — 반지름을 상수로 박으면 문양을 키울 때 선이 제자리라
## 다시 모티프를 가로지른다.
## ⚠ **문양 중심 반경(`BAND_RADII`)은 안 건드린다** — 그건 발사 층 계약이고 저장 도안·채점 골든이
## 그 값에 걸려 있다. 이 함수는 렌더 전용이라 계약을 안 스친다.
static func band_lane(band_index: int, ro: float) -> Vector2:
	var i := clampi(band_index, 0, BAND_RADII.size() - 1)
	var band_r := ro * float(BAND_RADII[i])
	# 🔴 `glyph_ring_subpaths`가 문양을 그릴 때 쓰는 크기 식 그대로여야 한다.
	var half := band_r * MOTIF_SIZE_FRAC + ro * BAND_LANE_PAD
	return Vector2(maxf(band_r - half, 0.0), band_r + half)


## 층 i의 **안쪽 경계선** 반지름 — 판에 실제로 그리는 선은 이것뿐이다(둘 다 그리면 선이 너무 많다).
## 🔴 경계는 **띠와 띠 사이의 빈 곳**에 놓는다 — 그래야 선이 칸막이가 되고 문양이 어느 선도 안 밟는다.
## ⚠ **가장 바깥 경계는 안 그린다** — 진 윤곽이 이미 그 자리의 칸막이다.
static func band_edge(band_index: int, ro: float) -> float:
	var i := clampi(band_index, 0, BAND_RADII.size() - 1)
	var lane := band_lane(i, ro)
	var inner_side := combined_rune_size(ro, 1) if i == 0 else band_lane(i - 1, ro).y
	return (inner_side + lane.x) * 0.5


## 밴드 문양-고리를 이어붙인 한 점열. ⚠ **호출자가 0곳이다** — 남길지 걷을지 결정 대기.
## 🔴 렌더엔 `glyph_ring_subpaths`를 써라 — 이 concat을 draw_polyline에 바로 넘기면
## 모티프 끝→다음 첫 점이 이어져 거미줄이 된다.
static func glyph_ring_pts(gr: GlyphRingDef, ctr: Vector2, band_r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for sub in glyph_ring_subpaths(gr, ctr, band_r):
		out.append_array(sub)
	return out


## 🔴 밴드별 (motif × count)를 **층 배열**로 만든다 — 발사 계약.
## 반환 = `[[8칸], [8칸], …]` (밴드 순서 = 안→밖 = **연산 순서**). 발사부가 이 순서대로 층을 훑는다.
## 🔴 `flatten_bands`를 쓰지 마라 — 8칸 하나로 뭉개면 순서가 사라져 `폭발(확산)`과 `확산(폭발)`이
## 구분되지 않는다.
## ⚠ static·인스턴스 상태 금지 — 헤드리스 테스트가 이 함수를 그물로 쓴다.
static func layer_rings(band_defs: Array) -> Array:
	var out: Array = []
	for gr_v in band_defs:
		var ring: Array = []
		for k in SLOTS:
			ring.append(GLYPH_NONE)
		var gr: GlyphRingDef = gr_v as GlyphRingDef
		if gr != null:
			# 🔴 칸 0부터 count개 — 발산 계열은 **칸 인덱스가 곧 탄 각도**다.
			# 빈 밴드도 층 자리를 지킨다(건너뛰면 감쌈 깊이가 밀린다).
			for i in mini(maxi(gr.count, 1), SLOTS):
				ring[i] = int(gr.motif)
		out.append(ring)
	# 🔴 밴드 0개여도 **빈 층 하나는 돌려준다** — 빈 배열을 주면 발사부가 `rings.is_empty()`에서
	# 통째로 접혀 「빈 진도 날아가 몸으로 때린다」 계약이 조용히 깨진다.
	if out.is_empty():
		var empty: Array = []
		for k in SLOTS:
			empty.append(GLYPH_NONE)
		out.append(empty)
	return out


## 🔴🔴 **바로 위 `layer_rings`의 역함수** — 저장된 정수 층 배열에서 `band_defs`를 재구성한다.
## 도안은 `.tres`에 정수만 저장하므로, 맺어 둔 마법진을 **다시 그리려면** 이 길뿐이다.
## 🔴 **위 함수와 짝이라 나란히 둔다 — 한쪽만 고치면 조용히 갈라진다.** 정방향 규칙을 여기 베끼지
## 말고 **왕복으로 재라**(그물 = `tests/test_band_inverse_auto.gd`).
##
## 🔴 **복원되는 건 `motif`·`count` 둘뿐이다** — 나머지 필드를 읽지 마라.
## ⚠ `id`·`display_name`을 빈 값으로 **지우는 게 계약**이다: 스키마 기본값이 실존하는 고리라
## 그냥 두면 합성본이 **진짜 고리인 척하고** `Db.get_glyph_ring`이 엉뚱한 걸 돌려준다.
## 🔴 **빈 층 = `null` 밴드**로 자리를 남긴다 — 압축하면 뒤 층의 `BAND_RADII[i]`가 밀려
## 바깥 층이 안쪽 반경에 그려진다.
## ⚠ 알려진 한계: 한 겹에 여러 모티프가 섞인 옛 도안은 **첫 모티프 + 칸 수**로 뭉갠다.
##   발사는 멀쩡하고(`rings`를 직접 읽는다) **그림만 거짓말한다.**
static func band_defs_of(rings: Array) -> Array:
	var out: Array = []
	# 🔴 층 판별은 **core 단일 소스를 그대로 부른다** — 판별식을 여기 복사하면 갈라진다.
	for layer_v in RingDesign.layers_of(rings):
		var layer: Array = layer_v
		var motif := GLYPH_NONE
		var count := 0
		for k in layer.size():
			var g := int(layer[k])
			if g == GLYPH_NONE:
				continue
			if motif == GLYPH_NONE:
				motif = g       # 섞여 있으면 **첫** 모티프가 층 전체를 대표한다(위 한계)
			count += 1
		if count == 0:
			out.append(null)    # 빈 층 = 빈 밴드. 🔴 건너뛰면 BAND_RADII 정렬이 밀린다
			continue
		var gr := GlyphRingDef.new()
		gr.motif = motif
		gr.count = mini(count, SLOTS)   # 정방향이 같은 자리에서 클램프한다
		gr.id = &""                     # 🔴 지우지 마라 — 기본값이 실존 id다
		gr.display_name = ""
		out.append(gr)
	return out


## 밴드들을 8칸 링 하나로 플래튼한다. 예: 발산×3 + 응집×3 → [1,1,1,0,0,0,-1,-1].
## 🔴 **새 코드에서 부르지 마라 — 층 순서가 조용히 사라진다.** src 호출자는 0이고, 남은 소비자는
## 「밴드가 하나뿐이면 층0 == flatten」을 재는 회귀 그물 하나뿐이라 그 기준자로만 살려 둔다.
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


## 🔴 **진 종류별 밑그림** — 새 진 = 여기 한 갈래.
## 공통 규율:
##   • 🔴 **반드시 닫힌다**(`_closed`가 그 한 점을 책임진다) — 진은 룬을 담는 그릇이라 터진 도형은 그릇이 아니다.
##   • 🔴 **중심을 비워 둔다** — 안에 룬이 앉을 자리가 남아야 한다. 새 도형은 수치를 베끼지 말고
##     `combined_rune_size`를 불러 실측하고 넣어라.
##   • 🔴 **점 밀도를 맞춘다**(`GUIDE_CIRCLE_N` 등분) — 완성도가 "점 중 몇 %"라 점 수가 도형마다
##     다르면 **채점이 도형마다 유불리**를 갖는다.
## 🔴 **static · public인 이유**: 책의 진 셀 아이콘이 이 함수를 그대로 부른다 —
## 「셀에서 본 모양 = 손으로 그을 모양」이 구조적으로 못 갈라지게.
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


## 8점 칸 다이어그램 — 칸 k마다 `{pos, open}`을 담아 SLOTS개를 돌려준다.
## `slots` = 이 도안이 **실제로 채운 칸들**(층들의 합집합). HUD·Tab이 넘긴다.
## ⚠ 점은 **원주 고정**이다 — 진 윤곽이 삼각·타원이어도 판의 칸은 원 위에 있다.
## 🔴 static·public = 헤드리스 관측점. 인스턴스 상태 금지.
static func jin_slot_dots(slots: Array, c: Vector2, s: float) -> Array:
	var out: Array = []
	for k in SLOTS:
		out.append({
			"pos": c + Vector2.from_angle(slot_angle(k)) * s,
			"open": k in slots,
		})
	return out


## 🔴 칸 k의 각도 — **"칸 0=위, 시계방향" 규약의 단일 소스.** 책 다이어그램·HUD 슬롯·
## 문양-고리 배치가 전부 이걸 부른다. 한쪽에 식을 베끼면 규약이 바뀔 때 조용히 어긋난다.
static func slot_angle(k: int) -> float:
	return TAU * float(k) / float(SLOTS) - PI / 2.0


## 🔴 룬 종류별 밑그림 꼭짓점 (닫힌 다각형, 마지막=처음) — 새 룬 = 여기 한 갈래.
## 공통 규율:
##   • **반드시 닫힌다** — 룬은 진 안에 앉는 하나의 인장이라 터진 획은 룬이 아니다.
##   • **서로 다른 손 궤적을 준다** — 색만 다르면 그리기가 N지선다가 된다. 같은 변 수라도
##     꺾이는 자리를 다르게 둔다(흙=축 나란한 사각 vs 바람=45° 돌린 마름모).
##   • **꼭짓점 수를 3~7에 둔다** — 호출부가 변마다 12등분하므로 꼭짓점이 많으면 그 룬만
##     가이드가 촘촘해져 **완성도 채점이 룬마다 유불리**를 갖는다.
##     🔴 **불은 이 상한의 명시 예외다**(곡선이라 점이 수십 개) — 근거는 그 유불리를 만드는
##     완성도 채점 자체가 `skip_drawing`으로 휴면이라는 것이다.
##     ⚠ 채점을 되살리면 이 예외부터 다시 재라.
## 🔴 **static · public인 이유**: 책의 룬 셀 아이콘이 이 함수를 그대로 부른다 —
## 모양을 베껴 두면 「셀에서 본 모양」과 「손으로 그을 모양」이 갈라진다.
static func rune_guide_verts(rune_type: int, ctr: Vector2, s: float) -> PackedVector2Array:
	match rune_type:
		Enums.RuneType.FIRE:
			# 소용돌이를 감싼 불꽃 — 혀 3갈래 + 왼쪽 아래로 휜 갈고리 꼬리 + 중심의 소용돌이.
			#
			# 🔴 **닫힌 한붓이라 소용돌이는 「홈의 두 벽」으로 낸다** — 나선은 중심이 막다른 끝이라
			#   되돌아 나오지 않으면 못 닫힌다. 안쪽 벽 A가 풀려 나와 꼬리·혀를 돌고, 바깥 벽 B가
			#   다시 감겨 들어가 중심에서 A와 만난다.
			# 🔴🔴 **두 벽은 반경이 아니라 각도로 어긋난다** — 반경 오프셋으로 두면 안쪽 입술이
			#   소용돌이 가장자리보다 **안**에 놓여 꼬리로 나가는 선이 바깥 윤곽을 가로지른다.
			# ⚠ 감는 바퀴 수를 늘리지 마라 — 실제 배치 크기에서 홈·살이 눌려 검은 뭉치가 된다.
			# ⚠ 꼭짓점이 수십 개인 유일한 룬이다(머리말 「3~7」의 명시 예외).
			var pts := PackedVector2Array()
			# 이차 베지어 한 구간. 시작점 `a`는 이미 들어가 있다고 보고 t>0만 낸다(중복 방지).
			var qc := func(a: Vector2, c: Vector2, b: Vector2, n: int) -> PackedVector2Array:
				var o := PackedVector2Array()
				for i in range(1, n + 1):
					var t := float(i) / float(n)
					var u := 1.0 - t
					o.append(a * (u * u) + c * (2.0 * u * t) + b * (t * t))
				return o
			var bc := ctr + Vector2(0.0, s * 0.45)   # 소용돌이 중심 — 불꽃 아래쪽에만 앉는다
			var rim := s * 0.52                      # 소용돌이 바깥 반경(두 입술이 여기 앉는다)
			var r_end := s * 0.12                    # 안쪽 끝(막다른 곳)
			var t_span := 0.90 * TAU                 # 감는 각도 — 더 감을수록 작은 크기에서 뭉친다
			var th_a := 2.75                         # 벽A 입술 = 꼬리가 나가는 자리(왼쪽 아래)
			var th_b := th_a - 2.60                  # 벽B 입술 = 오른쪽 혀에서 내려앉는 자리
			var narc := 12
			# ① 벽A — 홈의 안쪽 벽. 중심에서 각도가 **늘며** 밖으로 풀린다(시작점 = 닫힘점).
			# ⚠ 감는 향을 뒤집지 마라 — 벽B 입술이 오른쪽 위로 올라붙어 불꽃 아래-오른쪽이 텅 빈다.
			for i in narc + 1:
				var t := float(i) / float(narc)
				pts.append(bc + Vector2.from_angle(th_a - (1.0 - t) * t_span)
					* lerpf(r_end, rim, t))
			# ② 입술에서 그대로 이어지는 갈고리 꼬리 — 왼쪽 아래로 휘어 뾰족하게 끝난다.
			var tail := ctr + Vector2(-s * 0.70, s * 1.22)
			pts.append_array(qc.call(pts[pts.size() - 1],
				ctr + Vector2(-s * 0.34, s * 1.00), tail, 5))
			# ③ 꼬리 바깥선을 타고 올라가 왼쪽 혀 끝으로.
			# ⚠ 이 선과 소용돌이 왼쪽 가장자리 사이가 초승달의 두께다 — 벌리면 「잎사귀」가 된다.
			var mid := ctr + Vector2(-s * 0.80, s * 0.44)
			var lt := ctr + Vector2(-s * 0.64, -s * 0.76)
			pts.append_array(qc.call(tail, ctr + Vector2(-s * 0.84, s * 0.94), mid, 5))
			pts.append_array(qc.call(mid, ctr + Vector2(-s * 0.82, -s * 0.26), lt, 5))
			# ④ 혀 3갈래 — 왼쪽 → 골 → 가운데(가장 높다) → 골 → 오른쪽(작다).
			var v1 := ctr + Vector2(-s * 0.24, -s * 0.20)
			pts.append_array(qc.call(lt, ctr + Vector2(-s * 0.40, -s * 0.60), v1, 4))
			var top := ctr + Vector2(s * 0.02, -s * 1.20)
			pts.append_array(qc.call(v1, ctr + Vector2(-s * 0.18, -s * 0.72), top, 6))
			var v2 := ctr + Vector2(s * 0.32, -s * 0.34)
			pts.append_array(qc.call(top, ctr + Vector2(s * 0.26, -s * 0.80), v2, 5))
			var rt := ctr + Vector2(s * 0.62, -s * 0.56)
			pts.append_array(qc.call(v2, ctr + Vector2(s * 0.46, -s * 0.52), rt, 4))
			# ⑤ 오른쪽 혀 → 소용돌이 바깥 입술로 내려앉는다(이 구간이 오른쪽 윤곽이다).
			pts.append_array(qc.call(rt, ctr + Vector2(s * 0.70, -s * 0.12),
				bc + Vector2.from_angle(th_b) * rim, 5))
			# ⑥ 벽B — 홈의 바깥 벽. 각도가 줄며 안으로 감겨 중심에서 벽A와 만난다.
			for i in range(1, narc + 1):
				var t := float(i) / float(narc)
				pts.append(bc + Vector2.from_angle(th_b - t * t_span)
					* lerpf(rim, r_end, t))
			# ⑦ 🔴 닫는다 — 마지막 = 첫 점(홈의 막다른 끝을 잇는 캡). 룬은 하나의 인장이다.
			pts.append(pts[0])
			return pts
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
			# 잎사귀 — 위로 길게 뽑은 오각. 뾰족한 끝 + 넓은 밑동.
			return PackedVector2Array([
				ctr + Vector2(0, -s * 1.15), ctr + Vector2(s * 0.72, -s * 0.15),
				ctr + Vector2(s * 0.45, s * 0.85), ctr + Vector2(-s * 0.45, s * 0.85),
				ctr + Vector2(-s * 0.72, -s * 0.15), ctr + Vector2(0, -s * 1.15)])
		_:
			# 모르는 룬 = △. ⚠ 폴백이 크래시가 아니라 삼각형인 게 계약이다(룬이 늘어도 안 죽는다).
			return PackedVector2Array([
				ctr + Vector2(0, -s), ctr + Vector2(s * 0.87, s * 0.5),
				ctr + Vector2(-s * 0.87, s * 0.5), ctr + Vector2(0, -s)])


## 지금 그릴 대상·현재 점수 조회 (바깥이 안내문·점수 표시에 쓴다).
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


## 🔴 획이 **따로** 보관되는 게 계약이다 — 이어 붙이면 펜을 뗀 구간이 선이 돼 화살표가 삼각형이 된다.
func trace_strokes() -> Array[PackedVector2Array]:
	return _scorer.strokes()



# ─────────────────────────── 문지르기 (채점기에 위임) ───────────────────────────

## 🔴 새 획을 시작한다 — **앞서 그은 획은 남는다.** 여기서 지우면 한 조각 = 한 획이 강제돼
## 화살표처럼 획이 여러 개인 모양을 못 그린다. 다시 그리기는 `clear_stroke`다.
func begin_stroke() -> void:
	_scorer.begin_stroke()
	_stroke_counted = false   # 잉크 정산은 이 획의 최초 유효점에서 한다 (trace_stroke)


## 🔴 이 획을 잉크 정산에 넣는다 — **최초 유효점이 찍혔을 때만** 부른다.
## `begin_stroke`에서 부르면 먹선이 안 남는 **빈 클릭도** 특별잉크를 태워 눈에 안 보이게 샌다.
## 특별잉크가 바닥이면 소모·적립 없이 계속 그린다(그만큼 비율=효과가 낮아진다).
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
		return   # 바닥 = 소모·적립 없이 진행
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
	# ⓑ 새로 드러난 가이드 점 → 반짝임 적립. 가이드가 작아 유효점마다 훑어도 싸다.
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

## 마법진 분석 리포트 — 🔴 **죽은 코드가 아니다**: `get_assembly()`가 여기 결과를 `score`에 싣고,
## 그 `get_assembly()`를 패널이 특별잉크 집계 창구로 부른다.
## ⚠ 조각 잠금이 은퇴해 조각별 점수는 늘 비어 total 0이다 — 실제 점수는 패널 `_score_now()`가 쥔다.
func get_analysis() -> Dictionary:
	return _scorer.get_analysis(_asm.get_open())


# ─────────────────────────── 데이터 주입 (Db → 보드) ───────────────────────────

## 진·룬·문양 정의를 주입한다. 슬롯은 여전히 int code로 저장한다 — 발사 계약은 정수 그대로다.
## defs 없으면 아래 색 헬퍼가 const로 폴백한다.
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


func _glyph_def_by_code(code: int) -> GlyphDef:
	for d in _glyph_defs:
		if d.code == code:
			return d
	return null

## 🔴 색의 정본은 `GlyphDef.ui_color`다 — 보드는 오토로드를 안 보므로 주입된 defs에서 읽는다.
## ⚠ defs 주입 전엔 중립 먹선으로 떨어진다. 🔴 색 배열 폴백을 되살리지 마라 —
## 그게 `clampi`와 만나 어휘 밖 코드를 눌러 **엉뚱한 문양 색**으로 그리던 자리다.
func _glyph_color(code: int) -> Color:
	var d := _glyph_def_by_code(code)
	return d.ui_color if d else RING_LINE


## 🔴 **헤드리스 관측점** — 테스트가 `_glyph_defs` 같은 private을 더듬으면 리팩터 때 조용히 죽는다.
func glyph_color_of(code: int) -> Color:
	return _glyph_color(code)




# ─────────────────────────── 바깥이 주입하는 선택 ───────────────────────────

## 🔴 **여기 남은 건 주입뿐이다 — 선택을 판이 쥐지 않는다.**
##   • 진·룬 선택의 정본은 **패널**이고 판은 점열만 받는다.
##   • 문양은 낱개로 안 고른다 — 조립 단위가 **문양-고리**(motif × count)이고 책이 밴드에 끼운다.
## 선택 API를 판에 되살리면 `test_ring_assembly_auto`의 은퇴 목록이 빨개진다.

## 지금 긋는 획의 색 = 고른 잉크 색. 패널이 잉크를 고를 때마다 부른다.
func set_trace_ink(c: Color) -> void:
	_trace_ink = c
	queue_redraw()


## 고른 잉크 id — `get_assembly`가 실어 발사·저장에 등급 배수를 태운다.
## ⚠ `clear_all`은 이걸 안 지운다 — 잉크는 판 기하가 아니라 **지속되는 선택**이다.
func set_ink(id: StringName) -> void:
	_ink_id = id


## 진 확대 상한. ⚠ 종이 축이 은퇴해 src 호출자는 0이다 —
## `get_assembly()["size"]`가 아직 이 값을 싣기에 스키마 계약으로만 남겼다.
func set_jin_scale_max(v: float) -> void:
	_jin_scale_max = maxf(v, JIN_SCALE_MIN)
	_jin_scale = minf(_jin_scale, _jin_scale_max)
	queue_redraw()


## 판을 비운다 — 조립 상태·채점·연출 타이머를 처음으로 돌린다.
## ⚠ 여기서 가이드를 **다시 세우지 않는다** — 합성 밑그림의 소유자는 패널이고,
## 호출자가 이 직후 `recompose()`로 다시 넣는다.
func clear_all() -> void:
	_asm.clear()
	_scorer.clear()
	_trace = TraceTarget.NONE            # 빈 판 = 그릴 것 없음 (패널의 recompose가 다시 넣는다)
	_combined_subpaths = []
	_combined_band_count = 0
	_combined_runes = []
	_jin_scale = 1.0
	_reset_reveal_fx()
	# 판을 비웠는데 옛 마법진의 금빛이 계속 도는 건 거짓말이다.
	_finish_t = -1.0
	_finish_radii = PackedFloat32Array()
	# 🔴 여기서 지우는 건 "이번 진에 얼마나 썼나"뿐이다 — `_ink_id`·상한은 지속되는 선택이라 안 지운다.
	_special_ink_used = &""
	_special_strokes = 0
	_total_strokes = 0
	queue_redraw()


# ─────────────────────────── 기하 ───────────────────────────
## 통째 밑그림의 좌표는 static `compose_guide_paths`가 쥔다.

func _area_center() -> Vector2:
	return size * 0.5

func _outer_radius() -> float:
	return minf(size.x, size.y) * 0.44


# ─────────────────────────── 입력 (손으로 숨은 선 문지르기) ───────────────────────────
## 좌클릭 드래그 = 문지르기 · 우클릭 = 다시 그리기.
## ⚠ 확정은 판이 안 한다 — 패널이 리포트를 낸다. 🔴 점수도 패널 `_score_now()` 한 곳을 거친다.

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_drawing = true
			begin_stroke()                # 펜을 댔다 = 새 획 (앞 획은 남는다)
			trace_stroke(mb.position)
		else:
			_drawing = false
			stroke_ended.emit()           # 🔴 패널이 미뤄 둔 잉크 팔레트 재빌드를 여기서 흘린다
		accept_event()
		return
	# 우클릭 = **다시 그리기** — 획이 누적되므로 "지우고 처음부터"는 따로 있어야 한다.
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


## 「마법진 완성」 훅 — 패널이 부르는 공개 진입점.
## ⚠ 부르는 자리를 늘리지 마라 — 「완성」의 정의는 패널의 `_finish()` 하나다.
func play_finish() -> void:
	_finish_t = 0.0
	_finish_radii = _subpath_radii(_area_center(), _outer_radius())
	set_process(true)
	queue_redraw()


## 🔴 완성 연출 진행도 — **헤드리스 관측점**. 빛·색은 못 봐도 「훅이 실제로 불렸나」는 이걸로 잰다
## (조용히 안 불리는 게 이 연출의 실패 방식이다).
func finish_progress() -> float:
	return _finish_t


## 각 서브패스의 정규 반지름 — 룬(≈0) → 층 → 진 윤곽(≈1) 순서가 그대로 나온다
## = 파도가 훑는 순서가 곧 연산 순서다.
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


## 파도의 정규 반지름 (0=중심 → 1=바깥). ease-out이라 안쪽이 빠르고 바깥에서 느려진다.
## 🔴 아래 `finish_t_at_radius`가 이 식의 **역함수**다 — 한쪽만 고치면 룬 팝이 파도와 어긋난다.
static func finish_wave_frac(t: float) -> float:
	var u := clampf(t / FINISH_SWEEP_T, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


## 파도가 정규 반지름 r에 닿는 시점 — 🔴 위 `finish_wave_frac`의 역함수다(짝으로 고쳐라).
static func finish_t_at_radius(r_frac: float) -> float:
	return (1.0 - sqrt(1.0 - clampf(r_frac, 0.0, 1.0))) * FINISH_SWEEP_T


## 정규 반지름 r인 조각이 지금 얼마나 밝나 (0~1).
## 🔴 파도가 **지나가기 전엔 0**이다 — "아직 제 차례가 아니다"가 순서를 눈에 보이게 하는 자리다.
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
	# 완성 연출 — 수명이 다하면 스스로 꺼진다(순수 오버레이라 끝나도 남는 상태가 없다).
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

	# 빈 층 동심원(빈 층도 늘 보여 "여기가 1층" 구조가 읽힌다) + 룬 미선택 자리 마커.
	if _trace == TraceTarget.COMBINED and not _combined_subpaths.is_empty():
		# ⚠ DRAW에선 꺼진다(사연·미결 = `BAND_LANE_PAD` 주석). 룬 마커는 조립 안내라 늘 둔다.
		if _combined_show_bands:
			# 🔴 선은 **층을 가르는 칸막이 하나씩**뿐이다. 좌표는 `band_edge` 정본이 준다 —
			# 여기서 반지름을 계산하면 그게 곧 사본이다.
			for bi in _combined_band_count:
				draw_arc(ctr, band_edge(bi, ro), 0.0, TAU, 48,
					BAND_GUIDE_COLOR, BAND_GUIDE_WIDTH, true)
		# 🔴 미선택 마커는 **상태로** 그린다 — 좌표·크기는 `empty_rune_slot_marks`가 정본에서 뽑는다.
		if not _combined_runes.is_empty():
			for m: Dictionary in empty_rune_slot_marks(_combined_runes, ctr, ro):
				draw_arc(m["at"], float(m["r"]), 0.0, TAU, 24, RUNE_SLOT_COLOR, RUNE_SLOT_WIDTH, true)
		# ⚠ 룬 목록을 안 넘긴 호출자용 폴백 — 서브패스 **개수 유추**라 밴드 모티프 수에 오염된다.
		# 자리가 하나인 진에서만 옳다. 걷어야 할 폴백이지 목표 상태가 아니다.
		elif _combined_subpaths.size() <= _combined_band_count + 1:
			draw_arc(ctr, combined_rune_size(ro, 1), 0.0, TAU, 24, RUNE_SLOT_COLOR, RUNE_SLOT_WIDTH, true)

	# 🔴 지금 그리는 조각 — 숨은 정답 선(연하게) + 드러난 점(주황) + **그린 먹선 그대로**
	var guide := _scorer.guide_points()
	if _trace != TraceTarget.NONE and guide.size() >= 2:
		# 🔴 서브패스가 있으면 조각마다 별도 폴리라인으로 긋는다 — 한 줄로 이으면
		# 진 끝→룬 첫 점을 잇는 이음선이 생긴다.
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

	if _finish_t >= 0.0:
		_draw_finish(ctr, ro)


## 「마법진 완성」 렌더 — **순수 오버레이**(가이드·먹선 위에 얹기만 하고 가리지 않는다).
## 순서: ① 조각이 안→밖으로 차례로 빛나고 ② 파도 고리가 경계를 보여 주고 ③ 룬 자리가 팝 하고
## ④ 마지막에 바깥 테두리가 한 번 번쩍한다.
func _draw_finish(ctr: Vector2, ro: float) -> void:
	var t := _finish_t
	var wave := finish_wave_frac(t)
	# ① 조각이 파도에 닿는 순간 밝아진다 = **안에서 밖 = 연산 순서**.
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
	# ③ 룬 자리 팝 — 파도가 그 자리를 지나는 순간 고리 하나가 튄다.
	# 🔴 좌표·크기는 정본 함수를 그대로 부른다 — 각도를 베끼면 팝이 실제 룬에서 어긋난 자리에 뜬다.
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
