extends Control
## 공방 — 재료를 **조립 부품·장비**로 만들고(제작), 만든 장비를 **착용/해제**한다
## (세션32 장비 제작 · 세88에 조립 부품 제작이 붙었다).
## 베이스 공방 지점 [E]로 연다. 정제대(잉크·종이)와 형제지만 다루는 물건이 달라 별도 벤치다.
##
## 🔴 **레시피가 두 종류다** (세88 사냥 흐름 §4 — 이게 그 설계의 본줄이다):
##   ⓐ **장비** = `output_id`가 있어 창고에 아이템이 들어온다 (옛 9장)
##   ⓑ **조립 부품**(고리·진·룬) = `output_id`가 **비었고** `reward_unlock`으로 **codex를 해금**한다.
##      고리·룬·진은 `ItemDef`가 아니라 codex 키라 창고에 넣을 물건이 아니다.
## 사냥의 종착지가 「새로 조립할 것」이라 부품 구역을 위에 둔다.
##
## 🔴 왜 별도인가: 사용자 확정("별도 공방 스테이션"). 정제대는 소모품(잉크·종이), 공방은 장비.
## 레시피는 `station`으로 갈린다 — 공방은 &"craft"만, 정제대는 &"refine"만 (Db.recipes_for_station).
##
## 🔴 왜 장착을 여기 두나: 창고(I) 패널은 `_draw` 전용이라 버튼을 못 단다. 장비를 손에 넣는 곳과
## 몸에 맞추는 곳을 한 벤치로 묶는다(몬헌식). `equip_gear`/`unequip_gear`가 이미 창고 차감·반환·
## 상한 클램프까지 쥐고 있어(GameState) — 이 패널은 나열·버튼뿐이다.
##
## 🔴 **모달** — refine_panel과 같은 규약: 열리면 GameState.ui_modal_open을 켜 발사·이동·창고와
## 겹치지 않게 하고, mouse_filter=STOP으로 좌클릭을 통째로 먹는다. ESC로 닫고 closed를 쏜다.
## CanvasLayer(base.gd가 씌운다) 위에 산다 — 카메라 추적 무관.
##
## 계약: open() / closed 시그널. base.gd가 InteractZone(zone_id=craft)에서 연다.

signal closed

const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const NAME_COLOR := Color(0.94, 0.90, 0.80)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const HAVE_COLOR := Color(0.62, 0.80, 0.52)
const SHORT_COLOR := Color(0.86, 0.46, 0.40)
const SECTION_COLOR := Color(0.86, 0.80, 0.66)
const EQUIPPED_COLOR := Color(0.98, 0.86, 0.52)
const ROW_BG := Color(0.17, 0.15, 0.12, 0.95)
const EQUIPPED_ROW_BG := Color(0.20, 0.18, 0.11, 0.98)

## 🔴 장비 효과 문구·발사 패턴 라벨 = core 단일 소스 (세84 감사 #21 — 옛 사본 셋을 합쳤다).
## `tab_panel`(src/hud)도 같은 파일을 부른다 — **`src/hud`에 두면 모듈 경계 위반**이라 core다
## (`grade_colors.gd` 선례). 문구를 고치면 공방·개인 시트가 같이 따라온다.
const ItemText := preload("res://src/core/item_text.gd")

## 🔴 codex 해금 id → 「이름(어디에 쓰는 물건인지)」 = core 단일 소스 (세88). 발신처가 셋이라
## (보스 클리어 · 여기 · 두루마리 픽업) 각자 조립하면 그게 감사 T5의 재발이다.
## 🔴 룬은 진 **중심**, 고리는 **밴드**, 진은 **바탕** — 자리를 틀리게 가르치면 거짓 지시가 된다.
const CodexText := preload("res://src/core/codex_text.gd")

## 착용 부위 — 표시 순서·라벨. PEN을 앞에 둔다(공방을 여는 주된 이유가 펜이라).
const EQUIP_KINDS: Array = [
	[Enums.ItemKind.PEN, "펜"],
	[Enums.ItemKind.WAND, "지팡이"],
	[Enums.ItemKind.ROBE, "로브"],
	[Enums.ItemKind.CHARM, "부적"],
	[Enums.ItemKind.HAT, "모자"],
]

@onready var _vbox: VBoxContainer = $Center/Panel/Margin/VBox
@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/List

## 방금 무엇을 만들었나 — 패널 아랫변 한 줄. 🔴 **HUD가 아니라 여기**인 이유: 모달이 화면을 덮고
## 있어 뒤 HUD 토스트가 안 보이고, `src/base`가 `src/hud`를 직접 무는 건 모듈 경계 위반이다
## (takbon-rules §0). 해금 사실 자체는 `codex_unlocked`가 나르므로 이 줄은 순수 표시다.
var _notice: Label


func _ready() -> void:
	# 화면을 덮는 모달 — STOP이라 열린 동안 좌클릭을 통째로 먹는다(뒤에서 실수로 안 쏜다).
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.resources_changed.connect(_on_changed)
	EventBus.equipment_changed.connect(_on_changed)
	# 🔴 해금도 목록을 바꾼다 — 배운 부품 행이 [배웠다]로 잠겨야 재료를 두 번 태우지 않는다.
	# `resources_changed`(재료 소비)는 emit 시점이 해금보다 **앞이라** 이것만으론 옛 상태가 남는다.
	EventBus.codex_unlocked.connect(_on_unlocked)
	_notice = _hint_label("")
	_notice.add_theme_color_override(&"font_color", EQUIPPED_COLOR)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = false
	_vbox.add_child(_notice)   # Scroll이 세로로 늘어나므로 이 줄은 판 아랫변에 앉는다
	draw.connect(_on_draw)


func open() -> void:
	if visible:
		return
	visible = true
	GameState.ui_modal_open = true
	_say("")
	_refresh()
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.ui_modal_open = false
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_changed() -> void:
	if visible:
		_refresh()


func _on_unlocked(_unlock_id: StringName) -> void:
	if visible:
		_refresh()


## 판 아랫변 알림 한 줄 — 빈 문자열이면 줄 자체를 숨겨 여백이 안 생긴다.
func _say(text: String) -> void:
	_notice.text = text
	_notice.visible = text != ""


## 배경(어둠) — 카드 판은 씬 노드(Center/Panel)가 그린다.
func _on_draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)


## 세 구역을 다시 짓는다 — ① 조립 부품 제작 ② 장비 제작 ③ 장착(착용 중 + 보유 장비).
## 보유·착용·해금이 바뀌면(제작·장착·해제) resources_changed/equipment_changed/codex_unlocked가
## 여길 다시 부른다.
##
## 🔴 **구역을 가르는 축은 `reward_unlock`이다** — 옛 한 구역에 17줄을 쌓으면 새로 뜬 부품 8줄이
## 펜·지팡이 사이에 묻힌다(부품이 이 설계의 본줄인데 눈에 안 든다).
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()

	var parts: Array[RecipeDef] = []
	var gear: Array[RecipeDef] = []
	for r: RecipeDef in Db.recipes_for_station(&"craft"):
		if r.reward_unlock != &"":
			parts.append(r)
		else:
			gear.append(r)
	parts.sort_custom(_part_less)
	gear.sort_custom(_id_less)

	_list.add_child(_section_label("조립 부품 제작"))
	if parts.is_empty():
		_list.add_child(_hint_label("만들 수 있는 부품이 없다 (data/recipes에 reward_unlock 없음)"))
	else:
		for r: RecipeDef in parts:
			_list.add_child(_make_recipe_row(r))

	_list.add_child(_section_label("장비 제작"))
	if gear.is_empty():
		_list.add_child(_hint_label("만들 수 있는 장비가 없다 (data/recipes 비어 있음)"))
	else:
		for r: RecipeDef in gear:
			_list.add_child(_make_recipe_row(r))

	_list.add_child(_section_label("장착"))
	_add_equip_rows()


# ─────────────────────────── 제작 ───────────────────────────

## 🔴 표시 순서는 **패널이 정한다** — `Db.recipes_for_station`이 순서를 못 준다. 주석이 「id 오름차순」
## 이라 적고 있지만 `StringName` 배열의 `sort()`는 사전순이 아니라 인터닝 순이라 **부팅마다 목록
## 순서가 바뀐다**(세88 실측: 같은 데이터로 두 번 돌려 첫 줄이 달랐다). 17줄 목록에서 그건 그냥 버그다.
##
## 부품은 **아직 못 배운 것 → 닢 값 싼 것** 순 — 「다음에 닿을 것」이 맨 위에 온다(설계 §7 F:
## 재료 진행 숫자가 곧 목표 표시다). 배운 것은 아래로 내려 잠긴 행이 목록 머리를 안 막는다.
func _part_less(a: RecipeDef, b: RecipeDef) -> bool:
	var la := _learned(a)
	var lb := _learned(b)
	if la != lb:
		return lb
	var ca := int(a.inputs.get(&"coin", 0))
	var cb := int(b.inputs.get(&"coin", 0))
	if ca != cb:
		return ca < cb
	return String(a.id) < String(b.id)


## `StringName`이 아니라 `String`으로 비교한다 — 위 주석의 인터닝 순 함정 때문이다.
func _id_less(a: RecipeDef, b: RecipeDef) -> bool:
	return String(a.id) < String(b.id)


## 이 레시피가 주는 해금을 이미 배웠나 — 장비 레시피(`reward_unlock` 없음)는 늘 false다.
func _learned(r: RecipeDef) -> bool:
	return r.reward_unlock != &"" and GameState.is_unlocked(r.reward_unlock)


## 한 레시피 행 = [제목 + 재료(보유/필요)] ……… [제작]. 재료 부족이면 버튼 비활성.
## refine_panel과 같은 규약 — 소비·지급은 GameState.spend/add_item이 쥔다.
##
## 🔴 **제목은 `display_name` 우선**(세88 §4-C-b ②) — 해금 레시피는 `output_id`가 비어 있어
## 옛 `_item_name(output_id)` 하나로는 **" ×0"**만 찍힌다. 세88 전까지 `RecipeDef.display_name`을
## 읽는 코드가 프로젝트에 **한 곳도 없었다**(선언만 있는 죽은 필드 = 감사 T3).
## 🔴 **이미 배운 부품은 잠근다**(③) — 안 그러면 재료·닢을 태우고 아무것도 안 받는다. 그 자리엔
## 재료 진행 대신 **어디에 쓰는 물건인지**를 적는다(`CodexText`).
func _make_recipe_row(r: RecipeDef) -> Control:
	var learned := _learned(r)
	var afford := GameState.can_afford(r.inputs)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = _recipe_title(r)
	name_lbl.add_theme_color_override(&"font_color", HINT_COLOR if learned else NAME_COLOR)
	info.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override(&"font_size", 11)
	if learned:
		sub_lbl.text = _learned_text(r.reward_unlock)
		sub_lbl.add_theme_color_override(&"font_color", EQUIPPED_COLOR)
	else:
		sub_lbl.text = "재료: " + _inputs_text(r)
		sub_lbl.add_theme_color_override(&"font_color", HAVE_COLOR if afford else SHORT_COLOR)
	info.add_child(sub_lbl)

	var btn := Button.new()
	btn.text = "배웠다" if learned else "제작"
	btn.disabled = learned or not afford
	btn.pressed.connect(_craft.bind(r.id))
	return _row(info, btn, EQUIPPED_ROW_BG if learned else ROW_BG)


## 행 제목 — `display_name`이 정본, 없으면 결과 아이템 이름으로 폴백(옛 장비 레시피 9장이 그 경로다).
func _recipe_title(r: RecipeDef) -> String:
	if r.display_name != "":
		return r.display_name
	return "%s ×%d" % [_item_name(r.output_id), r.output_count]


## 이미 배운 부품 줄 — 「어디에 쓰는 물건인지」는 `CodexText`(core) 단일 소스가 안다.
func _learned_text(unlock_id: StringName) -> String:
	var hint := CodexText.hint_for_kind(CodexText.kind_of(unlock_id))
	if hint == "":
		return "이미 배웠다"
	return "이미 배웠다 · %s" % hint


## 🔴 제작 — 재료를 창고에서 빼고 **결과를 준다**. 결과가 두 종류다(세88 §4-C-b ①):
##   ⓐ `output_id`가 있으면 창고 아이템 · ⓑ `reward_unlock`이 있으면 **codex 해금**.
## 🔴 `output_id`가 비었는데 `add_item`을 부르면 **id=""인 유령 아이템이 창고에 쌓이고 세이브에
## 영구화된다** — 그래서 조건이 붙었다(세88 전까지 조건 없이 불렀다).
## 🔴 해금은 `codex_unlocked` **한 발**로 끝난다 — codex 심기 + 해금음 + UNLOCK 퀘스트 진행 +
## 자동 저장이 전부 따라온다(세37 station_* 선례). `GameState.codex`를 직접 쓰지 마라.
## spend가 can_afford를 확인하므로 이중 클릭도 안전 — 단 **이미 배운 해금은 재료만 태우므로**
## 그 앞에서 먼저 막는다(버튼도 잠겨 있지만 여기가 진짜 관문이다).
func _craft(recipe_id: StringName) -> void:
	var r := Db.get_recipe(recipe_id)
	if r == null:
		return
	if _learned(r):
		return
	if not GameState.spend(r.inputs):
		return
	if r.output_id != &"":
		GameState.add_item(r.output_id, r.output_count)
	Audio.play(&"craft")
	if r.reward_unlock != &"":
		EventBus.codex_unlocked.emit(r.reward_unlock)
	_say(_made_text(r))


# ─────────────────────────── 장착 ───────────────────────────

## 착용 중(부위별 [해제]) → 보유 장비([장착]). 착용품은 창고에서 빠져 있으니 두 목록이 겹치지 않는다.
func _add_equip_rows() -> void:
	var any_equipped := false
	for pair: Array in EQUIP_KINDS:
		var kind: int = pair[0]
		if GameState.equipment.has(kind):
			any_equipped = true
			_list.add_child(_make_equipped_row(kind, pair[1]))
	if not any_equipped:
		_list.add_child(_hint_label("착용 중인 장비가 없다"))

	var owned := _owned_equippable()
	if owned.is_empty():
		_list.add_child(_hint_label("보유한 장비가 없다 — 공방에서 만들거나 챕터에서 얻는다"))
		return
	for entry: Dictionary in owned:
		_list.add_child(_make_owned_row(entry["id"], int(entry["count"])))


## 착용 중인 한 부위 — "펜 · 길든 펜 (보정 …)" [해제].
func _make_equipped_row(kind: int, kind_label: String) -> Control:
	var item_id: StringName = GameState.equipment[kind]
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = "%s · %s" % [kind_label, _item_name(item_id)]
	name_lbl.add_theme_color_override(&"font_color", EQUIPPED_COLOR)
	info.add_child(name_lbl)

	var hint := ItemText.effect_text(Db.get_item(item_id))
	if hint != "":
		var eff := Label.new()
		eff.text = hint
		eff.add_theme_font_size_override(&"font_size", 11)
		eff.add_theme_color_override(&"font_color", HINT_COLOR)
		info.add_child(eff)

	var btn := Button.new()
	btn.text = "해제"
	btn.pressed.connect(GameState.unequip_gear.bind(kind))
	return _row(info, btn, EQUIPPED_ROW_BG)


## 창고에 있는 장착 가능한 한 아이템 — 이름 + 효과 [장착].
func _make_owned_row(item_id: StringName, count: int) -> Control:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = "%s ×%d" % [_item_name(item_id), count]
	name_lbl.add_theme_color_override(&"font_color", NAME_COLOR)
	info.add_child(name_lbl)

	var hint := ItemText.effect_text(Db.get_item(item_id))
	if hint != "":
		var eff := Label.new()
		eff.text = hint
		eff.add_theme_font_size_override(&"font_size", 11)
		eff.add_theme_color_override(&"font_color", HINT_COLOR)
		info.add_child(eff)

	var btn := Button.new()
	btn.text = "장착"
	btn.pressed.connect(GameState.equip_gear.bind(item_id))
	return _row(info, btn, ROW_BG)


## 창고에서 착용 가능한(장비 종류) 아이템만 — 종류→등급→id 순으로. 착용품은 창고에 없어 안 뜬다.
func _owned_equippable() -> Array:
	var equip_kinds: Array = []
	for pair: Array in EQUIP_KINDS:
		equip_kinds.append(pair[0])
	var out: Array = []
	var snap := GameState.get_inventory_snapshot()
	for id: StringName in snap:
		var count := int(snap[id])
		if count <= 0:
			continue
		var it := Db.get_item(id)
		if it != null and it.kind in equip_kinds:
			out.append({"id": id, "count": count})
	out.sort_custom(_owned_less)
	return out


func _owned_less(a: Dictionary, b: Dictionary) -> bool:
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


# ─────────────────────────── 조각 ───────────────────────────

## 왼쪽 정보(VBox) + 오른쪽 버튼을 한 카드에 담는다 — 제작·장착·해제가 같은 모양.
func _row(info: Control, btn: Button, bg: Color) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(9.0)
	sb.set_corner_radius_all(3)
	row.add_theme_stylebox_override(&"panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override(&"separation", 10)
	row.add_child(hb)
	hb.add_child(info)

	btn.custom_minimum_size = Vector2(88.0, 44.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(btn)
	return row


func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override(&"font_size", 15)
	lbl.add_theme_color_override(&"font_color", SECTION_COLOR)
	return lbl


func _hint_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override(&"font_size", 12)
	lbl.add_theme_color_override(&"font_color", HINT_COLOR)
	return lbl


## 🔴 장비 효과 문구·발사 패턴 라벨은 **여기 없다** — `ItemText`(core) 단일 소스다(세84 #21).
## 옛 `_effect_text`/`_wand_pattern_text` 사본은 은퇴했다(`tab_panel`에 같은 사본이 있었다).


## 제작 성공 한 줄 — 부품이면 `CodexText`가 「이름(어디에 쓰는지)」을, 장비면 **받은 물건**을 적는다.
## ⚠ 장비는 제목(`display_name`)이 아니라 아이템 이름이다 — "만들었다 — 길든 펜 제작"이 되지 않게.
## ⚠ 조사(을/를)를 붙이지 않는다 — 부품 이름이 `)`로 끝나 조사를 고를 수 없다.
func _made_text(r: RecipeDef) -> String:
	if r.reward_unlock != &"":
		return "✦ 배웠다 — %s" % CodexText.label_of(r.reward_unlock)
	return "✦ 만들었다 — %s ×%d" % [_item_name(r.output_id), r.output_count]


## "수액 슬라임 핵 3/5, 닢 12/30" — 재료마다 **보유/필요**. 소비자(GameState.spend)가 먹는 형식과 같은 dict.
## 🔴 한 칸의 형식은 `ItemText.count_text`(core) 단일 소스다 — 세88 전까지 공방·정제대가 **글자까지 같은
## 사본**을 각자 들고 있었고 **둘 다 인자가 거꾸로**였다(3개 갖고 5개 필요면 "5/3"으로 찍혔다).
## 한쪽만 고치면 다른 쪽이 계속 거꾸로 남는다 = 감사 T5. **여기서 다시 조립하지 마라.**
## ⚠ 순서는 `.tres`의 dict 순서를 그대로 따른다 — 새 레시피 8장은 **닢을 맨 끝에** 적어 뒀다
## (재료를 먼저 읽고 값을 마지막에 보는 게 자연스럽다).
func _inputs_text(r: RecipeDef) -> String:
	var parts: Array[String] = []
	for id: StringName in r.inputs:
		parts.append(ItemText.count_text(_item_name(id), GameState.get_count(id), int(r.inputs[id])))
	return ", ".join(parts)


func _item_name(id: StringName) -> String:
	var it := Db.get_item(id)
	return it.display_name if it != null and it.display_name != "" else String(id)
