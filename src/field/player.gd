extends CharacterBody2D
## 플레이어 — WASD 이동·마우스 에임·대시(짧은 무적)·기본 완드 약공격·캐스트 슬롯 4 (모듈 C).
## 계약(TECH_SPEC §5): 그룹 "player", 레이어 2. 사망 시 player_died + bag_lost 발신.
## 캐스트: cast_requested(GameState.equipped[i], global_position, aim_dir).
## null·손상 슬롯은 조용히 무시한다 (cast_failed는 B의 마나·내구 판정 전용).

const Util := preload("res://src/field/field_util.gd")
const WandBolt := preload("res://src/field/wand_bolt.gd")

@export var attack_cooldown_sec: float = 0.25
@export var dash_cooldown_sec: float = 0.6
@export var hit_invuln_sec: float = 0.5

var hp: float = 100.0
var is_dead: bool = false
## 탁본 중 무방비 — 이동·대시·공격·캐스트 전부 불가 (rubbing_spot이 설정)
var busy: bool = false
var aim_dir: Vector2 = Vector2.RIGHT

var _balance: BalanceData
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _attack_cd: float = 0.0
var _invuln_left: float = 0.0
var _light: PointLight2D
var _aim_line: Line2D

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1 << 1                # 2 = player
	collision_mask = (1 << 0) | (1 << 2)    # world + enemy
	_balance = GameState.balance
	hp = _balance.player_hp_max
	_build_body()
	EventBus.phase_changed.connect(_on_phase_changed)
	_light.enabled = Clock.is_night()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_invuln_left = maxf(_invuln_left - delta, 0.0)
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		aim_dir = to_mouse.normalized()
	if _aim_line != null:
		_aim_line.rotation = aim_dir.angle()
	if busy:
		velocity = Vector2.ZERO
		return
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * _balance.dash_speed
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input_dir * _balance.player_move_speed
	move_and_slide()
	if Input.is_action_pressed("attack_basic") and _attack_cd <= 0.0:
		_shoot()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or busy:
		return
	if event.is_action_pressed("dash"):
		_try_dash()
	for i in range(GameState.EQUIP_SLOTS):
		if event.is_action_pressed("cast_slot_%d" % (i + 1)):
			try_cast(i)

## 장착 슬롯 캐스트 요청 — 성공적으로 발신했으면 true
func try_cast(slot: int) -> bool:
	if is_dead or busy:
		return false
	if slot < 0 or slot >= GameState.equipped.size():
		return false
	var design: SpellDesign = GameState.equipped[slot]
	if design == null or design.is_broken():
		return false
	EventBus.cast_requested.emit(design, global_position, aim_dir)
	return true

func take_damage(amount: float) -> void:
	if is_dead or _invuln_left > 0.0 or _dash_left > 0.0:
		return
	hp -= amount
	_invuln_left = hit_invuln_sec
	EventBus.player_damaged.emit(amount)
	if hp <= 0.0:
		_die()

## 탁본 무방비 상태 토글 (rubbing_spot 전용)
func set_busy(value: bool) -> void:
	busy = value
	if busy:
		velocity = Vector2.ZERO

func _try_dash() -> void:
	if _dash_cd > 0.0 or _dash_left > 0.0:
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_dir = input_dir if input_dir != Vector2.ZERO else aim_dir
	_dash_left = _balance.dash_duration_sec
	_dash_cd = dash_cooldown_sec + _balance.dash_duration_sec
	# 대시 중 무적은 _dash_left로 판정 (take_damage 참조)

func _shoot() -> void:
	_attack_cd = attack_cooldown_sec
	var parent := get_parent()
	if parent == null:
		return
	var bolt: Variant = WandBolt.new()
	bolt.damage = _balance.wand_basic_damage
	bolt.dir = aim_dir
	bolt.global_position = global_position + aim_dir * 10.0
	parent.add_child(bolt)

func _die() -> void:
	is_dead = true
	busy = false
	hp = 0.0
	modulate = Color(1, 1, 1, 0.35)
	collision_layer = 0
	EventBus.player_died.emit()
	EventBus.bag_lost.emit()

func _on_phase_changed(phase: int) -> void:
	if _light != null:
		_light.enabled = (phase == Enums.Phase.NIGHT)

func _build_body() -> void:
	Util.add_circle_collider(self, 8.0)
	# 먹빛 두건의 견습 필경사 (플레이스홀더)
	Util.add_circle_visual(self, 8.0, Color(0.16, 0.18, 0.22))
	var brim := Polygon2D.new()
	brim.polygon = Util.circle_points(5.0, 10)
	brim.color = Color(0.85, 0.8, 0.7)
	brim.position = Vector2(0, -2)
	add_child(brim)
	_aim_line = Line2D.new()
	_aim_line.points = PackedVector2Array([Vector2(6, 0), Vector2(15, 0)])
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1, 1, 1, 0.5)
	add_child(_aim_line)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	add_child(cam)
	_light = PointLight2D.new()
	_light.texture = Util.radial_light_texture()
	_light.texture_scale = 1.4
	_light.energy = 1.2
	_light.enabled = false
	add_child(_light)
