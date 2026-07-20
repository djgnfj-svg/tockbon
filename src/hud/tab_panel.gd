extends Control
## 통합 개인 시트 모달 — 창고+가방(소지품)·퀘스트·마법진을 한 패널 3탭으로 묶는다.
## **베이스캠프와 숲이 같이 쓴다.** 기존 inventory_panel(I)·quest_panel(Q)을 흡수한 형제다.
##
## 🔴 왜 한 패널인가: 소지품/퀘스트/마법진이 따로 열리면 모달 슬롯(ui_modal_open)을 서로
## 밀치고, 근육 기억(I·Q)도 흩어진다. Tab 하나로 열고 탭으로 오가되, I/Q는 그 탭으로 바로
## 여는 지름길로 남긴다.
##
## 🔴 **inventory_panel / quest_panel과 완전히 같은 모달 규약이다** (그 둘이 참고 원본):
##  · 열리면 mouse_filter=STOP → 좌클릭을 통째로 먹어 시트를 보며 실수로 안 쏜다.
##  · 닫히면 visible=false → GUI 히트테스트에서 빠져 클릭이 다시 바닥으로 샌다.
##  · 열림/닫힘에 GameState.ui_modal_open을 토글 → player(이동)·caster(조준·발사)가 폴링해 멎는다.
##  · 닫힌 Control도 _unhandled_input은 받는다(mouse_filter는 마우스만 가른다) → Tab/I/Q로 연다.
##  · _draw가 매번 GameState/Db를 직접 읽는다(캐시 없음) → 갱신은 시그널에 queue_redraw() 하나로 끝.
##
## 🔴 **탭 헤더는 손으로 그린다**(TabContainer 아님) — 패널 전체가 즉시모드 손그림이라 룩을 맞춘다.
## 탭 전환은 _gui_input에서 헤더 rect 히트테스트로 처리한다(열린 동안 STOP이라 클릭이 이리로 온다).
## 🔴 헤더 rect는 _tab_header_rects() 한 함수가 쥔다 — _draw와 _gui_input이 같은 것을 봐서 어긋나지 않는다.
##
## 🔴 **CanvasLayer(layer 5) 위에 산다**(tab_panel.tscn) — 카메라가 플레이어를 따라다녀 월드에
## 그리면 패널이 흘러간다(HUD와 같은 이유). 책(forge, layer 10)보다 아래라 책이 펴진 동안엔
## ui_modal_open 게이트가 여는 것을 막는다(두 모달이 겹치지 않게).

# ── 패널·탭 레이아웃 (연출값 — 밸런스 아님. 선례: inventory_panel의 PANEL_SIZE 등) ──
const PANEL_SIZE := Vector2(840.0, 520.0)
const PAD := 22.0
const TAB_TOP := 46.0          # 제목 줄 아래
const TAB_W := 116.0
const TAB_H := 30.0
const TAB_GAP := 6.0
const CONTENT_TOP := 92.0      # origin.y 기준, 탭 헤더 아래 내용 시작 y

const TAB_NAMES: Array[String] = ["소지품", "퀘스트", "마법진"]

# ── 소지품 탭: 상단 착용줄(가로 5부위) ──
const EQUIP_ROW_H := 68.0
const EQUIP_SLOT_GAP := 10.0
const GRID_GAP := 16.0          # 착용줄 아래 카드 격자 시작 간격

# ── 소지품 탭: 카드 격자(착용줄 아래 전체폭) ──
const GUTTER := 84.0
const CARD_SIZE := Vector2(150.0, 40.0)
const CARD_GAP := 7.0
const SUB_GAP := 6.0
const SECTION_GAP := 14.0

# ── 퀘스트 탭 ──
const ROW_H := 66.0
const ROW_GAP := 10.0
const BAR_H := 8.0

# ── 색 (inventory_panel·quest_panel과 동일 팔레트) ──
const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const PANEL_BG := Color(0.12, 0.10, 0.08, 0.98)
const PANEL_EDGE := Color(0.48, 0.43, 0.34, 0.9)
const TITLE_COLOR := Color(0.96, 0.90, 0.78)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const SECTION_COLOR := Color(0.86, 0.80, 0.66)
const BAG_SECTION_COLOR := Color(0.92, 0.78, 0.42)
const NAME_COLOR := Color(0.93, 0.89, 0.80)
const KIND_COLOR := Color(0.64, 0.60, 0.52)
const COUNT_COLOR := Color(0.98, 0.86, 0.52)
const EMPTY_COLOR := Color(0.60, 0.56, 0.50)
const CARD_BG := Color(0.17, 0.15, 0.12, 0.95)
const CARD_EDGE := Color(0.40, 0.37, 0.31, 0.7)

# 탭 헤더
const TAB_BG := Color(0.15, 0.13, 0.10, 0.95)
const TAB_BG_ACTIVE := Color(0.24, 0.21, 0.15, 1.0)
const TAB_EDGE := Color(0.40, 0.37, 0.31, 0.7)
const TAB_ACCENT := Color(0.92, 0.78, 0.42)
const TAB_TEXT := Color(0.72, 0.68, 0.60)
const TAB_TEXT_ACTIVE := Color(0.98, 0.92, 0.80)

# 착용 슬롯
const SLOT_BG := Color(0.16, 0.14, 0.11, 0.95)
const SLOT_EDGE := Color(0.40, 0.37, 0.31, 0.7)
const SLOT_KIND_COLOR := Color(0.70, 0.66, 0.58)
const SLOT_ITEM_COLOR := Color(0.98, 0.86, 0.52)
const SLOT_EFFECT_COLOR := Color(0.66, 0.62, 0.54)
const SLOT_EMPTY_COLOR := Color(0.52, 0.49, 0.44)

# 퀘스트 행
const Q_ROW_BG := Color(0.17, 0.15, 0.12, 0.95)
const Q_ROW_EDGE := Color(0.40, 0.37, 0.31, 0.7)
const Q_DESC_COLOR := Color(0.72, 0.68, 0.60)
const Q_ACTIVE := Color(0.92, 0.78, 0.42)   # 진행 중 (금)
const Q_DONE := Color(0.55, 0.80, 0.50)     # 완료 (녹)
const Q_BAR_BG := Color(0.28, 0.25, 0.20, 1.0)
const Q_REWARD := Color(0.70, 0.66, 0.58)

## 등급 색 — 흔함→전설 (Db.get_item.grade). 없는 등급은 `of()`가 양끝으로 clamp한다.
## 🔴 단일 소스는 `src/core/grade_colors.gd` (세션51에 사본 셋을 합쳤다).
const GradeColors := preload("res://src/core/grade_colors.gd")

## 창고를 나누는 카테고리 순서·라벨 (inventory_panel과 동일 — `ItemDef.category()` 키).
const CATEGORY_ORDER: Array = [
	[&"equip", "장비"],
	[&"ink", "잉크"],
	[&"paper", "종이"],
	[&"fragment", "탁본 조각"],
	[&"ink_mat", "잉크재료"],
	[&"paper_mat", "종이재료"],
	[&"equip_mat", "장비재료"],
	[&"food", "밥"],
	[&"water", "물"],
	[&"material", "기타"],
]

## 착용 부위 — 표시 순서·라벨. 5부위(세션42 모자 추가). 상단 착용줄에 이 순서로 가로 배치.
const EQUIP_KINDS: Array = [
	[Enums.ItemKind.PEN, "펜"],
	[Enums.ItemKind.WAND, "지팡이"],
	[Enums.ItemKind.ROBE, "로브"],
	[Enums.ItemKind.CHARM, "부적"],
	[Enums.ItemKind.HAT, "모자"],
]

var _open: bool = false
var current_tab: int = 0


func _ready() -> void:
	# 닫힌 동안엔 클릭을 먹지 않는다(visible=false면 GUI 히트테스트에서 빠진다).
	# 열리면 STOP이라 좌클릭을 통째로 먹어 시트를 보며 실수로 안 쏜다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.resources_changed.connect(_on_changed)
	EventBus.equipment_changed.connect(_on_changed)
	EventBus.quest_completed.connect(_on_changed)
	EventBus.quest_advanced.connect(_on_changed)


# ─────────────────────────── 열고 닫기 ───────────────────────────

## 🔴 토글·지름길 키는 _unhandled_input에서 잡는다 — 발사(좌클릭)·슬롯(1~4)과 안 겹친다.
## 닫힌 Control도 _unhandled_input은 받는다(mouse_filter는 마우스만 가른다).
## Tab=열기/닫기(기본 탭=소지품) · I=소지품 탭 · Q=퀘스트 탭 · ESC=닫기.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_TAB:
			# Godot 기본 포커스 이동도 Tab을 쓴다 — 여기서 잡고 소비한다.
			_toggle()
			get_viewport().set_input_as_handled()
		KEY_I:
			_open_at(0)
			get_viewport().set_input_as_handled()
		KEY_Q:
			_open_at(1)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _open:
				_set_open(false)
				get_viewport().set_input_as_handled()


## 🔴 NPC(길잡이)가 E로 여는 공개 진입점 (세션37→40) — 퀘스트 탭으로 연다. quest_panel.open()을 대체.
## _open_at이 ui_modal_open 게이트(책 등 타 모달과 안 겹침)와 이미 열림일 때 탭 전환까지 처리한다.
func open_quest() -> void:
	_open_at(1)


func _toggle() -> void:
	if _open:
		_set_open(false)
	else:
		_open_at(0)


## 특정 탭으로 연다(이미 열려 있으면 그 탭으로 전환). 다른 모달(책 등)이 열려 있으면 안 연다.
func _open_at(tab: int) -> void:
	if _open:
		if current_tab != tab:
			current_tab = tab
			queue_redraw()
	elif not GameState.ui_modal_open:
		current_tab = tab
		_set_open(true)
	_mark_seen_if_quest_tab()

## 🔴 퀘스트 탭을 실제로 열어 보면 접수 처리한다 (세션43 [!]) — 시트로 목표를 "읽으면" NPC [!]가 꺼진다.
##  정산(턴인)이 아니라 이 열람이 접수의 유일한 경로(온보딩 q00 예외는 base가 직접). 열려 있고 퀘스트
##  탭(1)일 때만. mark_quests_seen이 실제 변화 시 quests_seen를 쏘고 base가 [!]를 끈다.
func _mark_seen_if_quest_tab() -> void:
	if _open and current_tab == 1:
		GameState.mark_quests_seen()


func _set_open(open: bool) -> void:
	_open = open
	visible = open
	GameState.ui_modal_open = open
	queue_redraw()


func _on_changed(_a: Variant = null) -> void:
	if _open:
		queue_redraw()


# ─────────────────────────── 탭 전환(마우스) ───────────────────────────

## 🔴 열린 동안 STOP이라 클릭이 이 Control의 _gui_input으로 온다. 헤더 rect를 히트테스트해
## 맞으면 탭을 바꾼다. _draw와 같은 _tab_header_rects()를 봐서 그린 것과 누른 곳이 어긋나지 않는다.
func _gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var rects := _tab_header_rects()
	for i in rects.size():
		if rects[i].has_point(mb.position):
			if current_tab != i:
				current_tab = i
				queue_redraw()
				_mark_seen_if_quest_tab()   # 🔴 마우스로 퀘스트 탭 전환도 접수 (세션43)
			accept_event()
			return

	# 소지품 탭에서만 착용/해제를 잡는다(탭 헤더 다음).
	if current_tab != 0:
		return
	# 상단 착용 슬롯 클릭 → 그 부위가 차 있으면 해제(창고로 반환). 비면 무시.
	var slots := _equip_slot_rects()
	for i in slots.size():
		if slots[i].has_point(mb.position):
			var kind := int((EQUIP_KINDS[i] as Array)[0])
			if GameState.equipment.has(kind):
				GameState.unequip_gear(kind)   # equipment_changed → _on_changed → queue_redraw
			accept_event()
			return
	# 하단 카드 클릭 → 착용 가능 종류면 착용. 그 외(잉크·재료 등)는 무시.
	var layout := _grid_sections()
	for sec: Dictionary in layout["sections"]:
		for card: Dictionary in sec["cards"]:
			var card_rect: Rect2 = card["rect"]
			if card_rect.has_point(mb.position):
				if _is_equippable(card["id"]):
					GameState.equip_gear(card["id"])   # 창고 차감·equipment_changed → queue_redraw
				accept_event()
				return


func _origin() -> Vector2:
	return ((size - PANEL_SIZE) * 0.5).round()


## 탭 헤더 3개의 rect(Control 로컬 좌표). _draw와 _gui_input이 공유하는 단일 소스.
func _tab_header_rects() -> Array[Rect2]:
	var o := _origin()
	var rects: Array[Rect2] = []
	var x := o.x + PAD
	var y := o.y + TAB_TOP
	for i in TAB_NAMES.size():
		rects.append(Rect2(Vector2(x, y), Vector2(TAB_W, TAB_H)))
		x += TAB_W + TAB_GAP
	return rects


# ─────────────────────────── 그리기 ───────────────────────────

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)

	var origin := _origin()
	draw_rect(Rect2(origin, PANEL_SIZE), PANEL_BG, true)
	draw_rect(Rect2(origin, PANEL_SIZE), PANEL_EDGE, false, 2.0)

	draw_string(font, origin + Vector2(PAD, 30.0), "개인 시트",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TITLE_COLOR)
	draw_string(font, origin + Vector2(PANEL_SIZE.x - PAD - 170.0, 30.0), "[Tab] / ESC  닫기",
		HORIZONTAL_ALIGNMENT_RIGHT, 170.0, 12, HINT_COLOR)

	_draw_tab_headers(font)

	var content_top := origin.y + CONTENT_TOP
	match current_tab:
		0:
			_draw_items_tab(font, origin, content_top)
		1:
			_draw_quests_tab(font, origin, content_top)
		2:
			_draw_magic_tab(font, origin, content_top)


func _draw_tab_headers(font: Font) -> void:
	var rects := _tab_header_rects()
	for i in rects.size():
		var r: Rect2 = rects[i]
		var is_cur := i == current_tab
		draw_rect(r, TAB_BG_ACTIVE if is_cur else TAB_BG, true)
		draw_rect(r, TAB_EDGE, false, 1.0)
		if is_cur:
			# 현재 탭 강조 — 아래쪽 액센트 밑줄.
			draw_rect(Rect2(Vector2(r.position.x, r.position.y + r.size.y - 3.0),
				Vector2(r.size.x, 3.0)), TAB_ACCENT, true)
		draw_string(font, Vector2(r.position.x, r.position.y + 20.0), TAB_NAMES[i],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14,
			TAB_TEXT_ACTIVE if is_cur else TAB_TEXT)


# ─────────────────────────── 탭1: 소지품 ───────────────────────────

## 상단 착용줄(가로 5부위) + 아래 전체폭 카드 격자. 클릭으로 착용/해제한다.
## 🔴 draw와 클릭이 같은 rect 함수를 본다 — 착용줄=_equip_slot_rects(), 격자=_grid_sections().
## 그린 곳과 누른 곳이 어긋나지 않게 좌표를 한 함수에서만 만든다.
func _draw_items_tab(font: Font, _origin: Vector2, _content_top: float) -> void:
	_draw_equip_row(font)
	_draw_grid(font)


## 착용줄 5칸 rect(Control 로컬). _draw_equip_row와 _gui_input의 단일 소스. EQUIP_KINDS 순.
func _equip_slot_rects() -> Array[Rect2]:
	var o := _origin()
	var top := o.y + CONTENT_TOP
	var left := o.x + PAD
	var total_w := PANEL_SIZE.x - PAD * 2.0
	var n := EQUIP_KINDS.size()
	var slot_w := (total_w - EQUIP_SLOT_GAP * float(n - 1)) / float(n)
	var rects: Array[Rect2] = []
	var x := left
	for i in n:
		rects.append(Rect2(Vector2(x, top), Vector2(slot_w, EQUIP_ROW_H)))
		x += slot_w + EQUIP_SLOT_GAP
	return rects


## 착용줄 그리기 — 부위 라벨 + 착용 아이템(등급 띠·이름·효과) 또는 "비어 있음".
## 슬롯 클릭=해제는 _gui_input이 처리(equipment.has(kind)일 때만).
func _draw_equip_row(font: Font) -> void:
	var o := _origin()
	draw_string(font, Vector2(o.x + PAD, o.y + CONTENT_TOP - 8.0), "착용 (슬롯 클릭=해제)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SECTION_COLOR)
	var rects := _equip_slot_rects()
	for i in rects.size():
		var r: Rect2 = rects[i]
		var pair: Array = EQUIP_KINDS[i]
		var kind: int = pair[0]
		var kind_label: String = pair[1]
		draw_rect(r, SLOT_BG, true)
		draw_rect(r, SLOT_EDGE, false, 1.0)
		draw_string(font, Vector2(r.position.x + 11.0, r.position.y + 16.0), kind_label,
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 11, SLOT_KIND_COLOR)
		if GameState.equipment.has(kind):
			var item_id: StringName = GameState.equipment[kind]
			var item := Db.get_item(item_id)
			var grade := item.grade if item != null else 1
			var chip := GradeColors.of(grade)
			draw_rect(Rect2(r.position, Vector2(4.0, r.size.y)), chip, true)
			draw_string(font, Vector2(r.position.x + 11.0, r.position.y + 38.0), _item_name(item_id),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 12, SLOT_ITEM_COLOR)
			var eff := _effect_text(item_id)
			if eff != "":
				draw_string(font, Vector2(r.position.x + 11.0, r.position.y + 55.0), eff,
					HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 9, SLOT_EFFECT_COLOR)
		else:
			draw_string(font, Vector2(r.position.x + 11.0, r.position.y + 40.0), "비어 있음",
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 11, SLOT_EMPTY_COLOR)


## 착용줄 아래 전체폭 카드 격자 그리기. _grid_sections()가 rect를 쥐고, 여기선 그리기만 한다.
func _draw_grid(font: Font) -> void:
	var o := _origin()
	var left := o.x + PAD
	var region_width := PANEL_SIZE.x - PAD * 2.0
	var grid_top := o.y + CONTENT_TOP + EQUIP_ROW_H + GRID_GAP
	var layout := _grid_sections()
	if bool(layout["empty_msg"]):
		draw_string(font, Vector2(left, grid_top + 12.0),
			"창고가 비었다 — 숲에서 적을 잡아 [E]로 귀환하면 여기 쌓인다",
			HORIZONTAL_ALIGNMENT_LEFT, region_width, 12, EMPTY_COLOR)
	for sec: Dictionary in layout["sections"]:
		_draw_section_layout(font, sec, region_width)


## 한 구역 그리기(라벨 + 카드들). 좌표는 전부 _section_layout이 이미 계산했다 — 여기선 그리기만.
func _draw_section_layout(font: Font, sec: Dictionary, region_width: float) -> void:
	var label_pos: Vector2 = sec["label_pos"]
	if bool(sec["label_above"]):
		draw_string(font, label_pos, sec["title"],
			HORIZONTAL_ALIGNMENT_LEFT, region_width, 13, sec["color"])
	else:
		draw_string(font, label_pos, sec["title"],
			HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 8.0, 13, sec["color"])
	for card: Dictionary in sec["cards"]:
		var rect: Rect2 = card["rect"]
		_draw_card(font, rect.position, card["id"], int(card["count"]))


## 🔴 격자 전체 레이아웃(순수) — 창고(카테고리별)+가방을 카드 rect까지 계산한다.
## _draw_grid와 _gui_input(카드 클릭)의 단일 소스. 그리지 않는다.
func _grid_sections() -> Dictionary:
	var o := _origin()
	var left := o.x + PAD
	var region_width := PANEL_SIZE.x - PAD * 2.0
	var y := o.y + CONTENT_TOP + EQUIP_ROW_H + GRID_GAP
	var sections: Array = []

	var groups := _grouped(GameState.get_inventory_snapshot())
	var empty_msg := groups.is_empty()
	if empty_msg:
		y += 28.0
	else:
		for pair: Array in CATEGORY_ORDER:
			var cat: StringName = pair[0]
			if groups.has(cat):
				var sec := _section_layout(pair[1], SECTION_COLOR, left, y, region_width, groups[cat], false)
				sections.append(sec)
				y = float(sec["next_y"]) + SUB_GAP

	var bag := _sorted_entries(_bag_counts())
	if not bag.is_empty():
		y += SECTION_GAP
		var sec := _section_layout("가방 (들고 있는 것 · 죽으면 사라진다)", BAG_SECTION_COLOR,
			left, y, region_width, bag, true)
		sections.append(sec)

	return {"sections": sections, "empty_msg": empty_msg}


## 한 구역의 좌표를 계산해 Dictionary로. 그리기·클릭이 공유한다(옛 _draw_section의 기하 그대로).
## label_above=false: 라벨을 왼쪽 좁은 칸(GUTTER)에, 카드를 오른쪽에.
## label_above=true: 라벨을 카드 위 전체폭에(가방 — 경고문이 길어 좁은 칸에 안 들어간다).
func _section_layout(title: String, color: Color, left: float, top: float,
		region_width: float, entries: Array, label_above: bool) -> Dictionary:
	var gutter := 0.0 if label_above else GUTTER
	var avail := region_width - gutter
	var cols := maxi(int((avail + CARD_GAP) / (CARD_SIZE.x + CARD_GAP)), 1)
	var rows := int(ceil(float(entries.size()) / float(cols))) if not entries.is_empty() else 0
	var block_h := float(rows) * (CARD_SIZE.y + CARD_GAP)
	var cards_top := top
	var cards_left := left
	var label_pos := Vector2.ZERO
	if label_above:
		label_pos = Vector2(left, top + 14.0)
		cards_top = top + 22.0
	else:
		# 라벨은 카드 블록 세로 중앙에 앉는다(1줄 폰트 보정 +4).
		label_pos = Vector2(left, top + block_h * 0.5 + 4.0)
		cards_left = left + GUTTER
	var cards: Array = []
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var col := i % cols
		var row := i / cols
		var at := Vector2(cards_left + float(col) * (CARD_SIZE.x + CARD_GAP),
			cards_top + float(row) * (CARD_SIZE.y + CARD_GAP))
		cards.append({"rect": Rect2(at, CARD_SIZE), "id": entry["id"], "count": int(entry["count"])})
	return {"title": title, "color": color, "label_pos": label_pos,
		"label_above": label_above, "cards": cards, "next_y": cards_top + block_h}


## 착용 가능 종류인가(EQUIP_KINDS의 kind와 일치). 카드 클릭 착용 필터.
func _is_equippable(id: StringName) -> bool:
	var it := Db.get_item(id)
	if it == null:
		return false
	for pair: Array in EQUIP_KINDS:
		if int(pair[0]) == int(it.kind):
			return true
	return false


## 카드 한 장 — 등급 색 띠 + 이름 + ★등급 + 수량. 알 수 없는 id도 그린다(정본이 GameState라).
func _draw_card(font: Font, at: Vector2, id: StringName, count: int) -> void:
	var item := Db.get_item(id)
	var rect := Rect2(at, CARD_SIZE)
	draw_rect(rect, CARD_BG, true)
	draw_rect(rect, CARD_EDGE, false, 1.0)

	var grade := item.grade if item != null else 1
	var chip := GradeColors.of(grade)
	draw_rect(Rect2(at, Vector2(4.0, CARD_SIZE.y)), chip, true)

	var name_text := item.display_name if item != null and item.display_name != "" else str(id)
	draw_string(font, at + Vector2(11.0, 17.0), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 16.0, 12, NAME_COLOR)
	draw_string(font, at + Vector2(11.0, 33.0), "★%d" % grade,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, KIND_COLOR)
	draw_string(font, at + Vector2(CARD_SIZE.x - 42.0, 33.0), "×%d" % count,
		HORIZONTAL_ALIGNMENT_RIGHT, 38.0, 13, COUNT_COLOR)


# ─────────────────────────── 탭2: 퀘스트 ───────────────────────────

## quest_panel의 _draw 본문·_visible_quests·_draw_row·_reward_text를 그대로 이관(내용 동일).
func _draw_quests_tab(font: Font, origin: Vector2, content_top: float) -> void:
	var rows := _visible_quests()
	var y := content_top
	var left := origin.x + PAD
	var width := PANEL_SIZE.x - PAD * 2.0

	if rows.is_empty():
		draw_string(font, Vector2(left, y + 14.0),
			"목표가 없다 — 숲으로 나가 사냥을 시작하라",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, EMPTY_COLOR)
		return

	for q: QuestDef in rows:
		_draw_quest_row(font, Vector2(left, y), width, q)
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


func _draw_quest_row(font: Font, at: Vector2, width: float, q: QuestDef) -> void:
	var done := GameState.is_quest_done(q.id)
	var accent := Q_DONE if done else Q_ACTIVE
	var rect := Rect2(at, Vector2(width, ROW_H))
	draw_rect(rect, Q_ROW_BG, true)
	draw_rect(rect, Q_ROW_EDGE, false, 1.0)
	draw_rect(Rect2(at, Vector2(4.0, ROW_H)), accent, true)   # 상태 색 띠

	var tx := at.x + 14.0
	var mark := "✓ " if done else ""
	draw_string(font, Vector2(tx, at.y + 20.0), mark + q.title,
		HORIZONTAL_ALIGNMENT_LEFT, width - 200.0, 15, NAME_COLOR if not done else Q_DONE)
	draw_string(font, Vector2(tx, at.y + 38.0), q.desc,
		HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 11, Q_DESC_COLOR)

	var need := q.need()
	var cur := mini(GameState.quest_count(q.id), need) if not done else need
	var prog_text := "완료" if done else "%d / %d" % [cur, need]
	draw_string(font, Vector2(at.x + width - 180.0, at.y + 20.0), prog_text,
		HORIZONTAL_ALIGNMENT_RIGHT, 168.0, 13, accent)
	var reward := _reward_text(q)
	if reward != "":
		draw_string(font, Vector2(at.x + width - 180.0, at.y + 38.0), "보상: " + reward,
			HORIZONTAL_ALIGNMENT_RIGHT, 168.0, 10, Q_REWARD)

	var bar_top := at.y + ROW_H - BAR_H - 6.0
	var bar_rect := Rect2(Vector2(tx, bar_top), Vector2(width - 28.0, BAR_H))
	draw_rect(bar_rect, Q_BAR_BG, true)
	var frac := 1.0 if done else (float(cur) / float(need) if need > 0 else 0.0)
	if frac > 0.0:
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * frac, BAR_H)), accent, true)


## 보상 아이템들을 "이름 ×n" 로(여러 개면 콤마). 없으면 빈 문자열.
func _reward_text(q: QuestDef) -> String:
	var parts: Array[String] = []
	for item_id: StringName in q.reward_items:
		var it := Db.get_item(item_id)
		var nm := it.display_name if it != null and it.display_name != "" else String(item_id)
		parts.append("%s ×%d" % [nm, int(q.reward_items[item_id])])
	return ", ".join(parts)


# ─────────────────────────── 탭3: 마법진 (스텁) ───────────────────────────

## 🔴 지금은 자리표만 — 실제 레이아웃은 나중에 붙인다. 탭 자리·헤더는 있어야 해 여기만 안내문 한 줄.
func _draw_magic_tab(font: Font, origin: Vector2, content_top: float) -> void:
	var left := origin.x + PAD
	draw_string(font, Vector2(left, content_top + 40.0),
		"마법진 — 준비 중",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, SECTION_COLOR)
	draw_string(font, Vector2(left, content_top + 66.0),
		"장착한 고리 도안이 여기에 표시될 예정이다.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HINT_COLOR)


# ─────────────────────────── 공용 헬퍼 ───────────────────────────

## {id: count} → {category: 정렬된 [{id,count}]}. 0개는 뺀다. 카테고리는 ItemDef.category()가 판다.
func _grouped(counts: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	for id: StringName in counts:
		if int(counts[id]) <= 0:
			continue
		var item := Db.get_item(id)
		var cat: StringName = item.category() if item != null else &"material"
		if not groups.has(cat):
			groups[cat] = []
		groups[cat].append({"id": id, "count": int(counts[id])})
	for cat: StringName in groups:
		groups[cat].sort_custom(_entry_less)
	return groups


## 가방 엔트리는 [{id, count}] 여러 개로 쌓인다(킬마다 append) — id로 합쳐서 보여 준다.
func _bag_counts() -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in GameState.bag:
		var id: StringName = entry["id"]
		out[id] = int(out.get(id, 0)) + int(entry["count"])
	return out


## {id: count} → 정렬된 [{id, count}] (종류 → 등급 내림 → id). 0개는 뺀다.
func _sorted_entries(counts: Dictionary) -> Array:
	var out: Array = []
	for id: StringName in counts:
		if int(counts[id]) > 0:
			out.append({"id": id, "count": int(counts[id])})
	out.sort_custom(_entry_less)
	return out


func _entry_less(a: Dictionary, b: Dictionary) -> bool:
	var ia := Db.get_item(a["id"])
	var ib := Db.get_item(b["id"])
	var ka := int(ia.kind) if ia != null else 99
	var kb := int(ib.kind) if ib != null else 99
	if ka != kb:
		return ka < kb
	var ga := ia.grade if ia != null else 0
	var gb := ib.grade if ib != null else 0
	if ga != gb:
		return ga > gb
	return String(a["id"]) < String(b["id"])


func _item_name(id: StringName) -> String:
	var it := Db.get_item(id)
	return it.display_name if it != null and it.display_name != "" else String(id)


## 장비 효과 한 줄 — 펜=보정, 로브=HP/마나, 지팡이=발사 패턴 (workshop_panel._effect_text와 동일).
func _effect_text(item_id: StringName) -> String:
	var it := Db.get_item(item_id)
	if it == null:
		return ""
	match int(it.kind):
		Enums.ItemKind.PEN:
			return "손그림 보정 +%.2f" % float(it.params.get("correction", 0.0))
		Enums.ItemKind.ROBE:
			var parts: Array[String] = []
			if it.params.has("hp_max_add"):
				parts.append("HP +%d" % int(it.params["hp_max_add"]))
			if it.params.has("mana_max_add"):
				parts.append("마나 +%d" % int(it.params["mana_max_add"]))
			return " · ".join(parts)
		Enums.ItemKind.WAND:
			return _wand_pattern_text(it)
		Enums.ItemKind.CHARM:
			return "구르기 쿨 -%d%%" % roundi((1.0 - float(it.params.get("dash_cooldown_mult", 1.0))) * 100.0)
		Enums.ItemKind.HAT:
			return "이동 속도 +%d%%" % roundi(float(it.params.get("move_speed_mult", 0.0)) * 100.0)
		_:
			return ""


## 지팡이 발사 패턴을 사람 말로 — 단발/산탄/전방위 (workshop_panel._wand_pattern_text와 동일).
func _wand_pattern_text(it: ItemDef) -> String:
	match int(it.params.get("wand_pattern", Enums.WandPattern.SINGLE)):
		Enums.WandPattern.MULTI:
			return "산탄 (여러 발)"
		Enums.WandPattern.NOVA:
			return "전방위"
		_:
			return "단발"
