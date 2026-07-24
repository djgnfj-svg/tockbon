extends CharacterBody2D
## 숲의 적 — 쫓아와서 접촉 피해. 사용자 확정 세션 26: *"한 종류만 — 쫓아와서 접촉 피해"*.
##
## 🔴 **적 노드 계약**을 지킨다 (허수아비 `src/spell/dummy_target.gd`가 그 참고 구현이다):
##   그룹 `"enemies"` · 레이어 4(enemy) · `take_hit(damage, rune_type, status, status_power)` ·
##   그 안에서 `EventBus.enemy_hit`를 **약점 배율까지 반영한 최종 피해**로 발신.
## 발사(ring_spell_system)가 이미 이 계약으로 때린다 — 그래서 이 파일은 발사를 전혀 모른다.
##
## 🔴 **수치는 전부 `data/enemies/*.tres`(EnemyDef)가 쥔다 — 새 적 = .tres 한 장**이다
## (선례: 룬·펜·진). 코드엔 하나도 안 박혀 있고 `enemy_id`만 바꾸면 hp·속도·피해가 따라온다.
##
## 🔴 **레이어: layer 4(enemy) / mask 1(world)** (forest_enemy.tscn).
##  • mask에 2(player)를 넣지 마라 — 적이 플레이어를 **밀어내는** 게임이 되고, 접촉 피해는
##    어차피 아래 거리 판정이 판다 (물리 충돌이 필요 없다).
##  • layer 4가 곧 **맞는 몸**이다 — 캐리어·탄 마스크가 5(world+enemy)라 여길 본다.
##    기본 레이어 1로 되돌리면 world로 읽혀 마법이 **부딪히기만 하고 take_hit이 안 불린다**.

## 적이 죽었다. ⚠ **지금은 수신자가 없다** — 승리 조건 없는 익스트랙션이라 킬카운트를 아무도 안 센다.
## 킬카운트·웨이브가 붙는 날을 위한 자리표(placeholder)다.
signal died

## 🔴 바닥 픽업 프롭 (세션46) — 드롭을 가방에 순간이동시키지 않고 이 씬을 죽은 자리에 떨군다.
## preload가 안전한 이유: 픽업은 forest/actors를 안 물어 **순환 preload가 없다**(base⇄forest 함정 무관).
const DropPickup := preload("res://src/props/drop_pickup.tscn")


## 🔴 적 투사체 (세56 gale 연사) — 픽업·상자와 같은 이유로 preload 안전(탄은 field/actors를 안 문다).
const GaleProj := preload("res://src/field/enemy_projectile.tscn")

## 🔴 상태이상·원소 반응의 **규칙 단일 소스** (세션49). 규칙을 여기 베끼지 마라 — 복사하면
## "진흙인데 안 묶인다" 식으로 조용히 갈라진다(ring_power와 같은 이유).
const SR := preload("res://src/core/status_rules.gd")
## 🔴 상태 **보유고** (세션50 추출) — 적·허수아비가 같은 물건을 쓴다.
const SH := preload("res://src/core/status_holder.gd")
## 지속·반경·틱 간격 수치는 전부 balance가 쥔다 (연출값이 아니라 밸런스다).
const BAL := preload("res://data/balance.tres")

## 🔴 히트 플래시 셰이더 (세63 설계 §A) — modulate 곱셈(어두운 픽셀이 안 하얘짐) 대신 mix-to-white.
## Shader **리소스** 공유는 안전 — 인스턴스마다 갈라야 하는 건 uniform을 쥔 ShaderMaterial 쪽이다
## (`_ready`가 per-instance 생성. 공유하면 한 마리의 플래시가 전원 플래시다).
const FLASH_SHADER := preload("res://src/actors/hit_flash.gdshader")
## 발밑 그림자 (세63 설계 §D) — 공용 배우 컴포넌트. 여기서 자동 부착하므로 **미래의 모든 적이
## 공짜**다("새 적 = .tres 한 장" 계약 — 씬마다 노드를 요구하면 새 적마다 침묵 누락이 생긴다).
const ShadowScript := preload("res://src/actors/shadow.gd")

@export var enemy_id: StringName = &"slime"

@onready var _visual: AnimatedSprite2D = $Visual

## 🔴 피격 손맛 (세션 38 · 세63 개편) — 넉백/플래시/스쿼시 **연출값**. 밸런스가 아니라 느낌값이라
## 여기 const (projectile 물리 여유 const 선례). 사용자가 직접 때려 보며 조인다.
const KNOCKBACK_IMPULSE := 140.0  ## 맞는 순간 플레이어 반대쪽으로 밀려나는 속도
const KNOCKBACK_DECAY := 600.0    ## 넉백 감쇠(속도/s) — 빨리 원래 추격으로 복귀
const POP_SQUASH := Vector2(1.25, 0.78)  ## 피격 스쿼시 — 가로로 눌리며 "맞았다"가 읽힌다
const POP_SEC := 0.18             ## 플래시 감쇠·스쿼시 복귀 시간(s)
const TELEGRAPH_AMOUNT := 0.6     ## 윈드업 붉은 달아오름 세기 (셰이더 telegraph_amount)
const HURT_HOLD_SEC := 0.15       ## 1프레임 hurt 스트립의 홀드 시간 (설계 §C 함정 — 아래 _play_hurt)
const SHADOW_RADIUS_FRAC := 0.30  ## 그림자 반경 = 프레임 한 변 × 이 값
const SHADOW_OFFSET_FRAC := 0.35  ## 발밑 오프셋 = 프레임 한 변 × 이 값 (프레임 바닥 근사)

var _def: EnemyDef = null
var _hp: float = 0.0
var _cool: float = 0.0
## 피격 넉백 속도 — 추격 속도 위에 얹혀 빠르게 사그라든다.
var _knockback: Vector2 = Vector2.ZERO

## 🔴 행동 갈래 = `params.ai` (기본 "chase" = 현행). "새 적 = .tres 한 장"이 **행동까지**
## 포함하게 params에 얹었다(스키마 확장 대신 — color·size·sprite 선례 그대로). 수치는 전부
## `_param`으로 .tres에서 읽는다 — balance.tres가 아니다(적 수치는 EnemyDef가 쥔다는 계약).
var _ai: String = "chase"

## 돌진(charge) 상태기계 — hound. 텔레그래프(윈드업)가 있어 **피할 수 있는** 공격이 된다.
enum ChargeState { APPROACH, WINDUP, CHARGE, RECOVER }
var _charge_state: int = ChargeState.APPROACH
var _charge_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO

## 부유(hover) 분산 상태 — mist. 분산 중엔 받는 피해가 준다(take_hit) + 반투명(때리기 나쁨이 보인다).
var _disperse_timer: float = 0.0
var _dispersed: bool = false

## 🔴 뱀 보스(boss_snake) 전용 상태 (세션 A). charge 변수를 재사용하지 않는다 — 두 AI가 섞이면
## 조용히 깨진다(설계 A-5). 위브 추격 → 텔레그래프 러시 → 회복 → 다시 위브.
enum SnakeState { WEAVE, RUSH_WINDUP, RUSH, RECOVER }
var _snake_state: int = SnakeState.WEAVE
var _snake_timer: float = 0.0     ## 현재 상태 잔여 시간
var _snake_rush_cd: float = 0.0   ## 러시 재사용 대기(위브 중에만 감소)
var _weave_t: float = 0.0         ## 위브 사인파의 시간 누적(boss 틱 delta)
var _snake_dir: Vector2 = Vector2.RIGHT  ## 러시 락 방향 + 머리 바라보는 방향
## hp 절반 페이즈 전이 — 1회 플래그. 🔴 **보스 공용**이다(세56) — 뱀은 위브 진폭·러시 빈도,
## gale은 돌풍·연사 빈도·이동속도 배율이 오른다. 전이 판정 패턴도 두 분기가 같다.
var _phase2: bool = false

## 🔴 gale 보스(boss_gale) 전용 상태 (세56). charge/snake 변수를 재사용하지 않는다 — 두 AI가
## 섞이면 조용히 깨진다(뱀과 같은 원칙). 거리 유지(DRIFT) → 붙으면 돌풍 윈드업 → 밀쳐내기.
enum GaleState { DRIFT, GUST_WINDUP }
var _gale_state: int = GaleState.DRIFT
var _gale_timer: float = 0.0        ## 윈드업 잔여 시간
var _gale_gust_cd: float = 0.0      ## 다음 돌풍까지 (DRIFT에서만 감소)
var _gale_volley_cd: float = 0.0    ## 다음 연사까지 (DRIFT에서만 감소)
var _gale_volley_left: int = 0      ## 이번 연사의 남은 발수 (DRIFT 위 오버레이 카운터 — 이동은 계속)
var _gale_shot_timer: float = 0.0   ## 다음 발까지
var _gale_ring: Line2D = null       ## 돌풍 반경 텔레그래프 링 (지연 생성 — gale이 아니면 안 만든다)

## 돌풍 텔레그래프 링 **연출값** (밸런스 아님 — vfx.gd 링 상수 선례). 반경은 gust_radius(.tres)가 쥔다.
const GUST_RING_SEGMENTS := 24      ## 링 원 분할 수 (vfx._spawn_ring과 같은 결)
const GUST_RING_WIDTH := 2.5        ## 링 선 굵기(px)
const GUST_RING_COLOR := Color(0.75, 0.95, 1.0, 0.85)  ## 옅은 바람색

## 🔴 상태이상 보유고 (세션49 → 세션50에 `src/core/status_holder.gd`로 **추출**).
## 보유·틱·반응 해결은 전부 holder가 한다 — 여기 남은 건 **몸의 일**(피해·확산·색)뿐이다.
## 추출한 이유: 허수아비가 같은 코드를 못 써서 **연습장에서 반응을 시험할 수 없었다**.
var _status: SH = SH.new()
## 🔴 죽음 1회 보장 — DoT·연쇄·즉발이 같은 프레임에 겹쳐도 `_die()`가 두 번 돌면
## 드롭이 두 번 떨어지고 퀘스트가 두 번 센다(queue_free는 프레임 끝에야 반영된다).
var _dead: bool = false
## hurt 홀드 세대 토큰 (세63) — 연타 시 마지막 발동의 타이머만 idle 복귀시킨다 (_play_hurt).
var _hurt_gen: int = 0


func _ready() -> void:
	add_to_group("enemies")
	_wire_status()
	_def = Db.get_enemy(enemy_id)
	if _def == null:
		# 조용히 죽지 않게 — .tres 이름을 틀리면 hp 0짜리 유령이 서 있게 된다.
		push_warning("EnemyDef '%s'를 못 찾았다 (data/enemies/ 확인) — 기본값으로 선다" % enemy_id)
	_hp = _def.hp if _def != null else 10.0
	_ai = str(_def.params.get("ai", "chase")) if _def != null else "chase"
	# 분산 주기를 처음 채워 둔다 — 곧장 분산으로 튀지 않게(첫 토글은 한 주기 뒤).
	_disperse_timer = _param("disperse_period", 2.5)
	# gale 쿨도 한 주기 채워 시작한다 — 조우 즉시 돌풍/연사가 터지지 않게 (disperse_timer 선례).
	_gale_gust_cd = _param("gust_period", 3.0)
	_gale_volley_cd = _param("volley_period", 4.5)
	# 🔴 히트 플래시 material은 **per-instance 생성** (세63 설계 §A) — 같은 ShaderMaterial 리소스를
	# 전원이 공유하면 한 마리의 플래시가 전원 플래시다. .tscn에 박지 않는 이유도 이것
	# (박으면 resource_local_to_scene이 필요한데 코드 생성이 더 단순하고 검증 가능하다).
	if _visual != null:
		var mat := ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		mat.set_shader_parameter(&"flash_amount", 0.0)
		mat.set_shader_parameter(&"telegraph_amount", 0.0)
		_visual.material = mat
	_apply_look()
	_attach_shadow()


## 🔴 외형도 .tres가 쥔다 (`params.color`·`params.size`) — "새 적 = .tres 한 장"이 생김새까지
## 포함하게 하려는 것. 없으면 기본 초록·1배(슬라임 그대로).
## ⚠ 이건 **표시일 뿐 AI가 아니다** — 세션 30 "데이터만(리스킨)" 방침 그대로다. 행동(추격+접촉)은
## 한 가지뿐이고, 색·덩치만 .tres로 달라진다. 스키마를 안 늘리고 `params`에 얹은 이유 = enemy_def.gd
## 주석("스키마 확장 대신 params를 쓴다"). size는 루트 scale이라 **덩치가 곧 히트박스**가 된다.
func _apply_look() -> void:
	if _def == null or _visual == null:
		return
	# 🔴 스프라이트 = `params.sprite` 경로 (세션45 — 옛 색 폴리곤에서 실제 도트 시트로). 프레임은
	# 정사각(높이=한 변)으로 가로 스트립이라, 런타임에 SpriteFrames를 구워 붙인다(플레이어 시트와 같은 결).
	# "새 적 = .tres 한 장"이 스프라이트까지 포함하게 params에 얹었다(스키마를 안 늘린다 — params.color·size 선례).
	var sprite_path := str(_def.params.get("sprite", ""))
	if sprite_path != "":
		var tex := load(sprite_path) as Texture2D
		if tex != null:
			_setup_frames(tex)
	var s := float(_def.params.get("size", 1.0))
	if not is_equal_approx(s, 1.0):
		scale = Vector2(s, s)


## 가로 스트립 시트(프레임 = 정사각, 한 변 = 시트 높이)를 루프 "idle" 애니로 굽는다.
## 프레임 수 = 폭 ÷ 높이. slime 128×32=4 · hound 256×32=8 · gale 384×64=6 — 높이 기준이라 다 맞는다.
## 🔴 세63 확장: `params.hurt_sprite` 경로가 있으면 **같은 규약**으로 비루프 "hurt"를 얹는다.
## 없으면 기존과 완전 동일 — **기존 경로 무변경이 하위호환 계약**이다(전 적 공용 함수).
func _setup_frames(tex: Texture2D) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	if not _bake_strip(frames, &"idle", tex, true):
		return
	var hurt_path := str(_def.params.get("hurt_sprite", "")) if _def != null else ""
	if hurt_path != "":
		if ResourceLoader.exists(hurt_path):
			var htex := load(hurt_path) as Texture2D
			if htex != null:
				_bake_strip(frames, &"hurt", htex, false)
		else:
			# 시트가 없으면 hurt 없이 선다 — 침묵 대신 경고 (enemy_projectile 시트 부재 선례).
			push_warning("hurt_sprite를 못 찾았다 (%s) — hurt 애니 없이 선다" % hurt_path)
	_visual.sprite_frames = frames
	_visual.play(&"idle")


## 가로 스트립 한 장 → 애니 하나 (idle·hurt 공용 굽기). 성공하면 true.
func _bake_strip(frames: SpriteFrames, anim: StringName, tex: Texture2D, loop: bool) -> bool:
	var side := tex.get_height()
	if side <= 0:
		return false
	var count := maxi(1, tex.get_width() / side)
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, 6.0)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * side, 0, side, side)
		frames.add_frame(anim, at)
	return true


## 🔴 발밑 그림자 자동 부착 (세63 설계 §D) — 루트 scale의 자식이라 `params.size`(=덩치)를 공짜로
## 추종한다. 크기·오프셋은 idle 첫 프레임의 한 변에서 근사(연출 시작값 — 사용자 튜닝).
## z는 **0 유지 + move_child(…, 0)** — 음수 z는 Ground(z0) 뒤로 숨는다(세54 마디 실증).
func _attach_shadow() -> void:
	var side := 32.0
	if _visual != null and _visual.sprite_frames != null \
			and _visual.sprite_frames.has_animation(&"idle") \
			and _visual.sprite_frames.get_frame_count(&"idle") > 0:
		var t := _visual.sprite_frames.get_frame_texture(&"idle", 0)
		if t != null:
			side = float(t.get_height())
	var shadow: Sprite2D = ShadowScript.new()
	shadow.radius_px = side * SHADOW_RADIUS_FRAC
	shadow.position = Vector2(0.0, side * SHADOW_OFFSET_FRAC)
	add_child(shadow)
	move_child(shadow, 0)


## 🔴 행동을 `params.ai`로 가른다 (기본 "chase" = 현행). 각 갈래가 `velocity`(추격 의지)를 세우면
## 공통 꼬리가 넉백을 얹어 move_and_slide한다. 접촉 피해는 각 갈래가 `_contact`로 부른다.
## 수치는 전부 `_param`으로 .tres에서 읽는다 (balance.tres 아님 — 적 수치는 EnemyDef가 쥔다).
func _physics_process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	# 🔴 `_dead`면 틱 자체를 건너뛴다 — holder는 죽음을 모른다(가드는 몸이 쥔다).
	if not _dead:
		_status.tick(delta)
	if _dead:
		return  # DoT로 죽었다 — 이 프레임엔 더 움직이지 않는다(queue_free는 프레임 끝에 반영된다)
	_regen(delta)
	var player := _player()
	if player == null:
		velocity = Vector2.ZERO
		_apply_move(delta)
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()

	match _ai:
		"charge":
			_ai_charge(delta, player, to_player, dist)
		"hover":
			_ai_hover(delta, player, to_player, dist)
		"stationary":
			_ai_stationary(player, dist)
		"boss_snake":
			_ai_boss_snake(delta, player, to_player, dist)
		"boss_gale":
			_ai_boss_gale(delta, player, to_player, dist)
		_:
			_ai_chase(player, to_player, dist)

	_apply_move(delta)


## 넉백을 추격 속도 위에 얹어 움직이고 넉백을 사그라뜨린다 (피격 손맛). 모든 갈래 공통 꼬리.
## 🔴 **감속은 여기 한 곳에만** 곱한다 (세션49) — AI 3종(추격·돌진·부유)이 전부 이 통로를 지나므로
## 한 줄이 전부를 먹는다. 갈래마다 곱하면 새 AI를 넣을 때 조용히 빠진다.
## ⚠ 넉백에는 안 곱한다 — 넉백은 손맛(연출)이지 이동 의지가 아니다.
func _apply_move(delta: float) -> void:
	velocity *= _status.move_mult()
	velocity += _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)


## "chase" (기본, 슬라임·갑충·엘리트) — aggro_range 안이면 다가오고 attack_range 안이면 때린다.
func _ai_chase(player: Node2D, to_player: Vector2, dist: float) -> void:
	if dist <= _param("aggro_range", 160.0) and dist > 1.0:
		velocity = to_player / dist * _param("move_speed", 55.0)
	else:
		velocity = Vector2.ZERO
	_contact(player, dist)


## "charge" (사냥개) — 접근 → 윈드업(멈춰 텔레그래프·방향 락) → 돌진(락 방향으로 빠르게) →
## 회복(느림) → 접근. 🔴 락을 **윈드업 시작에** 걸어 두므로, 그 사이 옆으로 피하면 돌진을 흘린다
## (피할 수 있는 공격이 되게 하는 핵심). 접촉 피해는 접근·돌진에서만 — 윈드업·회복은 무해(빈틈).
func _ai_charge(delta: float, player: Node2D, to_player: Vector2, dist: float) -> void:
	match _charge_state:
		ChargeState.APPROACH:
			if dist <= _param("aggro_range", 220.0) and dist > 1.0:
				velocity = to_player / dist * _param("move_speed", 95.0)
			else:
				velocity = Vector2.ZERO
			_contact(player, dist)
			if dist <= _param("charge_trigger_range", 120.0) and dist > 1.0:
				_charge_state = ChargeState.WINDUP
				_charge_timer = _param("windup_sec", 0.5)
				_charge_dir = to_player / dist  # 방향 락 (지금 이 순간의 플레이어 쪽)
				_set_telegraph(true)
		ChargeState.WINDUP:
			velocity = Vector2.ZERO
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.CHARGE
				_charge_timer = _param("dash_sec", 0.4)
				_set_telegraph(false)
		ChargeState.CHARGE:
			velocity = _charge_dir * _param("charge_speed", 330.0)
			_contact(player, dist)
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.RECOVER
				_charge_timer = _param("recover_sec", 0.8)
		ChargeState.RECOVER:
			velocity = Vector2.ZERO
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.APPROACH


## "hover" (안개) — 거리 유지: hover_min보다 가까우면 물러나고, hover_max보다 멀면 다가오고,
## 그 사이면 천천히 스트레이프. disperse_period마다 분산 상태를 토글(분산 중 피해 경감 + 반투명).
func _ai_hover(delta: float, player: Node2D, to_player: Vector2, dist: float) -> void:
	var spd := _param("move_speed", 70.0)
	var dir := to_player / dist if dist > 0.01 else Vector2.ZERO
	if dist < _param("hover_min", 55.0):
		velocity = -dir * spd            # 너무 가깝다 → 물러난다
	elif dist > _param("hover_max", 95.0):
		velocity = dir * spd             # 너무 멀다 → 다가온다
	else:
		velocity = Vector2(-dir.y, dir.x) * spd * 0.5  # 사이 → 천천히 옆으로 돈다
	_contact(player, dist)

	var period := _param("disperse_period", 0.0)
	if period > 0.0:
		_disperse_timer -= delta
		if _disperse_timer <= 0.0:
			_disperse_timer = period
			_set_dispersed(not _dispersed)


## "stationary" (덩굴) — 안 움직인다(move_speed 0). 재생은 `_regen`이 공통으로 돌린다.
## 접촉 피해는 긴 attack_range로 — "빨리 몰아쳐 죽여야 하는" 표적.
func _ai_stationary(player: Node2D, dist: float) -> void:
	velocity = Vector2.ZERO
	_contact(player, dist)


## "boss_snake" (뱀 보스, 세션 A) — 세그먼트 몸통(snake_body.gd)을 **살리는** 이동이 핵심이다.
##  • **위브 추격**: 플레이어를 향하는 진행 벡터에 그 수직 방향으로 sin(t·freq)·amp를 얹어 머리가
##    S자로 미끄러진다 → 몸통이 그 S를 물려받아 물결친다(설계 A-3·A-5).
##  • **텔레그래프 러시**: 짧게 멈춰 붉게 달아오른 뒤(기존 `_set_telegraph` 재사용) 플레이어 쪽으로
##    확 뻗고 회복한다. 방향은 윈드업 시작에 락(그 사이 피하면 흘린다 — charge와 같은 손맛).
##  • **hp 절반 페이즈**: 위브 진폭·러시 빈도·이동속도 배율이 오른다(1회 플래그).
## 🔴 수치는 전부 `_param`으로 .tres(EnemyDef)에서 읽는다 — balance.tres 아님(적 수치는 EnemyDef).
## 🔴 머리 회전은 **`_visual.rotation`만** 돌린다(루트 rotation은 SnakeBody 자식 좌표를 꼬는다, A-6).
func _ai_boss_snake(delta: float, player: Node2D, to_player: Vector2, dist: float) -> void:
	# 페이즈 전이 — hp가 임계 밑으로 처음 떨어지는 순간 1회.
	if not _phase2 and _def != null and _hp <= _def.hp * _param("phase2_hp_frac", 0.5):
		_phase2 = true

	_weave_t += delta
	_snake_rush_cd = maxf(0.0, _snake_rush_cd - delta)
	var speed_mult := _param("phase2_speed_mult", 1.35) if _phase2 else 1.0
	var weave_amp := _param("phase2_weave_amp", 90.0) if _phase2 else _param("weave_amp", 60.0)

	match _snake_state:
		SnakeState.WEAVE:
			if dist > 1.0:
				var fwd := to_player / dist
				var perp := Vector2(-fwd.y, fwd.x)
				var base_speed := _param("move_speed", 72.0) * speed_mult
				var lateral := sin(_weave_t * _param("weave_freq", 3.2)) * weave_amp
				velocity = fwd * base_speed + perp * lateral
			else:
				velocity = Vector2.ZERO
			_contact(player, dist)
			# 러시 발동 — 쿨다운이 끝났고 사거리 안이면 윈드업으로.
			if _snake_rush_cd <= 0.0 and dist <= _param("rush_range", 240.0) and dist > 1.0:
				_snake_state = SnakeState.RUSH_WINDUP
				_snake_timer = _param("rush_windup", 0.6)
				_snake_dir = to_player / dist  # 방향 락(지금 이 순간)
				_set_telegraph(true)
		SnakeState.RUSH_WINDUP:
			velocity = Vector2.ZERO
			_snake_timer -= delta
			if _snake_timer <= 0.0:
				_snake_state = SnakeState.RUSH
				_snake_timer = _param("rush_dur", 0.5)
				_set_telegraph(false)
		SnakeState.RUSH:
			velocity = _snake_dir * _param("rush_speed", 340.0) * speed_mult
			_contact(player, dist)
			_snake_timer -= delta
			if _snake_timer <= 0.0:
				_snake_state = SnakeState.RECOVER
				_snake_timer = _param("rush_recover", 0.8)
		SnakeState.RECOVER:
			velocity = Vector2.ZERO
			_snake_timer -= delta
			if _snake_timer <= 0.0:
				_snake_state = SnakeState.WEAVE
				var cd := _param("phase2_rush_cd", 1.8) if _phase2 else _param("rush_cd", 3.0)
				_snake_rush_cd = cd

	# 머리는 진행 방향(러시 중이면 락 방향)을 바라본다. 멈춰 있으면 마지막 방향 유지.
	if velocity.length_squared() > 1.0:
		_snake_dir = velocity.normalized()
	_face(_snake_dir)


## "boss_gale" (바람 보스, 세56) — hover형 거리 유지 + 근접 징벌(돌풍) + 원거리 압박(연사).
##  • **DRIFT**: hover_min~hover_max 거리 유지(가까우면 물러나고 멀면 다가오고 사이면 스트레이프).
##    `_ai_hover` 함수를 재사용하지 않고 분기 안에 다시 쓴다 — 그 함수엔 disperse(안개)가 얽혀 있다.
##  • **돌풍(gust)**: 쿨 소진 && dist ≤ gust_radius → 윈드업(붉은 텔레그래프 + 반경 링) →
##    끝나는 순간 반경 안이고 구르는 중이 아니면 피해 + 밀쳐내기(`player.apply_push`).
##    플레이어가 안 붙으면 안 쓴다 — 낭비 텔레그래프 없음.
##  • **연사(volley)**: DRIFT에서만 쿨 감소(윈드업과 안 겹치게). 발동하면 **이동을 유지한 채**
##    volley_interval마다 1발 — 매 발 발사 순간의 플레이어 위치로 **재조준**(움직이며 피하는 재미).
##  • **hp 절반 페이즈**: `_phase2` 공용 재사용 — 돌풍·연사 쿨(rate_mult)·이동속도(speed_mult)가 오른다.
##    배율은 **쿨 리셋 시점에** 곱한다(진행 중 타이머를 건드리면 전이 순간 이중 적용).
## 🔴 수치는 전부 `_param`으로 .tres(EnemyDef)에서 읽는다 — balance.tres 아님(적 수치는 EnemyDef).
func _ai_boss_gale(delta: float, player: Node2D, to_player: Vector2, dist: float) -> void:
	# 페이즈 전이 — hp가 임계 밑으로 처음 떨어지는 순간 1회 (boss_snake 첫 줄과 동일 패턴).
	if not _phase2 and _def != null and _hp <= _def.hp * _param("phase2_hp_frac", 0.5):
		_phase2 = true
	var rate_mult := _param("phase2_rate_mult", 0.65) if _phase2 else 1.0
	var speed_mult := _param("phase2_speed_mult", 1.3) if _phase2 else 1.0

	match _gale_state:
		GaleState.DRIFT:
			# 거리 유지 (hover형 재작성 — 로직 ~8줄이라 분기 내가 깨끗하다).
			var spd := _param("move_speed", 55.0) * speed_mult
			var dir := to_player / dist if dist > 0.01 else Vector2.ZERO
			if dist < _param("hover_min", 110.0):
				velocity = -dir * spd            # 너무 가깝다 → 물러난다
			elif dist > _param("hover_max", 170.0):
				velocity = dir * spd             # 너무 멀다 → 다가온다
			else:
				velocity = Vector2(-dir.y, dir.x) * spd * 0.5  # 사이 → 천천히 옆으로 돈다
			_contact(player, dist)               # attack_range 30 근접 징벌은 그대로 산다
			_gale_gust_cd = maxf(0.0, _gale_gust_cd - delta)
			_gale_volley_cd = maxf(0.0, _gale_volley_cd - delta)
			# 돌풍 — 쿨 소진 && 플레이어가 반경 안일 때만 (안 붙으면 낭비 텔레그래프 없음).
			if _gale_gust_cd <= 0.0 and dist <= _param("gust_radius", 90.0) and dist > 1.0:
				_gale_state = GaleState.GUST_WINDUP
				_gale_timer = _param("gust_windup", 0.8)
				_set_telegraph(true)             # 기존 붉은 달아오름 재사용 (charge·snake와 같은 규약)
				_show_gust_ring(true)
			# 연사 — 진행 중이 아닐 때만 새로 발동. 쿨 리셋 시점에 페이즈 배율을 곱는다.
			elif _gale_volley_cd <= 0.0 and _gale_volley_left <= 0 and dist <= _param("aggro_range", 260.0):
				_gale_volley_left = int(_param("volley_count", 3.0))
				_gale_shot_timer = 0.0           # 첫 발은 다음 틱 즉시
				_gale_volley_cd = _param("volley_period", 4.5) * rate_mult
		GaleState.GUST_WINDUP:
			velocity = Vector2.ZERO
			_gale_timer -= delta
			if _gale_timer <= 0.0:
				_gale_state = GaleState.DRIFT
				_set_telegraph(false)
				_show_gust_ring(false)
				_resolve_gust(player, dist)
				_gale_gust_cd = _param("gust_period", 3.0) * rate_mult

	# 연사 발사 — DRIFT 위 오버레이 카운터(전용 상태 아님 — 이동하며 쏘는 바람 궁수 느낌).
	# 윈드업 중엔 멈춘다(돌풍과 안 겹치게) — DRIFT로 돌아오면 남은 발수를 이어 쏜다.
	if _gale_volley_left > 0 and _gale_state == GaleState.DRIFT:
		_gale_shot_timer -= delta
		if _gale_shot_timer <= 0.0:
			_gale_shot_timer = _param("volley_interval", 0.25)
			_gale_volley_left -= 1
			_fire_gale_shot(player)


## 돌풍 판정 — 윈드업이 끝나는 순간 1회. 반경 밖이면 헛방(윈드업을 보고 걸어나가면 피한다),
## 구르는 중이면 피해·밀림 다 흘린다(구르기 = 무적 계약 — `_contact`와 동일 규약).
func _resolve_gust(player: Node2D, dist: float) -> void:
	if player == null or dist > _param("gust_radius", 90.0):
		return
	var dodging: bool = player.has_method(&"is_rolling") and bool(player.call(&"is_rolling"))
	if dodging:
		return
	# 🔴 source_pos(세63) = 내 위치 — player_hurt에 실려 방향성 카메라 킥이 쓴다.
	GameState.damage_player(_param("gust_damage", 8.0), global_position)
	# 밀쳐내기 — 방향 = 나 → 플레이어. has_method 가드: 테스트 더미(Node2D)도 견딘다.
	if player.has_method(&"apply_push"):
		var away := player.global_position - global_position
		if away.length() > 0.1:
			player.call(&"apply_push", away.normalized(), _param("gust_push_dist", 70.0))


## 연사 1발 — **발사 순간의 플레이어 위치**로 재조준(락 조준은 3발이 같은 자리에 몰려 밋밋).
## 탄은 현재 씬에 붙는다(death_puff·drop_pickup 규약 — 적이 죽어도 탄은 남는다: 유언 탄).
func _fire_gale_shot(player: Node2D) -> void:
	var scene := get_tree().current_scene
	if scene == null or player == null:
		return
	var dir := player.global_position - global_position
	if dir.length() < 0.1:
		return
	var proj := GaleProj.instantiate()
	scene.add_child(proj)
	proj.global_position = global_position
	proj.setup(dir.normalized(), _param("proj_damage", 6.0),
		_param("proj_speed", 170.0), _param("proj_lifetime", 2.8))


## 돌풍 반경 텔레그래프 링 — 윈드업 동안만 보인다. **절차적 VFX라 도형이 맞다**(takbon-rules §0
## 예외 — 돌풍은 형태 없는 공기 흐름, death_puff·vfx.gd 링과 같은 "그림"이다). 지연 생성이라
## gale이 아닌 적은 노드 자체가 없다. 🔴 z_index 양수 명시 — 세54에 음수 z 마디가 Ground(z0)
## 뒤로 숨은 함정의 재발 자리다.
func _show_gust_ring(on: bool) -> void:
	if on and _gale_ring == null:
		_gale_ring = Line2D.new()
		_gale_ring.width = GUST_RING_WIDTH
		_gale_ring.default_color = GUST_RING_COLOR
		var radius := _param("gust_radius", 90.0)
		var pts := PackedVector2Array()
		for i in GUST_RING_SEGMENTS:
			pts.append(Vector2.RIGHT.rotated(TAU * float(i) / float(GUST_RING_SEGMENTS)) * radius)
		pts.append(pts[0])  # 닫는다 (vfx._spawn_ring과 같은 결)
		_gale_ring.points = pts
		_gale_ring.z_index = 40
		add_child(_gale_ring)
	if _gale_ring != null:
		_gale_ring.visible = on


## 🔴 머리만 회전 — `_visual.rotation`(설계 A-6). boss_snake 분기에서만 부른다(다른 AI 무영향).
## 스프라이트/플레이스홀더는 진행 방향 +x 기준이라 각도를 그대로 준다.
func _face(dir: Vector2) -> void:
	if _visual == null or dir.length_squared() < 0.0001:
		return
	_visual.rotation = dir.angle()


## 접촉 피해 — attack_range 안이면 attack_cooldown 간격으로 GameState를 깎는다.
## 🔴 구르는 중이면 흘린다 (무적 프레임 — 세션41 구르기). player.is_rolling()가 유일 판정.
## .call로 부른다: player는 Node2D 타입이라 is_rolling()을 정적으로 못 찾는다(공용 배우 계약 무변경).
func _contact(player: Node2D, dist: float) -> void:
	if dist > _param("attack_range", 18.0) or _cool > 0.0:
		return
	_cool = _param("attack_cooldown", 0.9)
	var dodging: bool = player.has_method(&"is_rolling") and bool(player.call(&"is_rolling"))
	if not dodging:
		# 🔴 source_pos(세63) = 내 위치 — player_hurt에 실려 방향성 카메라 킥이 쓴다.
		GameState.damage_player(_param("contact_damage", 4.0), global_position)


## 🔴 재생 — `regen_per_sec > 0`이면 초당 회복(상한 = `_def.hp`). 죽은 뒤(_hp<=0)엔 회복 안 한다.
## "빨리 몰아쳐 죽여야 하는" 표적을 만든다 (덩굴). 대부분 적은 regen_per_sec가 없어 no-op.
func _regen(delta: float) -> void:
	if _def == null or _hp <= 0.0:
		return
	var rps := _param("regen_per_sec", 0.0)
	if rps <= 0.0:
		return
	_hp = minf(_def.hp, _hp + rps * delta)


# ── 상태이상 (세션49) ─────────────────────────────────────────────────────────
# 🔴 **규칙은 전부 `SR`(src/core/status_rules.gd)이 쥔다.** 여기 있는 건 "보유하고 시간을 돌리는"
# 일뿐이다 — 어떤 조합이 무엇이 되는지·얼마나 가는지·얼마나 느려지는지를 이 파일에서 판단하지 마라.


## holder의 콜백을 이 몸에 잇는다 (`_ready`에서 한 번). 🔴 **콜백 경계**가 추출의 핵심이다 —
## holder는 규칙과 시간만 알고, hp를 깎고 씬을 뒤지고 색을 칠하는 건 전부 여기(몸)다.
func _wire_status() -> void:
	_status.on_dot = func(amount: float) -> void:
		# 🔴 DoT는 `EventBus.enemy_hit`을 **안 쏜다** — 그 시그널은 "최종 피해" 계약이라
		# 피해 숫자·히트스톱·피격음이 물려 있다(세38·46). 0.5초마다 쏘면 화면이 숫자로
		# 도배되고 히트스톱에 갇힌다. DoT는 조용히 hp만 깎고 표현은 틴트가 맡는다.
		_hp -= amount
		if _hp <= 0.0:
			_die()
	_status.on_burst = func(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void:
		_burst_damage(radius, amount, include_self, result_status, rune)
	_status.on_spread = func(statuses: Dictionary) -> void:
		_spread_statuses(statuses)
	_status.on_changed = _refresh_tint


## ⚠ **여기 `_exit_tree`로 콜백을 끊지 마라** (세50에 넣었다가 리뷰에서 걷어냈다).
## 끊을 순환이 없다: Callable은 대상이 RefCounted일 때만 강참조를 잡는데 소유자는 **Node**라
## ObjectID만 쥔다 — node→holder(강) / holder→node(약)로 이미 비순환이고, node가 free되면
## 멤버 holder도 같이 죽는다. 반대로 끊어 두면 **`_wire_status`가 `_ready`에만 있어서**
## 노드를 뺐다 다시 넣는 순간(리페어런팅·풀링) 콜백이 영구히 죽고 **적이 상태를 하나도 안 받는데
## 에러가 안 난다** — 이 프로젝트가 제일 무서워하는 침묵을 없는 문제를 막으려다 새로 심는 셈이다.


## 반경 안의 다른 적들(그룹 "enemies")에게 즉발 피해. `include_self`면 자신도 맞는다(증기).
## 🔴 `take_hit`이 아니라 `take_reaction_damage`로 때린다 — take_hit을 부르면 상태 판정이 다시
## 돌아 **연쇄가 연쇄를 낳는다**(무한 재귀). 반응 피해는 피해일 뿐 새 상태를 안 만든다.
## rune = 이 버스트의 정체 룬(세56) — 자신·연쇄 대상 모두 take_reaction_damage에 그대로 넘긴다.
func _burst_damage(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void:
	# 🔴 VFX 방송 (세52) — 터진 자리·**게임 반경**·결과 상태(증기=NONE·감전=SHOCK). 링이 반경을
	# 폭로하므로 amount 가드 **앞에** 둔다(반응은 일어났으니 링은 늘 뜬다). 피해 계산은 안 바뀐다.
	EventBus.reaction_burst.emit(global_position, radius, result_status)
	if amount <= 0.0:
		return
	if include_self:
		take_reaction_damage(amount, rune)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > radius:
			continue
		if node.has_method(&"take_reaction_damage"):
			# 🔴 감전(SHOCK)만 대상마다 번개 아크 — 증기(NONE)는 링만(설계 §4). 피해 전에 쏜다.
			if result_status == Enums.Status.SHOCK:
				EventBus.reaction_chain.emit(global_position, (node as Node2D).global_position, result_status)
			node.take_reaction_damage(amount, rune)


## 🔴 바람 확산 — **내게 이미 붙은 상태를** 반경 안의 적들에게 옮겨 붙인다.
## 내 것은 남긴다(옮기는 게 아니라 번진다) — 안 그러면 바람을 섞을수록 판이 깨끗해진다.
## 🔴 옆 적을 찾는 건 **몸의 일**이라 여기 남았다(holder는 씬을 모른다).
func _spread_statuses(statuses: Dictionary) -> void:
	if statuses.is_empty():
		return
	# 🔴 VFX (세52) — 여러 상태를 옮겨도 아크는 **한 대상에 한 가닥**. 색은 대표 상태(가장 최근).
	# 대표 상태는 holder 공개 API로 얻는다(세52 리뷰) — 몸이 내부 dict의 ["seq"]를 더듬지 않는다.
	var rep := _status.representative()
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > BAL.status_spread_px:
			continue
		if not node.has_method(&"apply_status"):
			continue
		EventBus.reaction_chain.emit(global_position, (node as Node2D).global_position, rep)
		for key: int in statuses.keys():
			node.apply_status(key, float(statuses[key]["power"]))


## 🔴 공개 — 확산이 옆 적에게 상태를 옮길 때 쓰는 유일 경로(내부 필드를 남이 더듬지 않게).
## 테스트도 이걸로 상태를 세운다. ⚠ 시그니처는 세션49 그대로다 — 공개 계약이라 안 넓혔다.
func apply_status(status: int, power: float) -> void:
	if _dead:
		return
	_status.add(status, power)


## 🔴 공개 관측점 — 헤드리스가 상태를 **공개 API로만** 확인하게 (takbon-verify §3, `hp()` 선례).
func has_status(status: int) -> bool:
	return _status.has(status)


func status_power_of(status: int) -> float:
	return _status.power_of(status)


## 🔴 반응 피해 — 조용히 hp만 깎는 DoT와 달리 **한 번뿐인 사건**이라 `enemy_hit`을 쏴 손맛을 준다
## (연쇄가 눈에 보여야 조합할 이유가 생긴다). 상태를 안 만들어 재귀가 없다.
## 🔴 rune(세56) = 이 반응의 정체 룬(감전=BOLT·증기=WATER) — enemy_hit에 그대로 실어야 소리가
## 반응과 맞는다(그전엔 FIRE 하드코딩이라 감전 연쇄가 불 소리를 냈다). 기본 인자 = 하위호환.
func take_reaction_damage(amount: float, rune: int = Enums.RuneType.FIRE) -> void:
	if _dead or amount <= 0.0:
		return
	_hp -= amount
	EventBus.enemy_hit.emit(self, amount, rune)
	_pop()
	_play_hurt()
	if _hp <= 0.0:
		_die()


## 지금 보여 줄 상태 색 — 고르는 규칙은 holder가 쥔다(적·허수아비가 같게 보이도록).
## 세63: 팝·텔레그래프가 셰이더로 옮겨가 "복귀 목표" 곡예가 소멸했다 — 이 색을 쓰는 곳은
## 이제 `_refresh_tint` 하나뿐이다.
func _status_tint() -> Color:
	return _status.tint()


## 🔴 modulate 소유권 계약 (세63 개편): modulate는 **rgb=상태 틴트 · a=분산** 두 축만 남았다.
## 팝(흰 섬광)·텔레그래프(붉음)는 셰이더 uniform(flash_amount·telegraph_amount)이 쥔다 —
## modulate를 만지는 코드는 이 함수와 `_set_dispersed`뿐이어야 한다(3파전으로 되돌리지 마라).
func _refresh_tint() -> void:
	if _visual == null:
		return
	var c := _status_tint()
	c.a = _visual.modulate.a
	_visual.modulate = c


## 돌진 텔레그래프 — 윈드업 동안 붉게 달아오른다(모으는 중이 보인다 → 피할 수 있다).
## 세63 개편: modulate 대신 셰이더 `telegraph_amount` — 팝 uniform(flash_amount)과 갈라져 있어
## **윈드업 중에 맞아도 섬광이 텔레그래프를 지우는 사고가 없다**(단일 amount로 합치면 팝 트윈이
## 0으로 감쇠하며 텔레그래프까지 끄는 함정). 붉은색은 셰이더 기본 uniform(telegraph_color).
## ⚠ 연출값이다 — 사용자가 실게임에서 보고 조인다.
func _set_telegraph(on: bool) -> void:
	if _visual == null:
		return
	var mat := _visual.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter(&"telegraph_amount", TELEGRAPH_AMOUNT if on else 0.0)


## 분산 표시 — 분산 중엔 반투명(지금은 때리기 나쁨이 보인다). 경감 자체는 take_hit이 적용한다.
func _set_dispersed(on: bool) -> void:
	_dispersed = on
	if _visual != null:
		_visual.modulate.a = 0.4 if on else 1.0


## 🔴 그룹 `"player"`가 유일한 조준 경로다 (player.gd가 `_ready`에서 넣는다).
## 빠지면 적이 **제자리에 굳는데 에러는 안 난다** — 세션 24·25의 침묵과 같은 종류다.
func _player() -> Node2D:
	var found := get_tree().get_first_node_in_group("player")
	return found as Node2D


func _param(key: String, fallback: float) -> float:
	if _def == null:
		return fallback
	return float(_def.params.get(key, fallback))


## 🔴 공개 HP 리더 — 재생·피해를 테스트가 공개 API로 확인할 유일 경로다 (`_hp`는 internal이라
## 리팩터 때 옮겨 다니는 물건 = 계약이 아니다. takbon-verify §3 "공개 API로만").
func hp() -> float:
	return _hp


## 🔴 공개 페이즈 리더 — **보스 공용**(세56: boss_snake·boss_gale) 페이즈 전이를 헤드리스가
## 공개 API로 확인한다(`hp()` 선례). 1 = 기본, 2 = hp 절반 이후. 보스가 아닌 적은 항상 1.
func phase() -> int:
	return 2 if _phase2 else 1


## 🔴 계약: `enemy_hit`는 **약점 배율을 반영한 최종 피해**로 발신한다 (dummy_target 주석).
## ✅ 세션49: `status`·`status_power`를 **드디어 쓴다** — 세34~48까지 밑줄로 버려서 불·물·바람의
## 실질 차이가 색 + 데미지 ±15%뿐이었다. 시그니처는 그대로다(계약을 넓히지 않았다).
func take_hit(damage: float, rune_type: int, status: int, status_power: float) -> void:
	if _dead:
		return
	# 🔴 세81 M2 (융합진): 직격 피해가 0 = 보조 룬의 **상태 전용 히트**. 손맛·발신·넉백·죽음판정을
	# 건너뛰고 상태만 얹는다 — 안 그러면 한 발이 룬 수만큼 `enemy_hit`·팝·피해숫자 "0"을 도배한다
	# (`juice.gd`가 발신마다 무조건 그린다). 반응은 `apply_incoming`이 판정하므로 여기서 얹으면 충분하다.
	# ⚠ 반응 **버스트**는 `take_reaction_damage` 별도 경로라 이 가드와 무관하다(그쪽은 계속 pop을 낸다).
	if damage <= 0.0:
		_status.apply_incoming(rune_type, status, status_power)
		return
	var mult := 1.0
	if _def != null and _def.has_counter and rune_type == _def.counter_rune:
		mult = _param("weakness_mult", 1.0)
	var dealt := damage * mult
	# 🔴 피해 경감 — 방어(갑충 armor_reduction) · 분산 중이면(안개 dispersed_resist) "막는 비율"로
	# 곱한다. 0.95로 상한을 둬 완전 무적은 못 만든다. 🔴 계약: enemy_hit은 **이 경감까지 반영한
	# 최종 피해**로 발신한다 (리포트·손맛이 실제 든 피해를 봐야 한다) — 약점 배율과 함께 곱해진 값.
	dealt *= (1.0 - clampf(_param("armor_reduction", 0.0), 0.0, 0.95))
	if _dispersed:
		dealt *= (1.0 - clampf(_param("dispersed_resist", 0.0), 0.0, 0.95))
	_hp -= dealt
	EventBus.enemy_hit.emit(self, dealt, rune_type)
	# 🔴 상태·반응은 피해 **뒤에** 판정한다 — 증기·연쇄가 이 한 대의 피해까지 얹은 뒤 터져야
	# "한 발로 무너졌다"가 성립한다. 여기서 죽었더라도 `_dead` 가드가 이중 처리를 막는다.
	_status.apply_incoming(rune_type, status, status_power)
	# 넉백 = 플레이어 반대쪽으로 (탄이 플레이어→적 방향으로 오므로 그 근사다 — take_hit 계약을
	# 안 넓히고도 맞는 방향으로 밀린다. 세션 26 forest_enemy 주석의 "계약을 좁히지 않는다"와 같은 결).
	var p := _player()
	if p != null:
		var away := global_position - p.global_position
		if away.length() > 0.1:
			_knockback = away.normalized() * KNOCKBACK_IMPULSE
	_pop()
	_play_hurt()
	if _hp <= 0.0:
		_die()


## 🔴 죽으면 **드롭을 굴려 바닥에 떨군다** (세션46 — 사용자: *"게임답게 걸어가 줍게"*).
## 그전엔 여기서 곧장 `add_to_bag`으로 **가방에 순간이동**했다 — 이제 드롭마다 `DropPickup`을
## 죽은 자리에 심고, 가방에 넣는 건 픽업이 플레이어에 닿을 때 한다(픽업이 `add_to_bag`을 부른다).
## 인벤 흐름은 그대로다: `add_to_bag` → 귀환(extraction_success) 시 창고로 회수 · 죽으면(bag_lost)
## 통째로 사라진다. 바뀐 건 **가방에 언제 들어가느냐**뿐이다("주웠다"가 진짜 줍는 행위가 됐다).
##
## 🔴 룬 조각(fragment_*)은 **`until_unlock` 관문 드롭으로만** 나온다 (세58, 정본 docs/PROGRESSION.md
## — 「뼈대는 확정, 살은 랜덤」). 잡몹 순수 확률 조각은 세58에 은퇴했다 — 조각을 확률 줄로 되살리면
## test_progression_auto [4]·test_decode_auto ⑥이 붉는다. 새 관문 = 적 .tres의 until_unlock 드롭 한 줄.
##
## 🔴 `Audio.play(&"pickup")`은 여기서 **뺐다** — 소리는 실제로 주울 때(픽업) 울린다.
##
## 랜덤: Godot 전역 `randf()` — 부팅 시 자동 시드. 이 프로젝트의 첫 게임플레이 랜덤이다
## (세이브에 안 들어간다 — 드롭은 굴린 결과일 뿐 RNG 상태를 저장하지 않는다).
func _die() -> void:
	if _dead:
		return  # 🔴 DoT 틱·연쇄·직격이 같은 프레임에 겹쳐도 드롭·퀘스트는 한 번뿐이어야 한다
	_dead = true
	_status.clear()  # 남은 DoT 틱이 시체를 더 때리지 않게
	var scene := get_tree().current_scene
	if _def != null and scene != null:
		# 🔴 먼저 **굴리기만** 하고, 실제로 나온 걸 안 뒤에 심는다 — 개수를 알아야 낱개 픽업이
		# **균등 각도**를 나눌 수 있고(세51), 상자는 한 번에 담아야 하기 때문이다(세55).
		var rolled := _roll_drops()
		if not rolled.is_empty():
			# 🔴 세66: 상자 은퇴 (사용자 확정 "상자 시스템 기각, 그냥 다 떨구는 걸로"). 모든 적이
			# 보스 포함 재료를 **낱개로** 떨군다(자석 픽업). 값어치는 픽업의 **등급 후광**이 알린다
			# (상자가 하던 "열기 전 값어치 겉보기"를 후광이 대체 — drop_pickup 등급 halo).
			_spawn_loose(scene, rolled)
	# 🔴 처치 순간 1회 — GameState가 KILL 퀘스트를 센다 (세션36). `died` 로컬 시그널의
	# "킬카운트가 붙는 날의 자리표"가 마침내 수신자를 얻었다. enemy_id를 실어 특정 적 목표도 가능.
	EventBus.enemy_died.emit(enemy_id)
	died.emit()
	_spawn_death_puff()
	queue_free()


## 🔴 드롭 테이블을 굴린다 (세51에 _die 안에 있던 로직 — 세55에 상자/낱개가 공유하려고 추출).
## 반환 = `[{"id": StringName, "count": int}]` — drop_pickup·loot_panel 계약이 "count"라 세 곳이 같은 이름을 본다.
## 세58: until_unlock(관문 드롭)만 확률 대신 해금 상태로 갈린다 — 나머지 확률·수량 로직은 그대로.
## 랜덤: Godot 전역 `randf()`/`randi()` — 부팅 시 자동 시드. 세이브에 안 들어간다(굴린 결과만 남는다).
func _roll_drops() -> Array[Dictionary]:
	var rolled: Array[Dictionary] = []
	var gs := get_node_or_null("/root/GameState")
	for drop: DropEntry in _def.drops:
		# 🔴 관문 드롭 (세58, 정본 docs/PROGRESSION.md): until_unlock가 있으면 확률이 아니라
		# 해금 상태가 정한다 — 미해금 = 확정, 해금됨 = 스킵. GameState가 없으면(고립 테스트)
		# 관문을 못 재므로 순수 확률로 폴백한다.
		if drop.until_unlock != &"" and gs != null:
			if gs.is_unlocked(drop.until_unlock):
				continue
		elif randf() > drop.chance:
			continue
		var n := drop.min_count
		if drop.max_count > drop.min_count:
			n += randi() % (drop.max_count - drop.min_count + 1)
		if n > 0:
			rolled.append({"id": drop.item_id, "count": n})
	return rolled


## 낱개 바닥 픽업 (잡몹, 세46·51) — 죽은 자리에 드롭마다 하나씩 심고 균등 각도로 흩뿌린다.
## 🔴 로직은 추출 전과 동일하다(키 "n"→"count"만 반영). global_position은 add_child 뒤에 잡고
## setup은 그 뒤에 불러야 scatter가 올바른 자리에서 시작한다.
func _spawn_loose(scene: Node, rolled: Array[Dictionary]) -> void:
	var base_angle := randf() * TAU
	for i in rolled.size():
		var pickup := DropPickup.instantiate()
		scene.add_child(pickup)
		# 여러 드롭이 겹치지 않게 살짝 흩뿌린 지점에서 심는다(픽업이 여기서 또 scatter).
		pickup.global_position = global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		# i번째 드롭 = base_angle + i·TAU/n → 2개면 정반대, 3개면 삼각형으로 흩어진다.
		pickup.setup(rolled[i]["id"], int(rolled[i]["count"]), base_angle + float(i) * TAU / float(rolled.size()))


## 팝 — 셰이더 플래시 + 스쿼시 (피격 손맛, 세63 개편). modulate를 **아예 안 만진다** — 흰 섬광은
## 셰이더 `flash_amount`(mix-to-white라 어두운 픽셀도 하얘진다). 🔴 **scale은 _visual에만** 준다:
## 루트 scale은 _apply_look가 쥔 덩치(=히트박스)라 건드리면 히트박스가 출렁인다.
## 연타 시 트윈 중첩은 기존 규약 그대로(마지막 승리) — 단 flash는 트윈 전에 1.0을 직접 찍어
## **매 타마다 만빛에서 다시 시작**한다.
func _pop() -> void:
	if _visual == null:
		return
	var mat := _visual.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"flash_amount", 1.0)
	_visual.scale = POP_SQUASH
	var tween := create_tween()
	tween.set_parallel(true)
	if mat != null:
		tween.tween_property(mat, "shader_parameter/flash_amount", 0.0, POP_SEC)
	tween.tween_property(_visual, "scale", Vector2.ONE, POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 피격 프레임 재생 (세63 설계 §C — 보스처럼 `params.hurt_sprite`가 있는 적만). 플래시+스쿼시(_pop)
## 위에 **얹는 층**이다 — hurt가 없는 적은 no-op(기존 무변경). 뱀 머리 회전(_face)은 노드 속성이라
## 애니와 직교 — hurt 재생 중에도 머리가 진행 방향을 본다.
func _play_hurt() -> void:
	if _visual == null or _visual.sprite_frames == null:
		return
	if not _visual.sprite_frames.has_animation(&"hurt"):
		return
	_visual.play(&"hurt")
	# 🔴 1프레임 스트립이면 `animation_finished`가 즉시 온다(설계 §C 함정) — 그대로 두면 한 틱
	# 번쩍하고 끝나 "안 보인다". 타이머로 홀드한 뒤 idle 복귀로 분기한다.
	# 🔴 세대 토큰(juice 히트스톱 선례) — 연타 시 **첫** 타이머가 뒤 hurt를 일찍 끊지 않게, 마지막
	# 발동의 타이머만 복귀시킨다(세63 리뷰). 람다가 아니라 bind인 이유 = 메서드 Callable은 노드가
	# free되면 소멸돼 안 불리지만, 람다는 free된 self를 만져 에러가 난다.
	if _visual.sprite_frames.get_frame_count(&"hurt") <= 1:
		_hurt_gen += 1
		get_tree().create_timer(HURT_HOLD_SEC).timeout.connect(_back_to_idle_gen.bind(_hurt_gen))
	elif not _visual.animation_finished.is_connected(_back_to_idle):
		_visual.animation_finished.connect(_back_to_idle, CONNECT_ONE_SHOT)


## 세대 토큰 검문 — 내 세대가 마지막이 아니면(그 뒤에 또 맞았으면) 복귀를 양보한다.
func _back_to_idle_gen(gen: int) -> void:
	if gen != _hurt_gen:
		return
	_back_to_idle()


## hurt에서 idle로 복귀. 노드가 이미 free됐으면 시그널 연결이 소멸돼 안 불린다(타이머도 안전).
func _back_to_idle() -> void:
	if _dead or _visual == null or _visual.sprite_frames == null:
		return
	if _visual.sprite_frames.has_animation(&"idle"):
		_visual.play(&"idle")


## 처치 퍼프 — 적 색으로 확 커지며 사라지는 링. 적은 이 프레임에 queue_free되지만
## 퍼프는 현재 씬에 따로 붙어 살아남는다.
func _spawn_death_puff() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var puff := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / 8.0) * 10.0)
	puff.polygon = pts
	# 🔴 퍼프 색 = params.color (스프라이트로 바꾸며 _visual.color가 사라졌다 — AnimatedSprite2D엔 없다).
	# .tres의 color는 이제 퍼프/틴트 힌트로만 남는다(생김새는 스프라이트가 쥔다). 없으면 부드러운 흰빛.
	var pcol := Color(0.82, 0.86, 0.8)
	if _def != null and _def.params.get("color") is Color:
		pcol = _def.params.get("color")
	puff.color = pcol
	puff.global_position = global_position
	puff.z_index = 50
	scene.add_child(puff)
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector2(2.4, 2.4), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "modulate:a", 0.0, 0.25)
	tween.set_parallel(false)
	tween.tween_callback(puff.queue_free)
