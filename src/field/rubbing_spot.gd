extends Area2D
## 무늬 잔류물 — 엘리트 사망 위치에 스폰. E 유지 rubbing_duration_sec 동안 무방비로 탁본 (GDD §6).
## rubbing_started / rubbing_completed(fragment_id) 발신 + GameState.add_to_bag.

const Util := preload("res://src/field/field_util.gd")

const SHEET_PATH := "res://assets/sprites/field/rubbing_spot.png"

var fragment_id: StringName = &""

var _progress: float = 0.0
var _started: bool = false
var _completed: bool = false
var _player_in: Node2D = null
var _bar: Line2D

func _ready() -> void:
	add_to_group("rubbing_spots")
	collision_layer = 1 << 6    # 7 = interaction
	collision_mask = 1 << 1     # player
	Util.add_circle_collider(self, 26.0)
	if ResourceLoader.exists(SHEET_PATH):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Util.build_sprite_frames(load(SHEET_PATH), {"glow": [0, 2, 2.2]}, 32)
		spr.autoplay = "glow"
		add_child(spr)
	else:
		# 바닥에 남은 글자 무늬 (플레이스홀더 소용돌이)
		var mark := Line2D.new()
		var pts := PackedVector2Array()
		for i in range(24):
			var t := float(i) / 23.0
			pts.append(Vector2.from_angle(t * TAU * 2.0) * (3.0 + t * 11.0))
		mark.points = pts
		mark.width = 2.0
		mark.default_color = Color(0.9, 0.85, 0.6, 0.9)
		add_child(mark)
	_bar = Line2D.new()
	_bar.points = PackedVector2Array([Vector2(-14, -22), Vector2(-14, -22)])
	_bar.width = 3.0
	_bar.default_color = Color(0.95, 0.9, 0.5)
	add_child(_bar)
	body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_player_in = body)
	body_exited.connect(func(body: Node2D) -> void:
		if body == _player_in:
			_player_in = null)

func _process(delta: float) -> void:
	if _completed:
		return
	var holding: bool = _player_in != null \
		and _player_in.get("is_dead") != true \
		and Input.is_action_pressed("interact")
	if holding:
		if not _started:
			_start()
		_progress += delta
		_update_bar()
		if _progress >= GameState.balance.rubbing_duration_sec:
			_complete()
	elif _started:
		_cancel()

func _start() -> void:
	_started = true
	if _player_in != null and _player_in.has_method("set_busy"):
		_player_in.call("set_busy", true)
	EventBus.rubbing_started.emit(fragment_id)

func _cancel() -> void:
	_started = false
	_progress = 0.0
	_update_bar()
	if _player_in != null and _player_in.has_method("set_busy"):
		_player_in.call("set_busy", false)

## 테스트에서 직접 호출해 완료 경로 검증 가능
func _complete() -> void:
	if _completed:
		return
	_completed = true
	if _started and _player_in != null and _player_in.has_method("set_busy"):
		_player_in.call("set_busy", false)
	GameState.add_to_bag(fragment_id)
	EventBus.rubbing_completed.emit(fragment_id)
	queue_free()

func _update_bar() -> void:
	var frac: float = clampf(_progress / GameState.balance.rubbing_duration_sec, 0.0, 1.0)
	_bar.points = PackedVector2Array([Vector2(-14, -22), Vector2(-14 + 28.0 * frac, -22)])
