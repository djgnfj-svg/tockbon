extends Area2D
## 바닥 픽업 — 적이 죽으면 이 프롭이 죽은 자리에 떨어지고, 플레이어가 **걸어가 닿아야** 가방에 들어간다.
##
## 🔴 **자석은 「걸어가야 한다」를 안 지운다** — 마지막 한 뼘의 픽셀 더듬기만 없앤다. "처치 순간
##   플레이어에게 날아옴"은 각하됐다(그건 「가방 순간이동에 애니메이션만 씌운 것」이라, 보상을
##   챙기려면 위험한 자리에 몸을 노출한다는 긴장을 통째로 지운다).
##
## 🔴 **레이어 계약**(조용히 깨지는 함정):
##   • `collision_layer = 0` : 발사 캐리어/탄의 마스크가 5(world+enemy)라, 픽업이 **어떤 레이어든**
##     켜져 있으면 날아가던 마법이 바닥 아이템에 부딪혀 **총구 근처에서 조용히 죽는다**(에러 0).
##   • `collision_mask = 2` : 플레이어만 감지한다. `monitoring = true`라야 body_entered가 온다.
##   🔴 **자석은 물리를 아예 안 쓴다** — 그룹 조회 + 거리 계산이다. 레이어 필드를 하나 더 만드는
##     순간 그게 언젠가 잘못 채워진다.
##
## 🔴 **두 가지 페이로드 — 배타다**(`DropEntry`의 같은 계약. `setup`이 넷째 인자로 받는다):
##   • `item_id` — 가방행(귀환하면 창고, 죽으면 bag_lost로 증발)
##   • `unlock_id` — **codex 해금행.** 아이템이 아니라 배움이라 `add_to_bag`에 **안 넣는다**.
##   ⚠ 해금물도 땅에 떨어져 걸어가 줍는다 — 보너스는 눈에 보여야 보너스다.
##
## 🔴 연출 수치(scatter·줍기 지연·bob·자석)는 밸런스가 아니라 느낌값이라 스크립트 const다.

## 등급 색 단일 소스 — 마름모 폴백일 때 창고·획득 토스트와 **같은 아이템이 같은 색**이어야
## 등급이 정보로 읽힌다.
const GradeColors := preload("res://src/core/grade_colors.gd")

## 🔴 **화면 문구는 이 파일의 일이 아니다.** 픽업은 `unlock_id`만 나르고, 사람이 읽는 이름·안내는
## **HUD가** `codex_unlocked`를 받아 낸다 — 문구의 주인이 한 곳이라 사본이 생길 자리가 없다.
## ⚠ 여기에 라벨 필드를 다시 만들지 마라(소비자 0인 거짓 손잡이가 된다).

## 🔴 **두루마리 스프라이트** (24×24, 고리 3종 공용 한 장). 해금물엔 `ItemDef`가 없어
## `params.sprite`를 못 읽으므로 경로가 여기 있다. ⚠ **마름모 폴백으로 절대 안 떨어진다**(도형 금지).
const SCROLL_SPRITE := "res://assets/sprites/props/scroll_glyph_ring.png"

## 해금물의 **후광 등급** — 아이템이 아니라 등급 필드가 없다. 2~3%로 나오는 보너스라 멀리서도
## "챙겨라"로 읽혀야 한다. 밸런스가 아니라 연출값이라 const다.
const UNLOCK_GRADE := 4

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

## 🔴 등급 후광 — 바닥 드롭 뒤에 등급색 halo를 깔아 **줍기 전에 값어치를 알린다.** 등급이 높을수록
## 크고 진하고 세게 숨 쉰다 — 흔한 건 거의 안 보이고, 귀한 건 멀리서도 "챙겨라"로 읽힌다.
## 🔴 절차적 VFX라 도형 금지 예외 — 스프라이트가 아니라 그림이다.
const HALO_SIDES := 20            ## 원 근사 다각형 변 수
const HALO_BASE_R := 10.0         ## 반지름 = BASE + grade·PER_GRADE (등급이 클수록 넓다)
const HALO_R_PER_GRADE := 2.6
const HALO_ALPHA_PER_GRADE := 0.2 ## 알파 = grade·PER_GRADE (등급 1은 0 = 안 보임)
const HALO_ALPHA_MAX := 0.82
const HALO_PULSE_TIME := 0.85     ## 숨쉬기 한 결
const HALO_PULSE_LOW := 0.45      ## 알파가 이 비율까지 줄었다 돌아온다 (등급 높을수록 눈에 띄게 맥동)

## 🔴 자석 — `MAGNET_RADIUS`만은 "얼마나 편한가"라 밸런스에 가깝고 장래에 부적/모자로 키우고 싶은
## 축이다. 그래도 지금은 const다: 소비자 없는 밸런스 필드를 미리 만들면 그게 빚이 된다.
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
## 🔴 해금물 페이로드 — 채워지면 `item_id`는 비어 있고, 줍는 순간 `codex_unlocked`가 나간다.
var unlock_id: StringName = &""

var _state: State = State.IDLE
var _collected: bool = false
var _speed: float = 0.0
var _bob_tw: Tween = null
var _halo_tw: Tween = null
var _scatter_tw: Tween = null
## 등급 후광 — _ready에서 만들어 Visual 뒤에 깐다. 등급색·크기·맥동은 _apply_halo가 정한다.
var _halo: Polygon2D = null
var _halo_base_alpha: float = 0.0


func _ready() -> void:
	# 테스트가 찾는 그룹 (숲 어디에 떨어졌든 훑을 수 있다).
	add_to_group("drop_pickups")
	body_entered.connect(_on_body_entered)
	_make_halo()   # 색·크기·맥동은 setup→_apply_halo가 정한다
	_start_bob()
	# 줍기 지연 — 끝나면 이미 겹쳐 있는지 재확인한다.
	get_tree().create_timer(PICKUP_DELAY).timeout.connect(_enable_pickup)


## 🔴 아이템을 실은 뒤 부른다 — **위치를 잡은 뒤**(add_child + global_position 설정 후) 부를 것:
## scatter가 현재 위치에서 튀어나오기 때문이다.
##
## `p_scatter_angle` — 음수면 랜덤. forest_enemy가 드롭 인덱스로 **균등 각도**를 넘긴다: 랜덤이면
## 3개가 겹쳐 하나로 보여 "여러 개 나왔다"가 눈에 안 읽힌다(보상 체감의 절반이다).
## `p_unlock_id` — 채우면 `p_item_id`는 비어 있어야 한다(머리말의 배타 계약).
func setup(p_item_id: StringName, p_count: int, p_scatter_angle: float = -1.0,
		p_unlock_id: StringName = &"") -> void:
	item_id = p_item_id
	count = p_count
	unlock_id = p_unlock_id
	_apply_color()
	_apply_halo()
	_start_scatter(p_scatter_angle)
	_start_spawn_pop()


## 🔴 스프라이트 우선, 마름모 폴백 — 아이템 `params.sprite`가 있고 로드 가능하면 진짜 도트를 그리고
## 마름모(Polygon2D)는 투명하게 숨긴다.
##   • `_visual`은 여전히 Polygon2D라 모든 연출 트윈이 그대로 돌고, modulate는 자식 `Sprite`에
##     곱셈 전파되므로 pop 페이드가 스프라이트에도 먹는다.
##   • 마름모 숨김 = `color.a=0`(폴리곤 필드만 투명, 자식 스프라이트는 자기 텍스처로 보인다).
##   • 스프라이트는 **등급 틴트 없이 그대로**(엽전은 금색 자체가 정보). 폴백 마름모만 등급색.
##   • `ResourceLoader.exists` 가드 = import 전이거나 경로 오타면 조용히 폴백(크래시 금지).
##
## 🔴🔴 **해금물(두루마리)은 마름모로 절대 안 떨어진다**(도형 금지). `Db.get_item`이 해금 id엔 null이라
## 옛 흐름은 **곧바로 등급색 마름모**였다 → 해금물은 `SCROLL_SPRITE`를 쓰고, PNG가 없으면 마름모가
## 아니라 `push_warning` + 마름모 숨김으로 선다(화면엔 등급 후광이 남아 "뭔가 떨어졌다"는 읽힌다).
## ⚠ `push_warning`은 `SCRIPT ERROR` grep에 안 걸린다 — PNG 도착 확인은 리드의 F5 몫이다.
func _apply_color() -> void:
	if _visual == null:
		return
	var spr := _sprite_path()
	var sprite := _visual.get_node_or_null("Sprite") as Sprite2D
	if spr != "" and ResourceLoader.exists(spr) and sprite != null:
		sprite.texture = load(spr)
		sprite.visible = true
		_visual.color = Color(0.0, 0.0, 0.0, 0.0)  # 마름모 숨김 — 스프라이트로 대체
		return
	if sprite != null:
		sprite.visible = false
	if unlock_id != &"":
		# 🔴 해금물인데 스프라이트가 없다 — 마름모로 때우지 않는다(도형 금지).
		push_warning("drop_pickup: 두루마리 스프라이트가 없다 — %s (해금물 %s는 후광만으로 선다)"
			% [SCROLL_SPRITE, unlock_id])
		_visual.color = Color(0.0, 0.0, 0.0, 0.0)
		return
	_visual.color = GradeColors.of(_grade())


## 그릴 스프라이트 경로 — 해금물은 두루마리 한 장, 아이템은 `params.sprite`(없으면 빈 문자열).
func _sprite_path() -> String:
	if unlock_id != &"":
		return SCROLL_SPRITE
	var it := Db.get_item(item_id)
	if it != null and it.params.has("sprite"):
		return str(it.params["sprite"])
	return ""


## 후광·마름모가 보는 등급 — 해금물은 `ItemDef`가 없으니 연출 등급을 준다(위 UNLOCK_GRADE 주석).
func _grade() -> int:
	if unlock_id != &"":
		return UNLOCK_GRADE
	var it := Db.get_item(item_id)
	return it.grade if it != null else 1


## 죽은 자리에서 튀어나온다. 각도가 음수면 랜덤 = Godot 전역 randf()(세이브에 안 들어간다).
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


## 🔴 등급 후광 노드 — 단위원 폴리곤을 Visual 뒤(z=4)에 깐다. 반지름은 `_apply_halo`가 scale로 준다.
## 맥동은 **`_halo` 자신의 modulate:a**를 쓴다 — `_visual`(도착 팝의 modulate)과 노드가 달라
## 같은 프로퍼티를 놓고 싸우는 충돌이 원천적으로 없다.
func _make_halo() -> void:
	_halo = Polygon2D.new()
	_halo.name = &"Halo"
	_halo.z_index = 4                     # Visual(5) 뒤 · Ground(0) 앞
	var pts := PackedVector2Array()
	for i in HALO_SIDES:
		pts.append(Vector2.from_angle(TAU * float(i) / float(HALO_SIDES)))   # 단위원
	_halo.polygon = pts
	_halo.visible = false
	add_child(_halo)
	move_child(_halo, 0)                  # 트리 맨 앞 = 형제 중 먼저 그려진다(그림자·Visual 뒤로)

## 등급 후광을 아이템 등급에 맞춘다. 등급 1 = 알파 0 = 안 보임 · 높을수록 크고 진하고 세게 맥동.
## 색은 등급색 단일 소스 — 창고·토스트·마름모 폴백과 같은 색이라 등급이 한눈에 읽힌다.
func _apply_halo() -> void:
	if _halo == null:
		return
	var g := _grade()
	_halo_base_alpha = clampf(float(g - 1) * HALO_ALPHA_PER_GRADE, 0.0, HALO_ALPHA_MAX)
	if _halo_base_alpha <= 0.001:
		_halo.visible = false             # 흔한 것(등급 1)은 후광 없음 — 후광이 곧 "챙겨라" 신호
		return
	var gc := GradeColors.of(g)
	_halo.color = Color(gc.r, gc.g, gc.b, _halo_base_alpha)
	var r := HALO_BASE_R + float(g) * HALO_R_PER_GRADE
	_halo.scale = Vector2(r, r)
	_halo.modulate.a = 1.0
	_halo.visible = true
	_start_halo_pulse()

## 숨쉬기 — modulate:a를 LOW↔1.0으로 무한 왕복. 귀한 드롭이 멀리서도 눈에 들어오게.
func _start_halo_pulse() -> void:
	if _halo == null:
		return
	if _halo_tw != null and _halo_tw.is_valid():
		_halo_tw.kill()
	_halo_tw = create_tween()
	_halo_tw.set_loops()
	_halo_tw.tween_property(_halo, "modulate:a", HALO_PULSE_LOW, HALO_PULSE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_halo_tw.tween_property(_halo, "modulate:a", 1.0, HALO_PULSE_TIME) \
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
## 🔴 **null 가드 필수** — 플레이어가 없는 씬(연습장·테스트 하네스)에선 자석이 그냥 안 돈다. 없으면
##    매 프레임 null 접근으로 죽는데, `-s` 헤드리스는 그래도 "OK"를 찍는다.
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
	# 등급 후광을 접는다 — 빨려 들어가며 halo도 같이 페이드아웃(맥동 트윈 kill 후 알파 0).
	if _halo_tw != null and _halo_tw.is_valid():
		_halo_tw.kill()
	if _halo != null and _halo.visible:
		create_tween().tween_property(_halo, "modulate:a", 0.0, 0.14)
	if _visual != null:
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
	if _collected or not _has_payload():
		return false
	# mask=2가 이미 플레이어만 걸러 주지만, 방어적으로 몸 타입을 확인한다.
	if not (body is CharacterBody2D):
		return false
	_collect_at(global_position)
	return true


## 🔴 **가방에 넣는 시점 = 도착**(흡수 시작이 아니다) — 미리 채우면 "도착하는 느낌"이라는 목표
## 자체가 무너지고 연출과 실제가 어긋난다.
##
## 🔴 `_collected`를 **먼저** 세운다: `body_entered`(안전망)와 거리 도착(자석)이 둘 다 있어 이중
## 수집 위험이 실재하고, 도착 팝 0.12s 동안 노드가 아직 살아 있다.
## 🔴 빈 페이로드도 여기서 막는다 — `setup()`이 안 불린 픽업이 씬에 있으면 `add_to_bag(&"", 0)`이
## 불려 **유령 항목이 가방에 들어가고 세이브로 영구화된다**(add_to_bag은 검사 없이 append한다).
## 🔴🔴 **그 거부에서 `_collected`를 안 세우면 무한 재호출이다**: 자석 도착 경로는 거리 판정으로
## 여길 부르므로, 아무 일도 안 일어나고 상태도 안 바뀌면 **다음 물리 프레임에 또 부른다** → 픽업이
## 플레이어에 **붙은 채 영원히 안 사라진다**(에러도 경고도 없다). 해금물은 `item_id`가 빈 게
## 정상이라 그 경로가 이 함정을 연다. → 페이로드가 없으면 **먼저 불활성으로 못 박고 스스로 치운다.**
func _collect_at(at: Vector2) -> void:
	if _collected:
		return
	if not _has_payload():
		_collected = true
		_state = State.COLLECTED
		queue_free()   # 주울 게 없는 픽업은 세상에 남을 이유가 없다 (좀비 방지)
		return
	_collected = true
	_state = State.COLLECTED
	global_position = at
	# 🔴🔴 지급 자체는 **`grant_one` 한 곳**이다(↓ 그 함수 머리말). 여기 남은 건 노드에만 있는 일
	#  (소리 사다리·팝·자기 정리)뿐이다 — 그래야 상자가 같은 지급을 두 벌로 안 갖는다.
	if grant_one(item_id, count, unlock_id, GameState, EventBus):
		_play_pickup_sfx()
	_pop_and_free()


## 페이로드가 실렸나 — 아이템이든 해금물이든 하나면 된다(둘은 배타, 머리말 참조).
func _has_payload() -> bool:
	return item_id != &"" or unlock_id != &""


## 🔴🔴 **드롭 한 줄을 실제로 지급한다 — 이 리포의 유일한 지급 지점이다.**
##
## 🔴 **왜 static인가**: 상자는 「바로 가방」이라 **픽업 노드를 아예 안 지난다.** 그러면 「해금물이면
##  codex, 아이템이면 가방」이라는 분기가 **두 벌**이 되고, 갈리는 날 *"상자에서 나온 두루마리만
##  해금이 안 걸린다"*가 된다(에러 0). ⇒ 상자(`boss_room`)와 픽업이 **같은 함수**를 부른다.
## 🔴 **호출은 드롭 한 줄에 정확히 한 번이다** — 상자는 픽업을 안 뿌리고 픽업은 상자를 안 지나므로
##  경로가 안 겹친다. **둘 다 하면 이중 해금이고 에러가 0이다.**
## 🔴 `gs`·`bus`를 **인자로 받는다** — static에서 오토로드 식별자를 컴파일타임 참조하면 `-s` 테스트가
##  컴파일 단계에서 죽는다.
##
## **반환 = 「아이템을 가방에 넣었나」** — 픽업이 그걸로 소리를 낼지 정한다.
##  🔴 해금물은 소리를 **안 낸다**: `codex_unlocked`가 이미 unlock음을 울려 두 겹이 된다.
##
## 해금물 쪽 계약:
## 🔴 `codex_unlocked` **한 발**로 codex 심기 + 해금음 + UNLOCK 퀘스트 진행 + 자동 저장이 전부 따라온다.
## 🔴 **가방에 안 넣는다** — 아이템이 아니라 배움이다. 그래서 `item_collected`도 안 쏜다: HUD 토스트가
##   `Db.get_item(id)`으로 이름을 찾는데 해금물엔 `ItemDef`가 없어 **원시 id가 화면에 노출된다.**
## 🔴 **이미 해금이면 다시 안 쏜다** — 같은 두루마리를 둘 줍거나 그 사이 공방에서 같은 고리를 만들면
##   해금음·UNLOCK 퀘스트가 중복 반응한다.
static func grant_one(p_item_id: StringName, p_count: int, p_unlock_id: StringName,
		gs: Node, bus: Node) -> bool:
	if gs == null or bus == null:
		return false
	if p_unlock_id != &"":
		if not gs.is_unlocked(p_unlock_id):
			bus.codex_unlocked.emit(p_unlock_id)
		return false
	if p_item_id == &"" or p_count <= 0:
		return false
	gs.add_to_bag(p_item_id, p_count)
	bus.item_collected.emit(p_item_id, p_count)
	return true


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


## 도착 팝 — 플레이어 자리에서 터지고 사라진다.
## ⚠ `_exit_tree`로 뭘 끊지 마라: 트윈은 이 노드에 바인딩돼 노드가 free되면 같이 죽는다.
func _pop_and_free() -> void:
	if _visual == null:
		queue_free()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector2(POP_SCALE_IN, POP_SCALE_IN), POP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "modulate:a", 0.0, POP_TIME)
	tw.chain().tween_callback(queue_free)
