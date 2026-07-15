extends VBoxContainer
## 도안 작성 체크리스트 — 원 → 글자 → 화살표 (TECH_SPEC §6.2).
## 순서가 강제되므로 지금 무엇을 그릴 차례인지 항상 보여야 하고,
## **한 단계를 해낼 때마다 그게 눈에 보여야** "해냈다"는 감각이 생긴다 (✓ 팝 → 다음 항목 승격).
## 어휘·문구는 전부 drawing_copy.gd — 튜토리얼의 스승 목소리와 같은 말을 쓴다.
## 캔버스 신호만 받아 갱신한다 — 캔버스를 폴링하지 않는다.
## 사용: const DesignChecklist := preload("res://src/drawing/design_checklist.gd")
##       var cl := DesignChecklist.new(); parent.add_child(cl); cl.bind(canvas)

const DesignBuilder := preload("res://src/drawing/design_builder.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")

# 드로잉룸 톤(한지·먹). ui 모듈의 InkStyle은 타 모듈이라 preload하지 않는다
const DONE_COLOR := Color(0.55, 0.72, 0.55)      # ✓ 해낸 일
const CURRENT_COLOR := Color(0.95, 0.85, 0.60)   # ▶ 지금 차례 — 등불빛
const PENDING_COLOR := Color(0.62, 0.58, 0.52)   # ○ 아직 — 흐린 먹
const COMPLETE_COLOR := Color(0.95, 0.78, 0.42)  # 완성 문구

const MARK_DONE := "✓"
const MARK_CURRENT := "▶"
const MARK_PENDING := "○"

# ── 연출 상수 (밸런스 아님) ──
const POP_SCALE := 1.14        # ✓ 팝 — 조용히 바뀌지 않고 눈에 띄게
const POP_UP_SEC := 0.09
const POP_DOWN_SEC := 0.14
const GLOW_SEC := 0.28         # 다음 항목이 밝아지며 승격되는 시간
const GLOW_FROM_ALPHA := 0.25
const COMPLETE_POP_SCALE := 1.22   # 완성은 더 크게 — 이 화면의 클라이맥스
const COMPLETE_FADE_SEC := 0.35

const FONT_SIZE := 10

var _stage: int = Enums.DrawStage.CIRCLE
var _summary: Dictionary = {}
## **완성의 진실은 도안이 실재하는가**다 — 부품이 다 있어도 종이가 없으면 도안은 맺히지 않는다.
## 부품 요약으로 판정하면 그 순간 "「도안이 맺혔다」"고 거짓말한다 (실제 버그였다)
var _design: SpellDesign = null

var _rows: Dictionary = {}          # DrawStage → Label
var _complete_row: Label
var _prev_done: Dictionary = {}     # DrawStage → bool (전환 감지 — 해낸 순간에만 팝)
var _prev_stage: int = -1
var _prev_complete := false


func _init() -> void:
	add_theme_constant_override(&"separation", 1)


func _ready() -> void:
	for stage: int in [Enums.DrawStage.CIRCLE, Enums.DrawStage.RUNE, Enums.DrawStage.ARROW]:
		_rows[stage] = _make_row()
		_prev_done[stage] = false
	_complete_row = _make_row()
	_complete_row.add_theme_color_override(&"font_color", COMPLETE_COLOR)
	_complete_row.modulate.a = 0.0
	_rebuild(false)


func _make_row() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", FONT_SIZE)
	add_child(l)
	return l


## 캔버스에 연결 — 단계·부품 상태를 신호로만 받는다
func bind(canvas: Control) -> void:
	canvas.stage_changed.connect(_on_stage_changed)
	canvas.design_state_changed.connect(_on_design_state_changed)
	_stage = canvas.get_stage()
	_summary = canvas.get_summary()
	_design = canvas.get_design()
	_rebuild(false)   # 최초 표시는 연출 없이 — 붙자마자 팝하면 이상하다


func _on_stage_changed(stage: int) -> void:
	_stage = stage
	_rebuild(true)


func _on_design_state_changed(design: SpellDesign, summary: Dictionary) -> void:
	_design = design
	_summary = summary
	_rebuild(true)


func _rebuild(animate: bool) -> void:
	if _rows.is_empty():
		return   # _ready 전 — bind가 먼저 와도 안전
	var has_circle: bool = _summary.get("has_circle", false)
	var has_rune: bool = _summary.get("has_rune", false)
	var arrows: int = int(_summary.get("arrow_count", 0))
	var done := {
		Enums.DrawStage.CIRCLE: has_circle,
		Enums.DrawStage.RUNE: has_rune,
		Enums.DrawStage.ARROW: arrows > 0,
	}
	var notes := {
		Enums.DrawStage.CIRCLE: "",
		Enums.DrawStage.RUNE: _rune_note(has_rune),
		Enums.DrawStage.ARROW: "%d획" % arrows if arrows > 0 else "",
	}

	for stage: int in _rows:
		var row: Label = _rows[stage]
		_set_row(row, stage, bool(done[stage]), String(notes[stage]))
		if not animate:
			continue
		# 해낸 순간에만 ✓ 팝 — 매 갱신마다 튀면 소음이 된다
		if bool(done[stage]) and not bool(_prev_done.get(stage, false)):
			_pop(row, POP_SCALE)
		# 방금 내 차례가 됐다면 밝아지며 승격 — "이제 네 차례"가 보이게
		elif stage == _stage and _prev_stage != _stage:
			_glow(row)

	# 🔴 **맺힘은 명시적이다** (F1, 2026-07-15) — 세 단계를 다 갖춰도 화살표 하나로 자동 완성되지
	# 않는다. 두 상태를 가른다: **확정 대기**(초안이 준비됨 → 확정 키를 눌러라) / **맺혔다**(종이 소모).
	# committed = 도안이 실제로 실재하는가 — 종이가 없으면 부품이 다 있어도 맺히지 않는다.
	var committed: bool = bool(_summary.get("committed", _design != null))
	var can_commit: bool = bool(_summary.get("can_commit", false))
	if committed:
		_complete_row.text = Copy.COMPLETE
		_complete_row.add_theme_color_override(&"font_color", COMPLETE_COLOR)
	elif can_commit:
		_complete_row.text = Copy.COMMIT_PROMPT      # "▶ 완성 — Enter로 맺는다"
		_complete_row.add_theme_color_override(&"font_color", CURRENT_COLOR)
	else:
		_complete_row.text = ""
	# 맺힌 순간에만 클라이맥스 팝 — 확정 대기 프롬프트는 조용히 나타난다(매번 튀면 소음)
	if committed and not _prev_complete:
		_complete_row.modulate.a = 0.0
		var tw := _complete_row.create_tween()
		tw.tween_property(_complete_row, ^"modulate:a", 1.0, COMPLETE_FADE_SEC)
		_pop(_complete_row, COMPLETE_POP_SCALE)
	elif _complete_row.text == "":
		_complete_row.modulate.a = 0.0
	else:
		_complete_row.modulate.a = 1.0

	for stage: int in _rows:
		_prev_done[stage] = bool(done[stage])
	_prev_stage = _stage
	_prev_complete = committed


func _rune_note(has_rune: bool) -> String:
	if not has_rune:
		return ""
	return "%s %d%%" % [
		DesignBuilder.rune_name(int(_summary.get("rune_type", -1))),
		roundi(float(_summary.get("rune_accuracy_raw", 0.0)) * 100.0),
	]


## 한 줄 = [표식] 문구  주석 [← 지금 / 더 그어도 된다]
func _set_row(row: Label, stage: int, done: bool, note: String) -> void:
	var current := _stage == stage
	var mark := MARK_PENDING
	var col := PENDING_COLOR
	if done:
		mark = MARK_DONE
		col = DONE_COLOR
	if current:
		mark = MARK_DONE if done else MARK_CURRENT
		col = CURRENT_COLOR
	var text := "%s %s" % [mark, Copy.DONE.get(stage, "") if done else Copy.TODO.get(stage, "")]
	if note != "":
		text += "  %s" % note
	if current and not done:
		text += "   %s" % Copy.NOW_MARK
	elif current and done:
		# 화살표는 1획으로 완성되지만 계속 더 그을 수 있다
		text += "   %s" % Copy.MORE_MARK
	row.text = text
	row.add_theme_color_override(&"font_color", col)


## 스케일 펀치 — Tween이 row에 묶이므로 row가 사라지면 함께 죽는다
func _pop(row: Control, to: float) -> void:
	row.pivot_offset = row.size * 0.5
	row.scale = Vector2.ONE
	var tw := row.create_tween()
	tw.tween_property(row, ^"scale", Vector2(to, to), POP_UP_SEC)
	tw.tween_property(row, ^"scale", Vector2.ONE, POP_DOWN_SEC)


## 승격 — 흐렸다가 밝아진다
func _glow(row: Control) -> void:
	row.modulate.a = GLOW_FROM_ALPHA
	var tw := row.create_tween()
	tw.tween_property(row, ^"modulate:a", 1.0, GLOW_SEC)
