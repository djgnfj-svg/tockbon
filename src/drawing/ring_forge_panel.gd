extends Control
## 고리 조립 제작대 — **책을 좌우로 펼친다.** forge_panel(자유 드로잉)의 껍데기를 그대로
## 잇되(사용자 요청 "이전 왼쪽 UI를 그대로 쓰고 적용되는 형식으로"), 속을 조립 모델로 바꾼다.
##
## 왼쪽 페이지 = **조립 보드**(RingBoard) · 오른쪽 페이지 = **조각 선택기**(RingBook — 문양본·문양 탭).
##
## 🔴 세션 14b — 탁본: 왼쪽 판의 **숨은 선을 손으로 문질러**(자동추적·보정) 드러내고, 조각마다
## 점수를 매긴다. **[다음]**으로 조각을 잠그고 진행(마음에 안 들면 다시 문질러 덮어씀). 진→룬→문양(칸마다).
## 다 그리면 **분석 리포트**(조각별 점수+종합+등급)를 띄우고, 거기서 쏘거나 다시 그린다.
##
## 🔴 옛 forge_panel은 그대로 살아 있다 — 이건 방향 전환을 **손맛으로 확인하려는 평행 패널**이다.
##
## 계약: open() → 열림 / closed 시그널 → 닫힘 / design_committed(assembly) → 맺힘.
## 사용: const RingForgePanel := preload("res://src/drawing/ring_forge_panel.gd")

const RingBoard := preload("res://src/drawing/ring_board.gd")
const RingBook := preload("res://src/drawing/ring_book.gd")

signal closed
## 도안이 방금 맺혔다 — 여는 쪽(작업대·거점)이 발사·연출에 쓴다. assembly = board.get_assembly()
signal design_committed(assembly: Dictionary)

# ── 레이아웃 (뷰포트 640×360 고정) ──
const BOOK_RECT := Rect2(16, 10, 608, 340)
const PAGE_W := 304.0
const BOARD_RECT := Rect2(30, 30, 268, 268)          # 왼쪽 페이지의 조립 보드
const BOOK_RECT_R := Rect2(332, 24, 280, 262)        # 오른쪽 페이지의 선택기(탭)
const SAY_RECT := Rect2(30, 302, 268, 40)            # 스승의 말
const SCORE_RECT := Rect2(332, 288, 280, 12)         # 지금 조각 점수(완성도·정밀도)
const NEXT_BTN_RECT := Rect2(332, 302, 132, 24)      # [다음 ▶] — 조각 잠그고 진행
const COMMIT_BTN_RECT := Rect2(472, 302, 140, 24)    # [맺기] — 마법진 끝내고 분석
const HINT_RECT := Rect2(332, 328, 280, 22)
const TITLE_RECT := Rect2(28, 14, 300, 14)

# ── 한지·먹 톤 (forge_panel과 동일) ──
const DIM := Color(0.05, 0.04, 0.03, 0.62)
const PAPER_L := Color(0.93, 0.89, 0.80)
const PAPER_R := Color(0.89, 0.84, 0.74)
const SPINE := Color(0.62, 0.55, 0.45, 0.55)
const EDGE := Color(0.45, 0.38, 0.30, 0.70)
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)
const TITLE_COLOR := Color(0.36, 0.26, 0.16)
const HINT_COLOR := Color(0.50, 0.45, 0.38)
const SAY_COLOR := Color(0.30, 0.24, 0.18)
const WARN_COLOR := Color(0.62, 0.22, 0.14)
const REPORT_NAME := Color(0.24, 0.19, 0.14)
const REPORT_DESC := Color(0.44, 0.37, 0.30)

const OPEN_SEC := 0.20
const OPEN_FROM_X := 0.04
const CLOSE_SEC := 0.12

const Copy_START := "진을 왼쪽 판에 손으로 문질러 그리세요  (진 → 룬 → 문양 순서로 하나씩 · [다음]으로 진행)"
const SCORE_COLOR := Color(0.34, 0.28, 0.20)

var _board: Control
var _book: Control
var _title: Label
var _say: Label
var _hint: Label
var _score_lbl: Label
var _next_btn: Button
var _commit_btn: Button
var _spread: Control
var _report: Control                          # 분석 리포트 오버레이 (완성 시 표시)

var _committed := false
var _template_idx := 0                        # 지금 삽입된 문양본 (기본 = TEMPLATES[0] = 2방)
var _active_glyph := RingBoard.G_RADIATE      # 지금 고른 문양 (하이라이트)
var _analysis: Dictionary = {}                # 마지막 분석 리포트 (get_analysis 결과)
var _picking_template := false                # 🔴 문양 단계의 하위 단계 — 문양본 고르는 중(아직 안 그림)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_build()


# ─────────────────────────── 열고 닫기 ───────────────────────────

func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_committed = false
	_template_idx = 0
	_active_glyph = RingBoard.G_RADIATE
	_analysis = {}
	_picking_template = false
	_report.visible = false
	_inject_defs()                              # 🔴 Db에서 진·룬·문양 정의를 읽어 주입 (세션 13 구조화)
	_board.call(&"clear_all")                   # 🔴 빈 판에서 시작 — 진 → 룬 → 문양 순차
	_board.call(&"set_active_glyph", _active_glyph)
	_sync_book()
	_set_say(Copy_START, false)
	_update_score()
	_refresh_buttons()
	_spread_open()


func close() -> void:
	if not visible:
		return
	# 🔴 맺기 버튼을 깜빡해도 쏠 수 있게 — 닫을 때 유효한 조립(진·룬 그려짐)이면 자동으로 맺는다.
	if not _committed and bool(_board.call(&"can_commit")):
		_committed = true
		design_committed.emit(_board.call(&"get_assembly"))
		_refresh_buttons()
	var tw := create_tween()
	tw.tween_property(_spread, ^"scale", Vector2(OPEN_FROM_X, 1.0), CLOSE_SEC) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		visible = false
		closed.emit())


func _spread_open() -> void:
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.scale = Vector2(OPEN_FROM_X, 1.0)
	var tw := create_tween()
	tw.tween_property(_spread, ^"scale", Vector2.ONE, OPEN_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func() -> void:
		_board.mouse_filter = Control.MOUSE_FILTER_STOP)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# 🔴 확정은 손으로 문질러 그리고 **[다음]**(또는 Enter)으로 잠근다. Q·W = 문양 고르기.
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_on_next()
			get_viewport().set_input_as_handled()
		KEY_Q:
			_select_glyph(RingBoard.G_GATHER)
			get_viewport().set_input_as_handled()
		KEY_W:
			_select_glyph(RingBoard.G_RADIATE)
			get_viewport().set_input_as_handled()


# ─────────────────────────── Db 데이터 주입 (세션 13 구조화) ───────────────────────────

## Db에서 진·룬(불)·문양 정의를 읽어 보드·책에 넣는다. int const 대신 데이터가 UI를 채운다.
func _inject_defs() -> void:
	var jins: Array = Db.all_jins()
	var fire: RuneDef = Db.get_rune(Enums.RuneType.FIRE)
	var glyphs: Array = Db.all_glyphs()
	var jin0: JinDef = jins[0] if not jins.is_empty() else null
	_board.call(&"set_defs", jin0, fire, glyphs)
	_book.call(&"set_defs", jins, fire, glyphs)


# ─────────────────────────── 선택기 → 보드 (순차 조립) ───────────────────────────

## 오른쪽 탭·placed 표식을 보드의 현재 단계에 맞춘다.
func _sync_book() -> void:
	var tab := _stage_to_tab(int(_board.call(&"stage")))
	_book.call(&"go_stage", tab, bool(_board.call(&"has_jin")), bool(_board.call(&"has_rune")))
	_book.call(&"sync_state", _template_idx, _active_glyph)


func _stage_to_tab(stage: int) -> int:
	match stage:
		RingBoard.STAGE_JIN:
			return RingBook.TAB_JIN
		RingBoard.STAGE_RUNE:
			return RingBook.TAB_RUNE
		_:
			return RingBook.TAB_TEMPLATE


## 진 탭 셀을 눌렀다 — 왼쪽 판에 손으로 **문지르라**는 안내만 (열람용).
func _on_jin_selected() -> void:
	if int(_board.call(&"stage")) == RingBoard.STAGE_JIN:
		_set_say("진을 왼쪽 판에 손으로 문질러 그리세요 (바깥 원) → [다음]", false)


## 룬 탭 셀 — 마찬가지로 안내만.
func _on_rune_selected() -> void:
	if int(_board.call(&"stage")) == RingBoard.STAGE_RUNE:
		_set_say("룬(불)을 중심에 손으로 문질러 그리세요 (삼각) → [다음]", false)


## 🔴 문양 **고르기** (Q·W 또는 문양 셀). 얹기는 왼쪽 판에 손으로 문지른다 — 칸마다.
func _select_glyph(glyph: int) -> void:
	_active_glyph = glyph
	_board.call(&"set_active_glyph", glyph)
	_book.call(&"sync_state", _template_idx, glyph)
	if int(_board.call(&"stage")) != RingBoard.STAGE_GLYPH:
		_set_say("먼저 진과 룬을 그리세요  (진 → 룬 → 문양)", true)
	elif bool(_board.call(&"is_tracing")):
		_set_say("%s 선택 — 칸을 클릭해 손으로 그리세요 · 휠=크기"
			% RingBoard.GLYPH_NAMES[glyph], false)
	else:
		_set_say("%s 선택 — 칸이 다 찼어요. [맺기]로 분석" % RingBoard.GLYPH_NAMES[glyph], false)


func _on_glyph_selected(glyph: int) -> void:
	_select_glyph(glyph)


# ─────────────────── 손맛 피드백 (실시간 점수 · [다음] 진행 · 완성 분석) ───────────────────

## 지금 그리는 조각의 점수가 갱신됐다 (실시간). 완성도·정밀도를 점수 라벨에 보여준다.
func _on_score_changed(_score: float) -> void:
	_update_score()
	_refresh_buttons()


## 한 조각을 [다음]으로 잠갔다 (board.piece_locked). 손맛 피드백 — 문양 칸만 별도 문구.
func _on_piece_locked(target: int, slot: int, score: float) -> void:
	if target == RingBoard.TraceTarget.GLYPH:
		if bool(_board.call(&"is_tracing")):
			_set_say("%s 새겼다 (%d점) — 다른 칸을 클릭해 이어 그리거나 [맺기]"
				% [RingBoard.GLYPH_NAMES[_active_glyph], _pct(score)], false)
		else:
			_set_say("문양 칸을 다 새겼다 (%d점) — [맺기]로 분석" % _pct(score), false)


## 🔴 [다음] (또는 Enter) — 문양본 고르는 단계면 **문양 그리기로 넘어가고**, 아니면 지금 조각을 잠근다.
func _on_next() -> void:
	# 문양본 확정 → 문양 그리기 단계로 (여기서 비로소 문양 탭으로 넘어간다)
	if _picking_template:
		_picking_template = false
		_book.call(&"go_stage", RingBook.TAB_GLYPH, true, true)
		_book.call(&"sync_state", _template_idx, _active_glyph)
		_set_say("칸을 클릭해 고르고 문양(Q·W) 정해 손으로 그리세요 · 휠=문양 크기 · 다른 칸/[다음]으로 이어가기", false)
		_update_score()
		_refresh_buttons()
		return
	if not bool(_board.call(&"is_tracing")):
		return
	if float(_board.call(&"coverage")) <= 0.02:
		_set_say("먼저 왼쪽 선을 손으로 그리세요", true)
		return
	var r := String(_board.call(&"advance"))
	# "advanced" → stage_advanced가 안내 · "finished" → finished 시그널이 리포트를 띄운다
	_update_score()
	_refresh_buttons()


## 보드가 조각을 잠그고 단계를 넘겼다 (진→룬→문양). 탭·안내문을 맞춘다.
func _on_stage_advanced(stage: int) -> void:
	_book.call(&"go_stage", _stage_to_tab(stage),
		bool(_board.call(&"has_jin")), bool(_board.call(&"has_rune")))
	match stage:
		RingBoard.STAGE_RUNE:
			_set_say("진을 새겼다 — 이제 룬(불)을 중심에 그리세요 → [다음]", false)
		RingBoard.STAGE_GLYPH:
			# 🔴 문양 단계 진입 = 먼저 문양본을 고르는 하위 단계. [다음]으로 확정해야 그리기로 넘어간다.
			_picking_template = true
			_set_say("룬을 새겼다 — 문양본(칸 배치)을 고르세요 (바꿔도 됨) → [다음]", false)
		RingBoard.STAGE_JIN:
			_set_say(Copy_START, false)
	_update_score()
	_refresh_buttons()


## 문양본을 삽입했다 — 보드가 그 칸들을 연다. 🔴 **자동으로 문양 탭으로 넘어가지 않는다** (사용자:
## "확정 지으면 그때 넘어가야지"). 문양본 탭에 머물러 다른 문양본으로 바꿔도 되고, 준비되면 사용자가
## 직접 [문양] 탭으로 넘어간다.
func _on_template_selected(idx: int, slots: Array) -> void:
	_template_idx = idx
	_board.call(&"set_template", slots)
	_book.call(&"sync_state", _template_idx, _active_glyph)
	_set_say("%s 문양본 — 바꿔도 돼요. 정했으면 [다음]으로 문양 그리기"
		% RingBoard.TEMPLATES[idx].name, false)
	_update_score()
	_refresh_buttons()


# ─────────────────────────── 맺기 · 분석 리포트 ───────────────────────────

func _on_assembly_changed() -> void:
	_refresh_buttons()


## 🔴 [맺기] — 마법진을 끝내고 분석한다 (남은 문양 칸은 비운 채). 진·룬을 그렸어야 한다.
func _finish() -> void:
	if not bool(_board.call(&"can_commit")):
		_set_say("진과 룬을 먼저 그려야 맺힌다  (문양은 없어도 빈 진으로 날아간다)", true)
		return
	_board.call(&"finish")   # → finished 시그널이 리포트를 띄운다


## 보드가 마법진을 다 그렸다 — 분석 리포트를 띄운다.
func _on_finished(analysis: Dictionary) -> void:
	_analysis = analysis
	_set_say("마법진 완성 — 분석을 보고 쏘거나 다시 그리세요", false)
	_report.visible = true
	_report.queue_redraw()
	_refresh_buttons()


## 리포트에서 [쏘기] — 맺어서 발사로 넘긴다.
func _on_report_shoot() -> void:
	_committed = true
	_report.visible = false
	design_committed.emit(_board.call(&"get_assembly"))
	_set_say("맺혔다 — 책을 덮고(ESC) 쏴 보세요", false)
	_refresh_buttons()


## 리포트에서 [다시] — 처음부터 다시 그린다.
func _on_report_redo() -> void:
	_report.visible = false
	clear_board()


# ─────────────────────────── 버튼·점수 라벨 ───────────────────────────

## 지금 조각 점수(완성도·정밀도·종합)를 라벨에 쓴다. 문양본 고르는 중엔 점수 없음.
func _update_score() -> void:
	if _picking_template or not bool(_board.call(&"is_tracing")):
		_score_lbl.text = ""
		return
	var cov := int(round(float(_board.call(&"coverage")) * 100.0))
	var acc := int(round(float(_board.call(&"accuracy")) * 100.0))
	var sc := _pct(float(_board.call(&"piece_score")))
	_score_lbl.text = "이 조각 — 완성도 %d%% · 정밀도 %d%% · 점수 %d" % [cov, acc, sc]


## 버튼 상태. [다음] = 문양본 고르는 중이면(문양 그리러) 항상 활성 / 그 외엔 지금 조각을 그렸어야 활성.
## [맺기] = 문양을 그리는 중(진·룬 완료 & 문양본 확정)에만 — 룬 직후엔 안 뜬다("문양까지 가야 완료").
func _refresh_buttons() -> void:
	var tracing := bool(_board.call(&"is_tracing"))
	var drawn := float(_board.call(&"coverage")) > 0.02
	if _picking_template:
		_next_btn.disabled = false
		_next_btn.text = "문양 그리기 ▶"
	else:
		_next_btn.disabled = not (tracing and drawn)
		_next_btn.text = "다음 ▶"
	_commit_btn.text = "✓ 맺힘" if _committed else "✓ 맺기 (분석)"
	_commit_btn.disabled = _picking_template or not bool(_board.call(&"can_commit"))


func _pct(score: float) -> int:
	return int(round(clampf(score, 0.0, 1.0) * 100.0))


func _set_say(text: String, warn: bool) -> void:
	if text == "":
		return
	_say.text = text
	_say.add_theme_color_override(&"font_color", WARN_COLOR if warn else SAY_COLOR)


# ─────────────────────────── 외부 조회 ───────────────────────────

func get_assembly() -> Dictionary:
	if not _committed:
		return {}
	return _board.call(&"get_assembly")


func can_commit() -> bool:
	return bool(_board.call(&"can_commit"))


func clear_board() -> void:
	_board.call(&"clear_all")
	_committed = false
	_template_idx = 0
	_active_glyph = RingBoard.G_RADIATE
	_analysis = {}
	_picking_template = false
	_report.visible = false
	_sync_book()
	_set_say(Copy_START, false)
	_update_score()
	_refresh_buttons()


func play_cast() -> void:
	_board.call(&"play_cast")


# ─────────────────────────── 책 만들기 ───────────────────────────

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_spread = Control.new()
	_spread.name = "Spread"
	_spread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spread.pivot_offset = BOOK_RECT.get_center()
	add_child(_spread)

	var pages := Control.new()
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.draw.connect(_draw_pages.bind(pages))
	_spread.add_child(pages)

	var paper := ColorRect.new()
	paper.color = PAPER_L
	paper.position = BOARD_RECT.position
	paper.size = BOARD_RECT.size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.add_child(paper)

	_board = RingBoard.new()
	_board.name = "RingBoard"
	_board.position = BOARD_RECT.position
	_board.size = BOARD_RECT.size
	_spread.add_child(_board)
	_board.connect(&"assembly_changed", _on_assembly_changed)
	_board.connect(&"stage_advanced", _on_stage_advanced)
	_board.connect(&"score_changed", _on_score_changed)
	_board.connect(&"piece_locked", _on_piece_locked)
	_board.connect(&"finished", _on_finished)

	_book = RingBook.new()
	_book.name = "RingBook"
	_book.position = BOOK_RECT_R.position
	_book.size = BOOK_RECT_R.size
	_spread.add_child(_book)
	_book.connect(&"jin_selected", _on_jin_selected)
	_book.connect(&"rune_selected", _on_rune_selected)
	_book.connect(&"glyph_selected", _on_glyph_selected)
	_book.connect(&"template_selected", _on_template_selected)

	_next_btn = Button.new()
	_next_btn.position = NEXT_BTN_RECT.position
	_next_btn.size = NEXT_BTN_RECT.size
	_next_btn.text = "다음 ▶"
	_next_btn.add_theme_font_size_override(&"font_size", 10)
	_next_btn.disabled = true
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.pressed.connect(_on_next)
	_spread.add_child(_next_btn)

	_commit_btn = Button.new()
	_commit_btn.position = COMMIT_BTN_RECT.position
	_commit_btn.size = COMMIT_BTN_RECT.size
	_commit_btn.text = "✓ 맺기 (분석)"
	_commit_btn.add_theme_font_size_override(&"font_size", 9)
	_commit_btn.disabled = true
	_commit_btn.focus_mode = Control.FOCUS_NONE
	_commit_btn.pressed.connect(_finish)
	_spread.add_child(_commit_btn)

	_score_lbl = _label(SCORE_RECT, 9, SCORE_COLOR)
	_score_lbl.text = ""

	_title = _label(TITLE_RECT, 10, TITLE_COLOR)
	_title.text = "고리 조립 마법진"
	_say = _label(SAY_RECT, 8, SAY_COLOR)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.text = Copy_START
	_hint = _label(HINT_RECT, 8, HINT_COLOR)
	_hint.text = "왼쪽 판의 숨은 선을 손으로 그린다(탁본) · 휠=크기(진·룬·문양 칸) · 문양은 칸을 클릭해 골라 Q·W 정하고 다시 그림 · [다음]/[맺기]=분석"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_report()


# ─────────────────────────── 분석 리포트 오버레이 ───────────────────────────

## 완성 시 뜨는 분석 리포트 — 조각별 점수 + 종합 + 등급. 오른쪽 페이지를 덮는 카드.
func _build_report() -> void:
	_report = Control.new()
	_report.name = "Report"
	_report.position = BOOK_RECT_R.position + Vector2(-6, -6)
	_report.size = BOOK_RECT_R.size + Vector2(12, 60)
	_report.mouse_filter = Control.MOUSE_FILTER_STOP
	_report.visible = false
	_report.draw.connect(_draw_report)
	_spread.add_child(_report)

	var shoot := Button.new()
	shoot.position = Vector2(12, _report.size.y - 30)
	shoot.size = Vector2(120, 24)
	shoot.text = "쏘기 ▶"
	shoot.add_theme_font_size_override(&"font_size", 11)
	shoot.focus_mode = Control.FOCUS_NONE
	shoot.pressed.connect(_on_report_shoot)
	_report.add_child(shoot)

	var redo := Button.new()
	redo.position = Vector2(_report.size.x - 132, _report.size.y - 30)
	redo.size = Vector2(120, 24)
	redo.text = "다시 그리기"
	redo.add_theme_font_size_override(&"font_size", 11)
	redo.focus_mode = Control.FOCUS_NONE
	redo.pressed.connect(_on_report_redo)
	_report.add_child(redo)


## 분석 리포트 렌더 — 종합 등급·점수 + 조각별(진·룬·문양) 완성도·정밀도·점수 막대.
func _draw_report() -> void:
	var w := _report.size.x
	var h := _report.size.y
	_report.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.94, 0.90, 0.82, 0.98), true)
	_report.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), EDGE, false, 2.0)
	var font := ThemeDB.fallback_font

	var total := float(_analysis.get("total", 0.0))
	var grade := String(_analysis.get("grade", "?"))
	_report.draw_string(font, Vector2(14, 26), "마법진 분석",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TITLE_COLOR)
	_report.draw_string(font, Vector2(14, 50), "종합 %d점 · %s" % [_pct(total), grade],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.30, 0.12))

	var y := 74.0
	var jin: Variant = _analysis.get("jin", null)
	if jin != null:
		y = _report_row(font, y, "진 (바깥 원)", jin)
	var rune: Variant = _analysis.get("rune", null)
	if rune != null:
		y = _report_row(font, y, "룬 (불)", rune)
	for g in (_analysis.get("glyphs", []) as Array):
		var gname := "문양"
		if int(g.get("glyph", -1)) >= 0:
			gname = RingBoard.GLYPH_NAMES[int(g.glyph)]
		y = _report_row(font, y, "%s (칸 %d)" % [gname, int(g.slot)], g)


## 한 조각 행 — 이름 + 점수 + 막대 + 완성도·정밀도. 다음 y를 돌려준다.
func _report_row(font: Font, y: float, name_text: String, e: Dictionary) -> float:
	var val := clampf(float(e.get("score", 0.0)), 0.0, 1.0)
	var cov := int(round(float(e.get("cover", 0.0)) * 100.0))
	var acc := int(round(float(e.get("acc", 0.0)) * 100.0))
	_report.draw_string(font, Vector2(14, y), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, REPORT_NAME)
	_report.draw_string(font, Vector2(_report.size.x - 46.0, y), "%d점" % _pct(val),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.28, 0.12))
	var bar := Rect2(14, y + 6, _report.size.x - 28, 6)
	_report.draw_rect(bar, Color(0.80, 0.74, 0.62, 0.7), true)
	_report.draw_rect(Rect2(bar.position, Vector2(bar.size.x * val, bar.size.y)),
		Color(0.72, 0.45, 0.15), true)
	_report.draw_string(font, Vector2(14, y + 26), "완성도 %d%% · 정밀도 %d%%" % [cov, acc],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, REPORT_DESC)
	return y + 40.0


func _draw_pages(on: Control) -> void:
	var shadow := BOOK_RECT.grow(3.0)
	on.draw_rect(shadow, SHADOW, true)
	on.draw_rect(BOOK_RECT, PAPER_L, true)

	var right := Rect2(BOOK_RECT.position + Vector2(PAGE_W, 0.0),
		Vector2(PAGE_W, BOOK_RECT.size.y))
	on.draw_rect(right, PAPER_R, true)

	var mid := BOOK_RECT.position.x + PAGE_W
	for i in 7:
		var t := float(i) / 6.0
		var col := SPINE
		col.a = SPINE.a * (1.0 - t) * 0.8
		var w := 1.0 + t * 2.0
		on.draw_line(Vector2(mid - t * 7.0, BOOK_RECT.position.y),
			Vector2(mid - t * 7.0, BOOK_RECT.end.y), col, w)
		on.draw_line(Vector2(mid + t * 7.0, BOOK_RECT.position.y),
			Vector2(mid + t * 7.0, BOOK_RECT.end.y), col, w)
	on.draw_line(Vector2(mid, BOOK_RECT.position.y), Vector2(mid, BOOK_RECT.end.y),
		Color(0.42, 0.35, 0.27, 0.8), 1.0)

	on.draw_rect(BOOK_RECT, EDGE, false, 1.0)


func _label(r: Rect2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread.add_child(l)
	return l
