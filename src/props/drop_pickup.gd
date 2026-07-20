extends Area2D
## 바닥 픽업 — 적이 죽으면 이 프롭이 죽은 자리에 떨어지고, 플레이어가 **걸어가 닿아야** 가방에 들어간다.
## 세션46: 순간이동 드롭("죽으면 바로 가방")을 "게임다운" 바닥 픽업으로 교체 (사용자 요청).
## 세션51: **흡수 연출** — 스폰 팝·아치·그림자·등급 반짝임 + **자석**(가까이 가면 빨려온다) + 도착 팝.
##
## 🔴 **자석은 세46 계약을 안 지운다.** 여전히 드롭 쪽으로 **걸어가야** 하고, 자석은 마지막
##   한 뼘의 픽셀 더듬기만 없앤다. "처치 순간 플레이어에게 날아옴"은 각하됐다 — 그건 세46이
##   폐기한 "가방 순간이동에 애니메이션만 씌운 것"으로의 회귀이고, 익스트랙션의 스테이크스
##   (보상을 챙기려면 위험한 자리에 몸을 노출한다)를 통째로 지운다.
##
## 🔴 **레이어 계약** (조용히 깨지는 함정 — takbon-rules §5):
##   • `collision_layer = 0` : 아무도 이 픽업을 감지하지 않는다. **왜 0이 중요한가** —
##     발사 캐리어/탄의 마스크가 5(world+enemy)다. 픽업이 어떤 레이어든 켜져 있으면 날아가던
##     마법이 바닥 아이템에 부딪혀 **총구 근처에서 조용히 죽는다**(세션24 "진이 총구에서 죽는다"의
##     같은 종류 — 에러도 경고도 없다). 그래서 layer는 0으로 비운다.
##   • `collision_mask = 2` : 플레이어(layer 2)만 감지한다. `monitoring = true`라야 body_entered가 온다.
##   🔴 **자석은 물리를 아예 안 쓴다** — 그룹 조회(`"player"`) + 거리 계산이다. 새 Area2D도
##     새 CollisionShape도 없다. 레이어 필드를 하나 더 만드는 순간 그게 언젠가 잘못 채워진다
##     (세24·세46이 전부 그 종류의 사고였다).
##
## 🔴 class_name 선언 금지(서브에이전트 규칙). forest_enemy가 preload로 무는데, 픽업은 forest를
##   안 물어 순환이 없다(base⇄forest 순환 preload 함정과 무관).
##
## 🔴 연출 수치(scatter·줍기 지연·bob·자석)는 **밸런스가 아니라 느낌값이라 스크립트 const**다
##   (juice.gd·forest_enemy 넉백 const 선례). 사용자가 직접 주워 보며 조인다.

## 등급 색 — 🔴 단일 소스는 `src/core/grade_colors.gd` (세션51에 사본 셋을 합쳤다).
## 픽업은 플레이스홀더 마름모지만, 창고·획득 토스트와 **같은 아이템이 같은 색**이어야 등급이
## 정보로 읽힌다 — 진짜 도트 스프라이트로 바뀌어도 등급 색 규약은 여기서 온다.
const GradeColors := preload("res://src/core/grade_colors.gd")

## 🔴 줍기 지연 — 생성 직후 짧게 못 줍게 한다. 적을 **붙어서** 잡으면 픽업이 뜨는 프레임에
## 플레이어가 이미 겹쳐 있어 그대로 사라진다(튀어나오는 연출이 안 보인다). 지연이 끝날 때
## 이미 범위 안이면 그때 줍는다 — 그래서 붙어 잡아도 결국은 주워진다.
## 🔴 **자석도 이 게이트 뒤에서만 켜진다** — 안 그러면 자석이 지연의 존재 이유를 무력화한다.
const PICKUP_DELAY := 0.35
const SCATTER_DIST := 22.0   ## 죽은 자리에서 튀어나오는 거리
const SCATTER_TIME := 0.28
const BOB_AMPLITUDE := 3.0    ## 위아래 까딱임 폭 (눈에 띄게)
const BOB_TIME := 0.9

## 스폰 연출 — "쏟아져 나온다"
const SPAWN_POP_TIME := 0.22  ## Visual.scale 0.2 → 1.0
const ARC_HEIGHT := 14.0      ## 위로 튀었다 내려오는 높이 (루트는 평면 이동, 시각만 튄다)

## 등급 반짝임 — 🔴 **이 등급 이상만** 반짝인다. 전부 반짝이면 반짝임이 정보가 아니라
## 배경이 된다 — 반짝임이 곧 "이건 챙겨라" 신호여야 한다.
const GLOW_MIN_GRADE := 3
const GLOW_TIME := 1.1
const GLOW_STRENGTH := 1.45

## 🔴 자석 — `MAGNET_RADIUS`만은 "얼마나 편한가"라 밸런스에 가깝고 장래에 부적/모자로
## **키우고 싶은 축**이다. 그래도 **지금은 const로 둔다**: 소비자가 없는 밸런스 필드를 미리
## 만드는 건 세50의 `rune_fill` 빚(소비자 0곳)과 같은 병이다. 장비 보너스가 실제로 붙는
## 세션에 `GameState.magnet_radius()`(펜 보정 `stroke_correction()` 선례)로 승격시킨다.
const MAGNET_RADIUS := 72.0
const MAGNET_SPEED_START := 40.0   ## 처음엔 느리게 떨어져 나온다 (등속이면 "미끄러진다"로 읽힌다)
const MAGNET_ACCEL := 900.0        ## px/s²
const MAGNET_SPEED_MAX := 520.0    ## 플레이어 이동속도보다 확실히 빨라야 따라잡는다
const ARRIVE_PX := 10.0            ## 픽업 CircleShape r=11과 비슷하게
const HOMING_SCALE := 0.75         ## 빨려 들어가며 응축
const POP_SCALE_IN := 1.5
const POP_TIME := 0.12

## 연속 획득 피치 사다리 (마리오 코인 문법 — 연속 획득 자체가 기분 좋아진다).
## 🔴 인스턴스가 아니라 **픽업들 사이에** 공유돼야 하므로 static.
const PITCH_STEP := 0.06
const PITCH_MAX := 1.35
const PITCH_WINDOW_MS := 900    ## 이만큼 침묵하면 사다리 리셋
const SFX_GATE_MS := 50         ## 같은 프레임에 여럿 도착해도 소리는 한 번만 (플래밍 방지)

## 🔴 시각은 **`Time.get_ticks_msec()`** — delta 누적을 쓰면 처치 히트스톱(`Engine.time_scale`)
## 중에 시간이 20배 느려져 사다리가 안 리셋된다.
static var _last_sfx_ms: int = -100000
static var _pitch: float = 1.0

enum State { IDLE, READY, HOMING, COLLECTED }

@onready var _visual: Polygon2D = $Visual

var item_id: StringName = &""
var count: int = 0

var _state: State = State.IDLE
var _collected: bool = false
var _speed: float = 0.0
var _bob_tw: Tween = null
var _glow_tw: Tween = null
var _scatter_tw: Tween = null


func _ready() -> void:
	# 테스트가 찾는 그룹 (숲 어디에 떨어졌든 훑을 수 있다).
	add_to_group("drop_pickups")
	body_entered.connect(_on_body_entered)
	_start_bob()
	# 줍기 지연 — 끝나면 이미 겹쳐 있는지 재확인한다.
	get_tree().create_timer(PICKUP_DELAY).timeout.connect(_enable_pickup)


## 🔴 아이템을 실은 뒤 부른다 — 색·튀어나오기가 여기서 시작한다. **위치를 잡은 뒤**(add_child +
## global_position 설정 후) 부를 것: scatter가 현재 위치에서 튀어나오기 때문이다.
##
## `p_scatter_angle` — 🔴 **기본값 −1이면 지금처럼 랜덤**이라 기존 2인자 호출·테스트가 그대로 돈다.
## forest_enemy가 드롭 인덱스로 **균등 각도**를 넘긴다: 랜덤이면 3개가 겹쳐 하나로 보여
## "여러 개 나왔다"가 눈에 안 읽힌다 — 그게 보상 체감의 절반이다.
func setup(p_item_id: StringName, p_count: int, p_scatter_angle: float = -1.0) -> void:
	item_id = p_item_id
	count = p_count
	_apply_color()
	_start_scatter(p_scatter_angle)
	_start_spawn_pop()
	_start_glow_if_rare()


func _apply_color() -> void:
	if _visual == null:
		return
	_visual.color = GradeColors.of(_grade())


func _grade() -> int:
	var it := Db.get_item(item_id)
	return it.grade if it != null else 1


## 죽은 자리에서 튀어나온다. 각도가 음수면 랜덤 = Godot 전역 randf()(부팅 시 자동 시드 —
## forest_enemy._die의 드롭 굴림과 같은 RNG, 세이브에 안 들어간다).
func _start_scatter(angle: float) -> void:
	var a := angle if angle >= 0.0 else randf() * TAU
	var target := global_position + Vector2.from_angle(a) * SCATTER_DIST
	_scatter_tw = create_tween()
	_scatter_tw.tween_property(self, "global_position", target, SCATTER_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 스폰 팝 + 아치 — "터져 나와서 살짝 튀었다 내려앉는다".
## 🔴 아치는 `_visual.position:y`를 쓰는데 **bob도 같은 프로퍼티**다(같은 프로퍼티의 두 트윈은
## 서로 경쟁한다) → bob을 죽이고, 아치가 끝나면 다시 켠다.
func _start_spawn_pop() -> void:
	if _visual == null:
		return
	_visual.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2.ONE, SPAWN_POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _bob_tw != null and _bob_tw.is_valid():
		_bob_tw.kill()
	var base_y := 0.0
	var arc := create_tween()
	arc.tween_property(_visual, "position:y", base_y - ARC_HEIGHT, SCATTER_TIME * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(_visual, "position:y", base_y, SCATTER_TIME * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	arc.tween_callback(_start_bob)


## 🔴 등급 반짝임은 `_visual.modulate`를 쓴다 — **도착 팝의 `modulate:a`와 충돌**하므로
## HOMING 진입에서 반드시 kill + 리셋한다(세50 `_pop` ↔ `_status_tint` 충돌과 정확히 같은 함정).
func _start_glow_if_rare() -> void:
	if _visual == null or _grade() < GLOW_MIN_GRADE:
		return
	_glow_tw = create_tween()
	_glow_tw.set_loops()
	var bright := Color(GLOW_STRENGTH, GLOW_STRENGTH, GLOW_STRENGTH, 1.0)
	_glow_tw.tween_property(_visual, "modulate", bright, GLOW_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tw.tween_property(_visual, "modulate", Color.WHITE, GLOW_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_bob() -> void:
	if _visual == null or _state == State.HOMING or _state == State.COLLECTED:
		return
	if _bob_tw != null and _bob_tw.is_valid():
		_bob_tw.kill()
	var base_y := _visual.position.y
	_bob_tw = create_tween()
	_bob_tw.set_loops()
	_bob_tw.tween_property(_visual, "position:y", base_y - BOB_AMPLITUDE, BOB_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tw.tween_property(_visual, "position:y", base_y, BOB_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _enable_pickup() -> void:
	if _state == State.COLLECTED:
		return
	_state = State.READY
	# 지연이 끝났을 때 이미 범위 안이면 바로 줍는다 (적을 붙어서 잡은 경우).
	for body in get_overlapping_bodies():
		if _try_collect(body):
			return


# ── 자석 ──

## 🔴 물리를 안 쓴다: 그룹 조회 + 거리. 필드 픽업 개수는 한 자릿수라 매 프레임 거리 하나는 공짜다.
## 🔴 **null 가드 필수** — 플레이어가 없는 씬(연습장·테스트 하네스)에서는 자석이 그냥 안 돈다.
##    없으면 매 프레임 null 접근으로 죽는데, `-s` 헤드리스는 그래도 "OK"를 찍는다(세22·23 패턴).
func _physics_process(delta: float) -> void:
	if _state == State.IDLE or _state == State.COLLECTED:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		return  # 플레이어가 없으면 READY에 머문다 (크래시 금지)

	if _state == State.READY:
		if global_position.distance_to(p.global_position) > MAGNET_RADIUS:
			return
		_begin_homing()

	# 🔴 한번 켜지면 취소되지 않는다 — 반경 밖으로 도망가도 계속 따라온다. 그게 "이미 내
	# 것이다"를 만든다. 경계에서 들락날락하며 아이템이 떨었다 말았다 하면 최악이다.
	_speed = minf(_speed + MAGNET_ACCEL * delta, MAGNET_SPEED_MAX)
	var to_player := p.global_position - global_position
	if to_player.length() <= ARRIVE_PX:
		_collect_at(p.global_position)
		return
	global_position += to_player.normalized() * _speed * delta


func _begin_homing() -> void:
	_state = State.HOMING
	_speed = MAGNET_SPEED_START
	# scatter가 아직 남아 있으면 위치를 되끌어 자석과 경쟁한다.
	if _scatter_tw != null and _scatter_tw.is_valid():
		_scatter_tw.kill()
	if _bob_tw != null and _bob_tw.is_valid():
		_bob_tw.kill()
	# 🔴 반짝임(modulate)을 안 죽이면 도착 팝의 modulate:a와 경쟁해 아이템이 안 사라지거나
	# 색이 이상하게 굳는다. 죽이고 **1.0으로 되돌린다**.
	if _glow_tw != null and _glow_tw.is_valid():
		_glow_tw.kill()
	if _visual != null:
		_visual.modulate = Color.WHITE
		var tw := create_tween()
		tw.tween_property(_visual, "position:y", 0.0, 0.12)
		tw.parallel().tween_property(_visual, "scale", Vector2(HOMING_SCALE, HOMING_SCALE), 0.18)


# ── 수집 ──

func _on_body_entered(body: Node2D) -> void:
	if _state != State.READY:
		return  # 줍기 지연 중이거나 이미 흡수/수집됨 (지연 끝의 재확인이 나중에 줍는다).
	_try_collect(body)


## body_entered 경로 — 🔴 **자석이 추가돼도 이 경로는 유지된다**(안전망이자 기존 계약).
func _try_collect(body: Node) -> bool:
	if _collected or item_id == &"":
		return false
	# mask=2가 이미 플레이어만 걸러 주지만, 방어적으로 몸 타입을 확인한다.
	if not (body is CharacterBody2D):
		return false
	_collect_at(global_position)
	return true


## 🔴 픽업의 유일한 목적지 = `GameState.add_to_bag` (기존 인벤 흐름 그대로: 귀환하면 창고행,
## 죽으면 bag_lost로 증발). 🔴 **가방에 넣는 시점 = 도착**(흡수 시작이 아니다) — 미리 채우면
## "도착하는 느낌"을 만든다는 이 작업의 목표 자체가 무너지고, 연출과 실제가 어긋난다.
##
## 🔴 `_collected`를 **먼저** 세운다: `body_entered`(안전망)와 거리 도착(자석)이 둘 다 있어
## 이중 수집 위험이 실재하고, 도착 팝 0.12s 동안 노드가 아직 살아 있다.
## 🔴 빈 `item_id`도 여기서 막는다 (세51 리뷰). `_try_collect`(body_entered 경로)만 이 검사를
## 갖고 자석 도착 경로엔 없어서 **두 경로가 비대칭**이었다 — `setup()`이 안 불린 픽업이 씬에 있으면
## `add_to_bag(&"", 0)`이 불려 **유령 항목이 가방에 들어가고 귀환하면 창고로, 세이브로 영구화된다**
## (add_to_bag은 검사 없이 append한다). 지금은 유일 생성자 `forest_enemy._die`가 항상 setup을
## 부르지만, 손으로 씬에 놓거나 새 생성자가 생기는 날 열리는 잠복 함정이라 여기서 닫는다.
func _collect_at(at: Vector2) -> void:
	if _collected or item_id == &"":
		return
	_collected = true
	_state = State.COLLECTED
	global_position = at
	GameState.add_to_bag(item_id, count)
	_play_pickup_sfx()
	EventBus.item_collected.emit(item_id, count)
	_pop_and_free()


## 연속 획득 피치 사다리 + 같은-프레임 게이트.
func _play_pickup_sfx() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sfx_ms < SFX_GATE_MS:
		return  # 같은 프레임에 여럿 도착 — 소리는 한 번만
	if now - _last_sfx_ms > PITCH_WINDOW_MS:
		_pitch = 1.0
	else:
		_pitch = minf(_pitch + PITCH_STEP, PITCH_MAX)
	_last_sfx_ms = now
	Audio.play(&"pickup", _pitch)


## 도착 팝 — 플레이어 자리에서 터지고 사라진다. ⚠ `_exit_tree`로 뭘 끊지 마라: 트윈은 이
## 노드에 바인딩돼 노드가 free되면 같이 죽는다(세50이 없는 문제를 막다 진짜 함정을 심었다).
func _pop_and_free() -> void:
	if _visual == null:
		queue_free()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector2(POP_SCALE_IN, POP_SCALE_IN), POP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "modulate:a", 0.0, POP_TIME)
	tw.chain().tween_callback(queue_free)
