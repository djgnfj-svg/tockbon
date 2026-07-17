extends Control
## 창고(영구) + 가방(출격 중) 열람 모달 — **베이스캠프와 숲이 같이 쓴다** (백로그 E2, 세션 27).
##
## 🔴 왜 필요했나: 세션 27에 드롭이 붙어 잡기→가방→귀환하면 창고에 쌓이는데, **볼 데가 없었다**.
## `GameState.get_inventory_snapshot()`을 아무도 안 불러 "숫자만 는다"였다. 여기가 그 창이다.
##
## 🔴 **HUD처럼 `_draw`가 매번 GameState를 직접 읽는다** — 캐시하지 않는다. 그래서 갱신은
## `resources_changed`에 `queue_redraw()` 하나로 끝나고, 드롭·회수와의 순서를 따질 필요가 없다.
##
## 🔴 **모달이다** — 열리면 `GameState.ui_modal_open`을 켠다. player(이동)·caster(조준·발사)가
## 이걸 폴링해 멎는다 (그 필드는 이 용도로 game_state.gd에 이미 선언돼 있었다 — 세션 27에 처음 쓴다).
## 열린 동안 이 Control은 mouse_filter=STOP이라 좌클릭을 통째로 먹는다 → 창고를 보며 실수로
## 안 쏜다. 닫히면 visible=false라 GUI 히트테스트에서 빠져 클릭이 다시 바닥으로 샌다.
##
## 🔴 **CanvasLayer 위에 산다** (inventory_panel.tscn) — 카메라가 플레이어를 따라다녀서
## 월드에 그리면 패널이 같이 흘러간다 (HUD와 같은 이유). 책(forge, layer 10)보다 아래(layer 5)라,
## 책이 펴진 동안에는 `ui_modal_open` 게이트가 여는 것을 막는다 (두 모달이 겹치지 않게).

# ── 레이아웃 (연출값 — 밸런스 아님. 선례: hud.gd의 SLOT_SIZE 등) ──
## 🔴 카테고리 라벨을 **왼쪽 칸(GUTTER)**에 두고 카드를 오른쪽에 붙인다(덕코프식). 제목 줄을
## 따로 안 먹어 세로가 압축된다 — 카테고리가 7종이라 위로 쌓으면 패널을 넘긴다(세션28에 실측).
const PANEL_SIZE := Vector2(768.0, 500.0)
const PAD := 22.0
const GUTTER := 84.0
const CARD_SIZE := Vector2(150.0, 40.0)
const CARD_GAP := 7.0
const SECTION_GAP := 14.0

# ── 색 ──
const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const PANEL_BG := Color(0.12, 0.10, 0.08, 0.98)
const PANEL_EDGE := Color(0.48, 0.43, 0.34, 0.9)
const TITLE_COLOR := Color(0.96, 0.90, 0.78)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const SECTION_COLOR := Color(0.86, 0.80, 0.66)
const BAG_SECTION_COLOR := Color(0.92, 0.78, 0.42)
const CARD_BG := Color(0.17, 0.15, 0.12, 0.95)
const CARD_EDGE := Color(0.40, 0.37, 0.31, 0.7)
const NAME_COLOR := Color(0.93, 0.89, 0.80)
const KIND_COLOR := Color(0.64, 0.60, 0.52)
const COUNT_COLOR := Color(0.98, 0.86, 0.52)
const EMPTY_COLOR := Color(0.60, 0.56, 0.50)

## 등급 색 — 흔함→전설 (Db.get_item.grade). 없는 등급은 양끝으로 clamp.
const GRADE_COLORS: Array[Color] = [
	Color(0.72, 0.70, 0.66),  # 1 흔함 (회백)
	Color(0.55, 0.80, 0.50),  # 2 (녹)
	Color(0.42, 0.66, 0.95),  # 3 (청)
	Color(0.74, 0.52, 0.95),  # 4 (자)
	Color(0.98, 0.70, 0.32),  # 5 전설 (금)
]

## 🔴 창고를 나누는 카테고리 순서·라벨 (세션28) — `ItemDef.category()`가 돌려주는 키다.
## 완성품 먼저(장비·잉크·종이·조각) → 재료(잉크·종이·장비재료) → 소모(밥·물) → 기타.
## 밥·물은 아이템이 아직 없어 탭이 비지만, 생기면 저절로 뜬다 (분류는 .tres params.cat).
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
const SUB_GAP := 6.0

var _open: bool = false


func _ready() -> void:
	# 닫힌 동안엔 클릭을 먹지 않는다 (visible=false면 GUI 히트테스트에서 빠진다).
	# 열리면 STOP이라 좌클릭을 통째로 먹어 창고를 보며 실수로 안 쏜다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.resources_changed.connect(_on_resources_changed)


## 🔴 토글은 `_unhandled_input`에서 잡는다 — I키·ESC 둘 다 caster의 발사(좌클릭)·슬롯(1~4)과
## 겹치지 않는다. 닫힌 Control도 `_unhandled_input`은 받는다 (mouse_filter는 마우스만 가른다).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if key.keycode == KEY_I:
		_toggle()
		get_viewport().set_input_as_handled()
	elif _open and key.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _open:
		_set_open(false)
	elif not GameState.ui_modal_open:
		# 책(forge)이 펴진 동안엔 열지 않는다 — 두 모달이 겹치면 닫는 순서가 꼬인다.
		_set_open(true)


func _set_open(open: bool) -> void:
	_open = open
	visible = open
	GameState.ui_modal_open = open
	queue_redraw()


func _on_resources_changed() -> void:
	if _open:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)

	var origin := ((size - PANEL_SIZE) * 0.5).round()
	draw_rect(Rect2(origin, PANEL_SIZE), PANEL_BG, true)
	draw_rect(Rect2(origin, PANEL_SIZE), PANEL_EDGE, false, 2.0)

	draw_string(font, origin + Vector2(PAD, 30.0), "창고",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TITLE_COLOR)
	draw_string(font, origin + Vector2(PANEL_SIZE.x - PAD - 150.0, 30.0), "[I] / ESC  닫기",
		HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 12, HINT_COLOR)

	var y := origin.y + 52.0
	var left := origin.x + PAD

	# ── 창고 (영구) — 카테고리별로 나눠 그린다 ──
	var groups := _grouped(GameState.get_inventory_snapshot())
	if groups.is_empty():
		draw_string(font, Vector2(left, y + 12.0),
			"창고가 비었다 — 숲에서 적을 잡아 [E]로 귀환하면 여기 쌓인다",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, EMPTY_COLOR)
		y += 28.0
	else:
		for pair: Array in CATEGORY_ORDER:
			var cat: StringName = pair[0]
			if groups.has(cat):
				y = _draw_section(font, pair[1], SECTION_COLOR, left, y, groups[cat])
				y += SUB_GAP

	# ── 가방 (출격 중 — 있을 때만) ──
	var bag := _sorted_entries(_bag_counts())
	if not bag.is_empty():
		y += SECTION_GAP
		_draw_section(font, "가방 (들고 있는 것 · 죽으면 사라진다)", BAG_SECTION_COLOR, left, y, bag, true)


## 한 구역 = 라벨 + 카드 격자. 다음 y를 돌려준다.
## label_above=false(기본): 라벨을 왼쪽 좁은 칸(GUTTER)에, 카드를 오른쪽에 (카테고리 — 세로 압축).
## label_above=true: 라벨을 카드 위 전체폭에 (가방 — 경고문이 길어 좁은 칸에 안 들어간다).
func _draw_section(font: Font, title: String, title_color: Color,
		left: float, top: float, entries: Array, label_above: bool = false) -> float:
	var avail := PANEL_SIZE.x - PAD * 2.0 - (0.0 if label_above else GUTTER)
	var cols := maxi(int((avail + CARD_GAP) / (CARD_SIZE.x + CARD_GAP)), 1)
	var rows := int(ceil(float(entries.size()) / float(cols))) if not entries.is_empty() else 0
	var block_h := float(rows) * (CARD_SIZE.y + CARD_GAP)
	var cards_top := top
	var cards_left := left
	if label_above:
		draw_string(font, Vector2(left, top + 14.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, title_color)
		cards_top = top + 22.0
	else:
		# 라벨은 카드 블록 세로 중앙에 앉는다 (1줄 폰트 보정 +4).
		draw_string(font, Vector2(left, top + block_h * 0.5 + 4.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 8.0, 13, title_color)
		cards_left = left + GUTTER
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var col := i % cols
		var row := i / cols
		var at := Vector2(cards_left + float(col) * (CARD_SIZE.x + CARD_GAP),
			cards_top + float(row) * (CARD_SIZE.y + CARD_GAP))
		_draw_card(font, at, entry["id"], int(entry["count"]))
	return cards_top + block_h


## 카드 한 장 — 등급 색 띠 + 이름 + 종류 + 수량. 알 수 없는 id는 그래도 그린다(정본이 GameState라).
func _draw_card(font: Font, at: Vector2, id: StringName, count: int) -> void:
	var item := Db.get_item(id)
	var rect := Rect2(at, CARD_SIZE)
	draw_rect(rect, CARD_BG, true)
	draw_rect(rect, CARD_EDGE, false, 1.0)

	var grade := item.grade if item != null else 1
	var chip := GRADE_COLORS[clampi(grade - 1, 0, GRADE_COLORS.size() - 1)]
	draw_rect(Rect2(at, Vector2(4.0, CARD_SIZE.y)), chip, true)

	var name_text := item.display_name if item != null and item.display_name != "" else str(id)
	draw_string(font, at + Vector2(11.0, 17.0), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 16.0, 12, NAME_COLOR)

	# 카테고리는 왼쪽 라벨이 말하므로 카드엔 등급만 (★grade). 이름이 종류를 말해 준다.
	draw_string(font, at + Vector2(11.0, 33.0), "★%d" % grade,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, KIND_COLOR)

	draw_string(font, at + Vector2(CARD_SIZE.x - 42.0, 33.0), "×%d" % count,
		HORIZONTAL_ALIGNMENT_RIGHT, 38.0, 13, COUNT_COLOR)


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


## 가방 엔트리는 [{id, count}] 여러 개로 쌓인다 (킬마다 append) — id로 합쳐서 보여 준다.
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
