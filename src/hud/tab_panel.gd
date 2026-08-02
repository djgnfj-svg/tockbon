extends Control
## 통합 개인 시트 모달 — 소지품(창고+가방)·퀘스트·마법진·캐릭터를 한 패널에 묶는다.
## 따로 열리면 모달 슬롯(`ui_modal_open`)을 서로 밀치고 근육 기억도 흩어져서 하나로 합쳤다.
## 🔴 **탭 목록의 정본은 `TAB_NAMES` 하나다** — 개수를 주석·코드에 따로 박지 마라.
##
## 🔴 모달 규약 — `chapter_panel`·`dialogue_box`가 이 파일을 베낀다:
##  · 열리면 `mouse_filter = STOP` → 좌클릭을 통째로 먹어 시트를 보며 실수로 안 쏜다.
##  · 닫히면 `visible = false` → GUI 히트테스트에서 빠져 클릭이 다시 바닥으로 샌다.
##  · 열림/닫힘에 `GameState.ui_modal_open`을 토글 → player·caster가 폴링해 멎는다.
##  · 🔴 **닫힌 Control도 `_unhandled_input`은 받는다** — 그래서 Tab/I/Q로 열 수 있다.
##  · `_draw`가 매번 GameState/Db를 직접 읽는다(캐시 없음) → 갱신은 `queue_redraw()` 하나로 끝.
##
## 🔴 **탭 헤더는 손으로 그린다**(TabContainer 아님) — 패널 전체가 즉시모드 손그림이라 룩을 맞춘다.
## 🔴 헤더 rect는 `_tab_header_rects()` 한 함수가 쥔다 — `_draw`와 `_gui_input`이 같은 것을 봐야
## 그린 자리와 누르는 자리가 안 어긋난다.
##
## 🔴 **CanvasLayer 위에 산다** — 카메라가 플레이어를 따라다녀 월드에 그리면 패널이 흘러간다.
## 책보다 아래라 책이 펴진 동안엔 `ui_modal_open` 게이트가 여는 것을 막는다.

# ── 패널·탭 레이아웃 (연출값 — 밸런스 아님) ──
const PANEL_SIZE := Vector2(840.0, 520.0)
const PAD := 22.0
const TAB_TOP := 46.0          # 제목 줄 아래
const TAB_W := 116.0
const TAB_H := 30.0
const TAB_GAP := 6.0
const CONTENT_TOP := 92.0      # origin.y 기준, 탭 헤더 아래 내용 시작 y

const TAB_NAMES: Array[String] = ["소지품", "퀘스트", "마법진", "캐릭터"]

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

# ── 색 ──
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

## 🔴 등급 색 단일 소스. 없는 등급은 `of()`가 양끝으로 clamp한다.
const GradeColors := preload("res://src/core/grade_colors.gd")

## 🔴 위력·점수·등급은 **전부 core가 판다** — 여기서 계산하면 리포트·HUD와 갈라진다
## (리포트가 "위력 140"이라 적고 130으로 때리는 식).
const RingPower := preload("res://src/core/ring_power.gd")

## 🔴 장비 효과 문구·발사 패턴 라벨 = core 단일 소스. `workshop_panel`도 같은 파일을 부른다.
const ItemText := preload("res://src/core/item_text.gd")

## 마법진 탭의 표시 어휘 — 문양 이름·색·칸 각도.
## 🔴 core는 문양 이름·색을 **일부러 안 갖는다**(drawing 참조 금지) — 코드→말/색 해석은 여기 몫이다.
const RingBoard := preload("res://src/drawing/ring_board.gd")

## 창고를 나누는 카테고리 순서·라벨 (`ItemDef.category()` 키).
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

## 착용 부위 — 표시 순서·라벨. 상단 착용줄에 이 순서로 가로 배치.
const EQUIP_KINDS: Array = [
	[Enums.ItemKind.PEN, "펜"],
	[Enums.ItemKind.WAND, "지팡이"],
	[Enums.ItemKind.ROBE, "로브"],
	[Enums.ItemKind.CHARM, "부적"],
	[Enums.ItemKind.HAT, "모자"],
]

var _open: bool = false
var current_tab: int = 0

## 마법진 탭에서 고른 보관 도안(null = 안 골랐다).
## 🔴 **인덱스가 아니라 인스턴스 참조로 쥔다** — 보관 목록은 장착/해제마다 순서가 바뀐다.
## 패널을 닫거나 탭을 옮기면 지운다 — 고른 채로 잊히면 다음에 연 사람이 모르는 도안을 장착한다.
var _picked: RingDesign = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.resources_changed.connect(_on_changed)
	EventBus.equipment_changed.connect(_on_changed)
	EventBus.quest_completed.connect(_on_changed)
	EventBus.quest_advanced.connect(_on_changed)


# ─────────────────────────── 열고 닫기 ───────────────────────────

## Tab=열기/닫기 · I=소지품 · Q=퀘스트 · C=캐릭터 · ESC=닫기.
## 🔴 1·2·3 = 마법진 탭에서 **고른 도안을 그 슬롯에 올린다.** 발사 슬롯 키와 같은 키인데 안 겹치는
## 이유 = caster가 `ui_modal_open`이면 즉시 되돌아가 이 패널이 열린 동안 주인이 없다.
## **고른 게 없으면 소비도 안 한다.**
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if _open and current_tab == 2 and _picked != null \
			and key.keycode >= KEY_1 and key.keycode < KEY_1 + GameState.EQUIP_SLOTS:
		magic_assign(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_TAB:
			# ⚠ Godot 기본 포커스 이동도 Tab을 쓴다 — 반드시 여기서 소비해야 한다.
			_toggle()
			get_viewport().set_input_as_handled()
		KEY_I:
			_open_at(0)
			get_viewport().set_input_as_handled()
		KEY_Q:
			_open_at(1)
			get_viewport().set_input_as_handled()
		KEY_C:
			_open_at(3)   # 캐릭터 탭 — HUD 우하단 아이콘의 [C]와 짝
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _open:
				_set_open(false)
				get_viewport().set_input_as_handled()


## 퀘스트 탭을 코드에서 여는 공개 문 — 다음 호출자가 탭 인덱스를 베끼지 않게 남긴다.
## ⚠ 지금 부르는 곳이 없다(시트는 [Tab]·[I]·[Q]·[C]로만 열린다).
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
			_picked = null
			queue_redraw()
	elif not GameState.ui_modal_open:
		current_tab = tab
		_set_open(true)
	_mark_seen_if_quest_tab()

## 🔴 퀘스트 탭을 실제로 열어 보는 것이 **접수의 유일한 경로**다 — 읽으면 [!] 표시가 꺼진다.
func _mark_seen_if_quest_tab() -> void:
	if _open and current_tab == 1:
		GameState.mark_quests_seen()


func _set_open(open: bool) -> void:
	_open = open
	visible = open
	GameState.ui_modal_open = open
	_picked = null   # 다음에 연 사람이 모르는 채 장착하지 않게
	queue_redraw()


func _on_changed(_a: Variant = null) -> void:
	if _open:
		queue_redraw()


# ─────────────────────────── 탭 전환(마우스) ───────────────────────────

## 열린 동안 STOP이라 클릭이 여기로 온다. 🔴 히트테스트는 `_draw`와 **같은** `_tab_header_rects()`를
## 봐야 그린 자리와 누르는 자리가 안 어긋난다.
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
				_picked = null
				queue_redraw()
				_mark_seen_if_quest_tab()   # 마우스 전환도 접수다
			accept_event()
			return

	# 🔴 판정·적용은 `magic_click` 하나가 쥔다 — 헤드리스가 부르는 함수가 그거다.
	if current_tab == 2:
		if magic_click(mb.position):
			accept_event()
		return

	if current_tab != 0:
		return
	# 상단 착용 슬롯 클릭 → 차 있으면 해제(창고로 반환).
	var slots := _equip_slot_rects()
	for i in slots.size():
		if slots[i].has_point(mb.position):
			var kind := int((EQUIP_KINDS[i] as Array)[0])
			if GameState.equipment.has(kind):
				GameState.unequip_gear(kind)   # equipment_changed → _on_changed → queue_redraw
			accept_event()
			return
	# 하단 카드 클릭 → 착용 가능 종류면 착용.
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


## 🔴 탭 헤더 rect — `_draw`와 `_gui_input`이 공유하는 단일 소스(개수는 `TAB_NAMES`가 판다).
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
		3:
			_draw_character_tab(font, origin, content_top)


func _draw_tab_headers(font: Font) -> void:
	var rects := _tab_header_rects()
	for i in rects.size():
		var r: Rect2 = rects[i]
		var is_cur := i == current_tab
		draw_rect(r, TAB_BG_ACTIVE if is_cur else TAB_BG, true)
		draw_rect(r, TAB_EDGE, false, 1.0)
		if is_cur:
			draw_rect(Rect2(Vector2(r.position.x, r.position.y + r.size.y - 3.0),
				Vector2(r.size.x, 3.0)), TAB_ACCENT, true)
		draw_string(font, Vector2(r.position.x, r.position.y + 20.0), TAB_NAMES[i],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14,
			TAB_TEXT_ACTIVE if is_cur else TAB_TEXT)


# ─────────────────────────── 탭1: 소지품 ───────────────────────────

## 상단 착용줄 + 아래 전체폭 카드 격자. 클릭으로 착용/해제한다.
## 🔴 그린 곳과 누른 곳이 어긋나지 않게 좌표를 rect 함수 한 곳에서만 만든다
##   (착용줄 = `_equip_slot_rects()` · 격자 = `_grid_sections()`).
func _draw_items_tab(font: Font, _origin: Vector2, _content_top: float) -> void:
	_draw_equip_row(font)
	_draw_grid(font)


## 🔴 착용줄 rect — 그리기와 클릭의 단일 소스. `EQUIP_KINDS` 순.
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


## 착용줄 — 부위 라벨 + 착용 아이템(등급 띠·이름·효과) 또는 "비어 있음".
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
			var eff := ItemText.effect_text(item)
			if eff != "":
				draw_string(font, Vector2(r.position.x + 11.0, r.position.y + 55.0), eff,
					HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 9, SLOT_EFFECT_COLOR)
		else:
			draw_string(font, Vector2(r.position.x + 11.0, r.position.y + 40.0), "비어 있음",
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 11, SLOT_EMPTY_COLOR)


## 카드 격자 그리기 — rect는 `_grid_sections()`가 쥐고 여기선 그리기만 한다.
func _draw_grid(font: Font) -> void:
	var o := _origin()
	var left := o.x + PAD
	var region_width := PANEL_SIZE.x - PAD * 2.0
	var grid_top := o.y + CONTENT_TOP + EQUIP_ROW_H + GRID_GAP
	var layout := _grid_sections()
	if bool(layout["empty_msg"]):
		draw_string(font, Vector2(left, grid_top + 12.0),
			"창고가 비었다 — 챕터에서 주운 것을 들고 출구로 살아 나오면 여기 쌓인다",
			HORIZONTAL_ALIGNMENT_LEFT, region_width, 12, EMPTY_COLOR)
	for sec: Dictionary in layout["sections"]:
		_draw_section_layout(font, sec, region_width)
	# 잘려 반쯤 보이는 것보다 "몇 종이 더 있다"가 낫다.
	var hidden := int(layout["hidden"])
	if hidden > 0:
		draw_string(font, Vector2(left + 8.0, float(layout["fold_y"]) + 12.0),
			"… 외 %d종" % hidden, HORIZONTAL_ALIGNMENT_LEFT, region_width - 16.0, 11, EMPTY_COLOR)


## 한 구역 그리기 — 좌표는 전부 `_section_layout`이 이미 계산했다.
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


## 🔴 격자 전체 레이아웃(순수) — 그리기와 카드 클릭의 단일 소스. 그리지 않는다.
##
## 🔴 **패널 아랫변을 넘는 카드는 아예 만들지 않는다.** 이 함수가 클릭 rect의 단일 소스라, 안 그린
## 카드를 목록에 남기면 **화면 밖 카드가 클릭으로 착용되는** 유령 판정이 생긴다.
## 접는 방식 = 구역째 버리지 않고 **줄 단위로** 자른다 — 통째로 버리면 아이템이 많을 때
## "… 외 60종" 한 줄만 남고 화면이 텅 빈다.
## ⚠ 한 구역이 잘리면 **그 뒤 구역은 통째로** 접는다 — 중간을 건너뛰면 순서가 거짓이 된다.
const GRID_FOLD_H := 16.0     ## "… 외 N종" 한 줄이 차지하는 높이

func _grid_sections() -> Dictionary:
	var o := _origin()
	var left := o.x + PAD
	var region_width := PANEL_SIZE.x - PAD * 2.0
	var bottom := o.y + PANEL_SIZE.y - PAD - GRID_FOLD_H
	var y := o.y + CONTENT_TOP + EQUIP_ROW_H + GRID_GAP
	var sections: Array = []
	var hidden := 0

	var groups := _grouped(GameState.get_inventory_snapshot())
	var empty_msg := groups.is_empty()
	if empty_msg:
		y += 28.0
	else:
		for pair: Array in CATEGORY_ORDER:
			var cat: StringName = pair[0]
			if not groups.has(cat):
				continue
			var entries: Array = groups[cat]
			if hidden > 0:
				hidden += entries.size()   # 앞이 잘렸으면 뒤는 통째로 접는다 (순서 보존)
				continue
			var sec := _section_layout(pair[1], SECTION_COLOR, left, y, region_width,
				entries, false, bottom - y)
			if (sec["cards"] as Array).is_empty():
				hidden += entries.size()   # 한 줄도 못 들어간다
				continue
			sections.append(sec)
			hidden += int(sec["hidden"])
			y = float(sec["next_y"]) + SUB_GAP

	var bag := _sorted_entries(_bag_counts())
	if not bag.is_empty():
		var bag_top := y + SECTION_GAP
		var sec := _section_layout("가방 (들고 있는 것 · 죽으면 사라진다)", BAG_SECTION_COLOR,
			left, bag_top, region_width, bag, true, bottom - bag_top)
		if hidden > 0 or (sec["cards"] as Array).is_empty():
			hidden += bag.size()
		else:
			sections.append(sec)
			hidden += int(sec["hidden"])
			y = float(sec["next_y"])

	return {"sections": sections, "empty_msg": empty_msg, "hidden": hidden, "fold_y": y}


## 한 구역의 좌표를 계산해 Dictionary로 — 그리기·클릭이 공유한다.
## label_above=false: 라벨을 왼쪽 좁은 칸(GUTTER)에 · true: 카드 위 전체폭에(긴 문구용).
## 🔴 `max_h` = 이 구역이 쓸 수 있는 높이. 넘는 줄은 **카드를 안 만들고** 종 수를 `hidden`으로 준다.
func _section_layout(title: String, color: Color, left: float, top: float,
		region_width: float, entries: Array, label_above: bool,
		max_h: float = INF) -> Dictionary:
	var gutter := 0.0 if label_above else GUTTER
	var avail := region_width - gutter
	var cols := maxi(int((avail + CARD_GAP) / (CARD_SIZE.x + CARD_GAP)), 1)
	var head := 22.0 if label_above else 0.0
	var rows := int(ceil(float(entries.size()) / float(cols))) if not entries.is_empty() else 0
	if max_h < INF:
		# 블록 높이 산식을 그대로 뒤집어 줄 수 상한을 낸다.
		rows = mini(rows, maxi(int(floor((max_h - head) / (CARD_SIZE.y + CARD_GAP))), 0))
	var shown := mini(entries.size(), rows * cols)
	var block_h := float(rows) * (CARD_SIZE.y + CARD_GAP)
	var cards_top := top
	var cards_left := left
	var label_pos := Vector2.ZERO
	if label_above:
		label_pos = Vector2(left, top + 14.0)
		cards_top = top + head
	else:
		# 카드 블록 세로 중앙 (+4 = 1줄 폰트 보정).
		label_pos = Vector2(left, top + block_h * 0.5 + 4.0)
		cards_left = left + GUTTER
	var cards: Array = []
	for i in shown:
		var entry: Dictionary = entries[i]
		var col := i % cols
		var row := i / cols
		var at := Vector2(cards_left + float(col) * (CARD_SIZE.x + CARD_GAP),
			cards_top + float(row) * (CARD_SIZE.y + CARD_GAP))
		cards.append({"rect": Rect2(at, CARD_SIZE), "id": entry["id"], "count": int(entry["count"])})
	return {"title": title, "color": color, "label_pos": label_pos,
		"label_above": label_above, "cards": cards, "next_y": cards_top + block_h,
		"hidden": entries.size() - shown}


## 착용 가능 종류인가 — 카드 클릭 착용 필터.
func _is_equippable(id: StringName) -> bool:
	var it := Db.get_item(id)
	if it == null:
		return false
	for pair: Array in EQUIP_KINDS:
		if int(pair[0]) == int(it.kind):
			return true
	return false


## 카드 한 장. ⚠ Db에 없는 id도 그린다 — 소지품의 정본은 Db가 아니라 GameState다.
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

## 🔴 **넘침 = 잘림이 아니라 상한으로 막는다.** 캡이 없으면 퀘스트가 연쇄 완료될 때 마지막 행이
## 패널 아랫변을 뚫고 화면 밖으로 나간다(스크롤이 없다). 수용량은 상수를 박지 말고 `PANEL_SIZE`·
## `ROW_H`에서 **계산**한다 — 그래야 레이아웃을 건드릴 때 자동으로 따라온다.
## ⚠ 스크롤을 안 넣은 이유: 즉시모드 `_draw`에 붙이면 새 입력 경로가 생기고 그 순간
##   `mouse_filter` 함정 자리가 하나 더 는다.
const QUEST_FOLD_H := 16.0    ## "… 외 N개" 한 줄이 차지하는 높이

func _draw_quests_tab(font: Font, origin: Vector2, content_top: float) -> void:
	var rows := _visible_quests()
	var y := content_top
	var left := origin.x + PAD
	var width := PANEL_SIZE.x - PAD * 2.0
	var bottom := origin.y + PANEL_SIZE.y - PAD

	if rows.is_empty():
		draw_string(font, Vector2(left, y + 14.0),
			"목표가 없다 — 숲길에서 챕터를 골라 사냥을 시작하라",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, EMPTY_COLOR)
		return

	var shown := quest_rows_shown(rows.size(), bottom - content_top)
	for i in shown:
		_draw_quest_row(font, Vector2(left, y), width, rows[i])
		y += ROW_H + ROW_GAP
	if shown < rows.size():
		draw_string(font, Vector2(left + 8.0, y + 12.0),
			"… 외 %d개" % (rows.size() - shown),   # ⚠ 조작 안내를 붙이지 마라 — 목록을 줄이는 수단이 없다
			HORIZONTAL_ALIGNMENT_LEFT, width - 16.0, 11, EMPTY_COLOR)


## 그릴 퀘스트 = 진행 중 + 완료. 잠긴 것(선행 미완료)은 뺀다. 열린 것 먼저.
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


## 🔴 실제로 그릴 행 수 — **순수 함수라 헤드리스가 잰다**(렌더는 못 재도 「6행이면 5행」은 잰다).
## 접을 게 있으면 "… 외 N개" 한 줄 자리를 남긴다. 마지막 행은 ROW_GAP을 안 쓰므로 그만큼 얹는다.
static func quest_rows_shown(total: int, avail: float) -> int:
	var cap := maxi(int(floor((avail + ROW_GAP) / (ROW_H + ROW_GAP))), 1)
	if total <= cap:
		return total
	if float(cap) * (ROW_H + ROW_GAP) + QUEST_FOLD_H > avail:
		cap = maxi(cap - 1, 0)
	return cap


## 보상 아이템들을 "이름 ×n" 로(여러 개면 콤마). 없으면 빈 문자열.
func _reward_text(q: QuestDef) -> String:
	var parts: Array[String] = []
	for item_id: StringName in q.reward_items:
		var it := Db.get_item(item_id)
		var nm := it.display_name if it != null and it.display_name != "" else String(item_id)
		parts.append("%s ×%d" % [nm, int(q.reward_items[item_id])])
	return ", ".join(parts)


# ─────────────────────────── 탭3: 마법진 ───────────────────────────

## 🔴 **이 탭의 존재 이유 = 층 순서(안→밖)를 읽게 하는 것.** 층이 곧 연산 순서라 같은 재료로도
## `폭발(확산(불))` ≠ `확산(폭발(불))`인데, HUD 슬롯 다이어그램은 8칸 점 원 하나라 층을 못 보여 주고
## 책은 그리는 동안만 보인다. 그래서 예쁨보다 **"안쪽이 먼저"가 한눈에 읽히는가**가 먼저다.
##
## 🔴 **`rings`를 직접 뜯지 않는다** — 층 판별은 core 단일 소스(`layers_of`/`layer_summary`)가 쥔다
## (발사·요약·HUD 셋으로 갈라져 HUD가 조용히 거짓말한 전례가 있다). 문양 이름·색만 여기서 해석한다.
##
## 🔴 **넘침 = 잘림이 아니라 상한으로 막는다** — 층 줄 수를 캡해 행 높이에 상한을 두면 장착 3칸이
## 어떤 도안이든 들어간다. 스크롤을 안 넣은 이유는 퀘스트 탭과 같다(새 입력 경로 = 새 함정 자리).

# ── 레이아웃 (연출값 — 밸런스 아님) ──
const MAGIC_ROW_GAP := 10.0
const MAGIC_DIAG_COL := 104.0        ## 왼쪽 동심원 칸 폭 (텍스트는 이 오른쪽부터)
const MAGIC_DIAG_R_MAX := 32.0       ## 가장 바깥 층 반지름
const MAGIC_DIAG_R_MIN := 10.0       ## 가장 안쪽 층 반지름 하한 (층이 많아도 안 뭉개지게)
const MAGIC_DIAG_R_STEP := 8.0       ## 층 간격(층이 적을 때). 많아지면 MIN에 맞춰 좁아진다
const MAGIC_HEAD_H := 46.0           ## 수식 줄 + 진 이름 줄
const MAGIC_LINE_H := 15.0           ## 층 한 줄
const MAGIC_FOOT_H := 22.0           ## 위력·점수 줄
const MAGIC_EMPTY_ROW_H := 46.0      ## 빈 슬롯 행
## 🔴 층 줄 상한 — 이게 행 높이 상한을 만들어 슬롯 3행이 내용 높이에 반드시 들어간다.
## 넘는 층은 마지막 줄을 "… 외 N층"으로 접는다. ⚠ 올리려면 그 산식을 다시 재라.
const MAGIC_MAX_LAYER_LINES := 4
const MAGIC_STORE_ROW_H := 18.0
const MAGIC_STORE_HEAD_H := 20.0

# ── 색 (퀘스트 행·HUD 다이어그램과 같은 팔레트) ──
const MAGIC_ROW_BG := Color(0.17, 0.15, 0.12, 0.95)
const MAGIC_ROW_EDGE := Color(0.40, 0.37, 0.31, 0.7)
const MAGIC_FORMULA_COLOR := Color(0.96, 0.90, 0.78)
const MAGIC_RING_COLOR := Color(0.55, 0.48, 0.38, 0.60)
const MAGIC_OPEN_DOT := Color(0.62, 0.55, 0.44, 0.80)   # 열렸지만 빈 칸
const MAGIC_SHUT_DOT := Color(0.34, 0.30, 0.24, 0.55)   # 진이 닫은 칸
const MAGIC_POWER_COLOR := Color(0.90, 0.60, 0.25)
const MAGIC_INDEX_COLOR := Color(0.72, 0.64, 0.50)
## 고른 보관 행·「놓을 자리」 슬롯을 밝힌다.
const MAGIC_PICK_COLOR := Color(0.98, 0.84, 0.40)
const MAGIC_PICK_BG := Color(0.26, 0.22, 0.13, 0.95)
const MAGIC_TARGET_EDGE := Color(0.92, 0.78, 0.42, 0.85)
const MAGIC_HINT_W := 108.0          ## 슬롯 행 오른쪽 끝 조작 꼬리표 폭(위력 줄과 안 겹치게 빼 둔다)


func _draw_magic_tab(font: Font, _unused_origin: Vector2, content_top: float) -> void:
	var layout := magic_row_layout()
	var left: float = layout["left"]
	var width: float = layout["width"]
	var store_count: int = (layout["store_designs"] as Array).size()

	# 🔴 머리글은 **지금 상태에 맞는 다음 한 수**를 말한다 — 없는 조작을 적지 마라(뒤집으면
	# **있는 조작은 적어야 한다**).
	if _picked != null:
		draw_string(font, Vector2(left, content_top - 8.0),
			"「%s」 올릴 슬롯을 눌러라 — 슬롯 행 클릭 또는 1·2·3 (한 번 더 누르면 고르기 취소)"
				% spell_formula(_picked.layer_summary(), rune_seed(_design_runes(_picked))),
			HORIZONTAL_ALIGNMENT_LEFT, width, 12, MAGIC_PICK_COLOR)
	else:
		draw_string(font, Vector2(left, content_top - 8.0),
			"장착 마법진 — 안쪽 고리(층0)부터 바깥으로 걸린다 = 시전 순서",
			HORIZONTAL_ALIGNMENT_LEFT, width, 12, SECTION_COLOR)

	var slots: Array = layout["slots"]
	for i in slots.size():
		_draw_magic_row(font, slots[i], i, GameState.ring_equipped[i] as RingDesign, store_count)

	_draw_magic_storage(font, layout)


## 🔴🔴 **마법진 탭의 행 좌표 단일 소스** — 그리기와 클릭이 같은 함수를 본다.
## 반환: `slots`(장착 행 · 높이는 도안마다 다르다) · `store`(**실제로 그리는** 보관 행) ·
##       `store_designs`(보관 도안 전체 — 앞에서부터 `store`와 1:1).
## 🔴 접힌 행엔 rect를 만들지 마라 — 안 그린 행을 남기면 **화면 밖 도안이 클릭으로 장착된다.**
func magic_row_layout() -> Dictionary:
	var origin := _origin()
	var left := origin.x + PAD
	var width := PANEL_SIZE.x - PAD * 2.0
	var bottom := origin.y + PANEL_SIZE.y - PAD
	var y := origin.y + CONTENT_TOP

	var slots: Array[Rect2] = []
	for i in GameState.ring_equipped.size():
		var h := _magic_slot_row_height(GameState.ring_equipped[i] as RingDesign)
		slots.append(Rect2(Vector2(left, y), Vector2(width, h)))
		y += h + MAGIC_ROW_GAP

	var rest := _unequipped_designs()
	var store: Array[Rect2] = []
	var store_top := y
	if not rest.is_empty():
		var cap := int(floor((bottom - store_top - MAGIC_STORE_HEAD_H) / MAGIC_STORE_ROW_H))
		if cap > 0:
			var shown := rest.size() if rest.size() <= cap else maxi(cap - 1, 0)
			var sy := store_top + MAGIC_STORE_HEAD_H
			for i in shown:
				store.append(Rect2(Vector2(left + 8.0, sy), Vector2(width - 16.0, MAGIC_STORE_ROW_H)))
				sy += MAGIC_STORE_ROW_H
	return {"left": left, "width": width, "bottom": bottom, "store_top": store_top,
		"slots": slots, "store": store, "store_designs": rest}


## 슬롯 행 높이 — 찬 슬롯은 층 줄 수만큼 자란다. 레이아웃과 그리기가 같은 값을 쓰도록 여기서만 센다.
func _magic_slot_row_height(design: RingDesign) -> float:
	if design == null:
		return MAGIC_EMPTY_ROW_H
	return _magic_row_height(layer_lines(design.layer_summary(), MAGIC_MAX_LAYER_LINES).size())


## 🔴 좌표 → 어느 행인가 (순수 판정 — **헤드리스 관측점이다**).
## 반환 `{"kind": &"slot"/&"store"/&"none", "index": int}` — `none`이면 index=-1.
func magic_hit_test(point: Vector2) -> Dictionary:
	return _magic_hit_in(magic_row_layout(), point)


## 판정 본체 — 뽑아 둔 레이아웃을 재사용한다(클릭 한 번에 레이아웃을 두 번 안 센다).
func _magic_hit_in(layout: Dictionary, point: Vector2) -> Dictionary:
	var slots: Array = layout["slots"]
	for i in slots.size():
		if (slots[i] as Rect2).has_point(point):
			return {"kind": &"slot", "index": i}
	var store: Array = layout["store"]
	for i in store.size():
		if (store[i] as Rect2).has_point(point):
			return {"kind": &"store", "index": i}
	return {"kind": &"none", "index": -1}


## 마법진 탭 좌클릭 — **고르기 → 지정** 2단계. 처리했으면 true(호출부가 accept_event).
## ⚠ 손짓은 소지품 탭과 같게 맞춘다(보관 행 = 고르기/취소 · 슬롯 행 = 올리기 또는 해제).
func magic_click(point: Vector2) -> bool:
	var layout := magic_row_layout()
	var hit := _magic_hit_in(layout, point)
	var kind := StringName(hit["kind"])
	var idx := int(hit["index"])
	if kind == &"store":
		var rest: Array = layout["store_designs"]
		if idx < rest.size():
			var d: RingDesign = rest[idx]
			_picked = null if _picked == d else d
			queue_redraw()
		return true
	if kind == &"slot":
		magic_assign(idx)
		return true
	return false


## 🔴 슬롯 지정 — 클릭과 1·2·3 키가 **같은 여기로 들어온다**.
## 🔴🔴 `GameState.ring_equipped`에 **직접 대입하지 마라** — `equip_design()`이 중복 장착 정리와
## `equipment_changed`(= 자동 저장 트리거)를 쥔다. 배열을 직접 만지면 **바꾼 슬롯이 저장 없이
## 사라진다**(에러 없이).
func magic_assign(slot: int) -> void:
	if slot < 0 or slot >= GameState.ring_equipped.size():
		return
	if _picked != null:
		GameState.equip_design(slot, _picked)   # equipment_changed → _on_changed → queue_redraw
		_picked = null
	elif GameState.ring_equipped[slot] != null:
		GameState.equip_design(slot, null)      # 고른 게 없는 슬롯 클릭 = 해제(보관으로 돌아간다)
	queue_redraw()


## 슬롯 한 행 — 왼쪽 동심원 + 오른쪽(수식·진·층 목록·위력). rect는 `magic_row_layout`이 준다.
## 🔴 `store_count`를 받는 이유 = **빈 슬롯 안내문을 참으로 유지하려고.** 보관이 0장이면
## 「아래 보관에서 골라라」가 거짓말이 된다(가리킬 목록이 화면에 없다).
func _draw_magic_row(font: Font, rect: Rect2, idx: int, design: RingDesign, store_count: int) -> void:
	var at := rect.position
	var width := rect.size.x
	var h := rect.size.y
	# 고른 도안이 있으면 모든 슬롯이 「놓을 자리」다 — 테두리를 밝혀 그걸 보인다.
	var aiming := _picked != null
	draw_rect(rect, MAGIC_ROW_BG, true)
	draw_rect(rect, MAGIC_TARGET_EDGE if aiming else MAGIC_ROW_EDGE, false, 2.0 if aiming else 1.0)

	if design == null:
		# 🔴 이 문구는 **참이어야 한다** — 보관이 비면 그 길이 지금은 없으므로 책상 쪽만 적는다.
		var empty_text := "슬롯 %d — 비어 있음 (책상 [E]에서 그리면 여기 들어온다)" % (idx + 1)
		if store_count > 0:
			empty_text = "슬롯 %d — 비어 있음 (아래 보관에서 고른 뒤 이 줄 클릭 또는 [%d] · 책상 [E]로 새로 그려도 들어온다)" \
				% [idx + 1, idx + 1]
		draw_string(font, Vector2(at.x + 14.0, at.y + 28.0), empty_text,
			HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 12, EMPTY_COLOR)
		return

	var summary := design.layer_summary()
	var lines := layer_lines(summary, MAGIC_MAX_LAYER_LINES)
	_draw_rune_band(at, h, design)   # 룬 색 띠 (융합진이면 룬마다 한 토막)

	draw_string(font, Vector2(at.x + 14.0, at.y + 15.0), "슬롯 %d" % (idx + 1),
		HORIZONTAL_ALIGNMENT_LEFT, MAGIC_DIAG_COL - 20.0, 11, MAGIC_INDEX_COLOR)
	_draw_magic_diagram(Vector2(at.x + MAGIC_DIAG_COL * 0.5, at.y + h * 0.5 + 8.0), design)

	var tx := at.x + MAGIC_DIAG_COL
	var tw := width - MAGIC_DIAG_COL - 16.0
	draw_string(font, Vector2(tx, at.y + 24.0),
		spell_formula(summary, rune_seed(_design_runes(design))),
		HORIZONTAL_ALIGNMENT_LEFT, tw, 15, MAGIC_FORMULA_COLOR)
	draw_string(font, Vector2(tx, at.y + 41.0), _jin_text(design, summary.size()),
		HORIZONTAL_ALIGNMENT_LEFT, tw, 11, KIND_COLOR)

	var ly := at.y + MAGIC_HEAD_H + 13.0
	for i in lines.size():
		draw_string(font, Vector2(tx + 6.0, ly), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, tw - 6.0, 11, _magic_line_color(summary, i))
		ly += MAGIC_LINE_H

	# 🔴 변형형(확산·폭발)이 끼면 이 숫자는 **갈래당**이다 — 그냥 "위력 N"이라 적으면 리포트가
	# 거짓말하는 걸로 읽힌다.
	var unit := "갈래당 위력" if has_modifier(summary, Db.modifier_codes()) else "위력"
	draw_string(font, Vector2(tx, at.y + h - 8.0),
		"%s %d · %d점 · %s" % [unit,
			RingPower.power_display(design.total_score, Db.ink_mult(design.ink), design.size),
			RingPower.score_display(design.total_score),
			RingPower.grade_of(design.total_score)],
		HORIZONTAL_ALIGNMENT_LEFT, tw - MAGIC_HINT_W, 12, MAGIC_POWER_COLOR)
	# 조작 꼬리표 — **지금 이 행을 누르면 무슨 일이 나는지**를 그 자리에 적는다.
	draw_string(font, Vector2(at.x + width - 16.0 - MAGIC_HINT_W, at.y + h - 8.0),
		"[%d] 여기 장착" % (idx + 1) if aiming else "클릭 = 해제",
		HORIZONTAL_ALIGNMENT_RIGHT, MAGIC_HINT_W, 11,
		MAGIC_PICK_COLOR if aiming else HINT_COLOR)


## 층 겹 다이어그램 — 고리 하나 = 층 하나, **안쪽이 층0**. 칸 점은 그 층 문양 색, 열렸지만 빈 칸은
## 흐리게, 진이 닫은 칸은 더 흐리게. 중심 = 룬 색 씨앗(융합진이면 둘).
## 🔴 칸 각도(`jin_slot_dots`)·룬 자리(`rune_slot_positions`)·층 배열(`layers_of`)을 **그대로 부른다** —
## 식을 베끼면 판·책 셀·HUD 슬롯 다이어그램이 조용히 어긋난다.
func _draw_magic_diagram(center: Vector2, design: RingDesign) -> void:
	var layers := RingDesign.layers_of(design.rings)
	var n := maxi(layers.size(), 1)
	for i in n:
		var r := _magic_ring_radius(i, n)
		draw_arc(center, r, 0.0, TAU, 28, MAGIC_RING_COLOR, 1.0)
		var layer: Array = []
		if i < layers.size():
			layer = layers[i]
		var dots: Array = RingBoard.jin_slot_dots(design.open, center, r)
		for k in dots.size():
			var d: Dictionary = dots[k]
			var pos: Vector2 = d["pos"]
			var code := int(layer[k]) if k < layer.size() else -1
			if code != -1:
				draw_circle(pos, 3.0, _glyph_color(code))
			elif bool(d["open"]):
				draw_circle(pos, 1.8, MAGIC_OPEN_DOT)
			else:
				draw_circle(pos, 1.4, MAGIC_SHUT_DOT)
	# 반경 기준은 **가장 안쪽 고리**(층0)다 — 룬은 모든 층 안쪽에 앉아야 읽힌다.
	var cols := _rune_colors(design)
	var seeds := RingBoard.rune_slot_positions(cols.size(), center, _magic_ring_radius(0, n))
	var seed_r := 4.0 if cols.size() <= 1 else 4.0 * RingBoard.RUNE_MULTI_SIZE_FRAC
	for i in seeds.size():
		draw_circle(seeds[i], seed_r, cols[i])


## 층 i의 고리 반지름 — 바깥(마지막 층)이 R_MAX. 층이 많으면 간격이 좁아져 R_MIN 안으로 안 파고든다.
func _magic_ring_radius(i: int, n: int) -> float:
	if n <= 1:
		return MAGIC_DIAG_R_MAX
	var step := minf(MAGIC_DIAG_R_STEP,
		(MAGIC_DIAG_R_MAX - MAGIC_DIAG_R_MIN) / float(n - 1))
	return MAGIC_DIAG_R_MAX - float(n - 1 - i) * step


func _magic_row_height(line_count: int) -> float:
	return MAGIC_HEAD_H + float(maxi(line_count, 1)) * MAGIC_LINE_H + MAGIC_FOOT_H


## 층 줄 색 = 그 층 첫 문양의 색(층을 색으로도 구분). 빈 층·접힌 줄은 흐린 설명색.
func _magic_line_color(summary: Array, i: int) -> Color:
	if i >= summary.size():
		return HINT_COLOR
	var entries: Array = summary[i]
	if entries.is_empty():
		return HINT_COLOR
	return _glyph_color(int((entries[0] as Dictionary)["code"]))


## "진: 단발진 2등급 · 2층". 진이 없거나(옛 도안) Db에 없으면 이름을 흐리게 대체한다.
func _jin_text(design: RingDesign, layer_count: int) -> String:
	var jin := Db.get_jin(design.jin)
	var nm := jin.display_name if jin != null and jin.display_name != "" else "진 없음 (옛 도안)"
	return "진: %s · %d층" % [nm, maxi(layer_count, 1)]


## 🔴 도안의 룬 목록 — **반드시 `RingDesign.runes_of`를 거친다.** `design.rune`(첫 룬)만 읽으면
## **융합진의 두 번째 룬이 화면에서 통째로 사라져** 발사부는 두 룬을 쏘는데 수식·색 띠·다이어그램은
## 하나만 보여 준다(쏘는 것 ≠ 보이는 것).
func _design_runes(design: RingDesign) -> Array:
	return RingDesign.runes_of(design.runes, design.rune)


## 룬 자리별 색 — 자리 수만큼. 폴백이 있어 룬이 안 실린 옛 도안도 뭔가 보인다.
func _rune_colors(design: RingDesign) -> Array[Color]:
	var out: Array[Color] = []
	for rt in _design_runes(design):
		var r := Db.get_rune(int(rt))
		out.append(r.ui_color if r != null else Color(0.62, 0.22, 0.12))
	return out


## 행 왼쪽 룬 색 띠 — 🔴 융합진이면 룬마다 한 토막씩 나눈다(색 하나만 칠하면 둘째 룬이 여기서도 사라진다).
func _draw_rune_band(at: Vector2, h: float, design: RingDesign) -> void:
	var cols := _rune_colors(design)
	var n := maxi(cols.size(), 1)
	var seg := h / float(n)
	for i in n:
		draw_rect(Rect2(Vector2(at.x, at.y + float(i) * seg), Vector2(4.0, seg)), cols[i], true)


## 문양 코드 → 색. 🔴 정본은 `data/glyphs/*.tres`의 `ui_color` **하나뿐**이다 — 사본을 만들면
## "책이랑 판이랑 색이 다르네"가 어디서 오는지 못 찾는다.
func _glyph_color(code: int) -> Color:
	var gd := Db.glyph_by_code(code)
	return gd.ui_color if gd != null else RingBoard.RING_LINE


## 미장착 보관 도안 — 남는 높이에 들어가는 만큼만(못 담으면 "… 외 N장").
## 🔴 잘려서 반쯤 그려지는 게 제일 나쁘다 — `magic_row_layout`이 **먼저 수용량을 세고** 들어가는
## 행에만 rect를 만든다. 여긴 그리기만 한다.
## 🔴 **머리글은 지금 실제로 있는 조작만 적는다.**
func _draw_magic_storage(font: Font, layout: Dictionary) -> void:
	var rest: Array = layout["store_designs"]
	if rest.is_empty():
		return
	var rects: Array = layout["store"]
	var left: float = layout["left"]
	var width: float = layout["width"]
	draw_string(font, Vector2(left, float(layout["store_top"]) + 12.0),
		"보관 (미장착 — 행을 눌러 고른 뒤 위 슬롯을 누르거나 1·2·3)",
		HORIZONTAL_ALIGNMENT_LEFT, width, 12, SECTION_COLOR)
	var y := float(layout["store_top"]) + MAGIC_STORE_HEAD_H
	for i in rects.size():
		var d: RingDesign = rest[i]
		var s := d.layer_summary()
		var row: Rect2 = rects[i]
		# 배경·테두리·머리 기호를 다 바꾼다 — **무엇이 골라졌는지 안 보이면 조작이 아니다.**
		var chosen := _picked == d
		if chosen:
			draw_rect(row, MAGIC_PICK_BG, true)
			draw_rect(row, MAGIC_TARGET_EDGE, false, 1.0)
		draw_string(font, Vector2(left + 8.0, y + 12.0),
			"%s %s   %s %d · %d점" % ["▶" if chosen else "·",
				spell_formula(s, rune_seed(_design_runes(d))),
				"갈래당" if has_modifier(s, Db.modifier_codes()) else "위력",
				RingPower.power_display(d.total_score, Db.ink_mult(d.ink), d.size),
				RingPower.score_display(d.total_score)],
			HORIZONTAL_ALIGNMENT_LEFT, width - 16.0, 11,
			MAGIC_PICK_COLOR if chosen else HINT_COLOR)
		y += MAGIC_STORE_ROW_H
	if rects.size() < rest.size():
		draw_string(font, Vector2(left + 8.0, y + 12.0),
			"… 외 %d장" % (rest.size() - rects.size()),
			HORIZONTAL_ALIGNMENT_LEFT, width - 16.0, 11, EMPTY_COLOR)


## 보관 전체에서 장착 중인 것을 뺀다 — 같은 **인스턴스**가 슬롯에 꽂혀 있다.
func _unequipped_designs() -> Array[RingDesign]:
	var out: Array[RingDesign] = []
	for d: RingDesign in GameState.ring_designs:
		if d != null and not GameState.ring_equipped.has(d):
			out.append(d)
	return out


# ── 순수 함수 (헤드리스가 잴 수 있는 자리 — 렌더는 못 재도 이건 잰다) ──

## 🔴 **수식 문자열** — 안쪽 층부터 바깥으로 감싼다. 씨앗 = 룬 이름.
##   `[[확산×3], [폭발×1]]`, "불"  →  `폭발(확산(불))` · 순서를 뒤집으면 `확산(폭발(불))`
## 규칙: 빈 층은 건너뛴다(감싸는 게 없으니 괄호도 안 는다) · 한 층에 여러 종류면 `+`로 잇는다 ·
##   개수는 안 싣는다(층 목록의 일) · 문양이 없으면 룬 이름만 남는다.
## 🔴 이름에서 꼬리 기호(⋔·∗)를 뗀다 — `폭발∗(확산⋔(불))`이면 읽는 게 목적인 줄이 못 읽힌다.
static func spell_formula(summary: Array, rune_name: String) -> String:
	var out := rune_name
	for entries_v in summary:
		var entries: Array = entries_v
		if entries.is_empty():
			continue
		var parts: Array[String] = []
		for e: Dictionary in entries:
			parts.append(glyph_word(int(e["code"])))
		out = "%s(%s)" % ["+".join(parts), out]
	return out


## 층별 목록 줄 — `├ 층0(안) 확산 ×3` / `└ 층1(밖) 폭발 ×1`. 넘치면 "… 외 N층"으로 접는다.
## ⚠ 층이 하나면 (안)·(밖)을 안 붙인다 — 감쌈이 없는데 방향을 말하면 거짓 신호다.
static func layer_lines(summary: Array, max_lines: int) -> Array[String]:
	var out: Array[String] = []
	var n := summary.size()
	if n == 0:
		out.append("문양이 없다 — 룬만 나간다")
		return out
	var folded := n > max_lines
	var draw_n := (max_lines - 1) if folded else n
	for i in draw_n:
		var last := (not folded) and i == n - 1
		var tag := ""
		if n > 1:
			tag = "(안)" if i == 0 else ("(밖)" if i == n - 1 else "")
		out.append("%s 층%d%s %s" % ["└" if last else "├", i, tag, _entries_text(summary[i])])
	if folded:
		out.append("└ … 외 %d층" % (n - draw_n))
	return out


## 한 층의 내용 — "확산 ×3" (여러 종류면 콤마). 빈 층도 자리를 지킨다.
static func _entries_text(entries_v: Variant) -> String:
	var entries: Array = entries_v
	if entries.is_empty():
		return "비어 있음"
	var parts: Array[String] = []
	for e: Dictionary in entries:
		parts.append("%s ×%d" % [glyph_word(int(e["code"])), int(e["count"])])
	return ", ".join(parts)


## 변형형(확산·폭발)이 어느 층에든 있나 — 위력 표기를 "갈래당"으로 가른다.
## 🔴 **계열 코드 목록을 인자로 받는다** — static이라 오토로드를 못 보고, 계열의 단일 소스는
## 문양 데이터다. 판정식을 여기 베끼지 마라.
static func has_modifier(summary: Array, modifier_codes: Array) -> bool:
	if modifier_codes.is_empty():
		return false
	for entries_v in summary:
		var entries: Array = entries_v
		for e: Dictionary in entries:
			if int(e["code"]) in modifier_codes:
				return true
	return false


## 수식의 씨앗 문자열 — 룬 자리 목록을 `물+번개`로 잇는다(융합진). `+` 규약은 `spell_formula`의
## 한 층 여러 문양 표기를 재사용한 것이다. 빈 목록의 "룬" 폴백은 방어일 뿐이다.
static func rune_seed(runes: Array) -> String:
	var parts: Array[String] = []
	for r in runes:
		parts.append(rune_word(int(r)))
	return "+".join(parts) if not parts.is_empty() else "룬"


## 룬 종류 → 수식에 쓰는 **말**. Db에 없는 값은 "룬"(옛 도안·데이터 결손도 뭔가 읽히게).
static func rune_word(rune_type: int) -> String:
	var r := Db.get_rune(rune_type)
	return r.display_name if r != null and r.display_name != "" else "룬"


## 문양 코드 → 수식·목록에 쓰는 **말**(꼬리 기호 뗀 이름). 어휘 밖 코드는 "?".
static func glyph_word(code: int) -> String:
	var gd := Db.glyph_by_code(code)
	if gd == null:
		return "?"
	return _strip_symbol(String(gd.display_name))


## 꼬리의 비-한글 문자를 떼어 낸다("확산⋔"→"확산"). ⚠ 이름 길이를 가정하지 않는다 — 3자 문양도 산다.
static func _strip_symbol(s: String) -> String:
	var n := s.length()
	while n > 0:
		var c := s.unicode_at(n - 1)
		if c >= 0xAC00 and c <= 0xD7A3:   # 한글 음절
			break
		n -= 1
	return s.substr(0, n) if n > 0 else s


# ─────────────────────────── 탭4: 캐릭터 ───────────────────────────

## 읽기 전용 — 생명력·파생 스탯·착용 요약. 착용/해제는 소지품 탭이 한다.
## 🔴 스탯은 전부 **GameState getter**로 읽는다 — balance나 core를 직접 읽으면 장비 보정이 빠져
## 조용히 어긋난다.
const CHAR_VALUE_X := 200.0     # 라벨 왼쪽 정렬, 값은 여기서 시작
const CHAR_ROW_H := 26.0
const CHAR_SECTION_GAP := 20.0

func _draw_character_tab(font: Font, origin: Vector2, content_top: float) -> void:
	var left := origin.x + PAD
	var y := content_top

	# ── 생명력 ──
	draw_string(font, Vector2(left, y), "생명력",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SECTION_COLOR)
	y += CHAR_ROW_H
	y = _draw_stat(font, left, y, "HP",
		"%d / %d" % [ceili(GameState.hp), roundi(GameState.hp_max())])
	y = _draw_stat(font, left, y, "마나",
		"%d / %d" % [floori(GameState.mana), roundi(GameState.mana_max())])

	# ── 능력치 (파생 스탯) ──
	y += CHAR_SECTION_GAP
	draw_string(font, Vector2(left, y), "능력치",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SECTION_COLOR)
	y += CHAR_ROW_H
	y = _draw_stat(font, left, y, "이동 속도", "%d" % roundi(GameState.move_speed()))
	y = _draw_stat(font, left, y, "구르기 쿨", "%.2f초" % GameState.roll_cooldown())
	var corr := GameState.stroke_correction()
	y = _draw_stat(font, left, y, "손그림 보정",
		"+%.2f (펜)" % corr if corr > 0.0 else "없음 (맨손 — 그린 대로)")
	# 🔴 지팡이는 발사 **형태**를 안 정한다(그건 진의 몫) — 실효 스칼라 둘만 적는다.
	y = _draw_stat(font, left, y, "진 속도", "%d%%" % roundi(GameState.wand_speed_mult() * 100.0))
	y = _draw_stat(font, left, y, "발사 마나", "%.1f" % GameState.cast_mana_cost())

	# ── 착용 요약 (읽기 전용 — 착용/해제는 [소지품] 탭) ──
	y += CHAR_SECTION_GAP
	draw_string(font, Vector2(left, y), "착용 (착용·해제는 소지품 탭에서)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SECTION_COLOR)
	y += CHAR_ROW_H
	for pair: Array in EQUIP_KINDS:
		var kind: int = pair[0]
		var kind_label: String = pair[1]
		var val := "비어 있음"
		var col := SLOT_EMPTY_COLOR
		if GameState.equipment.has(kind):
			val = _item_name(GameState.equipment[kind])
			var eff := ItemText.effect_text(Db.get_item(GameState.equipment[kind]))
			if eff != "":
				val += "  ·  " + eff
			col = NAME_COLOR
		draw_string(font, Vector2(left, y), kind_label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, KIND_COLOR)
		draw_string(font, Vector2(left + CHAR_VALUE_X, y), val,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		y += CHAR_ROW_H


## 스탯 한 줄 — 라벨(왼쪽) + 값(CHAR_VALUE_X). 다음 줄 y를 돌려준다.
func _draw_stat(font: Font, left: float, y: float, label: String, value: String) -> float:
	draw_string(font, Vector2(left, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, KIND_COLOR)
	draw_string(font, Vector2(left + CHAR_VALUE_X, y), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NAME_COLOR)
	return y + CHAR_ROW_H


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


## 🔴 장비 효과 문구는 **여기 없다** — `ItemText`(core)가 단일 소스다.
## `workshop_panel`이 같은 함수를 부르므로 문구를 고치면 두 패널이 같이 따라온다.
