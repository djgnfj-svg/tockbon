extends Control
## 조각 선택기 — 고리 조립 제작대의 **오른쪽 페이지** (2026-07-16 방향 전환).
##
## 옛 forge_book처럼 **탭으로 넘겨 본다**: 진 · 룬 · 문양. 고른 것이 왼쪽 보드에 곧바로 적용된다.
##   • 🔴 진 탭 — **보유한 진을 격자로 열거**(세션48에 3→8종). 고른 진이 발사 형태·비행 경로와
##     **어느 문양 칸이 열리는지**(JinDef.glyph_slots — 옛 문양본 축을 세션60에 진으로 흡수)를 정한다.
##   • 룬 탭 — 불 하나 (열람용)
##   • 문양 탭 — 응집←·발산→ (진이 연 칸을 이걸로 채운다)
##
## 오토로드 의존 없음. 사용: const RingBook := preload("res://src/drawing/ring_book.gd")

const RingBoard := preload("res://src/drawing/ring_board.gd")

## 진을 골랐다 — 보드에 진(그릇)을 놓는다 (세션 13 순차 조립)
signal jin_selected(jin_id: StringName)
## 룬을 골랐다 — 보드 중심에 그 룬을 놓는다 (rune_type = Enums.RuneType, 세션 34)
signal rune_selected(rune_type: int)
## 문양을 골랐다 — 열린 칸을 한 칸 채운다 (RingBoard.G_*)
signal glyph_selected(glyph: int)

const TAB_JIN := 0
const TAB_RUNE := 1
const TAB_GLYPH := 2
const TAB_ORDER := [TAB_JIN, TAB_RUNE, TAB_GLYPH]
const TAB_LABEL := ["진", "룬", "문양"]

# ── 한지·먹 톤 ──
const INK := Color(0.13, 0.11, 0.10)
const DESC_COLOR := Color(0.44, 0.37, 0.30)
const NAME_COLOR := Color(0.24, 0.19, 0.14)
const CELL_BG := Color(0.86, 0.81, 0.70, 0.55)
const CELL_SEL_BG := Color(0.80, 0.74, 0.62, 0.95)
const CELL_LINE := Color(0.55, 0.48, 0.38, 0.45)
const SEL_EDGE := Color(0.72, 0.45, 0.15, 0.95)
const TAB_ON_BG := Color(0.80, 0.74, 0.62, 0.95)
const TAB_OFF_BG := Color(0.68, 0.62, 0.52, 0.75)
const TAB_ON_TEXT := Color(0.22, 0.16, 0.10)
const TAB_OFF_TEXT := Color(0.42, 0.37, 0.30)
const OPEN_DOT := Color(0.85, 0.50, 0.18)          # 진 셀 8점 다이어그램: 열린 문양 칸
const SHUT_DOT := Color(0.30, 0.26, 0.20, 0.4)     # 닫힌 칸

const TAB_H := 18.0
const TAB_GAP := 2.0

const TAB_DESC := [
	"진 — 바깥 그릇(형태). 발사 형태와 열리는 칸이 진마다 다르다.",
	"룬 — 중심 속성. 탁본으로 해독한 룬을 고른다.",
	"문양 — 열린 칸을 이걸로 채운다.",
]
## 문양 셀 설명 — **`_glyph_defs`가 주입 안 됐을 때만 쓰는 폴백**이다 (평소엔 `.tres`의 `desc`).
## 🔴 인덱스 = GlyphCode 값이라 `GLYPH_NAMES`와 **길이가 같아야 한다**. 세션44(관통 추가)에 여기가
## 2개인 채로 남아 `_glyph_rows`의 폴백이 인덱스 초과로 죽는 잠복 버그가 생겼다 — 폴백 경로라
## 아무도 안 밟아 세션47까지 살아 있었다. 아래 `_glyph_desc_at`이 이제 범위를 막는다.
const GLYPH_DESC := [
	"안쪽(룬)으로", "바깥(진)으로", "적을 뚫고 지나간다",
	"적을 쫓아간다", "벽에 튕긴다", "빠르게 날아간다",
]

var _stage := TAB_JIN                 # 진 탭부터 편다 (순차 조립)
var _active := RingBoard.G_RADIATE    # 지금 고른 문양 코드 (하이라이트)
var _jin_placed := false              # 진을 이미 놓았나 (탭 표식)
var _rune_placed := false             # 룬을 이미 놓았나
var _rune_choice := -1                # 지금 고른 룬 타입 (하이라이트) — -1=아직 (세션 34)
var _jin_choice: StringName = &""     # 지금 고른 진 id (하이라이트) — &""=아직 (세션44, 진=형태 선택)
var _tab_rects: Array[Rect2] = []
## 클릭 가능한 칸 — {rect, kind:"jin"/"rune"/"glyph", value}
var _cells: Array[Dictionary] = []

# ── 주입 데이터 (세션 13 구조화) — 패널이 Db에서 읽어 넣는다. 없으면 RingBoard const 폴백. ──
var _jin_defs: Array = []
## 🔴 해금된 룬들 (RuneDef 배열, 세션 34). 패널이 `is_unlocked`로 걸러 넘긴다 — 책은
## 오토로드를 안 봐서(주석 상단) 해금 판정을 직접 못 한다. 잠긴 룬은 셀 자체가 안 뜬다.
var _rune_defs: Array = []
var _glyph_defs: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Db에서 읽은 진·룬·문양 정의를 주입한다 (셀 이름·색을 여기서 열거한다).
## 🔴 runes = **해금된 룬만** (패널이 걸러 넘긴다) — 잠긴 룬은 셀이 안 뜬다 (세션 34).
func set_defs(jins: Array, runes: Array, glyph_defs: Array) -> void:
	_jin_defs = jins
	_rune_defs = runes
	_glyph_defs = glyph_defs
	queue_redraw()


## 문양 셀 행 — 주입된 def, 없으면 RingBoard const로 폴백. 통일 딕셔너리로 반환.
func _glyph_rows() -> Array:
	# 🔴 `key`(키 힌트)는 여기 없다 — 세션 25에 문양 고르기가 **마우스 클릭 전용**이 됐다.
	var rows: Array = []
	if _glyph_defs.is_empty():
		for g in RingBoard.GLYPH_NAMES.size():
			rows.append({"name": RingBoard.GLYPH_NAMES[g],
				"desc": _glyph_desc_at(g), "color": RingBoard.GLYPH_COLORS[g],
				"code": g})
	else:
		for d in _glyph_defs:
			rows.append({"name": d.display_name, "desc": d.desc,
				"color": d.ui_color, "code": d.code})
	return rows


## 폴백 설명 한 줄 — **어휘가 늘어도 책이 죽지 않게** 범위를 막는다.
## 새 문양을 `Enums.GlyphCode`에만 더하고 `GLYPH_DESC`를 잊어도 빈 줄이 뜰 뿐 크래시는 없다
## (세션44의 잠복 인덱스 초과가 세션47까지 살아 있던 이유 = 폴백 경로라 아무도 안 밟았다).
func _glyph_desc_at(g: int) -> String:
	return String(GLYPH_DESC[g]) if g >= 0 and g < GLYPH_DESC.size() else ""


func _jin_name() -> String:
	return String(_jin_defs[0].display_name) if not _jin_defs.is_empty() else "일반진"

func _jin_ui_color() -> Color:
	return _jin_defs[0].ui_color if not _jin_defs.is_empty() else RingBoard.RING_LINE


## 보드의 현재 상태를 받아 하이라이트를 맞춘다 (열 때·키 입력 시)
func sync_state(active_glyph: int) -> void:
	_active = active_glyph
	queue_redraw()


## 바깥(패널)이 단계 진행에 맞춰 탭을 넘겨 준다. placed 표식도 갱신.
func go_stage(tab: int, jin_placed: bool, rune_placed: bool) -> void:
	_stage = clampi(tab, 0, TAB_ORDER.size() - 1)
	_jin_placed = jin_placed
	_rune_placed = rune_placed
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


# ─────────────────────────── 입력 ───────────────────────────

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _tab_rects.size():
		if _tab_rects[i].has_point(mb.position):
			_stage = TAB_ORDER[i]
			queue_redraw()
			accept_event()
			return
	for cell in _cells:
		if not Rect2(cell.rect).has_point(mb.position):
			continue
		match String(cell.kind):
			"jin":
				_jin_choice = StringName(cell.value)   # 하이라이트 (세션44: 여러 진 셀)
				jin_selected.emit(StringName(cell.value))
			"rune":
				_rune_choice = int(cell.value)   # 하이라이트 (세션 34: 여러 룬 셀)
				rune_selected.emit(int(cell.value))
			_:
				_active = int(cell.value)
				glyph_selected.emit(_active)
		queue_redraw()
		accept_event()
		return


# ─────────────────────────── 렌더 ───────────────────────────

func _draw() -> void:
	_tab_rects.clear()
	_cells.clear()
	var font := ThemeDB.fallback_font

	var tab_w := (size.x - TAB_GAP * float(TAB_ORDER.size() - 1)) / float(TAB_ORDER.size())
	for i in TAB_ORDER.size():
		var stage: int = TAB_ORDER[i]
		var r := Rect2(float(i) * (tab_w + TAB_GAP), 0.0, tab_w, TAB_H)
		_tab_rects.append(r)
		var on := stage == _stage
		draw_rect(r, TAB_ON_BG if on else TAB_OFF_BG, true)
		draw_line(r.position, r.position + Vector2(r.size.x, 0.0), CELL_LINE, 1.0)
		if not on:
			draw_line(r.position + Vector2(0.0, r.size.y), r.position + r.size, CELL_LINE, 1.0)
		var text: String = TAB_LABEL[i]
		var fs := 10
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, TAB_H * 0.72),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TAB_ON_TEXT if on else TAB_OFF_TEXT)

	var body := Rect2(0.0, TAB_H, size.x, size.y - TAB_H)
	draw_rect(body, TAB_ON_BG, true)
	draw_rect(body, CELL_LINE, false, 1.0)

	var top := TAB_H + 8.0
	_text(font, Vector2(8, top), TAB_DESC[_stage], DESC_COLOR, 9)
	top += 20.0

	match _stage:
		TAB_JIN:
			_draw_jin_cells(font, top)
		TAB_RUNE:
			_draw_rune_cells(font, top)
		TAB_GLYPH:
			_draw_glyph_cells(font, top)


func _draw_single_cell(font: Font, top: float, name_text: String, desc: String,
		icon: String, kind: String, placed: bool, icon_col: Color) -> void:
	var cw := 120.0
	var ch := 120.0
	var r := Rect2((size.x - cw) * 0.5, top, cw, ch)
	_cells.append({"rect": r, "kind": kind, "value": 0})
	draw_rect(r, CELL_SEL_BG if placed else CELL_BG, true)
	draw_rect(r, SEL_EDGE if placed else CELL_LINE, false, 2.0 if placed else 1.0)
	_draw_icon(icon, r.get_center() + Vector2(0, -10.0), 30.0, [icon_col])
	var label := "✓ 그림" if placed else desc
	_text_center(font, r.position + Vector2(cw * 0.5, ch - 26.0), name_text, NAME_COLOR, 11)
	_text_center(font, r.position + Vector2(cw * 0.5, ch - 12.0), label,
		SEL_EDGE if placed else DESC_COLOR, 8)


## 진 탭 — **보유 진**을 셀로 열거 (세션44, 진=형태). 클릭 = 그 진 id가 jin_selected로 나간다.
## 진은 룬·문양과 나란한 선택 축 — 어느 진(단발·산탄·둘레…)에 그릴지 고른다. 잠긴 진은 배열에 없다.
##
## 🔴 세션48 — **격자로 감쌌다.** 세션44까지 셀을 한 줄에 몰아넣어 `cw = 전체폭/n`이었다. 진이
## 3→8로 늘자 셀이 1/8 폭(약 30px)으로 쪼그라들어 이름조차 넘쳤다 — **문양 탭이 세션47에 밟은
## 함정과 같은 것이다**(어휘 축이 늘면 폭이 아니라 줄 수가 늘어야 한다). 룬·문양이 이미
## 쓰는 규약(`i % cols` / `i / cols`)으로 통일했다.
## 🔴 설명은 **셀 안이 아니라 격자 아래 한 줄**(고른 진 것만)에 쓴다 — 3열 셀 폭(84px)에 한 줄
## 설명("가장 가까운 적을 스스로 겨눈다")이 안 들어간다. 문양 탭(2줄·6칸)은 들어가서 셀 안에 쓴다.
const JIN_COLS := 3
const JIN_CELL_H := 62.0
const JIN_GAP := 6.0
## 진 셀 아이콘의 윤곽 반지름 — 8점 칸 다이어그램도 이 원주 위에 앉는다 (세션60).
const JIN_ICON_S := 17.0

## 🔴 진 셀 격자 — **순수 함수**라 헤드리스가 잰다. `_draw_jin_cells`가 이걸 그대로 쓴다.
## ⚠ `_draw_*` 안에 계산을 두면 테스트가 렌더를 기다려야 하고(헤드리스는 `_draw`를 못 믿는다)
## 레이아웃 회귀를 못 잡는다 — 그래서 계산만 뽑았다.
static func jin_cell_rects(n: int, book_size: Vector2, top: float) -> Array:
	var out: Array = []
	var cols := maxi(mini(n, JIN_COLS), 1)
	var cw := (book_size.x - 16.0 - JIN_GAP * float(cols - 1)) / float(cols)
	for i in n:
		out.append(Rect2(8.0 + float(i % cols) * (cw + JIN_GAP),
			top + float(i / cols) * (JIN_CELL_H + JIN_GAP), cw, JIN_CELL_H))
	return out


## 탭 머리·설명을 뺀 본문 시작 y — 격자 계산과 `_draw`가 같은 값을 쓰게 상수화.
static func body_top() -> float:
	return TAB_H + 8.0 + 20.0


func _draw_jin_cells(font: Font, top: float) -> void:
	var defs := _jin_defs
	var n := maxi(defs.size(), 1)
	var cols := mini(n, JIN_COLS)
	var ch := JIN_CELL_H
	var nrows := ceili(float(n) / float(cols))
	var rects := jin_cell_rects(n, size, top)
	var sel_desc := ""
	for i in n:
		var jd := defs[i] as JinDef if i < defs.size() else null
		var jid := StringName(jd.id) if jd else &"jin_single"
		var jname := String(jd.display_name) if jd else "단발진"
		var jcol: Color = jd.ui_color if jd else RingBoard.RING_LINE
		var cw: float = rects[i].size.x
		var r: Rect2 = rects[i]
		_cells.append({"rect": r, "kind": "jin", "value": jid})
		var sel := _jin_choice == jid
		draw_rect(r, CELL_SEL_BG if sel else CELL_BG, true)
		draw_rect(r, SEL_EDGE if sel else CELL_LINE, false, 2.0 if sel else 1.0)
		# 진 아이콘 = 발사 형태(패턴) × 비행 경로(motion). 색만으로는 8지선다가 된다.
		var opaque := Color(jcol.r, jcol.g, jcol.b, 1.0)
		var icon_c := r.get_center() + Vector2(0.0, -8.0)
		for mark in jin_icon_marks(_jin_pattern_of(jd), _jin_motion_of(jd),
				icon_c, JIN_ICON_S, _jin_shape_of(jd)):
			if mark.size() >= 2:
				draw_polyline(mark, opaque, 2.0, true)
		# 🔴 8점 칸 다이어그램 — 이 진이 여는 문양 칸 (세션60, 옛 문양본 축을 진으로 흡수).
		# 단일 소스 = `JinDef.glyph_slots`를 **직접** 읽는다(사본 금지). 점 위치·열림 계산은
		# `RingBoard.jin_slot_dots`(순수 static = 헤드리스 관측점). ⚠ 점은 윤곽 반지름의 **원주
		# 고정**이다 — 진 윤곽이 삼각·타원이어도 판의 칸은 원 위라, 판과 읽는 방식이 같다.
		if jd != null:
			for dot: Dictionary in RingBoard.jin_slot_dots(jd.glyph_slots, icon_c, JIN_ICON_S):
				var open := bool(dot.open)
				draw_circle(dot.pos, JIN_ICON_S * (0.16 if open else 0.10),
					OPEN_DOT if open else SHUT_DOT)
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 12.0), jname, NAME_COLOR, 10)
		if sel:
			sel_desc = ("✓ 그림 — " if _jin_placed else "") + _jin_desc_of(jd)
	# 고른 진의 설명 한 줄 (격자 바로 아래). 아직 안 골랐으면 무엇을 하라는지 알린다.
	var dy := top + float(nrows) * (ch + JIN_GAP) + 2.0
	if sel_desc.is_empty():
		sel_desc = "셀을 클릭하면 왼쪽 판에 그 진의 밑그림이 뜬다."
	_text(font, Vector2(8.0, dy), sel_desc, SEL_EDGE if _jin_placed else DESC_COLOR, 8)


## 진 설명 한 줄 — **id로 찾는다**(인덱스 아님). 🔴 `GLYPH_DESC`가 세션44에 인덱스 초과로
## 잠복 크래시를 냈던 이유가 "배열 인덱스 = enum 값"이었다. 여기선 진이 늘어도 없는 id는
## 그냥 폴백 문구가 뜰 뿐 죽지 않는다.
## ⚠ 이건 UI 폴백이다 — 진짜 자리는 `JinDef.desc` 필드다(스키마=리드 영역이라 보고만 했다).
## 세션61 콘텐츠 리셋 — 진 카탈로그를 jin_single 하나로 비웠다(옛 7항목은 git에 있다).
## 진을 되살릴 때 여기 한 줄씩 같이 되살린다.
const JIN_DESC := {
	&"jin_single": "한 발을 곧게 쏜다. 기본이자 가장 안정적이다.",
}

func _jin_desc_of(jd: JinDef) -> String:
	if jd == null:
		return ""
	return String(JIN_DESC.get(StringName(jd.id), "이 진만의 발사 형태가 있다."))


func _jin_pattern_of(jd: JinDef) -> int:
	return int(jd.pattern) if jd != null else 0

func _jin_motion_of(jd: JinDef) -> int:
	return int(jd.motion) if jd != null else 0

func _jin_shape_of(jd: JinDef) -> int:
	return int(jd.guide_shape) if jd != null else Enums.JinShape.CIRCLE


## 🔴 진 셀 아이콘의 획들 — **패턴(몇 발·어디로) × 경로(어떻게 나는가)를 곱해서 그린다** (세션48).
## 두 축이 `Enums`에서 직교하므로 아이콘도 직교해야 한다: **경로가 획의 모양**을 정하고
## (직진=곧은 선 · 나선=물결 · 부메랑=나갔다 도는 활), **패턴이 그 획을 몇 개 어느 각도로 놓을지**
## 정한다. 그래서 새 조합(나선 산탄 등)이 .tres 한 장으로 늘어도 아이콘이 저절로 갈린다.
##
## ⚠ **`_draw_*`가 아니라 여기가 관측점이다** (문양 `glyph_icon_pts`와 같은 이유): 헤드리스는
## `draw_polyline`을 못 보지만 이 점 배열은 본다. "보인다"는 여전히 리드의 스샷이 최종 판정.
## ⚠ 이건 **셀 아이콘 전용**이다 — 판의 진 밑그림(둘레 원)은 채점(trace_scorer) 대상이라 안 건드렸다.
## 🔴 세션48 후반 — **바깥 윤곽은 `RingBoard.jin_guide_pts`가 만든 닫힌 도형이다.** 그전엔 셀이
## 열린 획(세로선·화살표·S자)만 그려 **진처럼 보이지가 않았고**(사용자 지적), 무엇보다 왼쪽 판에
## 손으로 그을 도형과 셀에서 본 모양이 **아무 관계가 없었다**. 세션47 문양이 밟은 그 함정이다:
## 고르는 순간에 안 갈리면 밑그림을 가른 의미가 절반 날아간다. 이제 같은 함수를 부른다.
## 발사 형태(패턴×경로) 힌트는 **닫힌 도형 안쪽에** `JIN_ICON_INNER`배로 줄여 얹는다 —
## 윤곽이 그릇이고 그 안이 내용물이라, 판의 "진 안에 룬" 구조와 읽는 방식이 같다.
## ⚠ `shape` 기본값이 CIRCLE이라 옛 4인자 호출도 그대로 산다(윤곽만 원으로 붙는다).
const JIN_ICON_INNER := 0.55

static func jin_icon_marks(pattern: int, motion: int, c: Vector2, s: float,
		shape: int = Enums.JinShape.CIRCLE) -> Array:
	var marks: Array = [RingBoard.jin_guide_pts(shape, c, s)]
	s *= JIN_ICON_INNER                        # 힌트는 윤곽 안쪽에 (가장 좁은 정삼각 내접원 0.5s 안)
	var base := c + Vector2(0.0, s * 0.85)     # 총구(아래) → 위로 나간다
	match pattern:
		Enums.WandPattern.MULTI:               # 산탄 = 넓은 부채 3
			for a in [-0.6, 0.0, 0.6]:
				marks.append(_jin_shaft(motion, base, Vector2.UP.rotated(a), s * 1.5))
		Enums.WandPattern.NOVA:                # 둘레 = 사방으로
			for k in 4:
				marks.append(_jin_shaft(motion, c, Vector2.UP.rotated(TAU * float(k) / 4.0), s * 0.95))
		Enums.WandPattern.BURST:               # 연발 = 같은 선 위 시간차 3발 (끊어진 획)
			for k in 3:
				var y := base.y - s * (0.25 + 0.55 * float(k))
				marks.append(_jin_shaft(motion, Vector2(base.x, y), Vector2.UP, s * 0.38))
		Enums.WandPattern.SPRAY:               # 분사 = 좁은 부채 5, 짧게
			for a in [-0.26, -0.13, 0.0, 0.13, 0.26]:
				marks.append(_jin_shaft(motion, base, Vector2.UP.rotated(a), s * 0.95))
		Enums.WandPattern.SEEK:                # 타겟 = 한 발 + 조준 꺾쇠
			marks.append(_jin_shaft(motion, base, Vector2.UP, s * 1.25))
			var t := c + Vector2(0.0, -s * 0.55)
			var b := s * 0.4
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				marks.append(PackedVector2Array([t + Vector2(q.x * b, q.y * b * 0.55),
					t + Vector2(q.x * b, q.y * b), t + Vector2(q.x * b * 0.55, q.y * b)]))
		_:                                     # 단발(SINGLE) · 미지의 패턴 = 한 발
			marks.append(_jin_shaft(motion, base, Vector2.UP, s * 1.7))
	return marks


## 획 하나 = **비행 경로의 모양**. 직진=선 · 나선=물결 · 부메랑=나갔다 되돌아오는 활.
static func _jin_shaft(motion: int, from: Vector2, dir: Vector2, length: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var side := Vector2(-dir.y, dir.x)
	match motion:
		Enums.JinMotion.SPIRAL:
			for i in 13:
				var t := float(i) / 12.0
				pts.append(from + dir * (length * t) + side * (sin(t * TAU * 1.5) * length * 0.22))
		Enums.JinMotion.BOOMERANG:
			for i in 15:
				var t := float(i) / 14.0
				# 나갔다(0→0.5) 돌아온다(0.5→1) — 앞으로 갔다 오는 동안 옆으로 부푼다
				var fwd: float = sin(t * PI) * 1.0
				pts.append(from + dir * (length * fwd) + side * (sin(t * TAU) * length * 0.30))
		_:
			pts.append(from)
			pts.append(from + dir * length)
	return pts


## 룬 탭 — **해금된 룬**을 셀로 열거 (세션 34). 클릭하면 그 룬 타입이 rune_selected로 나간다.
## 주입 전(폴백)엔 불 하나만 — set_defs가 오기 전 첫 프레임 대비. 잠긴 룬은 애초에 배열에 없다.
##
## 🔴 세션49 — **격자로 감쌌다.** 세션34까지 셀을 한 줄에 몰아넣어 `cw = 전체폭/n`이었다. 룬이
## 3→6으로 늘자 셀이 1/6 폭으로 쪼그라들어 이름·안내가 넘쳤다 — **문양 탭(세션47)·진 탭(세션48)이
## 밟은 것과 같은 함정이다**(어휘 축이 늘면 폭이 아니라 줄 수가 늘어야 한다). 같은 규약으로 통일.
const RUNE_COLS := 3
const RUNE_GAP := 8.0

## 🔴 룬 셀 격자 — **순수 함수**라 헤드리스가 잰다(`jin_cell_rects`와 같은 이유: `_draw_*` 안에
## 계산을 두면 레이아웃 회귀를 못 잡는다). 셀 높이는 줄 수에 따라 낮춘다 — 두 줄이 책 밖으로 안 밀리게.
static func rune_cell_rects(n: int, book_size: Vector2, top: float) -> Array:
	var out: Array = []
	var cols := maxi(mini(n, RUNE_COLS), 1)
	var nrows := ceili(float(n) / float(cols))
	var cw := (book_size.x - 16.0 - RUNE_GAP * float(cols - 1)) / float(cols)
	var ch := 120.0 if nrows <= 1 else 104.0
	for i in n:
		out.append(Rect2(8.0 + float(i % cols) * (cw + RUNE_GAP),
			top + float(i / cols) * (ch + RUNE_GAP), cw, ch))
	return out


func _draw_rune_cells(font: Font, top: float) -> void:
	var defs := _rune_defs if not _rune_defs.is_empty() else []
	var n := maxi(defs.size(), 1)
	var rects := rune_cell_rects(n, size, top)
	for i in n:
		var rd := defs[i] as RuneDef if i < defs.size() else null
		var rtype := int(rd.type) if rd else RingBoard.RUNE_FIRE
		var rname := String(rd.display_name) if rd else "불"
		var rcol: Color = rd.ui_color if rd else RingBoard.RUNE_COLOR
		var r: Rect2 = rects[i]
		var cw: float = r.size.x
		var ch: float = r.size.y
		_cells.append({"rect": r, "kind": "rune", "value": rtype})
		var sel := _rune_choice == rtype
		draw_rect(r, CELL_SEL_BG if sel else CELL_BG, true)
		draw_rect(r, SEL_EDGE if sel else CELL_LINE, false, 2.0 if sel else 1.0)
		_draw_rune_icon(r.get_center() + Vector2(0, -14.0), 22.0, rcol, rtype)
		var label := "✓ 그림" if (sel and _rune_placed) else "왼쪽에 손으로 그리기"
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 30.0), rname, NAME_COLOR, 11)
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 15.0), label,
			SEL_EDGE if (sel and _rune_placed) else DESC_COLOR, 8)


## 룬 아이콘 — 🔴 **판의 밑그림과 같은 함수를 부른다**(`RingBoard.rune_guide_verts`, 세션49).
## 세션34~48엔 여기가 같은 모양을 **따로 베끼고** 있어, 룬을 6종으로 늘릴 때 한쪽만 갈라질 수 있었다
## (진이 세션48에 `jin_guide_pts`로, 문양이 세션47에 같은 이유로 합쳐진 그 자리다).
## **셀에서 본 모양 = 손으로 그을 모양**이 이제 구조적으로 못 갈라진다.
func _draw_rune_icon(c: Vector2, s: float, col: Color, rune_type: int) -> void:
	draw_polyline(RingBoard.rune_guide_verts(rune_type, c, s), col, 2.5, true)


## 문양 탭 — 주입된 문양 def를 열거 (응집·발산…). 하드코딩 없음.
## 🔴 문양 탭 = **격자로 감싼다** (세션47). 세션44까지 셀을 한 줄에 몰아넣어 `cw = 전체폭/n`이었다 —
## 어휘가 3→6으로 늘자 셀이 1/6 폭으로 쪼그라들어 설명("적을 뚫고 지나간다")이 셀을 넘쳤다.
## 룬 탭이 이미 쓰는 격자 규약(`i % cols` / `i / cols`)으로 통일한다. **어휘가 더 늘어도
## 폭이 아니라 줄 수가 늘어난다** — 문양 축은 앞으로도 늘어날 자리라 여기가 버텨 줘야 한다.
const GLYPH_COLS := 3

func _draw_glyph_cells(font: Font, top: float) -> void:
	var rows := _glyph_rows()
	var n := rows.size()
	if n == 0:
		return
	var gap := 8.0
	var cols := mini(n, GLYPH_COLS)
	var nrows := ceili(float(n) / float(cols))
	var cw := (size.x - 16.0 - gap * float(cols - 1)) / float(cols)
	# 여러 줄이면 셀을 낮춰 책 밖으로 안 밀린다 (한 줄이면 예전 높이 그대로 — 회귀 0)
	var ch := 120.0 if nrows <= 1 else 104.0
	for i in n:
		var row: Dictionary = rows[i]
		var code := int(row.code)
		var r := Rect2(8.0 + float(i % cols) * (cw + gap),
			top + float(i / cols) * (ch + gap), cw, ch)
		_cells.append({"rect": r, "kind": "glyph", "value": code})
		var sel := _active == code
		draw_rect(r, CELL_SEL_BG if sel else CELL_BG, true)
		draw_rect(r, SEL_EDGE if sel else CELL_LINE, false, 2.0 if sel else 1.0)
		# 🔴 아이콘 반길이 26 = 예전 화살표와 **같은 전체 크기**(2×26=52px)라 셀 레이아웃은 그대로다.
		# ⚠ 추진만 1.1배(57px)로 살짝 크다 — 셀 높이 104~120 안이라 이름·설명과 안 겹친다.
		_draw_glyph_icon(r.get_center() + Vector2(0, -14.0), 26.0, row.color, code)
		# 🔴 키 힌트("[Q]")를 뗐다 (세션 25) — 문양도 **셀을 클릭해서** 고른다.
		# 진·룬이 전부 클릭인데 문양만 키를 광고하고 있었다 (클릭도 됐는데 몰랐다).
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 30.0),
			String(row.name), NAME_COLOR, 11)
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 15.0), String(row.desc), DESC_COLOR, 8)


## 아이콘. jin·fire = 진·룬 (폴백 단일 셀 전용 — 격자 셀은 각자 전용 렌더를 쓴다)
func _draw_icon(kind: String, c: Vector2, s: float, data: Array) -> void:
	match kind:
		"jin":
			var jc: Color = data[0] if data.size() > 0 else RingBoard.RING_LINE
			draw_arc(c, s, 0.0, TAU, 40, jc, 2.5, true)
			draw_arc(c, s * 0.5, 0.0, TAU, 32, Color(jc, 0.5), 1.5, true)
		"fire":
			var col: Color = data[0] if data.size() > 0 else RingBoard.RUNE_COLOR
			draw_polyline(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s * 0.87, s * 0.5),
				c + Vector2(-s * 0.87, s * 0.5), c + Vector2(0, -s)]), col, 2.5, true)
		_:
			pass


## 문양 아이콘 — **판의 밑그림과 같은 함수로 그린다** (세션47).
## 🔴 **화살표 하나** (세션 25, 사용자: "문양 모양도 그냥 문양 하나만 보이게 해줘").
## 예전엔 8방향 다발을 그렸다 — 한 칸에 들어가는 건 문양 **하나**인데 아이콘이 여덟을
## 보여 주니, 셀이 "문양 하나"가 아니라 "어느 칸을 여는 틀"처럼 읽혔다.
##
## 🔴 세션47 — 그 화살표를 **여기서 직접 그리던 걸 그만뒀다.** 판의 밑그림을 6종으로 갈라 놨는데
## 이 함수는 `inward`만 봐서 **6개 셀이 전부 같은 화살표**였다(색만 달랐다). 사용자가 문양을
## **고르는 바로 그 순간** 구분이 안 되면 밑그림을 가른 의미가 절반 날아간다.
## 이제 `RingBoard.glyph_guide_pts`를 그대로 부른다 — **셀과 밑그림이 구조적으로 못 갈라진다.**
## ⚠ `inward`를 인자에서 뺐다: `code == G_GATHER`와 같은 뜻이라 둘을 다 받으면 언젠가 어긋난다.
## 방향 규약은 그대로다 (발산 계열=바깥/위 · 응집=룬 쪽/아래) — outward에 UP을 넘겨 판과 맞춘다.
func _draw_glyph_icon(c: Vector2, s: float, col: Color, code: int) -> void:
	var pts := glyph_icon_pts(code, c, s)
	if pts.size() >= 2:
		draw_polyline(pts, col, 2.2, true)


## 🔴 셀 아이콘의 점 — **판의 밑그림과 같은 함수**에서 온다. `_draw_glyph_icon`이 이걸 그린다.
## ⚠ **`_draw_*`가 아니라 여기가 관측점인 이유**(세션47, 뮤테이션으로 배웠다): 테스트가
## `RingBoard.glyph_guide_pts`를 직접 부르면 **책이 자기 화살표를 다시 그려도 초록불이다** —
## 보드를 검증할 뿐 책을 검증하지 않기 때문이다. 실제로 그 뮤테이션이 그냥 통과했다.
## 그래서 책 쪽에 관측 가능한 이음매를 뒀다. `draw_polyline`은 헤드리스가 못 보지만 이 점 배열은 본다.
## ⚠ 그래도 **"보인다"는 여전히 못 잡는다** — 렌더는 리드의 스샷이 최종 판정이다.
func glyph_icon_pts(code: int, c: Vector2 = Vector2.ZERO, s: float = 26.0) -> PackedVector2Array:
	return RingBoard.glyph_guide_pts(code, c, Vector2.UP, s)


func _text(font: Font, at: Vector2, text: String, col: Color, fs: int) -> void:
	draw_string(font, at + Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_center(font: Font, at: Vector2, text: String, col: Color, fs: int) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-tw * 0.5, fs * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
