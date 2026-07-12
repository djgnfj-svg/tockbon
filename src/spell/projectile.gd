extends Area2D
## 투사체 — 모듈 B (TECH_SPEC §1: 레이어 4=player_projectile, 마스크 1|3=world|enemy).
## 파라미터 주입은 spell_system.setup() 경유. class_name 없음 — preload로 참조할 것.
## 적 노드 계약: 그룹 "enemies" + take_hit(damage, rune_type, status, status_power).

const SheetLib := preload("res://src/core/sheet_lib.gd")

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

var damage: float = 0.0
var rune_type: int = Enums.RuneType.FIRE
var status: int = Enums.Status.NONE
var status_power: float = 0.0
var direction_angle: float = 0.0

var _balance: BalanceData = preload("res://data/balance.tres")
var _velocity := Vector2.ZERO
var _life_left: float = 0.0
var _consumed := false

func _ready() -> void:
	_life_left = _balance.projectile_lifetime_sec
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(p_damage: float, p_rune_type: int, p_status: int, p_status_power: float,
		p_speed: float, p_angle: float, p_size_scale: float) -> void:
	damage = p_damage
	rune_type = p_rune_type
	status = p_status
	status_power = p_status_power
	direction_angle = p_angle
	rotation = p_angle
	scale = Vector2.ONE * p_size_scale
	_velocity = Vector2.RIGHT.rotated(p_angle) * p_speed
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

func _physics_process(delta: float) -> void:
	position += _velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	_handle_collision(body)

func _on_area_entered(area: Area2D) -> void:
	# 적이 Area2D 히트박스를 쓰는 경우 지원 — 마스크가 이미 world|enemy로 거른다
	_handle_collision(area)

func _handle_collision(node: Node2D) -> void:
	if _consumed:
		return
	_consumed = true
	if node.is_in_group("enemies"):
		# enemy_hit 발신은 적의 take_hit 내부 책임 (약점 배율 반영 최종 피해 기준 — 리드 확정)
		if node.has_method("take_hit"):
			node.take_hit(damage, rune_type, status, status_power)
	# 적이 아니면 마스크상 world(벽)뿐 — 어느 쪽이든 소멸
	queue_free()
