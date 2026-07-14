extends Area2D
## 투사체 — 모듈 B (TECH_SPEC §1: 레이어 4=player_projectile, 마스크 1|3=world|enemy).
## 파라미터 주입은 spell_system.setup() 경유. class_name 없음 — preload로 참조할 것.
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).
##
## **문양 = 발동 방식 + 세기 축 (v1.9, GDD §4.3)**: 이 탄이 **어떻게 나가는가**를 `glyph`가 정하고,
## **얼마나 세게 그러는가**를 `reach`(문양 길이 ÷ 진 반지름)가 정한다.
##   BASIC 곧게 / BOUNCE⚡ 벽 반사(횟수) / HOMING∿ 적 추적(지속) / PIERCE‖ 적 관통(뚫는 수)
## 🔴 문양은 **위력·탄 크기·기준 사거리를 건드리지 않는다** — 그건 진의 축이다. 사거리는 **배율만** 준다.
## 상태이상 종류·세기도 안 건드린다 — 그건 룬의 축이다.

const SheetLib := preload("res://src/core/sheet_lib.gd")
const InkRender := preload("res://src/core/ink_render.gd")

const RUNE_COLORS: Dictionary = {
	Enums.RuneType.FIRE: Color(1.0, 0.55, 0.1),    # 불 = 주황
	Enums.RuneType.IMPACT: Color(1.0, 0.9, 0.2),   # 충격 = 노랑
	Enums.RuneType.WATER: Color(0.25, 0.55, 1.0),  # 물 = 파랑
	Enums.RuneType.WIND: Color(0.65, 0.95, 0.45),  # 바람 = 연두
}

## 룬 투사체 시트 (ART_SPEC P5) — 우향 혜성형 2프레임, rotation이 조준각을 그대로 적용
const PROJ_SHEET_PATH := "res://assets/sprites/effects/projectiles.png"
const PROJ_ANIMS := {
	"fire": [0, 2, 10.0], "impact": [2, 2, 10.0],
	"water": [4, 2, 10.0], "wind": [6, 2, 10.0],
}
const RUNE_ANIM_NAMES := {
	Enums.RuneType.FIRE: "fire",
	Enums.RuneType.IMPACT: "impact",
	Enums.RuneType.WATER: "water",
	Enums.RuneType.WIND: "wind",
}
## 시트는 전 투사체 공유 — 1회만 빌드 (탄막 다발 스폰 대비)
static var _shared_frames: SpriteFrames = null
static var _sheet_checked: bool = false

## 벽 반사 구현 상수 — **밸런스 수치가 아니라 물리 여유값**이다 (선례: spell_system의 연출 상수).
## Area2D는 충돌 법선을 안 주므로 앞쪽 RayCast2D로 벽을 먼저 잡는다. 레이 길이는
## "이번 프레임 이동거리 + 히트박스 반경 + 아래 여유" — 히트박스가 벽에 닿기 전에 잡아야
## 레이 시점(중심)이 벽 안으로 들어가지 않는다 (안에서 시작한 레이는 그 벽을 못 본다).
const BOUNCE_PROBE_PAD_PX := 2.0
## 반사 직후 벽에서 밀어내는 거리 — 벽에 파묻혀 매 프레임 재반사하는 걸 막는다
const BOUNCE_PUSH_PX := 1.0

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0
## 발사 시점의 각도. **진행 방향이 아니다** — 유도·반사는 rotation과 _velocity가 바뀐다
var direction_angle: float = 0.0
## 문양 축 (v1.9) — 발동 방식과 그 세기
var glyph: int = Enums.GlyphType.BASIC
var reach: float = 1.0

var _balance: BalanceData = preload("res://data/balance.tres")
var _velocity := Vector2.ZERO
var _life_left: float = 0.0
var _consumed := false
## 남은 벽 반사 횟수 (BOUNCE)
var _bounces_left: int = 0
## 남은 관통 수 (PIERCE) — 0이 되면 소멸
var _pierces_left: int = 0
## 이미 뚫은 적 — Area2D는 겹쳐 있는 동안 재진입하므로 같은 적을 두 번 때리지 않게 기억한다
var _pierced_ids: Array[int] = []
## 남은 추적 지속시간 (HOMING). 0 이하가 되면 마지막 방향으로 직진
var _homing_left: float = 0.0
var _ray: RayCast2D = null

func _ready() -> void:
	_life_left = _balance.projectile_lifetime_sec
	_ray = get_node_or_null("Ray") as RayCast2D
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


# ── 문양 세기 축 (v1.9) — reach → 정규화 t → 각 거동의 세기 ───────────────────
# spell_system(사거리 배율)과 투사체(반사·관통·추적)가 **같은 t**를 쓴다. 공식은 여기 하나뿐이다.

## t = inverse_lerp(glyph_reach_min, glyph_reach_max, reach) — 아래 전부의 입력 (TECH_SPEC §4.0-a)
static func reach_t(balance: BalanceData, p_reach: float) -> float:
	return clampf(inverse_lerp(balance.glyph_reach_min, balance.glyph_reach_max, p_reach), 0.0, 1.0)

## 사거리 **배율** — 진이 준 기준 사거리에 곱해진다. 축을 뺏지 않고 배율만 준다 (GDD §4.3)
static func range_mult(balance: BalanceData, p_reach: float) -> float:
	return lerpf(balance.glyph_range_min, balance.glyph_range_max, reach_t(balance, p_reach))

## p_path: 그린 화살표 획 (ArrowData.path — 시작점=원점·+X=발사방향, 캔버스 단위).
## p_pressures: 짝을 이루는 필압 (ArrowData.path_pressures). 비면 균일 굵기 — 마우스로 그린 획.
## p_path가 2점 미만이면 기존 스프라이트/폴리곤 비주얼로 폴백 (샘플 도안·구세이브 호환).
## p_lifetime: 사거리(초) — **진 규모 축 × 문양 배율** (spell_system.compute_arrow_lifetime).
## 0 이하면 balance 기준값을 쓴다. p_size_scale도 진 규모다 — 문양 길이가 아니다.
## p_glyph/p_reach: **문양 축** (v1.9). 기본값 BASIC/1.0 = 구세이브·샘플 도안의 곧은 탄.
func setup(p_damage: float, p_rune_type: int, p_status: int, p_status_power: float,
		p_speed: float, p_angle: float, p_size_scale: float,
		p_path: PackedVector2Array = PackedVector2Array(),
		p_pressures: PackedFloat32Array = PackedFloat32Array(),
		p_lifetime: float = 0.0,
		p_glyph: int = Enums.GlyphType.BASIC,
		p_reach: float = 1.0) -> void:
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	direction_angle = p_angle
	rotation = p_angle
	_velocity = Vector2.RIGHT.rotated(p_angle) * p_speed
	if p_lifetime > 0.0:
		_life_left = p_lifetime
	glyph = p_glyph
	reach = p_reach
	_setup_glyph()

	# 머리를 원점에 맞추는 평행이동은 core가 한다 (TECH_SPEC §4.4 tail_line).
	# 진 규모는 굵기(width_mult)로만 — 길이·모양은 플레이어가 그린 그대로다.
	var ink := InkRender.tail_line(p_path, p_pressures, InkRender.unit_px(_balance), {
		"rune_type": p_rune_type,
		"bright": true,
		"width_mult": p_size_scale,
	})
	if ink != null:
		# 먹선은 그린 크기가 곧 크기 — 루트 scale로 한 번 더 키우면 이중 적용된다.
		# 히트박스만 진 규모 배율을 적용 (Shape 노드 스케일. 형상 리소스는 공유물이라 불변)
		($Visual as Polygon2D).visible = false
		($Shape as CollisionShape2D).scale = Vector2.ONE * p_size_scale
		add_child(ink)
		return

	scale = Vector2.ONE * p_size_scale
	var visual := $Visual as Polygon2D
	if _ensure_shared_frames():
		visual.visible = false
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = _shared_frames
		spr.play(StringName(RUNE_ANIM_NAMES.get(p_rune_type, "fire")))
		add_child(spr)
	else:
		visual.color = RUNE_COLORS.get(p_rune_type, Color.WHITE)

static func _ensure_shared_frames() -> bool:
	if not _sheet_checked:
		_sheet_checked = true
		if ResourceLoader.exists(PROJ_SHEET_PATH):
			_shared_frames = SheetLib.build_sprite_frames(load(PROJ_SHEET_PATH), PROJ_ANIMS, 16)
	return _shared_frames != null

## 문양 세기 배분 — reach가 클수록 더 많이 튕기고·더 오래 따라가고·더 많이 뚫는다 (GDD §4.3)
func _setup_glyph() -> void:
	var t := reach_t(_balance, reach)
	match glyph:
		Enums.GlyphType.BOUNCE:
			_bounces_left = roundi(lerpf(1.0, float(_balance.glyph_bounce_max), t))
		Enums.GlyphType.PIERCE:
			_pierces_left = roundi(lerpf(1.0, float(_balance.glyph_pierce_max), t))
		Enums.GlyphType.HOMING:
			_homing_left = lerpf(_balance.glyph_homing_duration_min, 1.0, t) * _life_left

func _physics_process(delta: float) -> void:
	match glyph:
		Enums.GlyphType.BOUNCE:
			_step_bounce(delta)
		Enums.GlyphType.HOMING:
			_step_homing(delta)
	if _consumed:
		return
	position += _velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()

# ── BOUNCE⚡ 벽 반사 ───────────────────────────────────────────
# 🔴 Area2D는 충돌 법선을 안 준다 (body_entered는 "닿았다"만 알려 준다). 그래서 진행 방향으로
# RayCast2D를 뻗어 world 레이어만 검사하고, get_collision_normal()로 반사한다.
# 벽 접촉(_hit_wall)은 반사 횟수가 남아 있는 동안 무시된다 — 소멸은 레이가 결정한다.

func _step_bounce(delta: float) -> void:
	if _ray == null:
		return
	# 레이는 노드 로컬 좌표다. 폴백 비주얼은 루트 scale이 걸려 있으므로 월드→로컬 환산이 필요하다
	var local_scale := maxf(absf(scale.x), 0.001)
	var probe := (_velocity.length() * delta + BOUNCE_PROBE_PAD_PX) / local_scale + _hit_radius_local()
	_ray.target_position = Vector2(probe, 0.0)   # rotation이 항상 진행 방향 → 로컬 +X가 앞
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		return
	var normal := _ray.get_collision_normal()
	if normal.is_zero_approx():
		return
	if _bounces_left <= 0:
		_consume()   # 다 튕겼다 — 벽에 부딪혀 소멸
		return
	_bounces_left -= 1
	var hit_point := _ray.get_collision_point()
	_velocity = _velocity.bounce(normal)
	rotation = _velocity.angle()
	# 벽 표면에 히트박스를 얹어 놓는다 — 파묻히면 다음 프레임에 또 반사한다
	global_position = hit_point + normal * (_hit_radius_local() * local_scale + BOUNCE_PUSH_PX)

## 히트박스 반경 (노드 로컬 단위). CircleShape2D가 기본이지만 룬별 커스텀 씬도 견딘다
func _hit_radius_local() -> float:
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs == null:
		return 0.0
	var r := 0.0
	if cs.shape is CircleShape2D:
		r = (cs.shape as CircleShape2D).radius
	elif cs.shape is RectangleShape2D:
		r = ((cs.shape as RectangleShape2D).size * 0.5).length()
	return r * absf(cs.scale.x)

# ── HOMING∿ 적 추적 ───────────────────────────────────────────

func _step_homing(delta: float) -> void:
	if _homing_left <= 0.0:
		return                     # 지속시간이 끝났다 — 마지막 방향으로 직진
	_homing_left -= delta
	var target := _nearest_enemy()
	if target == null:
		return
	var desired := (target.global_position - global_position).angle()
	var diff := wrapf(desired - _velocity.angle(), -PI, PI)
	var max_turn := _balance.glyph_homing_turn_rate * delta   # 선회 속도 상한 — 즉시 꺾이지 않는다
	_velocity = _velocity.rotated(clampf(diff, -max_turn, max_turn))
	rotation = _velocity.angle()   # 먹선·스프라이트도 진행 방향을 본다 (안 그러면 게걸음한다)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist_sq := _balance.glyph_homing_range_px * _balance.glyph_homing_range_px
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var dist_sq := global_position.distance_squared_to(enemy.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = enemy
	return best

# ── 충돌 ──────────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	_handle_collision(body)

func _on_area_entered(area: Area2D) -> void:
	# 적이 Area2D 히트박스를 쓰는 경우 지원 — 마스크가 이미 world|enemy로 거른다
	_handle_collision(area)

func _handle_collision(node: Node2D) -> void:
	if _consumed:
		return
	if node.is_in_group("enemies"):
		_hit_enemy(node)
		return
	# 적이 아니면 마스크상 world(벽)뿐
	_hit_wall()

func _hit_enemy(node: Node2D) -> void:
	if glyph == Enums.GlyphType.PIERCE:
		var id := node.get_instance_id()
		if _pierced_ids.has(id):
			return                 # 겹쳐 있는 동안의 재진입 — 같은 적을 두 번 때리지 않는다
		_pierced_ids.append(id)
		_deal_damage(node)
		_pierces_left -= 1
		if _pierces_left <= 0:
			_consume()             # 다 뚫었다
		return
	_consume()
	_deal_damage(node)

func _hit_wall() -> void:
	# BOUNCE는 반사 횟수가 남아 있는 한 벽에서 안 죽는다 — 반사는 _step_bounce(RayCast2D)의 몫
	if glyph == Enums.GlyphType.BOUNCE and _bounces_left > 0:
		return
	_consume()

func _deal_damage(node: Node2D) -> void:
	# enemy_hit 발신은 적의 take_hit 내부 책임 (약점 배율 반영 최종 피해 기준 — 리드 확정)
	if node.has_method("take_hit"):
		node.take_hit(damage, rune_type, status, status_power)

func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()
