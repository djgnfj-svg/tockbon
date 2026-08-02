extends Control
## 조각 선택기 — 고리 조립 제작대의 **오른쪽 페이지**. 탭으로 넘겨 본다: 진 · 룬 · 층.
## 고른 것이 왼쪽 보드에 곧바로 적용된다.
##   • 진 탭 — 보유한 진을 격자로. 고른 진이 발사 형태·비행 경로·층 수·룬 자리 수를 정한다.
##   • 룬 탭 — 해금된 룬을 격자로. 융합진(`rune_slots` ≥ 2)이면 격자 위에 룬 소켓 줄이 뜬다.
##   • 층 탭 — 진의 층(band) 소켓 N칸 + 보유 문양-고리 목록. ⚠ 문양을 **낱개로 고르지 않는다** —
##     조립 단위는 문양-고리다.
##
## 🔴 **오토로드를 안 본다** — Db·해금 판정이 필요한 값은 전부 패널이 `set_*`로 주입한다.
## 사용: const RingBook := preload("res://src/drawing/ring_book.gd")

const RingBoard := preload("res://src/drawing/ring_board.gd")

## 🔴 시그널을 받는 건 판이 아니라 **패널**이다 — 패널이 선택 상태를 갱신하고 `recompose()`로
## 왼쪽 밑그림을 다시 세운다(보드에 직접 놓는 API는 없다).
signal jin_selected(jin_id: StringName)
signal rune_selected(rune_type: int)
## 룬 소켓(자리)을 골랐다 — 다음에 고르는 룬이 이 자리에 들어간다. 자리 1개 진에선 안 난다.
signal rune_slot_selected(i: int)
## 밴드 소켓을 골랐다 / 소켓에 끼울 문양-고리를 골랐다.
signal band_selected(i: int)
signal ring_picked(gr_id: StringName)

const TAB_JIN := 0
const TAB_RUNE := 1
const TAB_GLYPH := 2                    # 라벨 = 「층」 (문양 낱개 탭이 아니다)
const TAB_ORDER := [TAB_JIN, TAB_RUNE, TAB_GLYPH]
const TAB_LABEL := ["진", "룬", "층"]

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
# 순서 잠금 탭(아직 못 여는 탭). 회색 베일 + 흐린 글자로 "지금은 못 연다"를 알린다.
const TAB_LOCK_BG := Color(0.58, 0.53, 0.46, 0.55)
const TAB_LOCK_VEIL := Color(0.50, 0.46, 0.40, 0.45)
const TAB_LOCK_TEXT := Color(0.52, 0.48, 0.42, 0.7)
const RUNE_SLOT_LINE := Color(0.30, 0.26, 0.20, 0.45)   # 진 셀: 아직 안 고른 룬 자리(빈 자리라 흐리게)
# ── 층(band) 소켓 톤 ──
const SOCKET_BG := Color(0.84, 0.78, 0.66)
const SOCKET_EMPTY := Color(0.20, 0.14, 0.09, 0.28)

const TAB_H := 18.0
const TAB_GAP := 2.0

## 탭·셀 카드 배경 한지 나인패치. PNG가 없으면 draw_rect 플랫 폴백(계약).
## off 탭/비선택 셀 = 같은 StyleBox 복제 + modulate — 상태별 텍스처를 늘리지 않는다.
const CARD_TEX := "res://assets/sprites/ui/panel_paper_s.png"
const CARD_TEX_MARGIN := 6.0
const CARD_OFF_MOD := Color(0.85, 0.85, 0.85, 1.0)

## ⚠ 탭 머리글엔 축의 **이름**만 적는다 — 값(칸 수·층 수)을 문장에 베끼면 축이 바뀔 때
## 화면이 조용히 거짓말한다. 숫자는 `jin_spec_text`가 JinDef에서 파생해 적는다.
const TAB_DESC := [
	"진 — 바깥 그릇(형태). 층 수와 룬 자리가 진마다 다르다.",
	"룬 — 중심 속성. 탁본으로 해독한 룬을 고른다.",
	"층 — 진의 층에 문양-고리를 끼운다.",
]

var _stage := TAB_JIN                 # 진 탭부터 편다 (순차 조립)
## 층 탭 목록 세로 스크롤(px) — 클램프는 `_draw_band_sockets`가 콘텐츠·가시영역으로 한다.
var _ring_scroll := 0.0
## 어느 탭이 열렸나 (진 선택⇒룬 탭·룬 선택⇒층 탭). 패널이 선택 상태에서 파생해 주입한다.
## 잠긴 탭은 회색으로 그리고 클릭을 거부한다. 기본 = 전부 열림(주입 전 첫 프레임).
var _open_tabs: Array = [true, true, true]
var _rune_choice := -1                # 지금 고른 룬 타입 (하이라이트) — -1=아직
## 자리별 고른 룬(or -1) 목록 + 활성 자리. size ≤ 1이면 소켓을 안 그린다.
var _rune_picks: Array = []
var _sel_rune_slot := 0
var _jin_choice: StringName = &""     # 지금 고른 진 id (하이라이트) — &""=아직
var _tab_rects: Array[Rect2] = []
## 클릭 가능한 칸 — {rect, kind:"jin"/"rune"/"band"/"ring", value}
var _cells: Array[Dictionary] = []
# ── 층 소켓 상태 — 패널이 Db로 해석해 `set_bands`로 주입한다. ──
var _bands: Array = []                # 밴드 idx → GlyphRingDef(or null)
var _sel_band := 0                    # 지금 고른(강조) 밴드
var _available_rings: Array = []      # 보유(해금) 문양-고리 GlyphRingDef 목록 — 패널이 필터해 넘긴다

# ── 주입 데이터 — 패널이 Db에서 읽어 넣는다. 없으면 RingBoard const 폴백. ──
var _jin_defs: Array = []
## 카드 StyleBox 캐시 — null이면 플랫 폴백.
var _card_sb_on: StyleBoxTexture = null
var _card_sb_off: StyleBoxTexture = null
var _card_sb_tried := false
## 🔴 **해금된 룬만** 온다 — 책은 해금 판정을 직접 못 한다. 잠긴 룬은 셀 자체가 안 뜬다.
var _rune_defs: Array = []
var _glyph_defs: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Db에서 읽은 진·룬·문양 정의를 주입한다. 🔴 runes = **해금된 룬만**.
func set_defs(jins: Array, runes: Array, glyph_defs: Array = []) -> void:
	_jin_defs = jins
	_rune_defs = runes
	_glyph_defs = glyph_defs   # 개별 문양 탭이 은퇴해 미사용 — 옛 호출부 호환용으로만 받는다
	queue_redraw()


## 층 소켓 상태를 주입한다 — 밴드별 GlyphRingDef(or null)와 보유 목록.
func set_bands(bands: Array, sel_band: int, available_rings: Array) -> void:
	_bands = bands
	_sel_band = sel_band
	_available_rings = available_rings
	queue_redraw()


## 룬 소켓 상태를 주입한다. picks[i] = 그 자리 룬(or -1), sel_slot = 활성 자리.
func set_rune_slots(picks: Array, sel_slot: int) -> void:
	_rune_picks = picks
	_sel_rune_slot = sel_slot
	queue_redraw()


## 열린 탭 집합을 주입한다. `open[stage]`가 false면 회색·클릭 거부.
## ⚠ 지금 펼친 탭이 잠겼으면 진 탭으로 되돌린다 — 잠긴 탭이 펼쳐진 채 남지 않게.
func set_open_tabs(open: Array) -> void:
	_open_tabs = open
	if not _tab_is_open(_stage):
		_stage = TAB_JIN
	queue_redraw()


func _tab_is_open(stage: int) -> bool:
	return stage >= 0 and stage < _open_tabs.size() and bool(_open_tabs[stage])


## ⚠ 아래 둘은 **호출자가 0곳**이다 — 남길지 걷을지 결정 대기.
func _jin_name() -> String:
	return String(_jin_defs[0].display_name) if not _jin_defs.is_empty() else "일반진"

func _jin_ui_color() -> Color:
	return _jin_defs[0].ui_color if not _jin_defs.is_empty() else RingBoard.RING_LINE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


# ─────────────────────────── 입력 ───────────────────────────

## 🔴 넘치는 목록이 책 밖으로 흘러 다른 UI를 덮지 않게 클립한다(스크롤과 한 쌍).
func _ready() -> void:
	clip_contents = true


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	# 굴린 뒤 클램프는 draw가 한다 — 콘텐츠 크기를 draw만 안다.
	if _stage == TAB_GLYPH and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_ring_scroll += RING_ROW_H + RING_ROW_GAP
		queue_redraw()
		accept_event()
		return
	if _stage == TAB_GLYPH and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_ring_scroll = maxf(0.0, _ring_scroll - (RING_ROW_H + RING_ROW_GAP))
		queue_redraw()
		accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _tab_rects.size():
		if _tab_rects[i].has_point(mb.position):
			# 잠긴 탭은 클릭을 **먹되 무시한다** — 순서를 건너뛸 수 없다.
			if not _tab_is_open(TAB_ORDER[i]):
				accept_event()
				return
			_stage = TAB_ORDER[i]
			queue_redraw()
			accept_event()
			return
	for cell in _cells:
		if not Rect2(cell.rect).has_point(mb.position):
			continue
		match String(cell.kind):
			"jin":
				_jin_choice = StringName(cell.value)
				jin_selected.emit(StringName(cell.value))
			"rune":
				_rune_choice = int(cell.value)
				rune_selected.emit(int(cell.value))
			"rune_slot":
				_sel_rune_slot = int(cell.value)   # 채울 활성 자리 (패널이 주입으로 되돌린다)
				rune_slot_selected.emit(int(cell.value))
			"band":
				_sel_band = int(cell.value)      # 강조할 밴드 (패널이 주입으로 되돌린다)
				band_selected.emit(int(cell.value))
			"ring":
				ring_picked.emit(StringName(cell.value))   # 선택 밴드에 이 고리를 끼운다
		queue_redraw()
		accept_event()
		return


# ─────────────────────────── 렌더 ───────────────────────────

## 탭·셀 카드 배경 StyleBox — 첫 호출에 exists 가드로 만들어 캐시.
## 🔴 PNG가 없으면 null을 돌려준다 — 헤드리스·에셋 미도착에서 안 죽어야 한다.
func _card_sb(on: bool) -> StyleBoxTexture:
	if not _card_sb_tried:
		_card_sb_tried = true
		if ResourceLoader.exists(CARD_TEX):
			_card_sb_on = StyleBoxTexture.new()
			_card_sb_on.texture = load(CARD_TEX) as Texture2D
			_card_sb_on.set_texture_margin_all(CARD_TEX_MARGIN)
			_card_sb_off = _card_sb_on.duplicate() as StyleBoxTexture
			_card_sb_off.modulate_color = CARD_OFF_MOD
	return _card_sb_on if on else _card_sb_off


## 카드 하나(탭·셀 공용). `flat_bg`/`flat_edge`는 텍스처가 없을 때만 쓰는 폴백 색이다.
func _draw_card(r: Rect2, on: bool, flat_bg: Color, flat_edge: Color, edge_w: float) -> void:
	var sb := _card_sb(on)
	if sb != null:
		draw_style_box(sb, r)
		if on:
			draw_rect(r, SEL_EDGE, false, 2.0)
	else:
		draw_rect(r, flat_bg, true)
		draw_rect(r, flat_edge, false, edge_w)


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
		var locked := not _tab_is_open(stage)   # 아직 못 여는 탭(순서 잠금)
		var tab_sb := _card_sb(on)
		if tab_sb != null:
			draw_style_box(tab_sb, r)
			if locked:
				draw_rect(r, TAB_LOCK_VEIL, true)   # 나인패치 위에 회색 베일
		else:
			draw_rect(r, TAB_LOCK_BG if locked else (TAB_ON_BG if on else TAB_OFF_BG), true)
			draw_line(r.position, r.position + Vector2(r.size.x, 0.0), CELL_LINE, 1.0)
			if not on:
				draw_line(r.position + Vector2(0.0, r.size.y), r.position + r.size, CELL_LINE, 1.0)
		var text: String = TAB_LABEL[i]
		var fs := 10
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tcol: Color = TAB_LOCK_TEXT if locked else (TAB_ON_TEXT if on else TAB_OFF_TEXT)
		draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, TAB_H * 0.72),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)

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
			_draw_band_sockets(font, top)


## 진 탭 — 보유 진을 셀로 열거. 클릭 = 그 진 id가 jin_selected로 나간다. 잠긴 진은 배열에 없다.
## 🔴 어휘가 늘면 **폭이 아니라 줄 수가 는다** — 한 줄에 몰아넣으면 셀이 쪼그라들어 이름이 넘친다.
## 설명은 셀 안이 아니라 **격자 아래 한 줄**에 쓴다(3열 셀 폭에 한 줄 설명이 안 들어간다).
const JIN_COLS := 3
const JIN_CELL_H := 62.0
const JIN_GAP := 6.0
## 진 셀 아이콘의 윤곽 반지름.
const JIN_ICON_S := 17.0

## 🔴 격자 계산은 **순수 static**이라야 헤드리스가 잰다 — `_draw_*` 안에 두면 레이아웃 회귀를 못 잡는다.
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
		_draw_card(r, sel, CELL_SEL_BG if sel else CELL_BG,
			SEL_EDGE if sel else CELL_LINE, 2.0 if sel else 1.0)
		# 획 굵기·색만 여기가 쥔다 — 기하는 `jin_icon_paths`.
		var opaque := Color(jcol.r, jcol.g, jcol.b, 1.0)
		var icon_c := r.get_center() + Vector2(0.0, -8.0)
		for path: Dictionary in jin_icon_paths(_jin_shape_of(jd), _jin_rune_slots_of(jd),
				icon_c, JIN_ICON_S):
			var pts: PackedVector2Array = path["pts"]
			if pts.size() >= 2:
				var faint := bool(path["faint"])
				draw_polyline(pts, RUNE_SLOT_LINE if faint else opaque,
					1.0 if faint else 2.0, true)
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 12.0), jname, NAME_COLOR, 10)
		if sel:
			sel_desc = _jin_desc_of(jd)
	# 고른 진의 설명 한 줄 (격자 바로 아래). 아직 안 골랐으면 무엇을 하라는지 알린다.
	var chosen := _jin_choice != &""
	var dy := top + float(nrows) * (ch + JIN_GAP) + 2.0
	if sel_desc.is_empty():
		sel_desc = "셀을 클릭하면 왼쪽 판에 그 진의 밑그림이 뜬다."
	_text(font, Vector2(8.0, dy), sel_desc, SEL_EDGE if chosen else DESC_COLOR, 8)


## 진 설명 한 줄 — 🔴 **id로 찾는다(인덱스 아님)**. 배열 인덱스로 잡으면 항목이 늘 때
## 인덱스 초과로 잠복 크래시가 난다. 없는 id는 폴백 문구가 뜰 뿐 안 죽는다.
## ⚠ 이건 UI 폴백이고 진짜 자리는 `JinDef.desc` 필드다. 진을 되살릴 때 여기 한 줄씩 같이 되살린다.
const JIN_DESC := {
	&"jin_single": "한 발을 곧게 쏜다. 기본이자 가장 안정적이다.",
}

## 🔴 진의 개성은 **데이터에서 파생**해 적는다 — 문장에 숫자를 베껴 두면 축이 바뀔 때
## 화면이 조용히 거짓말한다. 파생하면 진·층을 늘려도 셀 설명이 저절로 따라온다.
## ⚠ 룬 자리는 2 이상일 때만 적는다 — 늘 적으면 정보량 0인 노이즈다.
static func jin_spec_text(band_count: int, rune_slots: int) -> String:
	var s := "층 %d겹" % maxi(band_count, 0)
	if rune_slots >= 2:
		s += " · 룬 자리 %d개" % rune_slots   # ⚠ 짧게 — 셀 아래 한 줄에 들어가야 한다
	return s


## 셀 아래 한 줄 = 파생 스펙 + 설명. 🔴 static·public = 헤드리스 관측점
## (문자열 조립이 `_draw_*` 안에 있으면 「스펙이 실제로 실리나」를 아무도 못 잰다).
static func jin_desc_line(jin_id: StringName, band_count: int, rune_slots: int) -> String:
	return "%s — %s" % [jin_spec_text(band_count, rune_slots),
		String(JIN_DESC.get(jin_id, "이 진만의 발사 형태가 있다."))]


func _jin_desc_of(jd: JinDef) -> String:
	if jd == null:
		return ""
	return jin_desc_line(StringName(jd.id), int(jd.band_count), _jin_rune_slots_of(jd))


func _jin_shape_of(jd: JinDef) -> int:
	return int(jd.guide_shape) if jd != null else Enums.JinShape.CIRCLE

func _jin_rune_slots_of(jd: JinDef) -> int:
	return maxi(int(jd.rune_slots), 1) if jd != null else 1


## 진 셀 아이콘 = **진 모양(윤곽) + 룬 자리**, 그 둘뿐이다.
## 반환 = `[{"pts": PackedVector2Array, "faint": bool}, …]` — [0]이 윤곽, 나머지가 룬 자리.
## `faint` = 아직 안 고른 빈 자리(색·굵기는 `_draw_jin_cells`가 쥔다).
##
## 🔴🔴 윤곽도 룬 자리도 **판과 같은 함수**(`RingBoard.jin_guide_pts`·`rune_slot_positions`·
## `RUNE_GUIDE_FRAC`)를 부른다 — 좌표나 식을 베끼면 「셀에서 본 모양」과 「판에서 그을 모양」이
## 조용히 어긋나고, 그러면 고르는 행위 자체가 의미를 잃는다.
## ⚠ 여기가 관측점이다 — 헤드리스는 `draw_polyline`을 못 보지만 이 점 배열은 본다.
## ⚠ 자리 표식만 판보다 키운다 — 셀이 작아 판 비율 그대로면 "자리가 둘"이 안 읽힌다.
##   비율이 아니라 **가독성** 때문이라 상수로 분리했다.
const JIN_ICON_RUNE_SCALE := 1.6

static func jin_icon_paths(shape: int, rune_slots: int, c: Vector2, s: float) -> Array:
	var out: Array = [{"pts": RingBoard.jin_guide_pts(shape, c, s), "faint": false}]
	var n := maxi(rune_slots, 1)
	var rr := s * RingBoard.RUNE_GUIDE_FRAC * JIN_ICON_RUNE_SCALE
	if n >= 2:
		rr *= RingBoard.RUNE_MULTI_SIZE_FRAC   # 자리 여럿이면 겹치지 않게 — 판과 같은 규칙
	for p: Vector2 in RingBoard.rune_slot_positions(n, c, s):
		out.append({"pts": RingBoard.jin_guide_pts(Enums.JinShape.CIRCLE, p, rr), "faint": true})
	return out


## 룬 탭 — 해금된 룬을 셀로 열거. 주입 전엔 불 하나만(첫 프레임 대비).
## 🔴 진 탭과 같은 규약 — 어휘가 늘면 폭이 아니라 줄 수가 는다.
const RUNE_COLS := 3
const RUNE_GAP := 8.0
## 융합진 룬 소켓 (룬 탭 위, 자리 ≥2일 때만). 한 줄 가로 배치.
const RUNE_SOCKET_H := 34.0
const RUNE_SOCKET_GAP := 6.0
const RUNE_SOCKET_MARGIN := 8.0        # 소켓 줄과 아래 룬 격자 사이 여백

## 룬 소켓이 차지하는 세로 높이 (자리 ≤1이면 0 = 소켓 없음).
static func rune_socket_reserved(n: int) -> float:
	return (RUNE_SOCKET_H + RUNE_SOCKET_MARGIN) if n >= 2 else 0.0

## 🔴 순수 함수 = 헤드리스 관측점. 자리 ≤1이면 빈 배열(소켓 안 그림).
static func rune_socket_rects(n: int, book_size: Vector2, top: float) -> Array:
	var out: Array = []
	if n < 2:
		return out
	var sw := (book_size.x - 16.0 - RUNE_SOCKET_GAP * float(n - 1)) / float(n)
	for i in n:
		out.append(Rect2(8.0 + float(i) * (sw + RUNE_SOCKET_GAP), top, sw, RUNE_SOCKET_H))
	return out


## 🔴 순수 함수 = 헤드리스 관측점. 셀 높이는 줄 수에 따라 낮춘다 — 두 줄이 책 밖으로 안 밀리게.
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
	# 융합진(룬 자리 ≥2)이면 격자 위에 룬 소켓 줄을 그리고 격자를 그만큼 내린다.
	var slot_n := _rune_picks.size()
	_draw_rune_sockets(font, top, slot_n)
	top += rune_socket_reserved(slot_n)

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
		_draw_card(r, sel, CELL_SEL_BG if sel else CELL_BG,
			SEL_EDGE if sel else CELL_LINE, 2.0 if sel else 1.0)
		_draw_rune_icon(r.get_center() + Vector2(0, -14.0), 22.0, rcol, rtype)
		var label := "✓ 선택" if sel else "고르기"
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 30.0), rname, NAME_COLOR, 11)
		_text_center(font, r.position + Vector2(cw * 0.5, ch - 15.0), label,
			SEL_EDGE if sel else DESC_COLOR, 8)


## 🔴 판의 밑그림과 **같은 함수**를 부른다 — 모양을 여기 베끼면 「셀에서 본 모양 = 손으로 그을 모양」이 깨진다.
func _draw_rune_icon(c: Vector2, s: float, col: Color, rune_type: int) -> void:
	draw_polyline(RingBoard.rune_guide_verts(rune_type, c, s), col, 2.5, true)


## 융합진 룬 소켓 줄 — 자리 N칸(자리 ≥2일 때만). 클릭 = 그 자리를 활성으로.
func _draw_rune_sockets(font: Font, top: float, slot_n: int) -> void:
	if slot_n < 2:
		return
	var srects := rune_socket_rects(slot_n, size, top)
	for i in slot_n:
		var r: Rect2 = srects[i]
		var pick := int(_rune_picks[i]) if i < _rune_picks.size() else -1
		var active := i == _sel_rune_slot
		_cells.append({"rect": r, "kind": "rune_slot", "value": i})
		draw_rect(r, SOCKET_BG, true)
		draw_rect(r, SEL_EDGE if active else SOCKET_EMPTY, false, 2.5 if active else 1.0)
		if pick >= 0:
			var rd: RuneDef = _rune_def_of(pick)
			var rcol: Color = rd.ui_color if rd != null else RingBoard.RUNE_COLOR
			_draw_rune_icon(r.position + Vector2(r.size.y * 0.5, r.size.y * 0.5), r.size.y * 0.30, rcol, pick)
			var rnm := String(rd.display_name) if rd != null else "룬"
			_text(font, r.position + Vector2(r.size.y + 2.0, r.size.y * 0.5 - 6.0), rnm, NAME_COLOR, 9)
		else:
			_text(font, r.position + Vector2(6.0, r.size.y * 0.5 - 6.0), "자리 %d" % (i + 1),
				DESC_COLOR, 9)


## 주입된 해금 룬 정의 중 타입이 일치하는 것. 없으면 null.
func _rune_def_of(rune_type: int) -> RuneDef:
	for rd_v in _rune_defs:
		var rd := rd_v as RuneDef
		if rd != null and int(rd.type) == rune_type:
			return rd
	return null


## 층 탭 — 진의 층(band) 소켓 N칸 + 보유 문양-고리 목록. 소켓 클릭=강조 밴드 선택,
## 고리 클릭=선택 밴드에 끼움.
## 🔴 소켓/목록 rect는 **순수 static**이라야 헤드리스가 레이아웃을 잰다.
## ⚠ `RING_COLS`를 2로 올리면 「고리 목록 rect가 세로로 쌓인다」 테스트가 빨개진다 —
##   검사식이 0·1번 카드의 y를 비교하기 때문이다(계약 자체는 2열에서도 지켜진다).
const BAND_SOCKET_H := 44.0
const BAND_SOCKET_GAP := 6.0
const RING_ROW_H := 44.0
const RING_ROW_GAP := 4.0
const RING_COLS := 1
const RING_LIST_HEADER := 18.0        # 소켓 아래 "보유 문양-고리" 머리글 높이
## 카드 높이 대비 아이콘 반지름 — 아이콘의 **바깥 띠선**이 정확히 이 반지름에 앉는다.
const ICON_R_FRAC := 0.42

static func band_socket_rects(n: int, book_size: Vector2, top: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(Rect2(8.0, top + float(i) * (BAND_SOCKET_H + BAND_SOCKET_GAP),
			book_size.x - 16.0, BAND_SOCKET_H))
	return out

## 소켓 밑 목록의 시작 y — 소켓 N칸 + 머리글 높이. 소켓 rect와 같은 top을 넘긴다.
static func band_list_top(band_n: int, top: float) -> float:
	return top + float(band_n) * (BAND_SOCKET_H + BAND_SOCKET_GAP) + RING_LIST_HEADER

## 배치는 `RING_COLS` 한 곳에서 파생한다 — 열을 늘리려면 상수 하나만 바꾼다.
static func ring_list_rects(n: int, book_size: Vector2, list_top: float) -> Array:
	var out: Array = []
	var cw := (book_size.x - 16.0 - RING_ROW_GAP * float(RING_COLS - 1)) / float(RING_COLS)
	for i in n:
		out.append(Rect2(8.0 + float(i % RING_COLS) * (cw + RING_ROW_GAP),
			list_top + float(i / RING_COLS) * (RING_ROW_H + RING_ROW_GAP), cw, RING_ROW_H))
	return out


## 목록 콘텐츠 전체 높이 (스크롤 클램프용) — 🔴 항목 수가 아니라 **줄 수**로 센다.
## 항목 수로 세면 열이 늘어날 때 스크롤이 콘텐츠의 두 배까지 굴러간다.
static func ring_list_height(n: int) -> float:
	return float(ceili(float(n) / float(RING_COLS))) * (RING_ROW_H + RING_ROW_GAP)


func _draw_band_sockets(font: Font, top: float) -> void:
	var n := _bands.size()
	var srects := band_socket_rects(n, size, top)
	for i in n:
		var r: Rect2 = srects[i]
		var gr := _bands[i] as GlyphRingDef
		var sel := i == _sel_band
		_cells.append({"rect": r, "kind": "band", "value": i})
		draw_rect(r, SOCKET_BG, true)
		# ⚠ 선택 강조는 얇게 — 굵은 테두리가 카드보다 더 눈에 띄면 목록 전체가 시끄러워진다.
		draw_rect(r, SEL_EDGE if sel else SOCKET_EMPTY, false, 1.6 if sel else 1.0)
		# 밴드 번호는 **늘** 왼쪽 위에 — 끼웠든 비었든 "몇 층인가"가 이 칸의 정체다.
		_text(font, r.position + Vector2(4.0, 2.0), "%d" % (i + 1),
			SEL_EDGE if sel else DESC_COLOR, 8)
		# 비었을 때도 아이콘을 그린다 — 띠만 흐리게 나와 "여기가 한 층"이 끼우기 전에도 읽힌다.
		_ring_icon(r.position + Vector2(r.size.y * 0.5, r.size.y * 0.5),
			r.size.y * ICON_R_FRAC, gr, i)
		if gr != null:
			# ⚠ 이름을 두 번 적지 마라 — `display_name`에 이미 개수가 들어 있다.
			_text(font, r.position + Vector2(r.size.y + 6.0, r.size.y * 0.5 - 6.0),
				gr.display_name, NAME_COLOR, 9)
		else:
			_text(font, r.position + Vector2(r.size.y + 6.0, r.size.y * 0.5 - 6.0),
				"비었다 — 아래 고리를 클릭", DESC_COLOR, 9)

	# 보유 문양-고리 목록 (선택 밴드에 끼운다) — 머리글은 고정, 행만 휠 스크롤.
	var list_top := band_list_top(n, top)
	_text(font, Vector2(8.0, list_top - RING_LIST_HEADER + 2.0),
		"보유 문양-고리 (클릭 → 밴드 %d)" % (_sel_band + 1), DESC_COLOR, 9)
	# 콘텐츠 높이가 가시영역을 넘칠 때만 굴러간다.
	var content_h := ring_list_height(_available_rings.size())
	var visible_h := size.y - list_top
	var max_scroll := maxf(0.0, content_h - visible_h)
	_ring_scroll = clampf(_ring_scroll, 0.0, max_scroll)
	var lrects := ring_list_rects(_available_rings.size(), size, list_top)
	for i in _available_rings.size():
		var gr2 := _available_rings[i] as GlyphRingDef
		if gr2 == null:
			continue
		var rr: Rect2 = lrects[i]
		rr.position.y -= _ring_scroll
		# 가시영역에 **온전히 들어오는 행만** 그린다 — 걸친 행을 그리면 반쯤 잘린 카드가 남고,
		# _cells에도 안 담아야 반쯤 보이는 걸 클릭하는 일이 없다.
		if rr.position.y < list_top or rr.position.y + rr.size.y > size.y:
			continue
		_cells.append({"rect": rr, "kind": "ring", "value": gr2.id})
		# ⚠ 카드 톤은 **알파로만** 조인다 — `ui_color`는 정본이라 로컬에서 안 바꾼다.
		draw_rect(rr, Color(gr2.ui_color, 0.08), true)
		draw_rect(rr, Color(gr2.ui_color, 0.45), false, 1.0)
		# 목록 아이콘의 층 = 지금 고른 밴드 — "클릭 → 밴드 N"과 그림이 같은 층을 가리키게.
		_ring_icon(rr.position + Vector2(rr.size.y * 0.5, rr.size.y * 0.5),
			rr.size.y * ICON_R_FRAC, gr2, _sel_band)
		var name_x := rr.size.y + 4.0
		_text(font, rr.position + Vector2(name_x, rr.size.y * 0.5 - 5.0),
			_fit_text(font, gr2.display_name, rr.size.x - name_x - 4.0, 9), NAME_COLOR, 9)
	# 넘칠 때만 오른쪽에 얇은 썸 — 없으면 휠이 되는지 알 길이 없다.
	if max_scroll > 0.0:
		var track_x := size.x - 5.0
		var track_h := visible_h
		var thumb_h := maxf(18.0, track_h * (visible_h / content_h))
		var thumb_y := list_top + (track_h - thumb_h) * (_ring_scroll / max_scroll)
		draw_rect(Rect2(track_x, list_top, 3.0, track_h), Color(0.42, 0.30, 0.12, 0.12), true)
		draw_rect(Rect2(track_x, thumb_y, 3.0, thumb_h), Color(0.42, 0.30, 0.12, 0.5), true)


## 문양-고리 미리보기 아이콘의 **기하**.
##
## 🔴🔴 **각도도 반지름도 여기서 계산하지 않는다 — 전부 판 정본에서 파생한다**:
##   • 모티프 점열·배치 = `RingBoard.glyph_ring_subpaths` · 띠 경계 = `RingBoard.band_lane`
##   • 가상 판 반지름 `ro` = **탐침 역산** — `band_lane`을 임의 크기로 한 번 불러 비율만 얻고,
##     띠 바깥선이 아이콘 반지름 `s`에 앉도록 되민다.
## 베끼면 「본 것 ≠ 끼운 것」이 된다 — 실제로 선이 모티프를 관통하고 크기가 3배가 됐던 자리다.
## 탐침 역산이라야 판이 여백·모티프 크기를 바꿔도 아이콘이 **저절로** 따라온다.
##
## 반환 = `{"lane": Vector2(안쪽선, 바깥선), "motifs": Array[PackedVector2Array]}`.
## `gr == null`이면 lane만 온다 — 빈 소켓도 띠를 보여 "여기가 한 층"이 읽힌다.
## ⚠ 아이콘은 판의 축소판이 **아니라 그 층의 띠를 확대한 것**이다(그대로 줄이면 모티프가 점이 된다).
## 🔴 static·순수 = 헤드리스 관측점 — 「선이 모티프를 침범하지 않는다」를 관계식으로 잴 수 있다.
const ICON_PROBE_RO := 100.0
## 아이콘 전용 가독성 확대 — 판 비율 그대로면 모티프가 카드에서 4px라 점 하나로 읽힌다.
## 🔴 확대할 땐 **띠도 같은 배로 벌린다** — 모티프만 키우면 선을 다시 밟아 작업이 원상복귀된다.
const ICON_MOTIF_ZOOM := 2.2

static func ring_icon_geom(gr: GlyphRingDef, c: Vector2, s: float,
		band_index: int = 0) -> Dictionary:
	# 탐침으로 비율만 얻는다 — 상수를 베끼지 않으려고 이렇게 돈다.
	var probe: Vector2 = RingBoard.band_lane(band_index, ICON_PROBE_RO)
	var mid_frac := (probe.x + probe.y) * 0.5 / ICON_PROBE_RO
	var half_frac := (probe.y - probe.x) * 0.5 / ICON_PROBE_RO
	var ro := s / maxf(mid_frac + half_frac * ICON_MOTIF_ZOOM, 0.0001)
	var band_r := ro * mid_frac
	# 모티프는 판 정본이 만들고(각도·모양은 손대지 않는다), 배치 반경 위에서 같은 배로 키운다.
	var motifs: Array = []
	for sub_v in RingBoard.glyph_ring_subpaths(gr, c, band_r):
		motifs.append(_scaled_motif(sub_v as PackedVector2Array, c, band_r, ICON_MOTIF_ZOOM))
	# 🔴 띠는 **키운 문양의 실제 점 범위**에서 파생한다 — 폭을 식으로 잡으면 바깥으로 길게 뻗는
	# 문양(화살표)이 선을 넘는다. 실측 범위에서 뽑으면 어떤 문양이 와도 「선 사이」가 성립한다.
	var lo := band_r
	var hi := band_r
	for sub_v in motifs:
		for p: Vector2 in sub_v as PackedVector2Array:
			var d := p.distance_to(c)
			lo = minf(lo, d)
			hi = maxf(hi, d)
	var pad := ro * (half_frac - mid_frac * RingBoard.MOTIF_SIZE_FRAC) * ICON_MOTIF_ZOOM
	var lane := Vector2(maxf(lo - pad, 0.0), hi + pad)
	# 바깥 띠선이 정확히 `s`에 앉도록 전체를 c 기준으로 맞춘다 — 아이콘이 카드 밖으로 안 샌다.
	var fit := s / maxf(lane.y, 0.0001)
	if not is_equal_approx(fit, 1.0):
		lane *= fit
		var fitted: Array = []
		for sub_v in motifs:
			var out := PackedVector2Array()
			for p: Vector2 in sub_v as PackedVector2Array:
				out.append(c + (p - c) * fit)
			fitted.append(out)
		motifs = fitted
	return {"lane": lane, "motifs": motifs}


## 모티프 한 장을 **자기 배치점 기준**으로 확대한다 — 앉는 각도는 그대로, 크기만 키운다.
## ⚠ 배치 각도를 다시 계산하지 마라(그게 곧 사본이다) — 점열 평균의 방향이 배치 방향이다.
## ⚠ 평균을 그대로 중심으로 쓰면 확대가 문양을 바깥으로 밀어 띠를 넘는다.
static func _scaled_motif(sub: PackedVector2Array, c: Vector2, band_r: float,
		k: float) -> PackedVector2Array:
	if sub.size() == 0 or is_equal_approx(k, 1.0):
		return sub
	var mid := Vector2.ZERO
	for p in sub:
		mid += p
	mid /= float(sub.size())
	var dir := (mid - c).normalized()
	var anchor := c + dir * band_r if dir != Vector2.ZERO else mid
	var out := PackedVector2Array()
	for p in sub:
		out.append(anchor + (p - anchor) * k)
	return out


## 문양-고리 아이콘 렌더 — 기하는 `ring_icon_geom`, 여기는 **색·굵기만** 쥔다.
## `band_index` = 이 고리가 앉을 층(소켓은 자기 층, 목록은 지금 고른 층).
## ⚠ 색은 `ui_color` 정본 그대로다 — 로컬에서 바꾸면 판과 갈라진다. 톤은 카드 알파로 조인다.
const ICON_LANE_ALPHA := 0.32
const ICON_LANE_W := 1.0
const ICON_MOTIF_W := 1.6

func _ring_icon(c: Vector2, radius: float, gr: GlyphRingDef, band_index: int = 0) -> void:
	var geom := ring_icon_geom(gr, c, radius, band_index)
	var lane: Vector2 = geom["lane"]
	var line_col: Color = Color(gr.ui_color, ICON_LANE_ALPHA) if gr != null else SOCKET_EMPTY
	draw_arc(c, lane.x, 0.0, TAU, 32, line_col, ICON_LANE_W, true)
	draw_arc(c, lane.y, 0.0, TAU, 32, line_col, ICON_LANE_W, true)
	if gr == null:
		return
	for sub: PackedVector2Array in geom["motifs"]:
		if sub.size() >= 2:
			draw_polyline(sub, gr.ui_color, ICON_MOTIF_W, true)


## ⚠ 문양 이름이 필요해지면 주입된 `_glyph_defs`에서 `code`로 찾아라 — 책은 오토로드를 안 본다.


func _text(font: Font, at: Vector2, text: String, col: Color, fs: int) -> void:
	draw_string(font, at + Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 긴 이름이 카드 밖으로 넘치지 않게 잘라 준다(넘치면 「…」).
## ⚠ 자르는 건 **표시뿐**이고 값은 `display_name` 정본 그대로다.
func _fit_text(font: Font, text: String, max_w: float, fs: int) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
		return text
	var cut := text
	while cut.length() > 1 and font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT,
			-1, fs).x > max_w:
		cut = cut.substr(0, cut.length() - 1)
	return cut + "…"


func _text_center(font: Font, at: Vector2, text: String, col: Color, fs: int) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-tw * 0.5, fs * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
