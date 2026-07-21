extends StaticBody2D
## 연습장 허수아비 — 적 노드 계약의 **참고 구현**이자 베이스캠프 연습 표적
## (그룹 "enemies", collision_layer=4(enemy), take_hit).
##
## 🔴 세션50: **상태이상·원소 반응을 받는다.** 그전엔 `take_hit`이 hits에 기록만 하고 상태를 버려서
## **연습장에서 반응을 시험할 수 없었다** — 마법을 만들고 바로 쏴 보는 자리인데. 보유·틱·반응은
## `src/core/status_holder.gd`가 적과 **똑같이** 돌린다(규칙을 여기 베끼면 조용히 갈라진다).
##
## 🔴 적과 다른 점 = **몸이 다르다**:
##  • StaticBody2D라 이동이 없다 → `move_mult()`를 아예 안 부른다(콜백 경계의 이점).
##  • HP가 없다(안 죽는다) → 피해는 **누적 카운터**로 받는다. `status_damage_total()`이
##    "이 표적이 얼마나 지졌나"의 유일한 관측점이고, 테스트도 이걸로 확인한다.

## 🔴 상태 보유고 — 적(`forest_enemy`)과 같은 물건. core에 둔 이유가 이것이다.
const SH := preload("res://src/core/status_holder.gd")
## 확산 반경 등 수치는 balance가 쥔다 (연출값이 아니라 밸런스다 — forest_enemy와 같은 소스).
const BAL := preload("res://data/balance.tres")

var hits: Array[Dictionary] = []

# 🔴 스프라이트로 바뀌어(세션44 허수아비 도트) 타입을 Node2D로 넓혔다 — modulate·scale은
# CanvasItem/Node2D 공용이라 _pop 연출은 그대로 돈다(Polygon2D로 좁히면 Sprite2D 캐스트가 깨진다).
@onready var _visual: Node2D = $Visual

var _status: SH = SH.new()
## 상태로 받은 누적 피해(DoT + 반응). HP가 없으니 이게 유일한 관측점이다.
var _status_damage: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_wire_status()


## holder 콜백을 이 몸에 잇는다. 🔴 규칙은 holder가, 몸의 반응은 여기가 — 적과 같은 경계다.
func _wire_status() -> void:
	_status.on_dot = func(amount: float) -> void:
		# 🔴 DoT는 조용히 쌓인다 — `enemy_hit`을 쏘면 0.5초마다 피해 숫자·히트스톱이 도배된다
		# (forest_enemy와 같은 이유). 지지는 게 보이는 건 틴트가 맡는다.
		_status_damage += amount
	_status.on_burst = func(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void:
		_burst_damage(radius, amount, include_self, result_status, rune)
	_status.on_spread = func(statuses: Dictionary) -> void:
		_spread_statuses(statuses)
	_status.on_changed = _refresh_tint


## ⚠ 콜백 해제(`_exit_tree`)는 **일부러 없다** — 끊을 순환이 없고, 끊으면 재진입 시 콜백이 영구히
## 죽는다. 이유는 `forest_enemy._wire_status` 위 주석에 적어 뒀다(같은 판단이 두 곳에 산다).


func _physics_process(delta: float) -> void:
	_status.tick(delta)


func take_hit(damage: float, rune_type: int, status: int, status_power: float) -> void:
	hits.append({
		"damage": damage,
		"rune_type": rune_type,
		"status": status,
		"status_power": status_power,
	})
	print("[DummyTarget] 피격 damage=%.2f rune=%d status=%d power=%.2f" % [
		damage, rune_type, status, status_power])
	# 적 노드 계약: enemy_hit 발신은 take_hit 내부 책임 (실제 적은 약점 배율 반영 최종 피해로 발신)
	EventBus.enemy_hit.emit(self, damage, rune_type)
	# 🔴 상태·반응은 피해 **뒤에** 판정한다 (forest_enemy와 같은 순서 — 계약을 한쪽만 바꾸면 갈라진다).
	_status.apply_incoming(rune_type, status, status_power)
	_pop()


## 🔴 공개 — 확산이 옆 적에게 상태를 옮길 때 쓰는 유일 경로. 적과 **같은 시그니처**여야
## 바람 확산이 허수아비↔적 사이에서도 돈다(둘 다 그룹 "enemies"라 서로를 찾는다).
func apply_status(status: int, power: float) -> void:
	_status.add(status, power)


func has_status(status: int) -> bool:
	return _status.has(status)


func status_power_of(status: int) -> float:
	return _status.power_of(status)


## 🔴 공개 관측점 — HP가 없는 표적이라 "얼마나 지졌나"를 잴 유일한 자리
## (takbon-verify §3 "공개 API로만" — `_status_damage`는 내부 필드라 계약이 아니다).
func status_damage_total() -> float:
	return _status_damage


## 🔴 반응 피해 — 조용한 DoT와 달리 **한 번뿐인 사건**이라 `enemy_hit`을 쏴 손맛을 준다.
## 연습장에서 **연쇄가 눈에 보여야** 조합할 이유가 생긴다(피해 숫자 + 히트스톱 + 팝).
## 상태를 안 만들어 재귀가 없다 — `take_hit`으로 때리면 연쇄가 연쇄를 낳는다.
## 🔴 rune(세56) = 이 반응의 정체 룬(감전=BOLT·증기=WATER) — enemy_hit에 그대로 실어야 소리가
## 반응과 맞는다(그전엔 FIRE 하드코딩이라 감전 연쇄가 불 소리를 냈다). 기본 인자 = 하위호환.
func take_reaction_damage(amount: float, rune: int = Enums.RuneType.FIRE) -> void:
	if amount <= 0.0:
		return
	_status_damage += amount
	EventBus.enemy_hit.emit(self, amount, rune)
	_pop()


## 반경 안의 다른 적들에게 즉발 피해. `include_self`면 자신도 맞는다(증기).
## 씬을 뒤지는 건 **몸의 일**이라 여기 있다(holder는 씬을 모른다).
## rune = 이 버스트의 정체 룬(세56) — 자신·연쇄 대상 모두 take_reaction_damage에 그대로 넘긴다.
func _burst_damage(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void:
	# 🔴 VFX 방송 (세52) — forest_enemy와 **동일**해야 연습장↔숲 연출이 안 갈라진다. 링이 반경을
	# 폭로하므로 amount 가드 **앞에** 둔다(반응은 일어났으니 링은 늘 뜬다). 피해 계산은 안 바뀐다.
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
			# 🔴 감전(SHOCK)만 대상마다 번개 아크 — 증기(NONE)는 링만(설계 §4). 피해 전에 쏜다.
			if result_status == Enums.Status.SHOCK:
				EventBus.reaction_chain.emit(global_position, (node as Node2D).global_position, result_status)
			node.take_reaction_damage(amount, rune)


## 바람 확산 — 붙은 상태를 반경 안의 다른 표적에게 번뜨린다. 내 것은 남는다.
func _spread_statuses(statuses: Dictionary) -> void:
	if statuses.is_empty():
		return
	# 🔴 VFX (세52) — forest_enemy와 **동일**. 여러 상태를 옮겨도 아크는 한 대상에 한 가닥, 대표 상태색.
	# 대표 상태는 holder 공개 API로 얻는다(세52 리뷰) — 몸이 내부 dict의 ["seq"]를 더듬지 않는다.
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


## 🔴 상태 틴트 — 색을 **고르는 규칙은 holder**가 쥐고(적과 같게 보인다), 칠하는 건 여기다.
## 알파는 안 건드린다(허수아비엔 분산이 없지만 경계는 적과 같게 유지한다).
func _refresh_tint() -> void:
	if _visual == null:
		return
	var c := _status.tint()
	c.a = _visual.modulate.a
	_visual.modulate = c


## 팝 — 흰 섬광 + 크기 펀치 (피격 손맛, 세션 38). 허수아비는 StaticBody라 넉백은 없다.
## forest_enemy._pop과 같은 연출 (연습장에서도 손맛이 같게).
func _pop() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(2.2, 2.2, 2.2)
	_visual.scale = Vector2(1.35, 1.35)
	var tween := create_tween()
	tween.set_parallel(true)
	# 🔴 복귀 목표는 **상태 틴트**다 — Color.WHITE로 돌리면 때릴 때마다 화상 색이 벗겨진다
	# (헤드리스가 절대 못 잡는다 — 렌더가 없다).
	tween.tween_property(_visual, "modulate", _status.tint(), 0.18)
	tween.tween_property(_visual, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
