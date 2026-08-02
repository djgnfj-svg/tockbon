extends StaticBody2D
## 연습장 허수아비 — 적 노드 계약의 **참고 구현**(그룹 "enemies", collision_layer=4, take_hit).
##
## 🔴 상태·반응 규칙은 `status_holder`가 적과 **똑같이** 돌린다 — 규칙을 여기 베끼면 조용히 갈라진다.
## 적과 다른 점은 몸뿐이다: StaticBody2D라 `move_mult()`를 안 부르고, HP가 없어 피해를
## 누적 카운터로 받는다(`status_damage_total()`이 유일한 관측점).

## 🔴 상태 보유고 — 적(`forest_enemy`)과 같은 물건. core에 둔 이유가 이것이다.
const SH := preload("res://src/core/status_holder.gd")
## 확산 반경 등은 연출값이 아니라 밸런스다 — forest_enemy와 같은 소스.
const BAL := preload("res://data/balance.tres")
## 🔴 적과 **같은 셰이더 파일** — 여기만 갈라지면 연습장에서 시험한 손맛이 거짓말이 된다.
const FLASH_SHADER := preload("res://src/actors/hit_flash.gdshader")
## 팝 연출값 — forest_enemy와 같은 수치(파리티). 밸런스 아님.
const POP_SQUASH := Vector2(1.25, 0.78)
const POP_SEC := 0.18

var hits: Array[Dictionary] = []

# 🔴 Polygon2D로 좁히지 마라 — Sprite2D 캐스트가 깨진다. modulate·scale은 Node2D 공용이라 _pop은 그대로 돈다.
@onready var _visual: Node2D = $Visual

var _status: SH = SH.new()
## 상태로 받은 누적 피해(DoT + 반응). HP가 없으니 이게 유일한 관측점이다.
var _status_damage: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_wire_status()
	# 🔴 ShaderMaterial은 인스턴스마다 새로 만든다 — 공유하면 하나 맞을 때 다섯이 같이 번쩍인다
	# (Shader 리소스 자체는 상태가 없어 공유해도 안전).
	if _visual != null:
		var mat := ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		mat.set_shader_parameter(&"flash_amount", 0.0)
		mat.set_shader_parameter(&"telegraph_amount", 0.0)
		_visual.material = mat


## holder 콜백을 이 몸에 잇는다. 🔴 규칙은 holder가, 몸의 반응은 여기가 — 적과 같은 경계다.
func _wire_status() -> void:
	_status.on_dot = func(amount: float) -> void:
		# 🔴 DoT는 조용히 쌓는다 — `enemy_hit`을 쏘면 0.5초마다 피해 숫자·히트스톱이 도배된다.
		_status_damage += amount
	_status.on_burst = func(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void:
		_burst_damage(radius, amount, include_self, result_status, rune)
	_status.on_spread = func(statuses: Dictionary) -> void:
		_spread_statuses(statuses)
	_status.on_changed = _refresh_tint


## ⚠ 콜백 해제(`_exit_tree`)는 **일부러 없다** — 끊을 순환이 없고, 끊으면 재진입 시 콜백이 영구히 죽는다.


func _physics_process(delta: float) -> void:
	_status.tick(delta)


func take_hit(damage: float, rune_type: int, status: int, status_power: float) -> void:
	hits.append({
		"damage": damage,
		"rune_type": rune_type,
		"status": status,
		"status_power": status_power,
	})
	# ⚠ **여기에 `print`를 되살리지 마라** — 기둥이 매 틱 허수아비 5개를 잡아 로그가 도배되고
	# 진짜 `push_warning`이 묻힌다(검증이 로그 grep에 얹혀 있다). 관측은 `hits[]`·`status_damage_total()`로.
	# 🔴 피해 0 = 보조 룬 상태 전용 히트 — `enemy_hit`·팝을 건너뛰고 상태만 얹는다(forest_enemy와 같은 계약).
	if damage <= 0.0:
		_status.apply_incoming(rune_type, status, status_power)
		return
	# 적 노드 계약: enemy_hit 발신은 take_hit 내부 책임 (실제 적은 약점 배율 반영 최종 피해로 발신)
	EventBus.enemy_hit.emit(self, damage, rune_type)
	# 🔴 상태·반응은 피해 **뒤에** 판정한다 — forest_enemy와 순서가 어긋나면 두 몸이 갈라진다.
	_status.apply_incoming(rune_type, status, status_power)
	_pop()


## 🔴 확산이 옆 적에게 상태를 옮길 때 쓰는 유일 경로. 적과 **같은 시그니처**여야
## 바람 확산이 허수아비↔적 사이에서도 돈다(둘 다 그룹 "enemies"라 서로를 찾는다).
func apply_status(status: int, power: float) -> void:
	_status.add(status, power)


func has_status(status: int) -> bool:
	return _status.has(status)


func status_power_of(status: int) -> float:
	return _status.power_of(status)


## 🔴 HP가 없는 표적이라 "얼마나 지졌나"를 잴 유일한 공개 자리다.
func status_damage_total() -> float:
	return _status_damage


## 🔴 반응 피해 — 조용한 DoT와 달리 한 번뿐인 사건이라 `enemy_hit`을 쏴 손맛을 준다.
## 🔴 상태를 안 만들어 재귀가 없다 — `take_hit`으로 때리면 연쇄가 연쇄를 낳는다.
## 🔴 rune = 이 반응의 정체 룬(감전=BOLT·증기=WATER) — 하드코딩하면 감전 연쇄가 불 소리를 낸다.
func take_reaction_damage(amount: float, rune: int = Enums.RuneType.FIRE) -> void:
	if amount <= 0.0:
		return
	_status_damage += amount
	EventBus.enemy_hit.emit(self, amount, rune)
	_pop()


## 반경 안의 다른 적들에게 즉발 피해. `include_self`면 자신도 맞는다(증기).
## 씬을 뒤지는 건 **몸의 일**이라 여기 있다 — holder는 씬을 모른다.
func _burst_damage(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void:
	# 🔴 amount 가드 **앞에** 둔다 — 반응은 일어났으니 피해가 0이어도 링은 떠야 한다.
	EventBus.reaction_burst.emit(global_position, radius, result_status)
	if amount <= 0.0:
		return
	if include_self:
		take_reaction_damage(amount, rune)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > radius:
			continue
		if node.has_method(&"take_reaction_damage"):
			# 감전만 대상마다 번개 아크 — 증기는 링만.
			if result_status == Enums.Status.SHOCK:
				EventBus.reaction_chain.emit(global_position, (node as Node2D).global_position, result_status)
			node.take_reaction_damage(amount, rune)


## 바람 확산 — 붙은 상태를 반경 안의 다른 표적에게 번뜨린다. 내 것은 남는다.
func _spread_statuses(statuses: Dictionary) -> void:
	if statuses.is_empty():
		return
	# 여러 상태를 옮겨도 아크는 한 대상에 한 가닥, 대표 상태색. 🔴 대표 상태는 holder 공개 API로 —
	# 몸이 내부 dict를 더듬으면 갈라진다.
	var rep := _status.representative()
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > BAL.status_spread_px:
			continue
		if not node.has_method(&"apply_status"):
			continue
		EventBus.reaction_chain.emit(global_position, (node as Node2D).global_position, rep)
		for key: int in statuses.keys():
			node.apply_status(key, float(statuses[key]["power"]))


## 🔴 색을 **고르는 규칙은 holder**가 쥐고, 칠하는 것만 여기다. 알파는 안 건드린다.
func _refresh_tint() -> void:
	if _visual == null:
		return
	var c := _status.tint()
	c.a = _visual.modulate.a
	_visual.modulate = c


## 팝 — 셰이더 흰 섬광 + 스쿼시. forest_enemy._pop과 같은 연출이라야 연습장 손맛이 안 거짓말한다.
## 🔴 modulate는 안 만진다 — 소유권 계약이 rgb=상태 틴트·a=분산이다.
func _pop() -> void:
	if _visual == null:
		return
	var mat := _visual.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"flash_amount", 1.0)
	_visual.scale = POP_SQUASH
	var tween := create_tween()
	tween.set_parallel(true)
	if mat != null:
		tween.tween_property(mat, "shader_parameter/flash_amount", 0.0, POP_SEC)
	tween.tween_property(_visual, "scale", Vector2.ONE, POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
