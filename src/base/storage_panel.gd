extends "res://src/base/panel_base.gd"
## 창고 패널 — 창고·가방 내용 표시 + 장비(완드·로브·부적) 착용/해제 (모듈 D).

const KIND_NAMES: Dictionary = {
	Enums.ItemKind.INK: "잉크",
	Enums.ItemKind.PAPER: "종이",
	Enums.ItemKind.MATERIAL: "재료",
	Enums.ItemKind.FRAGMENT: "탁본 조각",
	Enums.ItemKind.WAND: "완드",
	Enums.ItemKind.ROBE: "로브",
	Enums.ItemKind.CHARM: "부적",
}
const KIND_ORDER: Array = [
	Enums.ItemKind.INK, Enums.ItemKind.PAPER, Enums.ItemKind.MATERIAL,
	Enums.ItemKind.FRAGMENT, Enums.ItemKind.WAND, Enums.ItemKind.ROBE, Enums.ItemKind.CHARM,
]
## 착용 가능 부위 — 착용 장비 섹션 표시 순서 겸용 (TECH_SPEC §4.2)
const GEAR_KINDS: Array = [Enums.ItemKind.WAND, Enums.ItemKind.ROBE, Enums.ItemKind.CHARM]

var _list_box: VBoxContainer

func _init() -> void:
	super()
	set_title("창고")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)
	EventBus.resources_changed.connect(_on_state_changed, CONNECT_DEFERRED)
	EventBus.equipment_changed.connect(_on_state_changed, CONNECT_DEFERRED)

func _on_state_changed() -> void:
	if is_visible_in_tree():
		refresh()

func refresh() -> void:
	clear_box(_list_box)
	add_row(_list_box, "— 착용 장비 (사망에도 보존) —")
	for kind: int in GEAR_KINDS:
		var slot_tag: String = KIND_NAMES.get(kind, "?")
		if GameState.equipment.has(kind):
			var row := add_row(_list_box, "[%s] %s" % [slot_tag, item_name(GameState.equipment[kind])])
			add_button(row, "해제", true, func() -> void: GameState.unequip_gear(kind))
		else:
			add_row(_list_box, "[%s] (미착용)" % slot_tag)
	add_row(_list_box, "")
	add_row(_list_box, "— 창고 (영구 보관) —")
	var entries: Array[Dictionary] = []
	for item_id: StringName in GameState.get_inventory_snapshot():
		var count := GameState.get_count(item_id)
		if count <= 0:
			continue
		var def: ItemDef = Db.get_item(item_id)
		var order := KIND_ORDER.find(def.kind) if def != null else 99
		entries.append({"order": order, "grade": def.grade if def != null else 0, "id": item_id, "count": count})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["order"] != b["order"]:
			return a["order"] < b["order"]
		if a["grade"] != b["grade"]:
			return a["grade"] < b["grade"]
		return String(a["id"]) < String(b["id"]))
	if entries.is_empty():
		add_row(_list_box, "(비어 있음)")
	for e: Dictionary in entries:
		var def: ItemDef = Db.get_item(e["id"])
		var kind_tag: String = KIND_NAMES.get(def.kind, "?") if def != null else "?"
		var row := add_row(_list_box, "[%s] %s ×%d" % [kind_tag, item_name(e["id"]), e["count"]])
		if def != null and def.kind in GEAR_KINDS:
			var gear_id: StringName = e["id"]
			add_button(row, "착용", true, func() -> void: GameState.equip_gear(gear_id))
	add_row(_list_box, "")
	add_row(_list_box, "— 가방 (출격 획득 · 사망 시 손실) —")
	if GameState.bag.is_empty():
		add_row(_list_box, "(비어 있음)")
	for entry: Dictionary in GameState.bag:
		add_row(_list_box, "%s ×%d" % [item_name(entry["id"]), int(entry["count"])])
