extends RefCounted
## 작업대 서비스 — 정제·종이 제작·수리 (모듈 D).
## 자원 증감은 전부 GameState 인벤토리 API를 통한다.

const Recipes := preload("res://src/base/recipes.gd")

# ── 정제 (재료 → 잉크)

func can_refine(recipe_id: StringName) -> bool:
	var r: Dictionary = Recipes.REFINE.get(recipe_id, {})
	return not r.is_empty() and GameState.can_afford(r["cost"])

func refine(recipe_id: StringName) -> bool:
	if not can_refine(recipe_id):
		return false
	var r: Dictionary = Recipes.REFINE[recipe_id]
	if not GameState.spend(r["cost"]):
		return false
	_grant(r["output"])
	return true

# ── 종이 제작 (연구 해금 조건부)

func is_paper_unlocked(recipe_id: StringName) -> bool:
	var r: Dictionary = Recipes.PAPER.get(recipe_id, {})
	if r.is_empty():
		return false
	var unlock: StringName = r["unlock"]
	return unlock == &"" or GameState.is_unlocked(unlock)

func can_craft_paper(recipe_id: StringName) -> bool:
	if not is_paper_unlocked(recipe_id):
		return false
	var r: Dictionary = Recipes.PAPER[recipe_id]
	return GameState.can_afford(r["cost"])

func craft_paper(recipe_id: StringName) -> bool:
	if not can_craft_paper(recipe_id):
		return false
	var r: Dictionary = Recipes.PAPER[recipe_id]
	if not GameState.spend(r["cost"]):
		return false
	_grant(r["output"])
	return true

# ── 수리 (비용 = 원본 ink_cost × repair_cost_frac, 올림)

func repair_cost(design: SpellDesign, emergency: bool = false) -> Dictionary:
	var out: Dictionary = {}
	var frac: float = GameState.balance.repair_cost_frac
	if emergency:
		frac *= GameState.balance.emergency_repair_cost_mult
	for ink_id: StringName in design.ink_cost:
		var amount := ceili(float(design.ink_cost[ink_id]) * frac)
		if amount > 0:
			out[ink_id] = amount
	return out

func can_repair(design: SpellDesign) -> bool:
	if design == null or design.durability >= design.durability_max:
		return false
	return GameState.can_afford(repair_cost(design))

## 완전 수리: durability → max, design_repaired 발신
func repair(design: SpellDesign) -> bool:
	if not can_repair(design):
		return false
	if not GameState.spend(repair_cost(design)):
		return false
	design.durability = design.durability_max
	EventBus.design_repaired.emit(design)
	return true

## 응급 수리 상한 (내구 최대치 × emergency_durability_frac, 올림)
func emergency_cap(design: SpellDesign) -> int:
	return ceili(float(design.durability_max) * GameState.balance.emergency_durability_frac)

func can_emergency_repair(design: SpellDesign) -> bool:
	if design == null or design.durability >= emergency_cap(design):
		return false
	return GameState.can_afford(repair_cost(design, true))

## 응급 수리: 비용은 emergency_repair_cost_mult 배, durability 는 상한까지만
func emergency_repair(design: SpellDesign) -> bool:
	if not can_emergency_repair(design):
		return false
	if not GameState.spend(repair_cost(design, true)):
		return false
	design.durability = emergency_cap(design)
	EventBus.design_repaired.emit(design)
	return true

func _grant(output: Dictionary) -> void:
	for item_id: StringName in output:
		GameState.add_item(item_id, int(output[item_id]))
