extends "res://src/base/panel_base.gd"
## 작업대 패널 — 정제·종이 제작·수리·도안함 (모듈 D 임시 UI).

const Recipes := preload("res://src/base/recipes.gd")
const WorkbenchService := preload("res://src/base/workbench_service.gd")

var _svc: WorkbenchService
var _refine_box: VBoxContainer
var _paper_box: VBoxContainer
var _repair_box: VBoxContainer
var _design_box: VBoxContainer

func _init(svc: WorkbenchService) -> void:
	super()
	_svc = svc
	set_title("작업대")
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	_refine_box = _make_tab(tabs, "정제")
	_paper_box = _make_tab(tabs, "종이 제작")
	_repair_box = _make_tab(tabs, "수리")
	_design_box = _make_tab(tabs, "도안함")
	EventBus.resources_changed.connect(_on_resources_changed, CONNECT_DEFERRED)

func _make_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	tabs.add_child(scroll)
	return box

func _on_resources_changed() -> void:
	if is_visible_in_tree():
		refresh()

func refresh() -> void:
	_refresh_refine()
	_refresh_paper()
	_refresh_repair()
	_refresh_designs()

func _refresh_refine() -> void:
	clear_box(_refine_box)
	for recipe_id: StringName in Recipes.REFINE:
		var r: Dictionary = Recipes.REFINE[recipe_id]
		var row := add_row(_refine_box, "%s — %s → %s" % [r["name"], fmt_items(r["cost"]), fmt_items(r["output"])])
		add_button(row, "정제", _svc.can_refine(recipe_id), _do_refine.bind(recipe_id))

func _refresh_paper() -> void:
	clear_box(_paper_box)
	for recipe_id: StringName in Recipes.PAPER:
		var r: Dictionary = Recipes.PAPER[recipe_id]
		var text := "%s — %s → %s" % [r["name"], fmt_items(r["cost"]), fmt_items(r["output"])]
		if not _svc.is_paper_unlocked(recipe_id):
			text += "  [연구 필요: %s]" % r["unlock"]
		var row := add_row(_paper_box, text)
		add_button(row, "제작", _svc.can_craft_paper(recipe_id), _do_craft.bind(recipe_id))

func _refresh_repair() -> void:
	clear_box(_repair_box)
	var any := false
	for design: SpellDesign in GameState.designs:
		if design.durability >= design.durability_max:
			continue
		any = true
		var row := add_row(_repair_box, "%s — 내구 %d/%d" % [design.display_name, design.durability, design.durability_max])
		add_button(row, "수리(%s)" % fmt_items(_svc.repair_cost(design)),
				_svc.can_repair(design), _do_repair.bind(design))
		add_button(row, "응급 %d까지(%s)" % [_svc.emergency_cap(design), fmt_items(_svc.repair_cost(design, true))],
				_svc.can_emergency_repair(design), _do_emergency.bind(design))
	if not any:
		add_row(_repair_box, "수리할 도안이 없다.")

func _refresh_designs() -> void:
	clear_box(_design_box)
	if GameState.designs.is_empty():
		add_row(_design_box, "보관된 도안이 없다.")
		return
	add_row(_design_box, "장착 슬롯 버튼(1~4)을 눌러 장착한다.")
	for design: SpellDesign in GameState.designs:
		var slot_tag := ""
		for i in range(GameState.equipped.size()):
			if GameState.equipped[i] == design:
				slot_tag = "  [장착 %d]" % (i + 1)
		var row := add_row(_design_box, "%s — 내구 %d/%d · 마나 %.0f%s" % [
			design.display_name, design.durability, design.durability_max, design.mana_cost, slot_tag])
		for i in range(GameState.equipped.size()):
			add_button(row, str(i + 1), GameState.equipped[i] != design, _do_equip.bind(i, design))

func _do_refine(recipe_id: StringName) -> void:
	_svc.refine(recipe_id)
	refresh.call_deferred()

func _do_craft(recipe_id: StringName) -> void:
	_svc.craft_paper(recipe_id)
	refresh.call_deferred()

func _do_repair(design: SpellDesign) -> void:
	_svc.repair(design)
	refresh.call_deferred()

func _do_emergency(design: SpellDesign) -> void:
	_svc.emergency_repair(design)
	refresh.call_deferred()

func _do_equip(slot: int, design: SpellDesign) -> void:
	GameState.equip(slot, design)
	refresh.call_deferred()
