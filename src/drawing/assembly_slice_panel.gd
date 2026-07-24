extends Control
## 🔴 세68 조립→탁본 **슬라이스 조립 패널** (신설·병렬 — 라이브 포지는 안 건드린다).
##
## 왼쪽 = RingBoard(재사용)에 합성 가이드를 통째로 긋는다. 오른쪽 = 얇은 조립 UI:
##   진 자동선택(jin_single) · 밴드 소켓 2칸 · 보유 문양-고리 목록(해금분만).
## 목록 셀 클릭 → 선택 밴드에 끼움 → `RingBoard.compose_guide`로 밑그림 재합성.
## 하단 [분석 ▶] → `combined_total`로 리포트 · [마력 주입] → `RingPower.is_stable` 판정 →
## 밴드→플래튼 8칸으로 발사 계약(assembly)을 조립해 `committed(assembly)`로 흘린다.
##
## 🔴 mouse_filter (세25 함정): 루트 = IGNORE(덮는 배경이 좌클릭을 안 먹는다),
## Board = STOP(그려야 하니까), RightPane = STOP(소켓·목록·버튼 클릭 잡이 — 루트로 forward).
## 발사는 이 패널이 **숨었을 때**(visible=false)만 시험대가 처리한다.
##
## 사용: const AssemblySlicePanel := preload("res://src/drawing/assembly_slice_panel.gd")

const RingBoard := preload("res://src/drawing/ring_board.gd")
const RingPower := preload("res://src/core/ring_power.gd")

const BANDS := 2                            # 최소 슬라이스 = 동심원 2겹
const JIN_ID := &"jin_single"               # 슬라이스 진 (동그라미)
const RUNE_FIRE := 0                        # 기본 룬 (불) — 발사 계약에 실린다

# ── 색 (양피지·먹 톤 — ring_board와 같은 계열) ──
const BG := Color(0.91, 0.87, 0.78)
const INK := Color(0.20, 0.14, 0.09)
const INK_FAINT := Color(0.20, 0.14, 0.09, 0.28)
const SOCKET_BG := Color(0.84, 0.78, 0.66)
const SOCKET_SEL := Color(0.95, 0.55, 0.15)
const REJECT_COL := Color(0.70, 0.20, 0.14)

signal committed(assembly: Dictionary)

var _board: Control = null                  # RingBoard 인스턴스 (씬에서 $Board)
var _bands: Array[StringName] = []          # 밴드 idx → 문양-고리 id (&"" = 빈 밴드)
var _sel_band := 0                          # 지금 고른 밴드 (강조)
var _report: Dictionary = {}                # 분석 결과 {score, power, grade, stable}
var _notice := ""                           # 하단 안내 (거부 사유 등)

var _db: Node = null
var _gs: Node = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 🔴 덮는 배경 — 클릭을 안 먹는다 (세25)


func _ready() -> void:
	_db = get_node_or_null(^"/root/Db")
	_gs = get_node_or_null(^"/root/GameState")
	_board = get_node_or_null(^"Board")
	var right := get_node_or_null(^"RightPane")
	if right != null and not right.gui_input.is_connected(_on_right_gui_input):
		right.gui_input.connect(_on_right_gui_input)
	_reset_bands()
	if _board != null:
		# 진 색·형태를 보드에 주입(합성엔 shape만 쓰지만 렌더 색 폴백에 도움)
		var jin := _jin_def()
		if jin != null and _board.has_method("set_defs"):
			_board.set_defs(jin, [], [])
	recompose()


# ─────────────────────────── 공개 API (시험대·헤드리스 테스트가 부른다) ───────────────────────────

## RingBoard 인스턴스 (트레이스 보드) — 테스트가 guide_points·trace_stroke를 관측한다.
func board() -> Control:
	return _board


## 보유(해금)한 문양-고리 목록 — sort 순. codex 미해금은 뺀다.
func available_rings() -> Array:
	var out: Array = []
	if _db == null or not _db.has_method("all_glyph_rings"):
		return out
	for gr in _db.all_glyph_rings():
		if _is_unlocked(gr):
			out.append(gr)
	return out


func _is_unlocked(gr: GlyphRingDef) -> bool:
	if gr == null:
		return false
	if String(gr.unlock_id).is_empty():
		return true
	if _gs == null:
		return true
	return bool(_gs.codex.get(gr.unlock_id, false))


## 밴드를 고른다 (강조 대상).
func select_band(i: int) -> void:
	_sel_band = clampi(i, 0, BANDS - 1)
	queue_redraw()


## 밴드에 문양-고리를 끼운다(또는 뺀다: gr_id=&""). 가이드를 재합성한다.
func socket_ring(band_idx: int, gr_id: StringName) -> void:
	if band_idx < 0 or band_idx >= BANDS:
		return
	_bands[band_idx] = gr_id
	_report = {}
	_notice = ""
	recompose()


## 각 밴드의 GlyphRingDef(or null) — compose_guide·flatten_bands가 받는 형식.
func band_defs() -> Array:
	var out: Array = []
	for id in _bands:
		out.append(_ring_def(id))
	return out


## 조립본을 합성해 보드에 통째 트레이스 가이드로 넣는다.
func recompose() -> void:
	if _board == null:
		return
	var ctr: Vector2 = _board.size * 0.5
	var ro := float(_board.size.x)
	if _board.has_method("_outer_radius"):
		ro = _board._outer_radius()
	var guide := RingBoard.compose_guide(_jin_shape(), [RUNE_FIRE], band_defs(), ctr, ro)
	if _board.has_method("enter_combined_trace"):
		_board.enter_combined_trace(guide)
	queue_redraw()


## 지금 그은 통째 점수 → 리포트 {score, power, grade, stable}. [분석 ▶]이 부른다.
func analyze() -> Dictionary:
	var score := 0.0
	if _board != null and _board.has_method("combined_total"):
		score = _board.combined_total()
	_report = {
		"score": score,
		"power": RingPower.power_display(score),
		"grade": RingPower.grade_of(score),
		"stable": RingPower.is_stable(score),
	}
	_notice = ""
	queue_redraw()
	return _report


## 🔴 밴드→플래튼 8칸 → 발사 계약(assembly). `score`를 반드시 싣는다(세26 함정 — 안 실으면
## 조용히 기준 위력). rune=불·jin=jin_single·ink=""·size=1.0. open = 채운 칸 목록.
func build_assembly() -> Dictionary:
	var ring := RingBoard.flatten_bands(band_defs())
	var open: Array = []
	for k in ring.size():
		if int(ring[k]) != RingBoard.GLYPH_NONE:
			open.append(k)
	var score := 0.0
	if _board != null and _board.has_method("combined_total"):
		score = _board.combined_total()
	return {
		"ring_count": 1, "rune": RUNE_FIRE, "jin": JIN_ID,
		"rings": [ring], "open": open, "score": score, "ink": &"", "size": 1.0,
	}


## [마력 주입] — 안정하면 맺어 `committed` 발신, 미달이면 거부 안내(펑). 반환 = 맺었나.
func try_inject() -> bool:
	if _report.is_empty():
		analyze()
	var score := float(_report.get("score", 0.0))
	if not RingPower.is_stable(score):
		_notice = "마력이 흩어졌다 — 더 정성껏 그려라 (점수 %d)" % RingPower.score_display(score)
		queue_redraw()
		return false
	var assembly := build_assembly()
	committed.emit(assembly)
	_notice = "마법진을 맺었다 (위력 %d)" % RingPower.power_display(score)
	queue_redraw()
	return true


## 패널을 연다 — 진 자동선택·밴드 비움·가이드 재합성.
func open_panel() -> void:
	visible = true
	_reset_bands()
	_report = {}
	_notice = ""
	recompose()


func close_panel() -> void:
	visible = false


# ─────────────────────────── 내부 ───────────────────────────

func _reset_bands() -> void:
	_bands = []
	for i in BANDS:
		_bands.append(&"")
	_sel_band = 0


func _jin_def() -> JinDef:
	if _db != null and _db.has_method("get_jin"):
		return _db.get_jin(JIN_ID)
	return null


func _jin_shape() -> int:
	var jin := _jin_def()
	return int(jin.guide_shape) if jin != null else int(Enums.JinShape.CIRCLE)


func _ring_def(id: StringName) -> GlyphRingDef:
	if String(id).is_empty() or _db == null or not _db.has_method("get_glyph_ring"):
		return null
	return _db.get_glyph_ring(id)


# ─────────────────────────── 오른쪽 UI 레이아웃 (root-space 사각형) ───────────────────────────
## RightPane(full-rect STOP)이 gui_input을 루트로 forward한다. 그리기는 루트가(IGNORE라도 draw는 된다).

func _right_x() -> float:
	return size.x * 0.58

func _socket_rect(i: int) -> Rect2:
	var x := _right_x()
	var y := size.y * 0.14 + float(i) * (size.y * 0.16 + 14.0)
	return Rect2(x, y, size.x * 0.36, size.y * 0.14)

func _ring_rects() -> Array:
	var out: Array = []
	var x := _right_x()
	var y := size.y * 0.50
	var rings := available_rings()
	for i in rings.size():
		out.append({"rect": Rect2(x, y + float(i) * 52.0, size.x * 0.36, 46.0), "gr": rings[i]})
	return out

func _analyze_rect() -> Rect2:
	return Rect2(_right_x(), size.y - 96.0, size.x * 0.17, 40.0)

func _inject_rect() -> Rect2:
	return Rect2(_right_x() + size.x * 0.19, size.y - 96.0, size.x * 0.17, 40.0)


func _on_right_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = mb.position   # RightPane full-rect라 root-space와 동일
	# 밴드 소켓
	for i in BANDS:
		if _socket_rect(i).has_point(p):
			select_band(i)
			accept_event()
			return
	# 문양-고리 목록 → 선택 밴드에 끼움
	for entry in _ring_rects():
		if (entry.rect as Rect2).has_point(p):
			socket_ring(_sel_band, (entry.gr as GlyphRingDef).id)
			accept_event()
			return
	# 버튼
	if _analyze_rect().has_point(p):
		analyze()
		accept_event()
		return
	if _inject_rect().has_point(p):
		try_inject()
		accept_event()
		return


# ─────────────────────────── 렌더 (루트가 전 영역을 그린다) ───────────────────────────

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var font := ThemeDB.fallback_font
	_text(font, Vector2(size.x * 0.03, 26), "조립 → 탁본  (세68 슬라이스)", INK, 20)
	_text(font, Vector2(_right_x(), size.y * 0.09),
		"진: 단발진 (동그라미 · 밴드 2겹)", INK, 14)

	# 밴드 소켓
	for i in BANDS:
		var r := _socket_rect(i)
		var sel := i == _sel_band
		draw_rect(r, SOCKET_BG)
		draw_rect(r, SOCKET_SEL if sel else INK_FAINT, false, 2.5 if sel else 1.0)
		var gr := _ring_def(_bands[i])
		if gr != null:
			_ring_icon(r.position + Vector2(r.size.y * 0.5, r.size.y * 0.5), r.size.y * 0.36, gr)
			_text(font, r.position + Vector2(r.size.y + 6.0, r.size.y * 0.5 + 5.0),
				gr.display_name, INK, 14)
		else:
			_text(font, r.position + Vector2(10, r.size.y * 0.5 + 5.0),
				"밴드 %d — 비었다 (아래에서 고리를 끼워라)" % (i + 1), INK_FAINT, 13)

	# 보유 문양-고리 목록
	_text(font, Vector2(_right_x(), size.y * 0.47), "보유 문양-고리 (클릭 → 선택 밴드)", INK, 14)
	for entry in _ring_rects():
		var rr: Rect2 = entry.rect
		var g := entry.gr as GlyphRingDef
		draw_rect(rr, Color(g.ui_color, 0.10))
		draw_rect(rr, Color(g.ui_color, 0.7), false, 1.5)
		_ring_icon(rr.position + Vector2(rr.size.y * 0.5, rr.size.y * 0.5), rr.size.y * 0.36, g)
		_text(font, rr.position + Vector2(rr.size.y + 8.0, rr.size.y * 0.5 + 5.0),
			"%s  (%s×%d)" % [g.display_name, _motif_name(g.motif), g.count], INK, 14)

	# 버튼
	_button(font, _analyze_rect(), "분석 ▶", INK)
	_button(font, _inject_rect(), "마력 주입", SOCKET_SEL)

	# 리포트 1줄
	if not _report.is_empty():
		var col: Color = INK if bool(_report.get("stable", false)) else REJECT_COL
		_text(font, Vector2(_right_x(), size.y - 116.0),
			"점수 %d · 위력 %d · %s" % [
				RingPower.score_display(float(_report.get("score", 0.0))),
				int(_report.get("power", 0)), String(_report.get("grade", ""))],
			col, 15)
	if not _notice.is_empty():
		_text(font, Vector2(_right_x(), size.y - 44.0), _notice, INK, 13)

	# 왼쪽 안내
	_text(font, Vector2(size.x * 0.03, size.y - 30.0),
		"왼쪽 판을 손으로 따라 그어라 (우클릭=다시 · 휠=크기) · [E] 덮고 발사", INK_FAINT, 13)


## 문양-고리 아이콘 — count번 낱개 모티프를 절차적으로 그린다(도형 아님, 가이드선 = 규칙 예외).
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


func _button(font: Font, r: Rect2, label: String, col: Color) -> void:
	draw_rect(r, Color(col, 0.14))
	draw_rect(r, col, false, 2.0)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, r.position + Vector2((r.size.x - w) * 0.5, r.size.y * 0.5 + 6.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


func _text(font: Font, at: Vector2, s: String, col: Color, fs: int) -> void:
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _motif_name(code: int) -> String:
	var names := RingBoard.GLYPH_NAMES
	return String(names[code]) if code >= 0 and code < names.size() else "?"
