extends CharacterBody2D
## 적 공통 베이스 — 단순 FSM(대기→추적→공격)·약점 배율·상태이상·밤 강화·사망 드롭 (모듈 C).
## 계약(모듈 B 합의, TECH_SPEC §5): 그룹 "enemies", 충돌 레이어 3,
## take_hit(damage, rune_type, status, status_power) 구현. 사망 시 enemy_died 발신 + 드롭.

const Util := preload("res://src/field/field_util.gd")
const PickupScript := preload("res://src/field/pickup.gd")
const RubbingSpotScript := preload("res://src/field/rubbing_spot.gd")

enum State { IDLE, CHASE, ATTACK, DEAD }

## ── 스프라이트 (ART_SPEC P2) — 시트 없으면 기존 원형 플레이스홀더 폴백
const ENEMY_SHEET_DIR := "res://assets/sprites/enemies/"
const POP_SHEET_PATH := "res://assets/sprites/enemies/pop.png"
## { 시트 키: { 애니 이름: [시작 프레임, 프레임 수, fps] } } — 키 = def.id (+ 미니는 "_mini")
const ENEMY_SHEET_ANIMS := {
	"vine": {"idle": [0, 2, 2.2], "attack": [2, 2, 6.0], "regen": [4, 2, 3.2]},
	"hound": {"idle": [0, 2, 2.2], "move": [2, 4, 8.0], "windup": [6, 1, 2.0], "dash": [7, 1, 2.5]},
	"slime": {"idle": [0, 2, 2.4], "move": [2, 2, 5.0]},
	"slime_mini": {"idle": [0, 2, 2.6], "move": [2, 2, 6.0]},
	"slime_elite": {"idle": [0, 2, 2.0], "move": [2, 2, 4.5]},
	"mist": {"gather": [0, 2, 2.4], "scatter": [2, 2, 2.4]},
	"beetle": {"idle": [0, 2, 2.2], "move": [2, 2, 5.0]},
	"gale": {"idle": [0, 2, 2.5], "gust": [2, 2, 2.5], "volley": [4, 2, 4.0]},
}
const ENEMY_SHEET_SIZES := {"slime_mini": 16, "gale": 64}

const BURN_DURATION := 3.0
const WET_DURATION := 4.0
const FLOW_DURATION := 1.2
## 젖음 둔화 배율 (GDD §4.2 물~ = 둔화)
const WET_SLOW := 0.55
const KNOCK_DECAY := 420.0
const FLOW_PUSH_SCALE := 55.0

@export var def: EnemyDef
## false면 _physics_process 정지 — 테스트가 simulate()를 직접 호출해 결정론적으로 검증
@export var ai_enabled: bool = true
## 슬라임 분열체 — 드롭·분열·잔류물 없음
@export var is_mini: bool = false

# ── 종별 스탯 — 기본값은 스크립트, 원장은 EnemyDef.params (.tres)가 _ready에서 덮어씀
var move_speed: float = 70.0
var aggro_range: float = 150.0
var attack_range: float = 26.0
var attack_cooldown: float = 1.0
var contact_damage: float = 5.0
## 약점 룬(def.counter_rune) 피격 배율 — def.has_counter가 false면 미적용
var weakness_mult: float = 1.5
var body_radius: float = 9.0
var body_color: Color = Color(0.6, 0.3, 0.3)

var hp: float = 30.0
var max_hp: float = 30.0
var night_mult: float = 1.0
var knock_velocity: Vector2 = Vector2.ZERO

var _base_max_hp: float = 30.0
var _anim_sprite: AnimatedSprite2D
var _state: State = State.IDLE
var _ai_velocity: Vector2 = Vector2.ZERO
var _attack_cd: float = 0.0
## {Enums.Status: {"time": float, "power": float, ("dir": Vector2)}}
var _statuses: Dictionary = {}
var _flow_push: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1 << 2                    # 3 = enemy
	collision_mask = (1 << 0) | (1 << 1)        # world + player
	if def != null and not def.params.is_empty():
		move_speed = float(def.params.get("move_speed", move_speed))
		aggro_range = float(def.params.get("aggro_range", aggro_range))
		attack_range = float(def.params.get("attack_range", attack_range))
		attack_cooldown = float(def.params.get("attack_cooldown", attack_cooldown))
		contact_damage = float(def.params.get("contact_damage", contact_damage))
		weakness_mult = float(def.params.get("weakness_mult", weakness_mult))
		_apply_params(def.params)
	_base_max_hp = def.hp if def != null else 30.0
	var night := Clock.is_night()
	night_mult = def.night_buff if (def != null and night) else 1.0
	max_hp = _base_max_hp * night_mult
	hp = max_hp
	_build_body()
	EventBus.phase_changed.connect(_on_phase_changed)

func _physics_process(delta: float) -> void:
	if ai_enabled:
		simulate(delta)

## 1틱 진행 — 테스트에서 delta를 직접 넣어 상태이상·재생을 결정론적으로 검증한다.
func simulate(delta: float, apply_motion: bool = true) -> void:
	if _state == State.DEAD:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_update_statuses(delta)
	if hp <= 0.0:
		_die()
		return
	_update_ai(delta)
	var slow := WET_SLOW if has_status(Enums.Status.WET) else 1.0
	velocity = _ai_velocity * slow + knock_velocity + _flow_push
	knock_velocity = knock_velocity.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
	if apply_motion:
		move_and_slide()
	_update_anim_sprite()

# ── 피격 계약 (모듈 B가 투사체에서 호출)

func take_hit(damage: float, rune_type: int, status: int, status_power: float) -> void:
	if _state == State.DEAD:
		return
	var dmg := damage
	if def != null and def.has_counter and rune_type == int(def.counter_rune):
		dmg *= weakness_mult
	dmg = _apply_defense(dmg, rune_type)
	if dmg > 0.0:
		hp -= dmg
		EventBus.enemy_hit.emit(self, dmg, rune_type)
	if status != Enums.Status.NONE:
		_apply_status(status, status_power)
	if hp <= 0.0:
		_die()

## 종별 방어 훅 — 갑충(장갑)·안개 정령(산개 저항)이 오버라이드
func _apply_defense(dmg: float, _rune_type: int) -> float:
	return dmg

## 종별 params 훅 — 변형 스크립트가 자기 전용 키(재생·돌진·장갑 등)를 읽는다
func _apply_params(_params: Dictionary) -> void:
	pass

func _apply_status(status: int, power: float) -> void:
	match status:
		Enums.Status.BURN:
			_statuses[status] = {"time": BURN_DURATION, "power": power}
		Enums.Status.WET:
			_statuses[status] = {"time": WET_DURATION, "power": power}
		Enums.Status.KNOCKBACK:
			knock_velocity = _push_dir() * maxf(80.0, power * 40.0)
		Enums.Status.FLOW:
			_statuses[status] = {"time": FLOW_DURATION, "power": power, "dir": _push_dir()}

func has_status(status: int) -> bool:
	return _statuses.has(status)

func is_burning() -> bool:
	return has_status(Enums.Status.BURN)

func _update_statuses(delta: float) -> void:
	_flow_push = Vector2.ZERO
	var expired: Array = []
	for s: int in _statuses:
		var entry: Dictionary = _statuses[s]
		var t: float = minf(delta, float(entry["time"]))
		if s == Enums.Status.BURN:
			hp -= float(entry["power"]) * t     # power = 초당 화상 피해
		elif s == Enums.Status.FLOW:
			_flow_push = (entry["dir"] as Vector2) * float(entry["power"]) * FLOW_PUSH_SCALE
		entry["time"] = float(entry["time"]) - delta
		if float(entry["time"]) <= 0.0:
			expired.append(s)
	for s: int in expired:
		_statuses.erase(s)

# ── FSM (종별 오버라이드 가능)

func _update_ai(_delta: float) -> void:
	var p := _get_player()
	if p == null:
		_state = State.IDLE
		_ai_velocity = Vector2.ZERO
		return
	var dist := global_position.distance_to(p.global_position)
	if dist > aggro_range:
		_state = State.IDLE
		_ai_velocity = Vector2.ZERO
	elif dist > attack_range:
		_state = State.CHASE
		_ai_velocity = global_position.direction_to(p.global_position) * move_speed
	else:
		_state = State.ATTACK
		_ai_velocity = Vector2.ZERO
		if _attack_cd <= 0.0:
			_attack_cd = attack_cooldown
			_do_attack(p)

func _do_attack(p: Node2D) -> void:
	if p.has_method("take_damage"):
		p.call("take_damage", contact_damage * night_mult)

func _get_player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		return null
	if p.get("is_dead") == true:
		return null
	return p

## 넉백·밀림 방향 — 플레이어 반대쪽, 없으면 랜덤
func _push_dir() -> Vector2:
	var p := _get_player()
	if p != null:
		var d := p.global_position.direction_to(global_position)
		if d != Vector2.ZERO:
			return d
	return Vector2.from_angle(randf() * TAU)

# ── 밤 강화 (EventBus.phase_changed 구독 — HP·공격 공통 배율)

func _on_phase_changed(phase: int) -> void:
	var target := 1.0
	if def != null and phase == Enums.Phase.NIGHT:
		target = def.night_buff
	if is_equal_approx(night_mult, target):
		return
	var frac := hp / max_hp if max_hp > 0.0 else 1.0
	night_mult = target
	max_hp = _base_max_hp * night_mult
	hp = max_hp * frac

# ── 사망·드롭·탁본 잔류물

func _die() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	EventBus.enemy_died.emit(def, global_position)
	# 적 종류별 첫 처치 → 도감 해금 (TECH_SPEC §5.1 — E가 게시판·도감 약점 표기에 사용)
	if def != null:
		var unlock_id := StringName("enemy_%s" % def.id)
		if not GameState.is_unlocked(unlock_id):
			EventBus.codex_unlocked.emit(unlock_id)
	if not is_mini and def != null:
		_spawn_drops()
		if def.is_elite:
			_spawn_rubbing_spot()
	_spawn_pop()
	_post_death()
	queue_free()

## 처치 팝 — 간결한 먹 튀김 (ART_SPEC P2, GDD 톤: 무겁지 않게)
func _spawn_pop() -> void:
	if not ResourceLoader.exists(POP_SHEET_PATH):
		return
	var parent := get_parent()
	if parent == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = Util.build_sprite_frames(
		load(POP_SHEET_PATH), {"pop": [0, 5, 14.0]}, 32)
	fx.sprite_frames.set_animation_loop(&"pop", false)
	fx.autoplay = "pop"
	fx.global_position = global_position
	if is_mini:
		fx.scale = Vector2(0.6, 0.6)
	fx.animation_finished.connect(fx.queue_free)
	parent.add_child.call_deferred(fx)

## 종별 사망 훅 — 슬라임 분열 등
func _post_death() -> void:
	pass

func _spawn_drops() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for entry: DropEntry in def.drops:
		# 탁본 조각은 직접 드롭이 아니라 잔류물(탁본 모션)로만 나온다 (GDD §6)
		if def.is_elite and String(entry.item_id).begins_with("fragment_"):
			continue
		if randf() > entry.chance:
			continue
		var count := randi_range(entry.min_count, entry.max_count)
		for i in range(count):
			var pickup: Variant = PickupScript.new()
			pickup.item_id = entry.item_id
			pickup.global_position = global_position + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 16.0)
			parent.add_child.call_deferred(pickup)

func _spawn_rubbing_spot() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for entry: DropEntry in def.drops:
		if String(entry.item_id).begins_with("fragment_"):
			var spot: Variant = RubbingSpotScript.new()
			spot.fragment_id = entry.item_id
			spot.global_position = global_position
			parent.add_child.call_deferred(spot)
			return

# ── 비주얼 — 스프라이트 시트 우선, 없으면 원형 플레이스홀더

func _build_body() -> void:
	var key := _sheet_key()
	var sheet_path := ENEMY_SHEET_DIR + key + ".png"
	if not key.is_empty() and ResourceLoader.exists(sheet_path):
		# 미니는 16×16 리드로잉 시트라 노드 스케일 없이 콜라이더만 축소 (기존 0.6 스케일과 동일 반경)
		Util.add_circle_collider(self, body_radius * (0.6 if is_mini else 1.0))
		var frame_size: int = ENEMY_SHEET_SIZES.get(key, 32)
		_anim_sprite = AnimatedSprite2D.new()
		_anim_sprite.sprite_frames = Util.build_sprite_frames(
			load(sheet_path), ENEMY_SHEET_ANIMS[key], frame_size)
		add_child(_anim_sprite)
		_update_anim_sprite()
		if def != null and def.is_elite:
			scale = Vector2(1.35, 1.35)   # 왕관·무늬는 시트에 포함 — 링 없이 크기만
		return
	Util.add_circle_collider(self, body_radius)
	Util.add_circle_visual(self, body_radius, body_color)
	if def != null and def.is_elite:
		scale = Vector2(1.35, 1.35)
		var ring := Line2D.new()
		ring.points = Util.circle_points(body_radius + 4.0, 20)
		ring.closed = true
		ring.width = 1.5
		ring.default_color = Color(0.95, 0.8, 0.3)
		add_child(ring)
	if is_mini:
		scale = Vector2(0.6, 0.6)

func _sheet_key() -> String:
	if def == null:
		return ""
	var key := String(def.id) + ("_mini" if is_mini else "")
	return key if ENEMY_SHEET_ANIMS.has(key) else ""

# ── 시트 애니메이션 상태 전환

func _update_anim_sprite() -> void:
	if _anim_sprite == null:
		return
	var next := _anim_key()
	if not next.is_empty() and _anim_sprite.animation != StringName(next):
		_anim_sprite.play(StringName(next))
	if absf(velocity.x) > 1.0:
		_anim_sprite.flip_h = velocity.x < 0.0

## 종별 오버라이드 훅 — 현재 상태에 맞는 시트 애니 이름
func _anim_key() -> String:
	if _state == State.ATTACK and _has_anim("attack"):
		return "attack"
	if velocity.length_squared() > 4.0 and _has_anim("move"):
		return "move"
	return "idle"

func _has_anim(anim_name: String) -> bool:
	return _anim_sprite != null and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(StringName(anim_name))
