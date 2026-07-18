extends Control
## 진행 목표(퀘스트) 열람 모달 — **베이스캠프와 숲이 같이 쓴다** (세션36, "진행 목표 = 깊이 스파인").
## [Q]로 토글. 창고 패널(I)의 형제다 — 같은 모달 규약·같은 _draw 방식.
##
## 🔴 왜 필요했나: 세션35까지 진행(룬 해금 사슬)이 **어디에도 안 보였다** — 플레이어가 "다음에
## 뭘 해야 새로 그릴 게 느나"를 알 길이 없었다. 여기가 그 창이다. 퀘스트 자체는 순수 오버레이라
## (GameState가 EventBus로 자동 진행) 이 패널은 **읽고 그리기만** 한다 — 정본은 GameState다.
##
## 🔴 **HUD처럼 _draw가 매번 GameState/Db를 직접 읽는다** — 캐시 없음. 갱신은
## quest_completed·quest_advanced·resources_changed에 queue_redraw() 하나로 끝난다.
##
## 🔴 **모달** — 열리면 GameState.ui_modal_open을 켠다(창고·책과 같은 슬롯 하나). 열린 동안
## mouse_filter=STOP이라 좌클릭을 통째로 먹어 목표를 보며 실수로 안 쏜다. 닫히면 visible=false라
## GUI 히트테스트에서 빠져 클릭이 다시 바닥으로 샌다(창고 패널과 같은 규약).
##
## 🔴 **CanvasLayer 위에 산다**(quest_panel.tscn, layer 5) — 카메라가 플레이어를 따라다녀
## 월드에 그리면 패널이 흘러간다. 책(forge, layer 10)보다 아래라 책이 펴진 동안엔 ui_modal_open이 연다.

# ── 레이아웃 (연출값 — 밸런스 아님) ──
const PANEL_SIZE := Vector2(700.0, 500.0)
const PAD := 22.0
const ROW_H := 66.0
const ROW_GAP := 10.0
const BAR_H := 8.0

# ── 색 ──
const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const PANEL_BG := Color(0.12, 0.10, 0.08, 0.98)
const PANEL_EDGE := Color(0.48, 0.43, 0.34, 0.9)
const TITLE_COLOR := Color(0.96, 0.90, 0.78)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const ROW_BG := Color(0.17, 0.15, 0.12, 0.95)
const ROW_EDGE := Color(0.40, 0.37, 0.31, 0.7)
const NAME_COLOR := Color(0.94, 0.90, 0.80)
const DESC_COLOR := Color(0.72, 0.68, 0.60)
const ACTIVE_ACCENT := Color(0.92, 0.78, 0.42)   # 진행 중 (금)
const DONE_ACCENT := Color(0.55, 0.80, 0.50)     # 완료 (녹)
const BAR_BG := Color(0.28, 0.25, 0.20, 1.0)
const REWARD_COLOR := Color(0.70, 0.66, 0.58)
const EMPTY_COLOR := Color(0.60, 0.56, 0.50)

var _open: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.quest_advanced.connect(_on_quest_changed)
	EventBus.resources_changed.connect(_on_quest_changed)


## 🔴 토글은 _unhandled_input에서 — Q·ESC 둘 다 발사(좌클릭)·슬롯(1~4)과 안 겹친다.
## 닫힌 Control도 _unhandled_input은 받는다(mouse_filter는 마우스만 가른다 — 창고 패널과 같은 이유).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if key.keycode == KEY_Q:
		_toggle()
		get_viewport().set_input_as_handled()
	elif _open and key.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _open:
		_set_open(false)
	elif not GameState.ui_modal_open:
		# 다른 모달(책·창고)이 열린 동안엔 안 연다 — 모달은 하나뿐.
		_set_open(true)


## 🔴 NPC(길잡이)가 E로 여는 공개 진입점 (세션37). Q 토글과 별개로 밖에서 연다 —
## 퀘스트를 "주는 존재"를 통해 라인을 따라가게(사용자 확정). 모달 규약은 _toggle과 동일.
func open() -> void:
	if not _open and not GameState.ui_modal_open:
		_set_open(true)


func _set_open(open: bool) -> void:
	_open = open
	visible = open
	GameState.ui_modal_open = open
	queue_redraw()


func _on_quest_changed(_a = null) -> void:
	if _open:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)

	var origin := ((size - PANEL_SIZE) * 0.5).round()
	draw_rect(Rect2(origin, PANEL_SIZE), PANEL_BG, true)
	draw_rect(Rect2(origin, PANEL_SIZE), PANEL_EDGE, false, 2.0)

	draw_string(font, origin + Vector2(PAD, 30.0), "진행 목표",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TITLE_COLOR)
	draw_string(font, origin + Vector2(PANEL_SIZE.x - PAD - 150.0, 30.0), "[Q] / ESC  닫기",
		HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 12, HINT_COLOR)

	# 열린 퀘스트(진행 중) 먼저, 완료한 퀘스트를 아래에 — 잠긴 것은 숨긴다(스파인을 미리 안 흘린다).
	var rows := _visible_quests()
	var y := origin.y + 52.0
	var left := origin.x + PAD
	var width := PANEL_SIZE.x - PAD * 2.0

	if rows.is_empty():
		draw_string(font, Vector2(left, y + 14.0),
			"목표가 없다 — 숲으로 나가 사냥을 시작하라",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, EMPTY_COLOR)
		return

	for q: QuestDef in rows:
		_draw_row(font, Vector2(left, y), width, q)
		y += ROW_H + ROW_GAP


## 그릴 퀘스트 = 열린 것(진행 중) + 완료한 것. 잠긴 것(선행 미완료)은 뺀다. 열린 것 먼저.
func _visible_quests() -> Array[QuestDef]:
	var active: Array[QuestDef] = []
	var done: Array[QuestDef] = []
	for q: QuestDef in Db.all_quests():
		if GameState.is_quest_done(q.id):
			done.append(q)
		elif GameState.is_quest_active(q):
			active.append(q)
	active.append_array(done)
	return active


func _draw_row(font: Font, at: Vector2, width: float, q: QuestDef) -> void:
	var done := GameState.is_quest_done(q.id)
	var accent := DONE_ACCENT if done else ACTIVE_ACCENT
	var rect := Rect2(at, Vector2(width, ROW_H))
	draw_rect(rect, ROW_BG, true)
	draw_rect(rect, ROW_EDGE, false, 1.0)
	draw_rect(Rect2(at, Vector2(4.0, ROW_H)), accent, true)   # 상태 색 띠

	var tx := at.x + 14.0
	# 제목 + 상태 표식
	var mark := "✓ " if done else ""
	draw_string(font, Vector2(tx, at.y + 20.0), mark + q.title,
		HORIZONTAL_ALIGNMENT_LEFT, width - 200.0, 15, NAME_COLOR if not done else DONE_ACCENT)
	# 설명
	draw_string(font, Vector2(tx, at.y + 38.0), q.desc,
		HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 11, DESC_COLOR)

	var need := q.need()
	var cur := mini(GameState.quest_count(q.id), need) if not done else need
	# 진행 텍스트 (오른쪽 위)
	var prog_text := "완료" if done else "%d / %d" % [cur, need]
	draw_string(font, Vector2(at.x + width - 180.0, at.y + 20.0), prog_text,
		HORIZONTAL_ALIGNMENT_RIGHT, 168.0, 13, accent)
	# 보상 (오른쪽, 설명 줄)
	var reward := _reward_text(q)
	if reward != "":
		draw_string(font, Vector2(at.x + width - 180.0, at.y + 38.0), "보상: " + reward,
			HORIZONTAL_ALIGNMENT_RIGHT, 168.0, 10, REWARD_COLOR)

	# 진행 막대 (맨 아래)
	var bar_top := at.y + ROW_H - BAR_H - 6.0
	var bar_rect := Rect2(Vector2(tx, bar_top), Vector2(width - 28.0, BAR_H))
	draw_rect(bar_rect, BAR_BG, true)
	var frac := 1.0 if done else (float(cur) / float(need) if need > 0 else 0.0)
	if frac > 0.0:
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * frac, BAR_H)), accent, true)


## 보상 아이템들을 "이름 ×n" 로 (여러 개면 콤마). 없으면 빈 문자열.
func _reward_text(q: QuestDef) -> String:
	var parts: Array[String] = []
	for item_id: StringName in q.reward_items:
		var it := Db.get_item(item_id)
		var nm := it.display_name if it != null and it.display_name != "" else String(item_id)
		parts.append("%s ×%d" % [nm, int(q.reward_items[item_id])])
	return ", ".join(parts)
