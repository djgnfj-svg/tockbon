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
## 🔴 세81 M2 융합진 — 룬 소켓(자리)을 골랐다(강조 대상). 다음에 고르는 룬이 이 자리에 들어간다.
## 자리 1개 진에선 소켓이 안 그려져 이 시그널이 안 난다(무회귀).
signal rune_slot_selected(i: int)
## 🔴 세71 조립→탁본 — 밴드 소켓을 골랐다(강조 대상) / 소켓에 끼울 문양-고리를 골랐다.
## 옛 `glyph_selected`(개별 문양 배치)를 대체한다 — 문양은 이제 진의 **층(band)**에 끼운다.
signal band_selected(i: int)
signal ring_picked(gr_id: StringName)

const TAB_JIN := 0
const TAB_RUNE := 1
const TAB_GLYPH := 2                    # 세71: "문양 개별" → "층 소켓" 탭 (라벨=층)
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
# 세71b — 순서 잠금 탭(아직 못 여는 탭). 회색 베일 + 흐린 글자로 "지금은 못 연다"를 알린다.
const TAB_LOCK_BG := Color(0.58, 0.53, 0.46, 0.55)
const TAB_LOCK_VEIL := Color(0.50, 0.46, 0.40, 0.45)
const TAB_LOCK_TEXT := Color(0.52, 0.48, 0.42, 0.7)
const OPEN_DOT := Color(0.85, 0.50, 0.18)          # 진 셀 8점 다이어그램: 열린 문양 칸
const SHUT_DOT := Color(0.30, 0.26, 0.20, 0.4)     # 닫힌 칸
# ── 층(band) 소켓 톤 (세71 — 슬라이스 패널 SOCKET_* 계열) ──
const SOCKET_BG := Color(0.84, 0.78, 0.66)
const SOCKET_EMPTY := Color(0.20, 0.14, 0.09, 0.28)

const TAB_H := 18.0
const TAB_GAP := 2.0

## 세62 — 탭·셀 카드 배경 한지 나인패치(panel_paper_s 24×24 m6, 세션21 대청소로 고아가 된 걸 되살림).
## 🔴 exists 가드로 첫 `_draw`에서 한 번 만들어 캐시 — PNG가 없으면 현 draw_rect 플랫 폴백(계약).
## off 탭/비선택 셀 = 같은 StyleBox 복제 + modulate_color 0.85 어둡게 — 상태별 텍스처를 늘리지 않는다.
const CARD_TEX := "res://assets/sprites/ui/panel_paper_s.png"
const CARD_TEX_MARGIN := 6.0
const CARD_OFF_MOD := Color(0.85, 0.85, 0.85, 1.0)

const TAB_DESC := [
	"진 — 바깥 그릇(형태). 발사 형태와 열리는 칸이 진마다 다르다.",
	"룬 — 중심 속성. 탁본으로 해독한 룬을 고른다.",
	"층 — 진의 층에 문양-고리를 끼운다.",
]

var _stage := TAB_JIN                 # 진 탭부터 편다 (순차 조립)
## 🔴 세81: 층 탭 「보유 문양-고리」 목록 세로 스크롤(px) — 목록이 책을 넘치면 마우스 휠로 굴린다
## (사용자 지적: 폭발진 등이 UI 밖으로 넘어감). 클램프는 `_draw_band_sockets`가 콘텐츠·가시영역으로.
var _ring_scroll := 0.0
## 🔴 세71b 점진 조립 — 어느 탭이 열렸나 (진 선택⇒룬 탭·룬 선택⇒층 탭). 패널이 선택 상태에서
## 파생해 `set_open_tabs`로 주입한다(단일 소스=패널 선택, `set_defs`와 동형·module-local). 잠긴 탭은
## 회색으로 그리고 클릭을 거부한다. 기본 = 전부 열림(옛 호출부·주입 전 첫 프레임 호환).
var _open_tabs: Array = [true, true, true]
var _rune_choice := -1                # 지금 고른 룬 타입 (하이라이트) — -1=아직 (세션 34)
## 🔴 세81 M2 융합진 룬 소켓 — 패널이 `set_rune_slots`로 주입한다(책은 오토로드를 안 본다). 자리별
## 고른 룬(or -1) 목록 + 활성 자리. size ≤ 1이면 소켓을 안 그린다(일반진 무회귀).
var _rune_picks: Array = []
var _sel_rune_slot := 0
var _jin_choice: StringName = &""     # 지금 고른 진 id (하이라이트) — &""=아직 (세션44, 진=형태 선택)
var _tab_rects: Array[Rect2] = []
## 클릭 가능한 칸 — {rect, kind:"jin"/"rune"/"band"/"ring", value}
var _cells: Array[Dictionary] = []
# ── 🔴 세71 층 소켓 상태 — 패널이 `set_bands`로 주입한다 (책은 오토로드·Db를 안 본다). ──
var _bands: Array = []                # 밴드 idx → GlyphRingDef(or null) — 패널이 Db로 해석해 넘긴다
var _sel_band := 0                    # 지금 고른(강조) 밴드
var _available_rings: Array = []      # 보유(해금) 문양-고리 GlyphRingDef 목록 — 패널이 필터해 넘긴다

# ── 주입 데이터 (세션 13 구조화) — 패널이 Db에서 읽어 넣는다. 없으면 RingBoard const 폴백. ──
var _jin_defs: Array = []
## 카드 StyleBox 캐시 (세62) — null이면 플랫 폴백. `_tried`로 매 프레임 exists 조회를 막는다.
var _card_sb_on: StyleBoxTexture = null
var _card_sb_off: StyleBoxTexture = null
var _card_sb_tried := false
## 🔴 해금된 룬들 (RuneDef 배열, 세션 34). 패널이 `is_unlocked`로 걸러 넘긴다 — 책은
## 오토로드를 안 봐서(주석 상단) 해금 판정을 직접 못 한다. 잠긴 룬은 셀 자체가 안 뜬다.
var _rune_defs: Array = []
var _glyph_defs: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Db에서 읽은 진·룬·문양 정의를 주입한다 (셀 이름·색을 여기서 열거한다).
## 🔴 runes = **해금된 룬만** (패널이 걸러 넘긴다) — 잠긴 룬은 셀이 안 뜬다 (세션 34).
func set_defs(jins: Array, runes: Array, glyph_defs: Array = []) -> void:
	_jin_defs = jins
	_rune_defs = runes
	_glyph_defs = glyph_defs   # 세71: 개별 문양 탭 은퇴로 미사용 — 옛 호출부 호환용으로만 받는다
	queue_redraw()


## 🔴 세71 조립→탁본 — 층 소켓 상태를 주입한다 (`set_defs`와 동형). 패널이 Db·codex를 해석해
## 밴드별 GlyphRingDef(or null)와 보유 목록을 넘긴다 — 책은 오토로드를 안 봐서 직접 못 한다.
func set_bands(bands: Array, sel_band: int, available_rings: Array) -> void:
	_bands = bands
	_sel_band = sel_band
	_available_rings = available_rings
	queue_redraw()


## 🔴 세81 M2 융합진 — 룬 소켓 상태를 주입한다 (`set_bands`와 동형). picks[i] = 그 자리 룬(or -1),
## sel_slot = 활성 자리. size ≤ 1이면 룬 탭이 소켓을 안 그린다(일반진 = 옛 흐름 그대로).
func set_rune_slots(picks: Array, sel_slot: int) -> void:
	_rune_picks = picks
	_sel_rune_slot = sel_slot
	queue_redraw()


## 🔴 세71b 점진 조립 — 열린 탭 집합을 주입한다(`set_defs`/`set_bands`와 동형). `open[stage]`가 false면
## 그 탭은 회색·클릭 거부. 지금 펼친 탭이 잠겼으면(리셋·펑) 진 탭으로 되돌린다 — 잠긴 탭이 펼쳐진 채
## 남지 않게. 잠금 판정 단일 소스는 패널의 선택 상태다(책은 오토로드·Db를 안 본다).
func set_open_tabs(open: Array) -> void:
	_open_tabs = open
	if not _tab_is_open(_stage):
		_stage = TAB_JIN
	queue_redraw()


func _tab_is_open(stage: int) -> bool:
	return stage >= 0 and stage < _open_tabs.size() and bool(_open_tabs[stage])


func _jin_name() -> String:
	return String(_jin_defs[0].display_name) if not _jin_defs.is_empty() else "일반진"

func _jin_ui_color() -> Color:
	return _jin_defs[0].ui_color if not _jin_defs.is_empty() else RingBoard.RING_LINE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


# ─────────────────────────── 입력 ───────────────────────────

## 🔴 세81: 넘치는 목록이 책 밖으로 흘러 다른 UI를 덮지 않게 Control 경계로 클립한다(스크롤과 한 쌍).
func _ready() -> void:
	clip_contents = true


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	# 🔴 세81: 층 탭 문양-고리 목록 휠 스크롤 — 굴린 뒤 클램프는 draw가 한다(콘텐츠 크기를 draw가 안다).
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
			# 🔴 세71b: 잠긴 탭(진 안 고름=룬 탭 잠김 등)은 클릭을 먹되 무시한다 — 순서를 건너뛸 수 없다.
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
				_jin_choice = StringName(cell.value)   # 하이라이트 (세션44: 여러 진 셀)
				jin_selected.emit(StringName(cell.value))
			"rune":
				_rune_choice = int(cell.value)   # 하이라이트 (세션 34: 여러 룬 셀)
				rune_selected.emit(int(cell.value))
			"rune_slot":
				_sel_rune_slot = int(cell.value)   # 세81 M2: 채울 활성 자리 (패널이 set_rune_slots로 되돌림)
				rune_slot_selected.emit(int(cell.value))
			"band":
				_sel_band = int(cell.value)      # 세71: 강조할 밴드 (패널이 set_bands로 되돌림)
				band_selected.emit(int(cell.value))
			"ring":
				ring_picked.emit(StringName(cell.value))   # 세71: 선택 밴드에 이 고리를 끼운다
		queue_redraw()
		accept_event()
		return


# ─────────────────────────── 렌더 ───────────────────────────

## 탭·셀 카드 배경 StyleBox — 첫 호출에 exists 가드로 만들어 캐시. PNG가 없으면 null을 돌려주고
## 호출한 쪽이 현 draw_rect 플랫 렌더로 폴백한다(세62 계약 — 헤드리스·에셋 미도착에서 안 죽는다).
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


## 카드 하나(탭·셀 공용) — 텍스처가 있으면 나인패치 + 선택 시 SEL_EDGE 코드 테두리(설계 §테마),
## 없으면 옛 플랫 렌더 그대로. `flat_bg`/`flat_edge`는 폴백 전용 색.
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
		var locked := not _tab_is_open(stage)   # 🔴 세71b: 아직 못 여는 탭(순서 잠금)
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
		_draw_card(r, sel, CELL_SEL_BG if sel else CELL_BG,
			SEL_EDGE if sel else CELL_LINE, 2.0 if sel else 1.0)
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
			sel_desc = _jin_desc_of(jd)
	# 고른 진의 설명 한 줄 (격자 바로 아래). 아직 안 골랐으면 무엇을 하라는지 알린다.
	var chosen := _jin_choice != &""
	var dy := top + float(nrows) * (ch + JIN_GAP) + 2.0
	if sel_desc.is_empty():
		sel_desc = "셀을 클릭하면 왼쪽 판에 그 진의 밑그림이 뜬다."
	_text(font, Vector2(8.0, dy), sel_desc, SEL_EDGE if chosen else DESC_COLOR, 8)


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
## ⚠ **`_draw_*`가 아니라 여기가 관측점이다** (`RingBoard.glyph_guide_pts`와 같은 이유): 헤드리스는
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
## 🔴 세81 M2 융합진 룬 소켓 (룬 탭 위, 자리 ≥2일 때만). 한 줄 가로 배치 — 자리마다 미니 룬 아이콘.
const RUNE_SOCKET_H := 34.0
const RUNE_SOCKET_GAP := 6.0
const RUNE_SOCKET_MARGIN := 8.0        # 소켓 줄과 아래 룬 격자 사이 여백

## 룬 소켓이 룬 탭 본문에서 차지하는 세로 높이 (자리 ≤1이면 0 = 소켓 없음 = 무회귀).
static func rune_socket_reserved(n: int) -> float:
	return (RUNE_SOCKET_H + RUNE_SOCKET_MARGIN) if n >= 2 else 0.0

## 🔴 룬 소켓 rect — 순수 함수(헤드리스 관측점). 자리 ≤1이면 빈 배열(소켓 안 그림).
static func rune_socket_rects(n: int, book_size: Vector2, top: float) -> Array:
	var out: Array = []
	if n < 2:
		return out
	var sw := (book_size.x - 16.0 - RUNE_SOCKET_GAP * float(n - 1)) / float(n)
	for i in n:
		out.append(Rect2(8.0 + float(i) * (sw + RUNE_SOCKET_GAP), top, sw, RUNE_SOCKET_H))
	return out


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
	# 🔴 세81 M2: 융합진(룬 자리 ≥2)이면 룬 격자 위에 **룬 소켓 줄**을 그리고, 격자를 그만큼 내린다.
	# 자리 1개(일반진)면 예약 높이 0 = 소켓 없음 = 옛 룬 탭 그대로(무회귀).
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


## 룬 아이콘 — 🔴 **판의 밑그림과 같은 함수를 부른다**(`RingBoard.rune_guide_verts`, 세션49).
## 세션34~48엔 여기가 같은 모양을 **따로 베끼고** 있어, 룬을 6종으로 늘릴 때 한쪽만 갈라질 수 있었다
## (진이 세션48에 `jin_guide_pts`로, 문양이 세션47에 같은 이유로 합쳐진 그 자리다).
## **셀에서 본 모양 = 손으로 그을 모양**이 이제 구조적으로 못 갈라진다.
func _draw_rune_icon(c: Vector2, s: float, col: Color, rune_type: int) -> void:
	draw_polyline(RingBoard.rune_guide_verts(rune_type, c, s), col, 2.5, true)


## 🔴 세81 M2 융합진 룬 소켓 줄 — 자리 N칸(자리 ≥2일 때만). 각 소켓 = 자리번호 + 채운 룬 미니 아이콘,
## 활성 자리는 강조 테두리. 클릭 = 그 자리를 활성으로(rune_slot_selected). 자리 1개면 아무것도 안 그린다.
## 소켓 상태는 패널이 `set_rune_slots`로 주입한다(책은 오토로드를 안 본다 = 밴드 소켓과 같은 규율).
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


## 주입된 해금 룬 정의 중 타입이 일치하는 것 (소켓 아이콘 색·이름용). 없으면 null.
func _rune_def_of(rune_type: int) -> RuneDef:
	for rd_v in _rune_defs:
		var rd := rd_v as RuneDef
		if rd != null and int(rd.type) == rune_type:
			return rd
	return null


## 🔴 세71 층 탭 — 진의 **층(band) 소켓** N칸 + 보유 문양-고리 목록. 소켓 클릭=강조 밴드 선택,
## 고리 클릭=선택 밴드에 끼움. 개별 문양 배치(옛 `_draw_glyph_cells`)를 대체한다.
## 밴드·고리 상태는 패널이 `set_bands`로 주입한다(책은 오토로드를 안 본다 = 기존 규율).
## 🔴 소켓/목록 rect는 **순수 static**(`band_socket_rects`·`ring_list_rects`) — `_draw_*` 안에
## 계산을 두면 헤드리스가 레이아웃을 못 잰다(`jin_cell_rects`·`rune_cell_rects`와 같은 규율).
const BAND_SOCKET_H := 40.0
const BAND_SOCKET_GAP := 6.0
const RING_ROW_H := 30.0
const RING_ROW_GAP := 4.0
const RING_LIST_HEADER := 20.0        # 소켓 아래 "보유 문양-고리" 머리글 높이

static func band_socket_rects(n: int, book_size: Vector2, top: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(Rect2(8.0, top + float(i) * (BAND_SOCKET_H + BAND_SOCKET_GAP),
			book_size.x - 16.0, BAND_SOCKET_H))
	return out

## 소켓 밑 목록의 시작 y — 소켓 N칸 + 머리글 높이. 소켓 rect와 같은 top을 넘긴다.
static func band_list_top(band_n: int, top: float) -> float:
	return top + float(band_n) * (BAND_SOCKET_H + BAND_SOCKET_GAP) + RING_LIST_HEADER

static func ring_list_rects(n: int, book_size: Vector2, list_top: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(Rect2(8.0, list_top + float(i) * (RING_ROW_H + RING_ROW_GAP),
			book_size.x - 16.0, RING_ROW_H))
	return out


func _draw_band_sockets(font: Font, top: float) -> void:
	var n := _bands.size()
	var srects := band_socket_rects(n, size, top)
	for i in n:
		var r: Rect2 = srects[i]
		var gr := _bands[i] as GlyphRingDef
		var sel := i == _sel_band
		_cells.append({"rect": r, "kind": "band", "value": i})
		draw_rect(r, SOCKET_BG, true)
		# ⚠ 선택 강조는 **얇게**(2.5→1.6). 굵은 주황 테두리가 카드보다 더 눈에 띄어
		# 목록 전체가 시끄러웠다(세82 사용자 지적).
		draw_rect(r, SEL_EDGE if sel else SOCKET_EMPTY, false, 1.6 if sel else 1.0)
		# 밴드 번호는 **늘** 왼쪽 위에 — 끼웠든 비었든 "몇 층인가"가 이 칸의 정체다.
		_text(font, r.position + Vector2(4.0, 2.0), "%d" % (i + 1),
			SEL_EDGE if sel else DESC_COLOR, 8)
		if gr != null:
			_ring_icon(r.position + Vector2(r.size.y * 0.5, r.size.y * 0.5), r.size.y * 0.34, gr)
			# ⚠ 이름을 두 번 적지 마라 — `display_name`이 이미 "발산 고리 ×5"라
			# 뒤에 `모티프×개수`를 붙이면 **"발산 고리 ×5 (발산→×5)"**가 된다(세82 사용자 지적).
			_text(font, r.position + Vector2(r.size.y + 6.0, r.size.y * 0.5 - 6.0),
				gr.display_name, NAME_COLOR, 9)
		else:
			_text(font, r.position + Vector2(10.0, r.size.y * 0.5 - 6.0),
				"밴드 %d — 비었다 (아래 고리 클릭)" % (i + 1), DESC_COLOR, 9)

	# 보유 문양-고리 목록 (선택 밴드에 끼운다) — 머리글은 고정, 행만 휠 스크롤(세81).
	var list_top := band_list_top(n, top)
	_text(font, Vector2(8.0, list_top - RING_LIST_HEADER + 2.0),
		"보유 문양-고리 (클릭 → 밴드 %d)" % (_sel_band + 1), DESC_COLOR, 9)
	# 🔴 세81: 스크롤 클램프 — 콘텐츠 높이가 가시영역(list_top→책 바닥)을 넘칠 때만 굴러간다.
	var row_pitch := RING_ROW_H + RING_ROW_GAP
	var content_h := float(_available_rings.size()) * row_pitch
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
		# 🔴 세82: 가시영역에 **온전히 들어오는 행만** 그린다. 예전엔 걸친 행도 그려서
		# 책 아래쪽에 **반쯤 잘린 카드**가 남았다(사용자: "좀 깔끔했으면"). _cells에도 안 담아
		# 반쯤 보이는 걸 클릭하는 일이 없다.
		if rr.position.y < list_top or rr.position.y + rr.size.y > size.y:
			continue
		_cells.append({"rect": rr, "kind": "ring", "value": gr2.id})
		draw_rect(rr, Color(gr2.ui_color, 0.10), true)
		draw_rect(rr, Color(gr2.ui_color, 0.7), false, 1.5)
		_ring_icon(rr.position + Vector2(rr.size.y * 0.5, rr.size.y * 0.5), rr.size.y * 0.34, gr2)
		_text(font, rr.position + Vector2(rr.size.y + 8.0, rr.size.y * 0.5 - 5.0),
			gr2.display_name, NAME_COLOR, 9)
	# 🔴 세81: 넘칠 때만 오른쪽에 얇은 스크롤 썸(있다는 신호 — 없으면 휠 되는지 모른다).
	if max_scroll > 0.0:
		var track_x := size.x - 5.0
		var track_h := visible_h
		var thumb_h := maxf(18.0, track_h * (visible_h / content_h))
		var thumb_y := list_top + (track_h - thumb_h) * (_ring_scroll / max_scroll)
		draw_rect(Rect2(track_x, list_top, 3.0, track_h), Color(0.42, 0.30, 0.12, 0.12), true)
		draw_rect(Rect2(track_x, thumb_y, 3.0, thumb_h), Color(0.42, 0.30, 0.12, 0.5), true)


## 문양-고리 아이콘 — 밴드 원 + count번 낱개 모티프(절차 가이드선 = 규칙 §0 도형금지 예외).
## `RingBoard.glyph_guide_pts`를 그대로 부른다(셀=밑그림 규율) — 슬라이스 패널 `_ring_icon` 이식.
func _ring_icon(c: Vector2, radius: float, gr: GlyphRingDef) -> void:
	if gr == null:
		return
	draw_arc(c, radius, 0.0, TAU, 24, Color(gr.ui_color, 0.35), 1.0, true)
	var n := maxi(gr.count, 1)
	for i in n:
		var a := TAU * float(i) / float(n) - PI / 2.0
		var p := c + Vector2.from_angle(a) * radius
		var outward := Vector2.from_angle(a)
		var mk := RingBoard.glyph_guide_pts(gr.motif, p, outward, radius * 0.42)
		if mk.size() >= 2:
			draw_polyline(mk, gr.ui_color, 1.5, true)


## ⚠ 옛 `_motif_name(code)`은 세82에 지웠다 — 소켓·목록이 `display_name`("발산 고리 ×5")에
## 모티프 이름을 **또** 붙여 "발산 고리 ×5 (발산→×5)"로 나오던 걸 걷어내자 **소비자가 0**이 됐다.
## 문양 이름이 다시 필요해지면 주입된 `_glyph_defs`에서 `code`로 찾아라(책은 오토로드를 안 본다).


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


func _text(font: Font, at: Vector2, text: String, col: Color, fs: int) -> void:
	draw_string(font, at + Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_center(font: Font, at: Vector2, text: String, col: Color, fs: int) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-tw * 0.5, fs * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
