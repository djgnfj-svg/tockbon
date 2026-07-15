extends Area2D
## 투사체 — 모듈 B (TECH_SPEC §1: 레이어 4=player_projectile, 마스크 1|3=world|enemy).
## 파라미터 주입은 spell_system.setup() 경유. class_name 없음 — preload로 참조할 것.
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).
##
## **v2.0 (TECH_SPEC §4.0-a)**
## - 🔴 **몸이 진이다.** 그린 진(+룬) 먹선이 그대로 날아가고 **히트박스가 진 반지름**을 따른다.
##   v1.9까지는 문양 획이 날아가고 히트박스는 **반지름 5의 원 고정**이었다 — 그린 획은 그 위에
##   얹힌 **그림일 뿐**이었다 (세션 11이 "아무도 안 정하는 것"으로 남긴 빈칸을 진이 채운다)
## - 🔴 **효과는 여러 개가 동시에 얹힌다.** v1.9의 `glyph` 하나(=이 탄의 방식)가 아니라
##   **효과 사전**을 받는다. 팅김⚡ + 관통‖ = 튕기면서 뚫는다
## - 🔴 **회전하지 않는다.** 마법진이 진행 방향을 보고 빙글빙글 돌면 그건 진이 아니다.
##   방향은 `_velocity`만 안다 (폴백 스프라이트일 때만 회전한다 — 혜성은 진행 방향을 봐야 하므로)
##
## 🔴 문양은 **위력·탄 크기·기준 사거리를 건드리지 않는다** — 그건 진의 축이다. 사거리는 **배율만** 준다.
## 상태이상 종류·세기도 안 건드린다 — 그건 룬의 축이다.

const SheetLib := preload("res://src/core/sheet_lib.gd")
const InkRender := preload("res://src/core/ink_render.gd")
const ShockwaveScene := preload("res://src/spell/shockwave.tscn")

const RUNE_COLORS: Dictionary = {
	Enums.RuneType.FIRE: Color(1.0, 0.55, 0.1),    # 불 = 주황
	Enums.RuneType.WATER: Color(0.25, 0.55, 1.0),  # 물 = 파랑
	Enums.RuneType.WIND: Color(0.65, 0.95, 0.45),  # 바람 = 연두
}

## 룬 투사체 시트 (ART_SPEC P5) — 우향 혜성형 2프레임. **먹선 진이 없을 때만 쓰는 폴백이다**
## (샘플 도안·구세이브처럼 strokes가 비어 있는 경우)
const PROJ_SHEET_PATH := "res://assets/sprites/effects/projectiles.png"
const PROJ_ANIMS := {
	"fire": [0, 2, 10.0],
	"water": [4, 2, 10.0], "wind": [6, 2, 10.0],
}
const RUNE_ANIM_NAMES := {
	Enums.RuneType.FIRE: "fire",
	Enums.RuneType.WATER: "water",
	Enums.RuneType.WIND: "wind",
}
## 시트는 전 투사체 공유 — 1회만 빌드 (탄막 다발 스폰 대비)
static var _shared_frames: SpriteFrames = null
static var _sheet_checked: bool = false

## 씬의 CollisionShape2D가 쥔 CircleShape2D 반지름. 히트박스는 scale로만 키운다
## (형상 리소스는 씬들이 공유하는 물건이라 건드리면 안 된다)
const BASE_HIT_RADIUS := 5.0

## 벽 반사 구현 상수 — **밸런스 수치가 아니라 물리 여유값**이다.
## Area2D는 충돌 법선을 안 주므로 진행 방향으로 RayCast2D를 뻗어 벽을 먼저 잡는다. 레이 길이는
## "이번 프레임 이동거리 + 히트박스 반경 + 아래 여유" — 히트박스가 벽에 닿기 전에 잡아야
## 레이 시점(중심)이 벽 안으로 들어가지 않는다 (안에서 시작한 레이는 그 벽을 못 본다).
const BOUNCE_PROBE_PAD_PX := 2.0
## 반사 직후 벽에서 밀어내는 거리 — 벽에 파묻혀 매 프레임 재반사하는 걸 막는다
const BOUNCE_PUSH_PX := 1.0

## 🔴 **중첩 진 (재귀) — 껍질이 열린다.** 이 탄이 죽는 순간(착탄·벽·수명 끝) `_design.children`이
## 있으면 그 자리에서 각자 전개된다. spell_system이 이 시그널을 받아 자식 진을 새 탄으로 스폰한다.
signal deploy_children(children: Array, at: Vector2, travel_angle: float)

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0
## 🔴 복합 룬 (N개, TRUTH §4) — 이 탄이 싣고 가는 모든 룬의 히트 정보 [{rune_type, status, status_power}].
## 착탄 시 primary(=rune_type)가 피해+상태, 나머지는 피해 0으로 상태만 얹는다 (적 계약 무변경).
## 비어 있으면 단일 룬(primary 하나)으로 본다 — 하위호환.
var rune_hits: Array = []
## 발사 시점의 각도. **진행 방향이 아니다** — 유도·반사는 _velocity가 바뀐다
var direction_angle: float = 0.0
## **v2.0 문양 축** — {GlyphType: Σreach}. 여러 효과가 **동시에** 얹힌다 (spell_system.compile_effects)
var effects: Dictionary = {}

var _balance: BalanceData = preload("res://data/balance.tres")
var _velocity := Vector2.ZERO
var _life_left: float = 0.0
var _consumed := false
## 남은 벽 반사 횟수 (팅김⚡)
var _bounces_left: int = 0
## 팅김을 **가졌는가** — 횟수를 다 써도 "벽에서 죽는" 판정은 레이가 맡는다 (_hit_wall이 아니라)
var _has_bounce := false
## 남은 관통 수 (관통‖) — 0이 되면 소멸
var _pierces_left: int = 0
## 이미 뚫은 적 — Area2D는 겹쳐 있는 동안 재진입하므로 같은 적을 두 번 때리지 않게 기억한다
var _pierced_ids: Array[int] = []
## 남은 추적 지속시간 (유도∿). 0 이하가 되면 마지막 방향으로 직진
var _homing_left: float = 0.0
## 먹선 진이 몸일 땐 **회전하지 않는다.** 폴백 스프라이트(혜성)일 때만 진행 방향을 본다
var _rotates := false
var _ray: RayCast2D = null
## 착탄 충격파(v2.1)의 재료 — 진 위 화살표들의 **자리와 방향**이 여기 들어 있다
var _design: SpellDesign = null
## 충격파는 **한 번만** 뿜는다 — 관통탄이 적마다 뿜으면 "여러 적을 뚫는다"는 보상 위에
## 충격파까지 얹혀 **이중 보상**이 된다
var _shock_fired := false

func _ready() -> void:
	_life_left = _balance.projectile_lifetime_sec
	_ray = get_node_or_null("Ray") as RayCast2D
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


# ── 문양 세기 축 — reach → 정규화 t → 각 효과의 세기 ──────────────────────
# spell_system(사거리 배율)과 투사체(반사·관통·추적)가 **같은 t**를 쓴다. 공식은 여기 하나뿐이다.

## t = inverse_lerp(glyph_reach_min, glyph_reach_max, reach) — 아래 전부의 입력 (TECH_SPEC §4.0-a)
static func reach_t(balance: BalanceData, p_reach: float) -> float:
	return clampf(inverse_lerp(balance.glyph_reach_min, balance.glyph_reach_max, p_reach), 0.0, 1.0)

## 사거리 **배율** — 진이 준 기준 사거리에 곱해진다. 축을 뺏지 않고 배율만 준다 (GDD §4.3)
static func range_mult(balance: BalanceData, p_reach: float) -> float:
	return lerpf(balance.glyph_range_min, balance.glyph_range_max, reach_t(balance, p_reach))


## p_effects: **효과 사전** {GlyphType: Σreach} — 한 탄에 여러 개가 얹힌다 (v2.0).
## p_lifetime: 사거리(초) = 진 규모 × 문양 배율 (spell_system.compute_design_lifetime).
## p_design: **탄의 몸** — 이 진(+룬)의 먹선이 그대로 날아가고 히트박스가 진 반지름을 따른다.
##   null이거나 strokes가 비면 기존 스프라이트/폴리곤으로 폴백 (샘플 도안·구세이브 호환).
func setup(p_damage: float, p_rune_type: int, p_status: int, p_status_power: float,
		p_speed: float, p_angle: float,
		p_effects: Dictionary = {},
		p_lifetime: float = 0.0,
		p_design: SpellDesign = null,
		p_rune_hits: Array = []) -> void:
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	rune_hits = p_rune_hits
	direction_angle = p_angle
	_velocity = Vector2.RIGHT.rotated(p_angle) * p_speed
	if p_lifetime > 0.0:
		_life_left = p_lifetime
	effects = p_effects
	_setup_effects()
	_setup_body(p_design, p_rune_type)


## 효과 세기 배분 — 각 효과는 **자기 reach 합**으로 세기가 정해진다 (GDD §4.3).
## 같은 글자를 여럿 그으면 합산돼 더 세다 (팅김 둘 = 더 많이 튕긴다).
func _setup_effects() -> void:
	if effects.has(Enums.GlyphType.BOUNCE):
		_has_bounce = true
		_bounces_left = roundi(lerpf(1.0, float(_balance.glyph_bounce_max),
			reach_t(_balance, effects[Enums.GlyphType.BOUNCE])))
	if effects.has(Enums.GlyphType.PIERCE):
		_pierces_left = roundi(lerpf(1.0, float(_balance.glyph_pierce_max),
			reach_t(_balance, effects[Enums.GlyphType.PIERCE])))
	if effects.has(Enums.GlyphType.HOMING):
		_homing_left = lerpf(_balance.glyph_homing_duration_min, 1.0,
			reach_t(_balance, effects[Enums.GlyphType.HOMING])) * _life_left
	# 추진 (v2.2) — 탄이 빠르게 날아간다. _velocity는 setup()에서 이미 세워졌으니 크기만 키운다.
	# 방향은 그대로. 길게 그은 추진일수록 더 빠르다 (reach_t).
	if effects.has(Enums.GlyphType.THRUST):
		_velocity *= lerpf(_balance.glyph_thrust_speed_min, _balance.glyph_thrust_speed_max,
			reach_t(_balance, effects[Enums.GlyphType.THRUST]))


## 탄의 몸 = **진**(v2.0). 먹선과 히트박스가 **같은 반지름**을 쓴다 — 갈라지면
## 보이는 것과 맞는 것이 어긋나고, 그건 이 게임의 정체성이 깨지는 것이다.
func _setup_body(design: SpellDesign, p_rune_type: int) -> void:
	_design = design
	var ink: Node2D = null
	if design != null:
		# roles 기본값(CIRCLE_ROLES) = 진 + 룬. **문양 획은 안 붙는다** — 문양은 효과이지 몸이 아니다.
		# build_design은 진 중심을 원점에 두므로 그대로 얹으면 탄의 중심이 곧 진의 중심이다.
		ink = InkRender.build_design(design,
			InkRender.unit_px(_balance) * _balance.projectile_circle_scale,
			{"bright": true})
	if ink != null:
		($Visual as Polygon2D).visible = false
		_set_hit_radius(_design_radius_px(design))
		add_child(ink)
		return

	# ── 폴백: strokes가 없는 샘플·구세이브 도안 — 기성 혜성 스프라이트가 진행 방향을 보고 날아간다.
	# 그릴 진은 없어도 **진 크기는 있다** — 히트박스는 여전히 진을 따른다 (루트 scale로 한 번에).
	_rotates = true
	rotation = direction_angle
	if design != null:
		scale = Vector2.ONE * (_design_radius_px(design) / BASE_HIT_RADIUS)
	var visual := $Visual as Polygon2D
	if _ensure_shared_frames():
		visual.visible = false
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = _shared_frames
		spr.play(StringName(RUNE_ANIM_NAMES.get(p_rune_type, "fire")))
		add_child(spr)
	else:
		visual.color = RUNE_COLORS.get(p_rune_type, Color.WHITE)


## 진 반지름 → 월드 px. **spell_system.compute_radius_px와 같은 공식이다** (TECH_SPEC §4.0-a).
## ⚠ 여기서만 계산하고 spell_system이 또 계산하면 언젠가 갈라진다 — 둘 다 balance의 같은 두
## 노브(projectile_circle_scale·projectile_min_radius_px)만 읽는다.
func _design_radius_px(design: SpellDesign) -> float:
	var r := design.circle_radius * 0.5 * InkRender.unit_px(_balance) \
		* _balance.projectile_circle_scale
	return maxf(r, _balance.projectile_min_radius_px)


## 히트박스 반경(px)을 맞춘다. 형상 리소스(CircleShape2D)는 씬 간 공유물이라 **scale로만** 만진다
func _set_hit_radius(radius_px: float) -> void:
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs == null:
		return
	cs.scale = Vector2.ONE * (radius_px / BASE_HIT_RADIUS)


static func _ensure_shared_frames() -> bool:
	if not _sheet_checked:
		_sheet_checked = true
		if ResourceLoader.exists(PROJ_SHEET_PATH):
			_shared_frames = SheetLib.build_sprite_frames(load(PROJ_SHEET_PATH), PROJ_ANIMS, 16)
	return _shared_frames != null


func _physics_process(delta: float) -> void:
	# 🔴 효과는 **동시에** 산다 (v2.0) — match로 하나만 고르면 팅김+유도가 서로를 지운다
	if _has_bounce:
		_step_bounce(delta)
	if _homing_left > 0.0:
		_step_homing(delta)
	if _consumed:
		return
	position += _velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_consume()   # 수명 끝 = 껍질이 열리는 순간이기도 하다 → _consume 한 곳으로 모은다

# ── 팅김⚡ 벽 반사 ───────────────────────────────────────────
# 🔴 Area2D는 충돌 법선을 안 준다 (body_entered는 "닿았다"만 알려 준다). 그래서 진행 방향으로
# RayCast2D를 뻗어 world 레이어만 검사하고, get_collision_normal()로 반사한다.
# 벽 접촉(_hit_wall)은 반사 횟수가 남아 있는 동안 무시된다 — 소멸은 레이가 결정한다.

func _step_bounce(delta: float) -> void:
	if _ray == null or _velocity.is_zero_approx():
		return
	# 🔴 **v2.0: 탄이 회전하지 않으므로 로컬 +X가 진행 방향이 아니다.** 레이를 속도 방향으로
	# 직접 겨눈다 — v1.9의 Vector2(probe, 0)를 그대로 두면 반사가 조용히 엉뚱한 데를 본다.
	var local_scale := maxf(absf(scale.x), 0.001)
	var reach_px := _velocity.length() * delta + BOUNCE_PROBE_PAD_PX + _hit_radius_local() * local_scale
	_ray.target_position = _velocity.normalized().rotated(-rotation) * (reach_px / local_scale)
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
	if _rotates:
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

# ── 유도∿ 적 추적 ───────────────────────────────────────────

func _step_homing(delta: float) -> void:
	_homing_left -= delta
	var target := _nearest_enemy()
	if target == null:
		return
	var desired := (target.global_position - global_position).angle()
	var diff := wrapf(desired - _velocity.angle(), -PI, PI)
	var max_turn := _balance.glyph_homing_turn_rate * delta   # 선회 속도 상한 — 즉시 꺾이지 않는다
	_velocity = _velocity.rotated(clampf(diff, -max_turn, max_turn))
	if _rotates:
		rotation = _velocity.angle()   # 혜성 폴백은 진행 방향을 봐야 한다 (안 그러면 게걸음한다)

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

# ── 착탄 충격파 (v2.1, TECH_SPEC §4.0-b) ──────────────────────
# 🔴 **화살표 하나 = 충격파 하나.** **탄이 곧 진**이므로 적에 닿는 순간 진이 히트 지점에 놓이고,
# 진 위의 화살표들이 **각자 제자리에서 제 방향으로** 뿜는다 — 종이 위 배치가 곧 착탄 그림이다.
#
# **기둥을 여기서 만들지 않는다.** 룬을 겨눈 화살표들은 중심에서 **저절로 만나** 기둥이 되고
# (shockwave._collide_with), 밖을 겨눈 것들은 영영 안 만난다.

## **회전량은 하나다.** 위치와 방향에 **똑같이** 적용된다 — 갈라지면 보이는 배치와
## 터지는 그림이 어긋난다.
##
## 🔴 **회전은 여기서 딱 한 번 건다.** `ArrowData.direction`·`origin`은 **캔버스 절대각**이고
## (종이 위쪽 = UP_AXIS = -π/2), 여기서 "탄이 가던 방향"으로 옮긴다. 세션 7의 "모든 문양이
## 90도 틀어져 나갔다"는 버그가 **이 축을 두 번 뺀** 것이었다. 미리 빼 두지 말 것.
func _shock_rotation() -> float:
	# 유도∿로 꺾였으면 **꺾인 뒤의 방향**이다 — "탄이 가던 방향"이지 발사각이 아니다
	var travel := _velocity.angle() if not _velocity.is_zero_approx() else direction_angle
	return travel - InkRender.UP_AXIS


func _fire_shockwaves() -> void:
	if _shock_fired or _design == null:
		return
	_shock_fired = true
	var parent := get_parent()
	if parent == null:
		return
	var rotate_by := _shock_rotation()
	var radius_px := _design_radius_px(_design)
	for arrow: ArrowData in _design.arrows:
		# ⚠ **미정 (사용자: "아직 미정")**: 팅김·유도·관통 획도 충격파를 뿜는지.
		# 일단 **곧은 화살표(BASIC)만** — 지금 아무 일도 안 하는 값이라 죽은 값이 살아난다
		if arrow.glyph != Enums.GlyphType.BASIC:
			continue
		var wave := ShockwaveScene.instantiate()
		# 🔴 **위치·setup을 트리에 넣기 전에 끝낸다.** 여기는 물리 콜백 안이라 Area2D를 즉시
		# add_child 하면 "Can't change this state while flushing queries"가 뜨고 **조용히
		# 충격파가 안 생긴다.** 부모 로컬 좌표로 미리 앉힌 뒤 지연 추가한다
		var at := global_position + (arrow.origin * radius_px).rotated(rotate_by)
		wave.position = _to_parent_local(parent, at)
		wave.call(&"setup", damage, rune_type, status, status_power,
			arrow.direction + rotate_by)
		parent.call_deferred(&"add_child", wave)


## 월드 좌표 → 부모 로컬. 부모가 Node2D가 아니면(테스트 홀더 등) 월드 = 로컬로 본다
static func _to_parent_local(parent: Node, at: Vector2) -> Vector2:
	var n2d := parent as Node2D
	return n2d.to_local(at) if n2d != null else at


func _hit_enemy(node: Node2D) -> void:
	_fire_shockwaves()
	if _pierces_left > 0:
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
	# 팅김은 반사 횟수가 남아 있는 한 벽에서 안 죽는다 — 반사는 _step_bounce(RayCast2D)의 몫
	if _has_bounce and _bounces_left > 0:
		return
	_consume()

func _deal_damage(node: Node2D) -> void:
	# enemy_hit 발신은 적의 take_hit 내부 책임 (약점 배율 반영 최종 피해 기준 — 리드 확정)
	if not node.has_method("take_hit"):
		return
	# 🔴 복합 — primary(=rune_type)가 피해+자기 상태를 얹고, 나머지 룬은 **피해 0**으로 상태만
	# 얹는다 (take_hit의 `if dmg>0` 덕에 피해·enemy_hit 이중 계산 없음 — 적 계약 무변경).
	node.take_hit(damage, rune_type, status, status_power)
	for rh: Dictionary in rune_hits:
		if int(rh.get("rune_type", -1)) == rune_type:
			continue   # primary는 위에서 이미 얹었다
		node.take_hit(0.0, int(rh.rune_type), int(rh.status), float(rh.status_power))

func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	# 🔴 껍질이 열린다 — 품은 진들이 이 자리에서 각자 전개된다 (재귀, TRUTH §4).
	# 방위 기준 = **탄이 가던 방향** (유도로 꺾였으면 꺾인 뒤). 종이 위쪽이 그쪽을 향한다.
	if _design != null and not _design.children.is_empty():
		var travel := _velocity.angle() if not _velocity.is_zero_approx() else direction_angle
		deploy_children.emit(_design.children, global_position, travel)
	queue_free()
