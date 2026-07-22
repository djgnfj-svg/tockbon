extends Area2D
## 고리 조립 캐리어 — 모듈 B (세션 12~). class_name 없음 — preload로 참조할 것.
##
## 🔴 **진이 곧 투사체다** (고리 모델, 사용자 확정 세션 10). 조립한 마법진(진)이 통째로 조준
## 방향으로 날아가고, **적에 닿는 순간 안의 고리 패턴이 그 자리에서 전개된다** — 껍질이 내용물을
## 착탄점에 배달한다. [[takbon-nested-circle-model]] 껍질=배달.
##   • 발산→ 칸: 그 화살표 방향으로 불 탄환이 퍼진다 (ring_spell_system이 projectile.tscn 스폰)
##   • 응집← 칸: 하나로 모여 불기둥 하나 (pillar.tscn, 많을수록 굵다)
##
## **빈 진도 날아가 몸으로 때린다** (열린 칸을 안 채워 전개할 게 없어도 — RingBoard.can_commit 항상 참).
##   → 캐리어 자체가 착탄 시 damage를 얹는다. 전개는 그 위에 덤이다.
##
## **전개는 적에 닿을 때만.** 벽·수명으로 죽으면 조용히 사라진다 (안 맞으면 전개 없음 — 데모 규칙).
## **회전하지 않는다.** 진은 진행 방향을 보고 빙글 돌지 않는다 (방향은 _velocity만 안다).
##
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

const RADIUS_PX := 18.0       # 히트박스·먹선 반지름 (진 몸) — 세션 13: 9→18 (발사체가 안 보였다)
## 부메랑 선회 각속도(rad/s) — 연출값이라 balance 아닌 여기 상수 (선례: juice의 손맛 수치).
## 8.0 = 180도 유턴에 약 0.4초. 낮추면 크게 휘고 높이면 칼같이 꺾인다 — 사용자가 쏴 보고 조인다.
const BOOMERANG_TURN_RATE := 8.0
const RING_COLOR := Color(0.98, 0.66, 0.28)
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)

const Trail := preload("res://src/spell/carrier_trail.gd")

# ── 속성형 볼 연출 (세션59 설계 §2-A) — 전부 손맛값(스크립트 const, balance 아님). 사용자가 쏴 보고 조인다.
## 🔴 자전은 전부 `_draw` 안의 위상값(_spin)이다 — **node.rotation은 영원히 0** ("회전하지 않는다"
## 계약은 노드 수준 불변. rotation을 돌리면 자식 Shape까지 돌아 계약이 깨진다).
const SPIN_RATE := 0.8            ## 안쪽 장식 자전 각속도(rad/s) — 바깥 진 링은 고정(사용자 확정)
const GLYPH_SPIN_RATIO := 1.0     ## 문양 화살표 자전 배율 (안쪽 대시 링 대비)
const RING_TINT_MIX := 0.45       ## 바깥 진 링 색 = RING_COLOR.lerp(룬색, 이 값) — 0=먹선 주황, 1=룬색
const GLOW_LIGHTEN := 0.45        ## 코어 색 = ui_color.lightened(이 값) — UI 셀 색은 글로우로 쓰기엔 어둡다
const GLOW_ALPHA := 0.85          ## 코어 글로우 기준 알파
const PULSE_PERIOD := 0.9         ## 코어 펄스 주기(s)
const PULSE_SCALE_AMP := 0.12     ## 펄스 크기 진폭 (기준 배율 대비 ±)
const PULSE_ALPHA_AMP := 0.18     ## 펄스 알파 진폭
## body_radius 대비 코어 반지름 — 글로우가 히트박스보다 **커 보이면 안 된다**
## (세50 "보이는 크기 ≠ 맞는 크기" 함정의 시각 버전 — 스침 판정이 거짓말이 된다)
const CORE_RADIUS_FRAC := 0.62
const GLOW_TEX_SIZE := 64         ## 정적 캐시 radial 텍스처 픽셀 폭
const INNER_DASH_COUNT := 7       ## 안쪽 대시 링 조각 수 — 매끈한 원은 돌아도 안 보인다, 대시여야 읽힌다
const INNER_DASH_FILL := 0.55     ## 대시 조각의 채움 비율 (나머지는 틈)
const TRAIL_LIFE := 0.25          ## 트레일 포인트 수명(s)
const TRAIL_WIDTH_FRAC := 0.9     ## 트레일 굵기 = body_radius × 이 값

## 착탄 = 안의 고리를 편다. ring_spell_system이 받아 발산 탄환·응집 기둥을 스폰한다.
## travel = 탄이 가던 방향 (전개 회전 기준).
signal deployed(ring: Array, at: Vector2, travel: float)

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0

var _ring: Array = []
var _velocity := Vector2.ZERO
var _life_left: float = 0.0
var _consumed := false

# 🔴 비행 경로 (세션48). motion=STRAIGHT면 아래 전부 안 쓰이고 예전과 픽셀 동일하게 돈다.
var _motion: int = Enums.JinMotion.STRAIGHT
var _scale: float = 1.0
var _age: float = 0.0            # 발사 후 경과 — 나선 위상·부메랑 반환 시점의 기준
var _lifetime: float = 0.0       # 처음 받은 수명 (부메랑이 반환 시점을 재는 데 쓴다)
var _origin := Vector2.ZERO      # 발사 지점 — 부메랑이 돌아올 목표
var _spiral_amp: float = 0.0
var _spiral_period: float = 0.45
var _turn_ratio: float = 0.5

# 연출 상태 (세션59) — 전부 시각. 헤드리스에선 _draw가 안 돌 뿐 위상 변수는 무해.
var _spin: float = 0.0            ## 안쪽 장식 자전 위상 — _draw 전용, node.rotation 아님
var _glow: Sprite2D = null        ## 코어 글로우 (CoreGlow — _ready가 코드로 만든다)
var _glow_base: float = 1.0       ## 펄스의 기준 scale
var _trail_spawned := false

## 코어 글로우 텍스처 — 정적 캐시 radial GradientTexture2D (전 캐리어 공유, 셰이더·아트 0).
static var _glow_tex: GradientTexture2D = null


static func _core_glow_tex() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = GLOW_TEX_SIZE
		t.height = GLOW_TEX_SIZE
		_glow_tex = t
	return _glow_tex


func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# 룬색 에너지 코어 — ADD 블렌드라 배경 위에서 빛으로 읽힌다 (설계 §2-A)
	_glow = Sprite2D.new()
	_glow.name = "CoreGlow"
	_glow.texture = _core_glow_tex()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)
	_refresh_glow()


## p_ring: 8칸 배열 (RingBoard.G_GATHER / G_RADIATE / GLYPH_NONE). p_angle: 조준각.
func setup(p_ring: Array, p_angle: float, p_speed: float, p_lifetime: float,
		p_damage: float, p_rune_type: int, p_status: int, p_status_power: float) -> void:
	_ring = p_ring.duplicate()
	_velocity = Vector2.RIGHT.rotated(p_angle) * p_speed
	_life_left = maxf(p_lifetime, 0.05)
	_lifetime = _life_left
	_origin = global_position
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	_apply_body_radius()
	_refresh_glow()
	# 트레일은 지연 스폰 — set_motion(규모)이 setup **뒤에** 오므로, 굵기가 최종 body_radius를 보게.
	call_deferred(&"_spawn_trail")
	queue_redraw()


## 🔴 비행 경로·규모를 얹는다 (세션48). setup **뒤에** 부른다 — 안 부르면 예전 그대로 직진 1.0배라
## 옛 호출자·테스트가 그대로 돈다. 진(JinDef)이 없는 매직볼·옛 도안이 정확히 그 경로다.
func set_motion(p_motion: int, p_scale: float, p_spiral_amp: float,
		p_spiral_period: float, p_turn_ratio: float) -> void:
	_motion = p_motion
	_scale = maxf(p_scale, 0.1)
	_spiral_amp = p_spiral_amp
	_spiral_period = maxf(p_spiral_period, 0.05)
	_turn_ratio = clampf(p_turn_ratio, 0.05, 0.95)
	_apply_body_radius()
	_refresh_glow()
	queue_redraw()


## 히트박스를 진 몸 반지름에 맞춘다 (형상 리소스는 공유물 — scale로만 건드린다).
func _apply_body_radius() -> void:
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		cs.scale = Vector2.ONE * (body_radius() / (cs.shape as CircleShape2D).radius)


## 진 몸 반지름 — 규모가 곱해진다. 먹선(_draw)과 히트박스가 **같은 함수**를 봐야 갈라지지 않는다
## (선례: ring_power의 is_stable — 보이는 크기와 맞는 크기가 다르면 아무도 못 알아챈다).
func body_radius() -> float:
	return RADIUS_PX * _scale


## 코어 글로우의 색·기준 크기 갱신 — _ready(생성)·setup(룬 확정)·set_motion(규모 확정)이 부른다.
## 색은 Db `ui_color`의 **파생**(lightened)이다 — 새 색 테이블이 아니라 단일 소스의 변환 (설계 §2-A).
func _refresh_glow() -> void:
	if _glow == null:
		return   # setup이 add_child(_ready)보다 먼저 불린 컨텍스트(헤드리스) — _ready가 다시 부른다
	var col := _rune_color().lightened(GLOW_LIGHTEN)
	col.a = GLOW_ALPHA
	_glow.modulate = col
	_glow_base = body_radius() * CORE_RADIUS_FRAC * 2.0 / float(GLOW_TEX_SIZE)
	_glow.scale = Vector2.ONE * _glow_base


## 트레일 스폰 — **형제**(spell_system의 자식)로 단다. 캐리어가 착탄으로 죽어도 잔상이 페이드하게
## (설계 §2-C). 🔴 트레일은 player_projectiles 그룹 무가입 — 테스트가 이 그룹으로 탄을 센다.
func _spawn_trail() -> void:
	# 🔴 null 가드 — 트리 밖 setup(헤드리스가 setup만 부르는 경우)·부모 없음이면 조용히 생략
	if _trail_spawned or _consumed or not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null:
		return
	_trail_spawned = true
	var trail := Trail.new()
	parent.add_child(trail)
	trail.setup(self, _rune_color(), body_radius() * TRAIL_WIDTH_FRAC, TRAIL_LIFE)


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	_age += delta
	match _motion:
		Enums.JinMotion.SPIRAL:
			# 진행축에 **수직**으로 사인 흔들림 — 경로가 넓어져 밀집한 적을 훑는다.
			# 위치를 직접 찍지 않고 속도에 수직 성분을 더한다(충돌이 매 프레임 연속으로 잡히게).
			var perp := _velocity.orthogonal().normalized()
			var w := TAU / _spiral_period
			var swing := perp * (_spiral_amp * _scale) * w * cos(w * _age)
			position += (_velocity + swing) * delta
		Enums.JinMotion.BOOMERANG:
			# 반환 시점을 넘기면 발사 지점 쪽으로 속도를 꺾는다 — 유턴이 곡선으로 그려진다.
			# 놓친 적을 **돌아오는 길에** 한 번 더 만난다(진짜 두 번째 기회).
			if _age >= _lifetime * _turn_ratio:
				# 🔴 속도를 **회전**시킨다 — `lerp`로 하면 안 된다. 되돌아올 방향은 지금 방향의
				# 거의 정반대라 두 벡터가 상쇄돼 **속도가 0으로 죽고 진이 공중에 멈춘다**
				# (세션48에 실제로 그렇게 났다: 최대거리 = 끝거리 218.6px로 제자리). 각도만 돌리면
				# 속력이 보존돼 나간 만큼의 기세로 돌아온다.
				var speed := _velocity.length()
				var want := (_origin - global_position).angle()
				var turned := rotate_toward(_velocity.angle(), want, BOOMERANG_TURN_RATE * delta)
				_velocity = Vector2.from_angle(turned) * speed
			position += _velocity * delta
		_:
			position += _velocity * delta
	# 연출 구동 (세션59) — 자전 위상·코어 펄스. node.rotation은 건드리지 않는다.
	_spin += SPIN_RATE * delta
	if _glow != null:
		var ph := sin(TAU * _age / PULSE_PERIOD)
		_glow.scale = Vector2.ONE * (_glow_base * (1.0 + PULSE_SCALE_AMP * ph))
		_glow.modulate.a = clampf(GLOW_ALPHA + PULSE_ALPHA_AMP * ph, 0.0, 1.0)
	queue_redraw()
	_life_left -= delta
	if _life_left <= 0.0:
		_die_without_deploy()   # 수명 끝 = 못 맞음 → 전개 없이 사라진다


func _on_body_entered(body: Node2D) -> void:
	_handle(body)


func _on_area_entered(area: Area2D) -> void:
	_handle(area)


func _handle(node: Node2D) -> void:
	if _consumed:
		return
	if node.is_in_group("enemies"):
		_hit_enemy(node)
	else:
		_die_without_deploy()   # 마스크상 적 아니면 벽 — 못 맞음 처리


## 적 착탄 — 진 몸으로 때리고, 그 자리에서 고리를 전개한다.
func _hit_enemy(node: Node2D) -> void:
	_consumed = true
	if node.has_method("take_hit"):
		node.take_hit(damage, rune_type, status, status_power)
	# "탄이 박혔다" 연출 신호 (세션59 설계 §3) — 적 착탄 1회만. 벽·수명 소멸(_die_without_deploy)엔 없다.
	EventBus.spell_impact.emit(global_position, rune_type)
	var travel := _velocity.angle() if not _velocity.is_zero_approx() else 0.0
	deployed.emit(_ring, global_position, travel)
	queue_free()


func _die_without_deploy() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()


## 진 = **날아가는 마법진** → 세션59: **속성형 볼**. 바깥 이중 진 링(먹선 정체성, 룬색으로 살짝
## 틴트)은 고정이고, 안쪽 대시 링·문양 화살표만 `_spin` 위상으로 천천히 자전한다(사용자 확정).
## 중심 삼각 룬은 삭제 — CoreGlow 볼이 그 자리를 차지한다. node.rotation은 영원히 0.
func _draw() -> void:
	var r := body_radius()   # 🔴 히트박스와 같은 함수 — 보이는 크기 ≠ 맞는 크기가 되면 아무도 못 알아챈다
	var ring_col := RING_COLOR.lerp(_rune_color(), RING_TINT_MIX)
	# 글로우(은은한 후광) — 배경과 상관없이 눈에 띄게
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(ring_col, 0.30), 6.0, true)
	# 바깥 진 링 — **고정, 자전 없음** (사용자 확정: 바깥 진은 돌지 않는다)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, ring_col, 2.5, true)
	# 안쪽 대시 링 — _spin 위상 자전 (매끈한 원은 돌아도 안 보인다 — 대시여야 자전이 읽힌다)
	var dash_arc := TAU / float(INNER_DASH_COUNT)
	for d in INNER_DASH_COUNT:
		var a0 := _spin + dash_arc * float(d)
		draw_arc(Vector2.ZERO, r * 0.58, a0, a0 + dash_arc * INNER_DASH_FILL, 6,
			Color(ring_col, 0.85), 1.5, true)
	# 문양 화살표 — 응집=안쪽 / 발산=바깥 (조립한 칸 그대로) · _spin으로 천천히 자전
	var n := _ring.size()
	if n <= 0:
		return
	for k in n:
		var g := int(_ring[k])
		if g < 0:
			continue
		var ang := TAU * float(k) / float(n) - PI / 2.0 + _spin * GLYPH_SPIN_RATIO
		var outward := Vector2.from_angle(ang)
		var p := outward * (r * 0.78)
		var dir := -outward if g == Enums.GlyphCode.GATHER else outward   # 응집만 안쪽 · 발산·관통은 바깥
		var a := p - dir * (r * 0.14)
		var b := p + dir * (r * 0.14)
		draw_line(a, b, ring_col, 1.8, true)
		draw_line(b, b - dir.rotated(0.5) * (r * 0.1), ring_col, 1.8, true)
		draw_line(b, b - dir.rotated(-0.5) * (r * 0.1), ring_col, 1.8, true)


## 룬 색 — Db에서 읽고, 없으면 폴백. (오토로드 없는 컨텍스트도 견딘다)
func _rune_color() -> Color:
	var db := get_node_or_null(^"/root/Db")
	if db != null:
		var rune := db.get_rune(rune_type) as RuneDef
		if rune != null:
			return rune.ui_color
	return RUNE_FALLBACK
