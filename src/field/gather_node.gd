extends Area2D
## 채집 노드 — 접근 후 E로 획득 → GameState.add_to_bag (모듈 C).
## night_only=true면 밤에만 활성 (GDD §7 — 밤 전용 희귀 재료).

const Util := preload("res://src/field/field_util.gd")

## 채집 노드 시트 (ART_SPEC P3) — 주간 2종·야간 발광 2종, 각 2프레임
const SHEET_PATH := "res://assets/sprites/field/gather.png"
const SHEET_ANIMS := {
	"day_a": [0, 2, 2.0], "day_b": [2, 2, 2.0],
	"night_a": [4, 2, 2.5], "night_b": [6, 2, 2.5],
}

var item_id: StringName = &"mat_vine"
var count: int = 1
var night_only: bool = false

var _depleted: bool = false
var _night: bool = false
var _player_in: Node2D = null

func _ready() -> void:
	add_to_group("gather_nodes")
	collision_layer = 1 << 6    # 7 = interaction
	collision_mask = 1 << 1     # player
	_night = Clock.is_night()
	Util.add_circle_collider(self, 20.0)
	if ResourceLoader.exists(SHEET_PATH):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Util.build_sprite_frames(load(SHEET_PATH), SHEET_ANIMS, 16)
		# 품목별로 배리에이션 고정 (같은 재료 = 같은 생김새)
		var variant := "_b" if (hash(item_id) & 1) == 1 else "_a"
		spr.play(StringName(("night" if night_only else "day") + variant))
		add_child(spr)
	else:
		var color := Color(0.4, 0.65, 0.9) if night_only else Color(0.35, 0.5, 0.3)
		Util.add_circle_visual(self, 8.0, color)
		var sprout := Polygon2D.new()
		sprout.polygon = PackedVector2Array([Vector2(-2, -6), Vector2(2, -6), Vector2(0, -14)])
		sprout.color = color.lightened(0.3)
		add_child(sprout)
	EventBus.phase_changed.connect(_on_phase_changed)
	body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_player_in = body)
	body_exited.connect(func(body: Node2D) -> void:
		if body == _player_in:
			_player_in = null)
	_refresh()

func _process(_delta: float) -> void:
	if not _is_active() or _player_in == null:
		return
	if _player_in.get("busy") == true:
		return
	if Input.is_action_just_pressed("interact"):
		_collect()

func _is_active() -> bool:
	return not _depleted and (not night_only or _night)

## 채집 실행 — 비활성이면 false (테스트에서 직접 호출)
func _collect() -> bool:
	if not _is_active():
		return false
	_depleted = true
	GameState.add_to_bag(item_id, count)
	_refresh()
	return true

func _on_phase_changed(phase: int) -> void:
	_night = (phase == Enums.Phase.NIGHT)
	_refresh()

func _refresh() -> void:
	if _depleted:
		modulate.a = 0.25
	elif night_only and not _night:
		modulate.a = 0.0    # 낮에는 숨김 — 밤에만 드러난다
	else:
		modulate.a = 1.0
