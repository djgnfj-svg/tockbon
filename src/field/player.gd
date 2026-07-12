extends CharacterBody2D
## 플레이어 — WASD 이동·마우스 에임·대시(짧은 무적)·기본 완드 약공격·캐스트 슬롯 4 (모듈 C).
## 계약(TECH_SPEC §5): 그룹 "player", 레이어 2. 사망 시 player_died + bag_lost 발신.
## 캐스트: cast_requested(GameState.equipped[i], global_position, aim_dir).
## null·손상 슬롯은 조용히 무시한다 (cast_failed는 B의 마나·내구 판정 전용).

const Util := preload("res://src/field/field_util.gd")
const WandBolt := preload("res://src/field/wand_bolt.gd")

## 주인공 스프라이트시트 (ART_SPEC P1) — 32×32 가로 스트립 32프레임, 태그 순서는 아래 _SHEET_ANIMS
const PLAYER_SHEET_PATH := "res://assets/sprites/player/player.png"
## { 애니 이름: [시작 프레임, 프레임 수, fps] } — assets/sprites/player/player.json과 동일 배치
const _SHEET_ANIMS := {
	"idle_down": [0, 2, 2.5], "idle_up": [2, 2, 2.5],
	"idle_left": [4, 2, 2.5], "idle_right": [6, 2, 2.5],
	"walk_down": [8, 4, 7.0], "walk_up": [12, 4, 7.0],
	"walk_left": [16, 4, 7.0], "walk_right": [20, 4, 7.0],
	"dash_down": [24, 1, 10.0], "dash_up": [25, 1, 10.0],
	"dash_left": [26, 1, 10.0], "dash_right": [27, 1, 10.0],
	"rub": [28, 4, 2.8],
}

@export var attack_cooldown_sec: float = 0.25
@export var dash_cooldown_sec: float = 0.6
@export var hit_invuln_sec: float = 0.5

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
var _anim: AnimatedSprite2D
var _facing: String = "down"

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1 << 1                # 2 = player
	collision_mask = (1 << 0) | (1 << 2)    # world + enemy
	_balance = GameState.balance
	GameState.reset_player_hp()  # HP 원장은 GameState (출격마다 회복)
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
	if busy or GameState.ui_modal_open:
		velocity = Vector2.ZERO
		_update_anim()
		return
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * _balance.dash_speed
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input_dir * _balance.player_move_speed
	move_and_slide()
	_update_anim()
	if Input.is_action_pressed("attack_basic") and _attack_cd <= 0.0:
		_shoot()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or busy or GameState.ui_modal_open:
		return
	if event.is_action_pressed("dash"):
		_try_dash()
	for i in range(GameState.EQUIP_SLOTS):
		if event.is_action_pressed("cast_slot_%d" % (i + 1)):
			try_cast(i)

## 장착 슬롯 캐스트 요청 — 성공적으로 발신했으면 true
func try_cast(slot: int) -> bool:
	if is_dead or busy or GameState.ui_modal_open:
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
	GameState.damage_player(amount)
	_invuln_left = hit_invuln_sec
	EventBus.player_damaged.emit(amount)
	if GameState.hp <= 0.0:
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
	_dash_cd = dash_cooldown_sec * GameState.gear_param(Enums.ItemKind.CHARM, "dash_cooldown_mult", 1.0) \
			+ _balance.dash_duration_sec
	# 대시 중 무적은 _dash_left로 판정 (take_damage 참조)

func _shoot() -> void:
	_attack_cd = attack_cooldown_sec * GameState.gear_param(Enums.ItemKind.WAND, "attack_cooldown_mult", 1.0)
	var parent := get_parent()
	if parent == null:
		return
	var bolt: Variant = WandBolt.new()
	bolt.damage = _balance.wand_basic_damage + GameState.gear_param(Enums.ItemKind.WAND, "wand_damage_add", 0.0)
	bolt.dir = aim_dir
	bolt.global_position = global_position + aim_dir * 10.0
	parent.add_child(bolt)

func _die() -> void:
	is_dead = true
	busy = false
	if _anim != null:
		_anim.stop()
	modulate = Color(1, 1, 1, 0.35)
	collision_layer = 0
	EventBus.player_died.emit()
	EventBus.bag_lost.emit()

func _on_phase_changed(phase: int) -> void:
	if _light != null:
		_light.enabled = (phase == Enums.Phase.NIGHT)

func _build_body() -> void:
	Util.add_circle_collider(self, 8.0)
	if ResourceLoader.exists(PLAYER_SHEET_PATH):
		_anim = _build_sprite()
		add_child(_anim)
	else:
		# 미임포트 환경 폴백 — 먹빛 두건의 견습 필경사 (플레이스홀더)
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

func _build_sprite() -> AnimatedSprite2D:
	var tex: Texture2D = load(PLAYER_SHEET_PATH)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim_name: String in _SHEET_ANIMS:
		var d: Array = _SHEET_ANIMS[anim_name]
		var sn := StringName(anim_name)
		frames.add_animation(sn)
		frames.set_animation_speed(sn, d[2])
		frames.set_animation_loop(sn, true)
		for i in range(d[1]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((int(d[0]) + i) * 32, 0, 32, 32)
			frames.add_frame(sn, at)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.play(&"idle_down")
	return sprite

func _update_anim() -> void:
	if _anim == null:
		return
	var next: String
	if busy:
		next = "rub"
	elif _dash_left > 0.0:
		_facing = _dir_name(_dash_dir)
		next = "dash_" + _facing
	elif velocity.length_squared() > 1.0:
		_facing = _dir_name(velocity)
		next = "walk_" + _facing
	else:
		next = "idle_" + _facing
	if _anim.animation != StringName(next):
		_anim.play(StringName(next))

func _dir_name(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "down" if v.y >= 0.0 else "up"
