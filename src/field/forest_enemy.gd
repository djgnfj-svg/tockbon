extends CharacterBody2D
## 숲의 적 — 쫓아와서 접촉 피해. 사용자 확정 세션 26: *"한 종류만 — 쫓아와서 접촉 피해"*.
##
## 🔴 **적 노드 계약**을 지킨다 (허수아비 `src/spell/dummy_target.gd`가 그 참고 구현이다):
##   그룹 `"enemies"` · 레이어 3(enemy) · `take_hit(damage, rune_type, status, status_power)` ·
##   그 안에서 `EventBus.enemy_hit`를 **약점 배율까지 반영한 최종 피해**로 발신.
## 발사(ring_spell_system)가 이미 이 계약으로 때린다 — 그래서 이 파일은 발사를 전혀 모른다.
##
## 🔴 **수치는 전부 `data/enemies/*.tres`(EnemyDef)가 쥔다 — 새 적 = .tres 한 장**이다
## (선례: 룬·펜·진). 코드엔 하나도 안 박혀 있고 `enemy_id`만 바꾸면 hp·속도·피해가 따라온다.
##
## 🔴 **레이어: layer 4(enemy) / mask 1(world)** (forest_enemy.tscn).
##  • mask에 2(player)를 넣지 마라 — 적이 플레이어를 **밀어내는** 게임이 되고, 접촉 피해는
##    어차피 아래 거리 판정이 판다 (물리 충돌이 필요 없다).
##  • layer 4가 곧 **맞는 몸**이다 — 캐리어·탄 마스크가 5(world+enemy)라 여길 본다.
##    기본 레이어 1로 되돌리면 world로 읽혀 마법이 **부딪히기만 하고 take_hit이 안 불린다**.

## 적이 죽었다 — 숲이 남은 수를 센다.
signal died

@export var enemy_id: StringName = &"slime"

@onready var _visual: Polygon2D = $Visual

var _def: EnemyDef = null
var _hp: float = 0.0
var _cool: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_def = Db.get_enemy(enemy_id)
	if _def == null:
		# 조용히 죽지 않게 — .tres 이름을 틀리면 hp 0짜리 유령이 서 있게 된다.
		push_warning("EnemyDef '%s'를 못 찾았다 (data/enemies/ 확인) — 기본값으로 선다" % enemy_id)
	_hp = _def.hp if _def != null else 10.0


## 쫓아오기 + 접촉 피해. **거리 하나로 둘 다 판정한다** — aggro_range 안이면 다가오고,
## attack_range 안이면 attack_cooldown 간격으로 때린다 (수치는 전부 .tres).
func _physics_process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	var player := _player()
	if player == null:
		velocity = Vector2.ZERO
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()

	if dist <= _param("aggro_range", 160.0) and dist > 1.0:
		velocity = to_player / dist * _param("move_speed", 55.0)
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if dist <= _param("attack_range", 18.0) and _cool <= 0.0:
		_cool = _param("attack_cooldown", 0.9)
		GameState.damage_player(_param("contact_damage", 4.0))


## 🔴 그룹 `"player"`가 유일한 조준 경로다 (player.gd가 `_ready`에서 넣는다).
## 빠지면 적이 **제자리에 굳는데 에러는 안 난다** — 세션 24·25의 침묵과 같은 종류다.
func _player() -> Node2D:
	var found := get_tree().get_first_node_in_group("player")
	return found as Node2D


func _param(key: String, fallback: float) -> float:
	if _def == null:
		return fallback
	return float(_def.params.get(key, fallback))


## 🔴 계약: `enemy_hit`는 **약점 배율을 반영한 최종 피해**로 발신한다 (dummy_target 주석).
## ⚠ `status`·`status_power`는 아직 안 쓴다 — 적의 상태이상(화상·젖음)은 미구현이다.
## 인자는 계약이라 시그니처에 그대로 남긴다 (받아 놓고 버리는 게 계약을 좁히는 것보다 낫다).
func take_hit(damage: float, rune_type: int, _status: int, _status_power: float) -> void:
	var mult := 1.0
	if _def != null and _def.has_counter and rune_type == _def.counter_rune:
		mult = _param("weakness_mult", 1.0)
	var dealt := damage * mult
	_hp -= dealt
	EventBus.enemy_hit.emit(self, dealt, rune_type)
	_flash()
	if _hp <= 0.0:
		_die()


## ⚠ `EnemyDef.drops`를 아직 안 뿌린다 — 사용자 확정 세션 26: *"이번엔 없다 — 싸움 + 귀환만"*.
## 얻는 게 생기는 순간(탁본) 여기가 그 자리다: 드롭 → `GameState.add_to_bag` → 귀환해야 창고행.
func _die() -> void:
	died.emit()
	queue_free()


func _flash() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.25)
