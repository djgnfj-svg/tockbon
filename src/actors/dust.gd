extends Node2D
## 걷기·구르기 먼지 (세63 설계 §E) — Player 자식 형제 노드 (juice·vfx 선례). Player가 공용
## 배우라 **베이스·숲 자동 적용**.
##
## 🔴 **부모(Player)의 공개 API만 폴링한다** (`velocity`·`is_rolling()`) — player.gd 무수정 = 회귀 0
## (juice가 get_parent()로 카메라를 잡는 선례 그대로). EventBus를 안 쓴다 — 발걸음마다 시그널을
## 쏘는 건 "매 프레임성" 트래픽이라 vfx.gd 규약(순수 오버레이)에도 과하다.
##
## 🔴 퍼프 = **절차적이 맞다** (도형 금지 규칙의 예외, takbon-rules §0): 형태 없는 흙먼지 이펙트 —
## death_puff Polygon2D 링과 정확히 같은 부류의 "그림"이다. 도트 퍼프로 승격하고 싶으면
## `_spawn_puff` 한 곳만 바꾸면 된다.
##
## 🔴 퍼프는 `get_tree().current_scene`에 add_child (juice._spawn_number·death_puff 규약) —
## 플레이어를 따라오면 안 되고 **그 자리에 남아야** 이동감이 생긴다. 그룹 무가입(shadow와 같은 결).
##
## 🔴 여기 수치는 밸런스가 아니라 **연출값(손맛)이다** — balance.tres가 아니라 const. 사용자 튜닝.
##
## class_name 없음 — 모듈 규칙(preload로만 참조).

const WALK_PUFF_INTERVAL := 0.28  ## 걷기 퍼프 간격(s)
const WALK_SPEED_MIN := 20.0      ## 이 속도 이상일 때만 "걷는다"로 본다
const ROLL_BURST_COUNT := 5       ## 구르기 시작 버스트 발수 (설계 §E: 4~5개)
const ROLL_FAN_RAD := 0.9         ## 버스트 부채꼴 전체 각(rad) — 구르기 반대 방향 중심
const PUFF_RADIUS := 4.5          ## 퍼프 원 반지름(px)
const PUFF_COLOR := Color(0.62, 0.55, 0.45, 0.55)  ## 반투명 흙색 (설계 §E 시작값)
const PUFF_TIME := 0.5            ## 퍼프 수명(s) — 떠오르며 커지며 페이드
const PUFF_RISE := 8.0            ## 퍼프가 떠오르는 거리(px)
const PUFF_DRIFT := 22.0          ## 버스트 퍼프가 부채꼴로 흩어지는 거리(px)
## ⚠ 세63 실게임 실측으로 한 번 키웠다(3.5/0.35/10 → 겹쳐서 한 점으로 보였다). 최종 손맛은 F5.
const FOOT_OFFSET := Vector2(0.0, 2.0)  ## 발밑 오프셋 — 루트가 곧 발(Sprite가 (0,-12) 오프셋)

var _walk_timer: float = 0.0
## 구르기 상승 엣지 감지용 직전값 — dust 내부 로컬이라 "직전값 비교 사본" 문제가 없다(설계 §E).
var _was_rolling: bool = false
## 누적 퍼프 발수(스폰 시도 포함 — 수명이 다한 것도 센다). 헤드리스 관측점.
var _puffs: int = 0


func _process(delta: float) -> void:
	var parent := get_parent() as CharacterBody2D
	if parent == null:
		return
	var rolling: bool = parent.has_method(&"is_rolling") and bool(parent.call(&"is_rolling"))
	# 구르기 상승 엣지 → 반대 방향 부채꼴 버스트. 구르기 중 velocity = 대시 방향 × 속도라
	# -velocity가 곧 "구르기 반대 방향"이다 (공개 API만으로 방향을 얻는다).
	if rolling and not _was_rolling:
		_roll_burst(parent)
	_was_rolling = rolling
	if rolling:
		return
	# 걷기 퍼프 — 일정 간격. ui_modal_open이면 player가 velocity를 0으로 세워 자동 침묵(추가 가드 불필요).
	if parent.velocity.length() > WALK_SPEED_MIN:
		_walk_timer -= delta
		if _walk_timer <= 0.0:
			_walk_timer = WALK_PUFF_INTERVAL
			_spawn_puff(parent.global_position + FOOT_OFFSET, Vector2.ZERO)
	else:
		_walk_timer = 0.0  # 멈추면 리셋 — 다시 걷는 첫 프레임에 퍼프가 바로 나온다


func _roll_burst(parent: CharacterBody2D) -> void:
	var back := -parent.velocity.normalized() if parent.velocity.length() > 0.1 else Vector2.DOWN
	for i in ROLL_BURST_COUNT:
		var frac := float(i) / float(maxi(1, ROLL_BURST_COUNT - 1)) - 0.5
		var dir := back.rotated(frac * ROLL_FAN_RAD)
		_spawn_puff(parent.global_position + FOOT_OFFSET, dir * PUFF_DRIFT)


## 작은 반투명 흙색 원(6각 근사) 하나 — 살짝 떠오르며 축소·페이드 (death_puff 결).
func _spawn_puff(pos: Vector2, drift: Vector2) -> void:
	# 🔴 카운터는 스폰 시도에 센다 — `-s` 헤드리스는 current_scene이 없어 노드는 못 심지만
	# "몇 발 나가야 하는가"는 계약이라 잰다 (takbon-verify §3 공개 API 관측점).
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
	# z 0 — 플레이어 Sprite z=2(player.tscn 세63) 밑에 깔린다. 음수 금지(세54 Ground 함정).
	puff.z_index = 0
	scene.add_child(puff)
	puff.global_position = pos
	# 먼지는 **퍼지며** 사라진다(축소가 아니라 팽창+페이드) — 세63 실게임에서 축소형이 "한 점"으로
	# 뭉개져 보여 뒤집었다. 시작을 작게 잡고 커지게 한다.
	puff.scale = Vector2(0.6, 0.6)
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "global_position", pos + drift + Vector2(0.0, -PUFF_RISE), PUFF_TIME) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector2(1.35, 1.35), PUFF_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "modulate:a", 0.0, PUFF_TIME).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(puff.queue_free)


## 공개 카운터 — 헤드리스가 "구르기 시작 → 버스트 발수"를 공개 API로 잰다 (takbon-verify §3).
func puff_count() -> int:
	return _puffs
