extends Area2D
## 바닥 픽업 — 적이 죽으면 이 프롭이 죽은 자리에 떨어지고, 플레이어가 **걸어가 닿아야** 가방에 들어간다.
## 세션46: 순간이동 드롭("죽으면 바로 가방")을 "게임다운" 바닥 픽업으로 교체 (사용자 요청).
##
## 🔴 **레이어 계약** (조용히 깨지는 함정 — takbon-rules §5):
##   • `collision_layer = 0` : 아무도 이 픽업을 감지하지 않는다. **왜 0이 중요한가** —
##     발사 캐리어/탄의 마스크가 5(world+enemy)다. 픽업이 어떤 레이어든 켜져 있으면 날아가던
##     마법이 바닥 아이템에 부딪혀 **총구 근처에서 조용히 죽는다**(세션24 "진이 총구에서 죽는다"의
##     같은 종류 — 에러도 경고도 없다). 그래서 layer는 0으로 비운다.
##   • `collision_mask = 2` : 플레이어(layer 2)만 감지한다. `monitoring = true`라야 body_entered가 온다.
##
## 🔴 class_name 선언 금지(서브에이전트 규칙). forest_enemy가 preload로 무는데, 픽업은 forest를
##   안 물어 순환이 없다(base⇄forest 순환 preload 함정과 무관).
##
## 🔴 연출 수치(scatter·줍기 지연·bob)는 **밸런스가 아니라 느낌값이라 스크립트 const**다
##   (juice.gd·forest_enemy 넉백 const 선례). 사용자가 직접 주워 보며 조인다.

## 등급 색 — 흔함→전설 (tab_panel.GRADE_COLORS와 같은 규약). 픽업은 플레이스홀더 마름모라
## 여기에 사본 const를 둔다(하드 계약이 아니라 표시 규약 — 진짜 도트 스프라이트로 바뀔 자리).
const GRADE_COLORS: Array[Color] = [
	Color(0.72, 0.70, 0.66),  # 1 흔함 (회백)
	Color(0.55, 0.80, 0.50),  # 2 (녹)
	Color(0.42, 0.66, 0.95),  # 3 (청)
	Color(0.74, 0.52, 0.95),  # 4 (자)
	Color(0.98, 0.70, 0.32),  # 5 전설 (금)
]

## 🔴 줍기 지연 — 생성 직후 짧게 못 줍게 한다. 적을 **붙어서** 잡으면 픽업이 뜨는 프레임에
## 플레이어가 이미 겹쳐 있어 그대로 사라진다(튀어나오는 연출이 안 보인다). 지연이 끝날 때
## 이미 범위 안이면 그때 줍는다 — 그래서 붙어 잡아도 결국은 주워진다.
const PICKUP_DELAY := 0.35
const SCATTER_DIST := 22.0   ## 죽은 자리에서 튀어나오는 거리
const SCATTER_TIME := 0.28
const BOB_AMPLITUDE := 3.0    ## 위아래 까딱임 폭 (눈에 띄게)
const BOB_TIME := 0.9

@onready var _visual: Polygon2D = $Visual

var item_id: StringName = &""
var count: int = 0
var _pickable: bool = false
var _collected: bool = false


func _ready() -> void:
	# 테스트가 찾는 그룹 (숲 어디에 떨어졌든 훑을 수 있다).
	add_to_group("drop_pickups")
	body_entered.connect(_on_body_entered)
	_start_bob()
	# 줍기 지연 — 끝나면 이미 겹쳐 있는지 재확인한다.
	get_tree().create_timer(PICKUP_DELAY).timeout.connect(_enable_pickup)


## 🔴 아이템을 실은 뒤 부른다 — 색·튀어나오기가 여기서 시작한다. **위치를 잡은 뒤**(add_child +
## global_position 설정 후) 부를 것: scatter가 현재 위치에서 튀어나오기 때문이다.
func setup(p_item_id: StringName, p_count: int) -> void:
	item_id = p_item_id
	count = p_count
	_apply_color()
	_start_scatter()


func _apply_color() -> void:
	if _visual == null:
		return
	var grade := 1
	var it := Db.get_item(item_id)
	if it != null:
		grade = it.grade
	_visual.color = GRADE_COLORS[clampi(grade - 1, 0, GRADE_COLORS.size() - 1)]


## 죽은 자리에서 랜덤 방향으로 살짝 튀어나온다. 방향 = Godot 전역 randf()(부팅 시 자동 시드 —
## forest_enemy._die의 드롭 굴림과 같은 RNG, 세이브에 안 들어간다).
func _start_scatter() -> void:
	var dir := Vector2.from_angle(randf() * TAU)
	var target := global_position + dir * SCATTER_DIST
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, SCATTER_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _start_bob() -> void:
	if _visual == null:
		return
	var base_y := _visual.position.y
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(_visual, "position:y", base_y - BOB_AMPLITUDE, BOB_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_visual, "position:y", base_y, BOB_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _enable_pickup() -> void:
	_pickable = true
	# 지연이 끝났을 때 이미 범위 안이면 바로 줍는다 (적을 붙어서 잡은 경우).
	for body in get_overlapping_bodies():
		if _try_collect(body):
			return


func _on_body_entered(body: Node2D) -> void:
	if not _pickable:
		return  # 줍기 지연 중 — 무시한다 (지연 끝의 재확인이 나중에 줍는다).
	_try_collect(body)


## 🔴 픽업의 유일한 목적지 = `GameState.add_to_bag` (기존 인벤 흐름 그대로: 귀환하면 창고행,
## 죽으면 bag_lost로 증발). 순간이동 드롭이 하던 걸 이제 여기서 한다 — 주울 때 소리도 여기서.
func _try_collect(body: Node) -> bool:
	if _collected or item_id == &"":
		return false
	# mask=2가 이미 플레이어만 걸러 주지만, 방어적으로 몸 타입을 확인한다.
	if not (body is CharacterBody2D):
		return false
	_collected = true
	GameState.add_to_bag(item_id, count)
	Audio.play(&"pickup")
	queue_free()
	return true
