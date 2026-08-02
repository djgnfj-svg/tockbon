extends Area2D
## 적 투사체 — 플레이어 탄(`src/spell/projectile.gd`)과 별개인 **최소** 탄(직진·수명·플레이어 히트만).
## 그쪽은 발사 계약(assembly·effects·rune_hits)에 물려 있어 재사용하면 같이 끌려온다.
## 🔴 물리 = layer 0 / mask 3(world+player, enemy_projectile.tscn) — **mask에 2가 빠지면 맞았는데 안 아프고 에러도 안 난다.**
## 수치(피해·속도·수명)는 전부 `setup` 주입 — 코드에 수치 0.

const SheetLib := preload("res://src/core/sheet_lib.gd")

## wind 혜성 2프레임 — projectile.gd `PROJ_ANIMS["wind"]`와 같은 시트·같은 굽기.
const PROJ_SHEET_PATH := "res://assets/sprites/effects/projectiles.png"
const WIND_ANIM := {"wind": [6, 2, 10.0]}
## 시트는 전 탄 공유 — 1회만 빌드.
static var _shared_frames: SpriteFrames = null
static var _sheet_checked: bool = false

var _damage: float = 0.0
var _velocity := Vector2.ZERO
var _life_left: float = 0.0
var _consumed := false


func _ready() -> void:
	# "enemies"가 아니다 — 플레이어 탄이 때리면 안 된다.
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)


## 혜성형이라 진행 방향으로 회전한다(projectile.gd 폴백 스프라이트와 같은 규약).
func setup(dir: Vector2, damage: float, speed: float, lifetime: float) -> void:
	_damage = damage
	_velocity = dir.normalized() * speed
	_life_left = lifetime
	rotation = dir.angle()
	_setup_visual()


func _setup_visual() -> void:
	if _ensure_shared_frames():
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = _shared_frames
		spr.play(&"wind")
		add_child(spr)
	else:
		# 시트가 없으면 탄이 안 보인 채 아프기만 한다 — 침묵 대신 경고를 남긴다.
		push_warning("enemy_projectile: 투사체 시트를 못 찾았다 (%s)" % PROJ_SHEET_PATH)


static func _ensure_shared_frames() -> bool:
	if not _sheet_checked:
		_sheet_checked = true
		if ResourceLoader.exists(PROJ_SHEET_PATH):
			_shared_frames = SheetLib.build_sprite_frames(load(PROJ_SHEET_PATH), WIND_ANIM, 16)
	return _shared_frames != null


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	position += _velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_consume()


func _on_body_entered(body: Node2D) -> void:
	if _consumed:
		return
	if body.is_in_group("player"):
		# 구르는 중이면 관통·무해 (구르기 = 무적 계약, forest_enemy._contact와 동일 규약).
		if body.has_method(&"is_rolling") and bool(body.call(&"is_rolling")):
			return
		# source_pos = 탄의 위치 — player_hurt에 실려 방향성 카메라 킥이 쓴다.
		GameState.damage_player(_damage, global_position)
		_consume()
		return
	# 마스크상 남은 건 world(벽) — 그냥 죽는다.
	_consume()


func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()
