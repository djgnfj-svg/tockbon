extends Node2D
## 걷기·구르기 먼지 — Player 자식. 부모의 공개 API(`velocity`·`is_rolling()`)만 폴링한다:
## player.gd를 안 고치면 회귀가 없고, 발걸음마다 EventBus를 쏘는 건 매 프레임성 트래픽이라 과하다.
## 수치는 밸런스가 아니라 연출값(손맛)이라 const다.

const WALK_PUFF_INTERVAL := 0.28  ## 걷기 퍼프 간격(s)
const WALK_SPEED_MIN := 20.0      ## 이 속도 이상일 때만 "걷는다"로 본다
const ROLL_BURST_COUNT := 5       ## 구르기 시작 버스트 발수
const ROLL_FAN_RAD := 0.9         ## 버스트 부채꼴 전체 각(rad) — 구르기 반대 방향 중심
const PUFF_RADIUS := 4.5          ## 퍼프 원 반지름(px)
const PUFF_COLOR := Color(0.62, 0.55, 0.45, 0.55)  ## 반투명 흙색
const PUFF_TIME := 0.5            ## 퍼프 수명(s)
const PUFF_RISE := 8.0            ## 퍼프가 떠오르는 거리(px)
const PUFF_DRIFT := 22.0          ## 버스트 퍼프가 부채꼴로 흩어지는 거리(px)
const FOOT_OFFSET := Vector2(0.0, 2.0)  ## 발밑 오프셋 — 루트가 곧 발(Sprite가 (0,-12) 오프셋)

var _walk_timer: float = 0.0
var _was_rolling: bool = false
var _puffs: int = 0


func _process(delta: float) -> void:
	var parent := get_parent() as CharacterBody2D
	if parent == null:
		return
	var rolling: bool = parent.has_method(&"is_rolling") and bool(parent.call(&"is_rolling"))
	if rolling and not _was_rolling:
		_roll_burst(parent)
	_was_rolling = rolling
	if rolling:
		return
	# ui_modal_open이면 player가 velocity를 0으로 세워 자동 침묵한다(추가 가드 불필요).
	if parent.velocity.length() > WALK_SPEED_MIN:
		_walk_timer -= delta
		if _walk_timer <= 0.0:
			_walk_timer = WALK_PUFF_INTERVAL
			_spawn_puff(parent.global_position + FOOT_OFFSET, Vector2.ZERO)
	else:
		_walk_timer = 0.0  # 다시 걷는 첫 프레임에 퍼프가 바로 나오게


func _roll_burst(parent: CharacterBody2D) -> void:
	var back := -parent.velocity.normalized() if parent.velocity.length() > 0.1 else Vector2.DOWN
	for i in ROLL_BURST_COUNT:
		var frac := float(i) / float(maxi(1, ROLL_BURST_COUNT - 1)) - 0.5
		var dir := back.rotated(frac * ROLL_FAN_RAD)
		_spawn_puff(parent.global_position + FOOT_OFFSET, dir * PUFF_DRIFT)


func _spawn_puff(pos: Vector2, drift: Vector2) -> void:
	# 🔴 노드보다 먼저 센다 — 헤드리스는 current_scene이 없어 아래에서 빠져나가지만
	# "몇 발 나가야 하는가"는 계약이라 재야 한다.
	_puffs += 1
	var scene := get_tree().current_scene
	if scene == null:
		return
	var puff := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / 6.0) * PUFF_RADIUS)
	puff.polygon = pts
	puff.color = PUFF_COLOR
	puff.z_index = 0  # 🔴 음수 z는 Ground(ColorRect, z0) 뒤로 숨어 안 보인다
	# 🔴 플레이어가 아니라 current_scene에 붙인다 — 그 자리에 남아야 이동감이 생긴다.
	scene.add_child(puff)
	puff.global_position = pos
	puff.scale = Vector2(0.6, 0.6)  # 축소형은 한 점으로 뭉개져 보여 팽창+페이드로 뒤집었다
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "global_position", pos + drift + Vector2(0.0, -PUFF_RISE), PUFF_TIME) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector2(1.35, 1.35), PUFF_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "modulate:a", 0.0, PUFF_TIME).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(puff.queue_free)


## 헤드리스 관측점 — "구르기 시작 → 버스트 발수"를 공개 API로 잰다.
func puff_count() -> int:
	return _puffs
