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
## 🔴 세션 21 대청소: 옛 forge_panel(자유 드로잉)은 **삭제됐다** — 이제 이게 유일한 제작대다.
## (한때 둘이 평행으로 살아 있었다. 되돌리려면 git 이력.)
##
## 계약: open() → 열림 / closed 시그널 → 닫힘 / design_committed(assembly) → 맺힘.
##
## 🔴 2026-07-17 세션 22 (I5): 껍데기가 **씬(ring_forge_panel.tscn)으로 나갔다** — 예전엔 _build()가
## 종이·라벨·버튼·리포트 카드를 전부 `.new()`하고 좌표 상수 14개를 코드에 박아 뒀다. 종이의 "느낌"이
## 그리는 재미를 좌우해서 계속 만질 곳인데, 한 픽셀 옮기려면 코드를 고쳐야 했다.
## ⚠ 전부 씬으로 옮기지는 **않았다** — RingBoard·RingBook은 `_draw()` 커스텀 렌더라 에디터에서
## 드래그할 게 없다. 그 둘은 씬의 노드로 배치하되 스크립트가 계속 그린다. `_draw_pages`(책등 그라데이션)·
## `_draw_report`(점수 막대)도 코드에 남는다.
##
## 🔴 인스턴스화는 **씬으로** 한다 — `RingForgePanel.new()`는 껍데기가 없는 빈 Control이다:
##   const ForgeScene := preload("res://src/drawing/ring_forge_panel.tscn")
##   var panel := ForgeScene.instantiate() as RingForgePanelScript

const RingBoard := preload("res://src/drawing/ring_board.gd")
const RingBook := preload("res://src/drawing/ring_book.gd")
## 점수 → 안정성·위력 규칙. 🔴 **발사와 같은 함수를 쓴다** — 리포트가 보여 준 위력과 실제로
## 때리는 위력이 갈라지면 안 된다 (src/core/ring_power.gd의 주석 참조).
const RingPower := preload("res://src/core/ring_power.gd")

signal closed
## 도안이 방금 맺혔다 — 여는 쪽(작업대·거점)이 발사·연출에 쓴다. assembly = board.get_assembly()
signal design_committed(assembly: Dictionary)

# ── 레이아웃 (**논리 크기** 640×360 — 씬의 좌표도 전부 이 좌표계다) ──
## 🔴 세션 21: 뷰포트는 960×540(세션 18에 올림)이고 `stretch/aspect=expand`라 전체화면에선
## 그보다 더 넓어지기도 한다. 이 책은 640×360 좌표로 짜여 있어 그대로 두면 **왼쪽 위에 몰려 깨진다.**
## 고치는 방법은 좌표를 다시 재는 게 아니라 **무대(Stage)를 화면에 맞춰 비율 유지로 확대**하는 것이다.
## RingBoard·RingBook은 자기 size 비례로 그리므로(ring_board.gd `_outer_radius()`) 무대만 키우면
## 속도 같이 커진다.
## ⚠ `Spread.scale`은 **책 펼침 애니가 이미 쓴다**(open/close tween) — 배율을 거기 얹으면 애니가 덮어쓴다.
## 그래서 Spread를 감싸는 별도 무대(Stage)에 배율을 건다.
const DESIGN_SIZE := Vector2(640.0, 360.0)
## 책 껍데기 기하 — `_draw_pages`(코드 렌더)가 쓴다. 나머지 좌표는 전부 씬으로 나갔다.
const BOOK_RECT := Rect2(16, 10, 608, 340)
const PAGE_W := 304.0

# ── 한지·먹 톤 — 코드 렌더(_draw_pages·_draw_report)와 _set_say가 쓰는 것만 남았다 ──
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
## 펑 섬광이 가시는 시간 — 연출값(밸런스 아님). 짧아야 "터졌다"로 읽히고 길면 화면 전환처럼 보인다
const BURST_SEC := 0.45

## 🔴 세션 25: **고르는 게 먼저다** — 오른쪽 셀을 눌러야 왼쪽에 밑그림이 뜬다 (진·룬·문양 전부).
const Copy_START := "오른쪽에서 진을 골라 왼쪽 판에 손으로 그리세요  (진 → 룬 → 문양 순서로 하나씩 · [다음]으로 진행)"

## 🔴 `class_name` 없이도 정적 타입을 받는다 — `const X := preload(...)`를 타입으로 쓸 수 있다.
## 예전엔 `Control`로 받아 `.call(&"...")`로 더듬었고, 오타가 파싱이 아니라 **런타임에** 터졌다.
@onready var _stage: Control = $Stage         # 640×360 논리 무대 — 화면에 맞춰 통째로 확대(_fit_stage)
@onready var _spread: Control = $Stage/Spread
@onready var _pages: Control = $Stage/Spread/Pages
@onready var _board: RingBoard = $Stage/Spread/RingBoard
@onready var _book: RingBook = $Stage/Spread/RingBook
@onready var _next_btn: Button = $Stage/Spread/NextBtn
@onready var _commit_btn: Button = $Stage/Spread/CommitBtn
@onready var _score_lbl: Label = $Stage/Spread/ScoreLabel
@onready var _title: Label = $Stage/Spread/TitleLabel
@onready var _say: Label = $Stage/Spread/SayLabel
@onready var _hint: Label = $Stage/Spread/HintLabel
@onready var _report: Control = $Stage/Spread/Report   # 분석 리포트 오버레이 (완성 시 표시)

var _committed := false
var _template_idx := 0                        # 지금 삽입된 문양본 (기본 = TEMPLATES[0] = 2방)
var _active_glyph := RingBoard.G_RADIATE      # 지금 고른 문양 (하이라이트)
var _analysis: Dictionary = {}                # 마지막 분석 리포트 (get_analysis 결과)
var _picking_template := false                # 🔴 문양 단계의 하위 단계 — 문양본 고르는 중(아직 안 그림)


## 껍데기는 씬이 만든다 — 여기서는 **코드 렌더와 배선만** 붙인다.
func _ready() -> void:
	_pages.draw.connect(_draw_pages)
	_report.draw.connect(_draw_report)
	_spread.pivot_offset = BOOK_RECT.get_center()   # 책 펼침 애니의 회전축 = 책 한가운데

	_board.assembly_changed.connect(_on_assembly_changed)
	_board.stage_advanced.connect(_on_stage_advanced)
	_board.score_changed.connect(_on_score_changed)
	_board.piece_locked.connect(_on_piece_locked)
	_board.finished.connect(_on_finished)

	_book.jin_selected.connect(_on_jin_selected)
	_book.rune_selected.connect(_on_rune_selected)
	_book.glyph_selected.connect(_on_glyph_selected)
	_book.template_selected.connect(_on_template_selected)

	_next_btn.pressed.connect(_on_next)
	_commit_btn.pressed.connect(_finish)
	# 🔴 [쏘기] → **[마력 주입]** (세션 23). 조용히 성공하던 자리에 성공/실패가 갈리는 의식이 들어갔다.
	var inject_btn := $Stage/Spread/Report/ShootBtn as Button
	inject_btn.text = "마력 주입"
	inject_btn.pressed.connect(_on_inject)
	($Stage/Spread/Report/RedoBtn as Button).pressed.connect(_on_report_redo)

	resized.connect(_fit_stage)   # 창 크기·전체화면 전환마다 다시 맞춘다
	_fit_stage()


## 논리 무대(640×360)를 화면에 **비율 유지로** 꽉 채우고 중앙에 놓는다.
## 뷰포트는 960×540이지만 `stretch/aspect=expand`라 전체화면에선 화면비에 따라 더 넓어질 수 있다 —
## 그래서 배율을 상수로 박지 않고 매번 실측해서 잰다(1.5 하드코딩은 21:9 같은 화면에서 다시 깨진다).
func _fit_stage() -> void:
	if _stage == null:
		return
	var s := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if s <= 0.0:
		return
	_stage.scale = Vector2(s, s)
	_stage.position = (size - DESIGN_SIZE * s) * 0.5   # 남는 여백은 위아래(또는 좌우)로 반씩


# ─────────────────────────── 열고 닫기 ───────────────────────────

func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_fit_stage()          # 숨어 있는 동안 창이 바뀌었을 수 있다(resized는 안 왔을 수 있음)
	_committed = false
	_template_idx = 0
	_active_glyph = RingBoard.G_RADIATE
	_analysis = {}
	_picking_template = false
	_report.visible = false
	_inject_defs()                              # 🔴 Db에서 진·룬·문양 정의를 읽어 주입 (세션 13 구조화)
	_board.clear_all()                          # 🔴 빈 판에서 시작 — 진 → 룬 → 문양 순차
	_board.set_active_glyph(_active_glyph)
	_sync_book()
	_set_say(Copy_START, false)
	_update_score()
	_refresh_buttons()
	_spread_open()


func close() -> void:
	if not visible:
		return
	# 🔴 맺기 버튼을 깜빡해도 쏠 수 있게 — 닫을 때 유효한 조립(진·룬 그려짐)이면 자동으로 맺는다.
	# ⚠ **단, 견디는 마법진만** (세션 23). 안 그러면 못 그린 진도 책만 덮으면 [마력 주입]을
	# 건너뛰고 맺히는 셈이라 펑이 **누르지 않으면 그만인 벌**이 된다 — 규칙에 구멍이 뚫린다.
	if not _committed and _board.can_commit():
		var a := _board.get_assembly()
		if RingPower.is_stable(float(a.get("score", 0.0))):
			_committed = true
			design_committed.emit(a)
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
	# 🔴 확정은 손으로 문질러 그리고 **[다음]**(또는 Enter)으로 잠근다.
	# ⚠ **문양 고르기 키(Q·W)는 없다** (세션 25, 사용자: "q w 이런게 아니라 똑같이 마우스로
	# 선택하는걸로해줘"). 진·룬·문양본이 전부 오른쪽 셀을 클릭해서 고르는데 문양만 키였다 —
	# 셀 클릭은 그때도 됐지만 UI가 "[Q]"라 적어 놔 키보드를 시키는 것처럼 보였다.
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_on_next()
			get_viewport().set_input_as_handled()


# ─────────────────────────── Db 데이터 주입 (세션 13 구조화) ───────────────────────────

## Db에서 진·룬(불)·문양 정의를 읽어 보드·책에 넣는다. int const 대신 데이터가 UI를 채운다.
func _inject_defs() -> void:
	var jins: Array = Db.all_jins()
	var fire: RuneDef = Db.get_rune(Enums.RuneType.FIRE)
	var glyphs: Array = Db.all_glyphs()
	var jin0: JinDef = jins[0] if not jins.is_empty() else null
	_board.set_defs(jin0, fire, glyphs)
	_book.set_defs(jins, fire, glyphs)


# ─────────────────────────── 선택기 → 보드 (순차 조립) ───────────────────────────

## 오른쪽 탭·placed 표식을 보드의 현재 단계에 맞춘다.
func _sync_book() -> void:
	var tab := _stage_to_tab(_board.stage())
	_book.go_stage(tab, _board.has_jin(), _board.has_rune())
	_book.sync_state(_template_idx, _active_glyph)


func _stage_to_tab(stage: int) -> int:
	match stage:
		RingBoard.STAGE_JIN:
			return RingBook.TAB_JIN
		RingBoard.STAGE_RUNE:
			return RingBook.TAB_RUNE
		_:
			return RingBook.TAB_TEMPLATE


## 🔴 진 탭 셀을 눌렀다 → **왼쪽에 밑그림이 선다** (세션 25). 예전엔 안내만 띄웠고 밑그림은
## 단계에 들어가는 순간 이미 서 있었다 (사용자: "이게 눌러야 뜨게 해줘").
func _on_jin_selected() -> void:
	if _board.stage() != RingBoard.STAGE_JIN:
		return
	_board.choose_jin()
	_set_say("진을 왼쪽 판에 손으로 문질러 그리세요 (바깥 원) → [다음]", false)
	_refresh_buttons()


## 룬 탭 셀 — 마찬가지. ⚠ 룬이 불·물·바람으로 늘면 **셀마다 idx를 실어** choose_rune(idx)로
## 넘긴다 (지금은 Db에 불 하나뿐이라 책이 idx를 안 준다).
func _on_rune_selected() -> void:
	if _board.stage() != RingBoard.STAGE_RUNE:
		return
	_board.choose_rune()
	_set_say("룬(불)을 중심에 손으로 문질러 그리세요 (삼각) → [다음]", false)
	_refresh_buttons()


## 🔴 문양 **고르기** (오른쪽 문양 셀 클릭). 얹기는 왼쪽 판에 손으로 문지른다 — 칸마다.
func _select_glyph(glyph: int) -> void:
	_active_glyph = glyph
	_board.set_active_glyph(glyph)
	_book.sync_state(_template_idx, glyph)
	if _board.stage() != RingBoard.STAGE_GLYPH:
		_set_say("먼저 진과 룬을 그리세요  (진 → 룬 → 문양)", true)
	elif _board.is_tracing():
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
		if _board.is_tracing():
			_set_say("%s 새겼다 (%d점) — 다른 칸을 클릭해 이어 그리거나 [맺기]"
				% [RingBoard.GLYPH_NAMES[_active_glyph], _pct(score)], false)
		else:
			_set_say("문양 칸을 다 새겼다 (%d점) — [맺기]로 분석" % _pct(score), false)


## 🔴 [다음] (또는 Enter) — 문양본 고르는 단계면 **문양 그리기로 넘어가고**, 아니면 지금 조각을 잠근다.
func _on_next() -> void:
	# 문양본 확정 → 문양 그리기 단계로 (여기서 비로소 문양 탭으로 넘어간다)
	if _picking_template:
		_picking_template = false
		_book.go_stage(RingBook.TAB_GLYPH, true, true)
		_book.sync_state(_template_idx, _active_glyph)
		_set_say("칸을 클릭해 고르고 오른쪽에서 문양을 골라 손으로 그리세요 · 휠=문양 크기 · 다른 칸/[다음]으로 이어가기", false)
		_update_score()
		_refresh_buttons()
		return
	if not _board.is_tracing():
		return
	if _board.coverage() <= 0.02:
		_set_say("먼저 왼쪽 선을 손으로 그리세요", true)
		return
	_board.advance()
	# "advanced" → stage_advanced가 안내 · "finished" → finished 시그널이 리포트를 띄운다
	_update_score()
	_refresh_buttons()


## 보드가 조각을 잠그고 단계를 넘겼다 (진→룬→문양). 탭·안내문을 맞춘다.
func _on_stage_advanced(stage: int) -> void:
	_book.go_stage(_stage_to_tab(stage), _board.has_jin(), _board.has_rune())
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
	_board.set_template(slots)
	_book.sync_state(_template_idx, _active_glyph)
	_set_say("%s 문양본 — 바꿔도 돼요. 정했으면 [다음]으로 문양 그리기"
		% RingBoard.TEMPLATES[idx].name, false)
	_update_score()
	_refresh_buttons()


# ─────────────────────────── 맺기 · 분석 리포트 ───────────────────────────

func _on_assembly_changed() -> void:
	_refresh_buttons()


## 🔴 [맺기] — 마법진을 끝내고 분석한다 (남은 문양 칸은 비운 채). 진·룬을 그렸어야 한다.
func _finish() -> void:
	if not _board.can_commit():
		_set_say("진과 룬을 먼저 그려야 맺힌다  (문양은 없어도 빈 진으로 날아간다)", true)
		return
	_board.finish()   # → finished 시그널이 리포트를 띄운다


## 보드가 마법진을 다 그렸다 — 분석 리포트를 띄운다 (점수·위력. **판정은 없다**).
## 🔴 견딜지 터질지는 여기서 말하지 않는다 — 알려면 [마력 주입]을 눌러야 한다 (사용자 확정).
func _on_finished(analysis: Dictionary) -> void:
	_analysis = analysis
	_set_say("마법진 완성 — 분석을 보고 [마력 주입]으로 맺으세요", false)
	_report.visible = true
	_report.queue_redraw()
	_refresh_buttons()


## 🔴 리포트에서 [마력 주입] — 마법진이 맺히거나 **펑** 한다 (사용자 확정 2026-07-17 세션 23).
## 기준선(65점) 이하면 도안이 통째로 날아가고 처음부터 다시 그린다. 잃는 건 시간·정성뿐이다.
func _on_inject() -> void:
	var total := float(_analysis.get("total", 0.0))
	if not RingPower.is_stable(total):
		_burst(total)
		return
	_committed = true
	_report.visible = false
	design_committed.emit(_board.get_assembly())
	_set_say("마력이 돌았다 — 위력 %d의 마법진이 맺혔다. 책을 덮고(ESC) 쏴 보세요"
		% RingPower.power_display(total), false)
	_refresh_buttons()


## 펑 — 도안이 날아간다. 붉은 섬광 뒤 판을 비운다 (연출 중엔 입력을 막아 두 번 못 누른다).
func _burst(total: float) -> void:
	_report.visible = false
	_spread.modulate = Color(1.9, 0.5, 0.4)
	var tw := create_tween()
	tw.tween_property(_spread, ^"modulate", Color.WHITE, BURST_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		clear_board()
		_set_say("펑! — 종합 %d점, %d점을 넘겨야 견딘다. 처음부터 다시."
			% [_pct(total), _pct(RingPower.threshold())], true))


## 리포트에서 [다시] — 처음부터 다시 그린다 (터지기 전에 무르는 길).
func _on_report_redo() -> void:
	_report.visible = false
	clear_board()


# ─────────────────────────── 버튼·점수 라벨 ───────────────────────────

## 지금 조각 점수(완성도·정밀도·종합)를 라벨에 쓴다. 문양본 고르는 중엔 점수 없음.
func _update_score() -> void:
	if _picking_template or not _board.is_tracing():
		_score_lbl.text = ""
		return
	var cov := int(round(_board.coverage() * 100.0))
	var acc := int(round(_board.accuracy() * 100.0))
	var sc := _pct(_board.piece_score())
	_score_lbl.text = "이 조각 — 완성도 %d%% · 정밀도 %d%% · 점수 %d" % [cov, acc, sc]


## 버튼 상태. [다음] = 문양본 고르는 중이면(문양 그리러) 항상 활성 / 그 외엔 지금 조각을 그렸어야 활성.
## [맺기] = 문양을 그리는 중(진·룬 완료 & 문양본 확정)에만 — 룬 직후엔 안 뜬다("문양까지 가야 완료").
func _refresh_buttons() -> void:
	var tracing := _board.is_tracing()
	var drawn := _board.coverage() > 0.02
	if _picking_template:
		_next_btn.disabled = false
		_next_btn.text = "문양 그리기 ▶"
	else:
		_next_btn.disabled = not (tracing and drawn)
		_next_btn.text = "다음 ▶"
	_commit_btn.text = "✓ 맺힘" if _committed else "✓ 맺기 (분석)"
	_commit_btn.disabled = _picking_template or not _board.can_commit()


## 🔴 반올림은 core가 판다 — 「퍼펙트」가 "이 함수가 100을 돌려주는 순간"으로 정의돼 있어서,
## 여기서 따로 반올림하면 등급과 표시가 갈라진다 (ring_power.score_display 주석).
func _pct(score: float) -> int:
	return RingPower.score_display(score)


func _set_say(text: String, warn: bool) -> void:
	if text == "":
		return
	_say.text = text
	_say.add_theme_color_override(&"font_color", WARN_COLOR if warn else SAY_COLOR)


# ─────────────────────────── 외부 조회 ───────────────────────────

func get_assembly() -> Dictionary:
	if not _committed:
		return {}
	return _board.get_assembly()


func can_commit() -> bool:
	return _board.can_commit()


func clear_board() -> void:
	_board.clear_all()
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
	_board.play_cast()


# ─────────────────────────── 분석 리포트 렌더 (코드 렌더 — 씬에 없다) ───────────────────────────

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

	# 🔴 「퍼펙트」는 눈에 띄게 다르다 (사용자: *"백은 뭔가 달랐으면 좋겠네"*). 금색 · 크게 · ★.
	# 등급 **이름을 == 비교하지 않는다** — 이름은 바뀔 수 있고, 그때 조용히 평범해진다.
	var perfect := RingPower.is_perfect(total)
	if perfect:
		_report.draw_rect(Rect2(8, 36, w - 16, 22), Color(1.0, 0.86, 0.45, 0.35), true)
	_report.draw_string(font, Vector2(14, 52),
		("종합 %d점 · ★ %s ★" if perfect else "종합 %d점 · %s") % [_pct(total), grade],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if perfect else 13,
		Color(0.72, 0.48, 0.05) if perfect else Color(0.55, 0.30, 0.12))

	# 🔴 위력 = 이 진이 **버텨 준다면** 낼 힘. 발사와 같은 함수(RingPower)로 뽑는다.
	# ⚠ **견디는지는 여기서 말하지 않는다** (사용자 확정: "주입을 하면 그때 평가해서 터지게 할 거임 /
	# 지금은 안내하는 거 같은데 그러면 안 됨"). 미리 판정을 흘리면 [마력 주입]이 결과를 확인하는
	# 형식 절차가 된다 — 눌러 봐야 아는 게 이 버튼의 전부다.
	_report.draw_string(font, Vector2(14, 68), "위력 %d  (기준 100)"
		% RingPower.power_display(total), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.35, 0.30, 0.20))

	var y := 92.0
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


## 책 껍데기 렌더 — 종이 두 장 + **책등 그라데이션**(7줄). 씬의 ColorRect로는 못 하는 그림이라
## 코드에 남는다 (씬으로 옮긴 건 드래그로 만질 수 있는 것들뿐).
func _draw_pages() -> void:
	var on := _pages
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
