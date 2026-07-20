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

## 🔴 상태이상·원소 반응의 **규칙 단일 소스** (세션49). 규칙을 여기 베끼지 마라 — 복사하면
## "진흙인데 안 묶인다" 식으로 조용히 갈라진다(ring_power와 같은 이유).
const SR := preload("res://src/core/status_rules.gd")
## 🔴 상태 **보유고** (세션50 추출) — 적·허수아비가 같은 물건을 쓴다.
const SH := preload("res://src/core/status_holder.gd")
## 지속·반경·틱 간격 수치는 전부 balance가 쥔다 (연출값이 아니라 밸런스다).
const BAL := preload("res://data/balance.tres")

@export var enemy_id: StringName = &"slime"

@onready var _visual: AnimatedSprite2D = $Visual

## 🔴 피격 손맛 (세션 38) — 넉백/팝 **연출값**. 밸런스가 아니라 느낌값이라 여기 const
## (projectile 물리 여유 const 선례). 사용자가 직접 때려 보며 조인다.
const KNOCKBACK_IMPULSE := 140.0  ## 맞는 순간 플레이어 반대쪽으로 밀려나는 속도
const KNOCKBACK_DECAY := 600.0    ## 넉백 감쇠(속도/s) — 빨리 원래 추격으로 복귀
const POP_SCALE := 1.35           ## 팝 순간 시각 크기

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

## 🔴 상태이상 보유고 (세션49 → 세션50에 `src/core/status_holder.gd`로 **추출**).
## 보유·틱·반응 해결은 전부 holder가 한다 — 여기 남은 건 **몸의 일**(피해·확산·색)뿐이다.
## 추출한 이유: 허수아비가 같은 코드를 못 써서 **연습장에서 반응을 시험할 수 없었다**.
var _status: SH = SH.new()
## 🔴 죽음 1회 보장 — DoT·연쇄·즉발이 같은 프레임에 겹쳐도 `_die()`가 두 번 돌면
## 드롭이 두 번 떨어지고 퀘스트가 두 번 센다(queue_free는 프레임 끝에야 반영된다).
var _dead: bool = false


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
	_apply_look()


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
func _setup_frames(tex: Texture2D) -> void:
	var side := tex.get_height()
	if side <= 0:
		return
	var count := maxi(1, tex.get_width() / side)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.set_animation_speed(&"idle", 6.0)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * side, 0, side, side)
		frames.add_frame(&"idle", at)
	_visual.sprite_frames = frames
	_visual.play(&"idle")


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


## 접촉 피해 — attack_range 안이면 attack_cooldown 간격으로 GameState를 깎는다.
## 🔴 구르는 중이면 흘린다 (무적 프레임 — 세션41 구르기). player.is_rolling()가 유일 판정.
## .call로 부른다: player는 Node2D 타입이라 is_rolling()을 정적으로 못 찾는다(공용 배우 계약 무변경).
func _contact(player: Node2D, dist: float) -> void:
	if dist > _param("attack_range", 18.0) or _cool > 0.0:
		return
	_cool = _param("attack_cooldown", 0.9)
	var dodging: bool = player.has_method(&"is_rolling") and bool(player.call(&"is_rolling"))
	if not dodging:
		GameState.damage_player(_param("contact_damage", 4.0))


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
	_status.on_burst = func(radius: float, amount: float, include_self: bool) -> void:
		_burst_damage(radius, amount, include_self)
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
func _burst_damage(radius: float, amount: float, include_self: bool) -> void:
	if amount <= 0.0:
		return
	if include_self:
		take_reaction_damage(amount)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > radius:
			continue
		if node.has_method(&"take_reaction_damage"):
			node.take_reaction_damage(amount)


## 🔴 바람 확산 — **내게 이미 붙은 상태를** 반경 안의 적들에게 옮겨 붙인다.
## 내 것은 남긴다(옮기는 게 아니라 번진다) — 안 그러면 바람을 섞을수록 판이 깨끗해진다.
## 🔴 옆 적을 찾는 건 **몸의 일**이라 여기 남았다(holder는 씬을 모른다).
func _spread_statuses(statuses: Dictionary) -> void:
	if statuses.is_empty():
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > BAL.status_spread_px:
			continue
		if not node.has_method(&"apply_status"):
			continue
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
func take_reaction_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	_hp -= amount
	EventBus.enemy_hit.emit(self, amount, Enums.RuneType.FIRE)
	_pop()
	if _hp <= 0.0:
		_die()


## 지금 보여 줄 상태 색 — 고르는 규칙은 holder가 쥔다(적·허수아비가 같게 보이도록).
## 🔴 `_pop`·`_set_telegraph`의 **복귀 목표가 이 함수**다 — `Color.WHITE`로 돌리면 때릴 때마다
## 화상 색이 벗겨지는데 **헤드리스가 절대 못 잡는다**(렌더가 없다).
func _status_tint() -> Color:
	return _status.tint()


## 🔴 색 소유권 정리: 상태 틴트는 rgb만 쥐고 **알파는 분산(_set_dispersed)이 쥔다** — 둘이 같은
## modulate를 나눠 쓰므로 서로의 축을 덮어쓰지 않게 나눴다. 팝·텔레그래프도 복귀 목표를 이 색으로 쓴다.
func _refresh_tint() -> void:
	if _visual == null:
		return
	var c := _status_tint()
	c.a = _visual.modulate.a
	_visual.modulate = c


## 돌진 텔레그래프 — 윈드업 동안 붉게 달아오른다(모으는 중이 보인다 → 피할 수 있다).
## ⚠ 연출값이다 — 사용자가 실게임에서 보고 조인다. _pop과 modulate를 공유하지만 윈드업이 짧아 무해.
func _set_telegraph(on: bool) -> void:
	if _visual == null:
		return
	# 🔴 복귀 목표가 Color.WHITE면 **상태 틴트가 지워진다**(윈드업 한 번에 화상이 안 보이게 된다).
	if on:
		_visual.modulate = Color(1.6, 0.75, 0.55)
	else:
		_refresh_tint()


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


## 🔴 계약: `enemy_hit`는 **약점 배율을 반영한 최종 피해**로 발신한다 (dummy_target 주석).
## ✅ 세션49: `status`·`status_power`를 **드디어 쓴다** — 세34~48까지 밑줄로 버려서 불·물·바람의
## 실질 차이가 색 + 데미지 ±15%뿐이었다. 시그니처는 그대로다(계약을 넓히지 않았다).
func take_hit(damage: float, rune_type: int, status: int, status_power: float) -> void:
	if _dead:
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
	if _hp <= 0.0:
		_die()


## 🔴 죽으면 **드롭을 굴려 바닥에 떨군다** (세션46 — 사용자: *"게임답게 걸어가 줍게"*).
## 그전엔 여기서 곧장 `add_to_bag`으로 **가방에 순간이동**했다 — 이제 드롭마다 `DropPickup`을
## 죽은 자리에 심고, 가방에 넣는 건 픽업이 플레이어에 닿을 때 한다(픽업이 `add_to_bag`을 부른다).
## 인벤 흐름은 그대로다: `add_to_bag` → 귀환(extraction_success) 시 창고로 회수 · 죽으면(bag_lost)
## 통째로 사라진다. 바뀐 건 **가방에 언제 들어가느냐**뿐이다("주웠다"가 진짜 줍는 행위가 됐다).
##
## 🔴 룬 조각(fragment_*)은 이 풀에 **없어야 한다** — 룬은 드롭이 아니라 보스 퀘스트 보상이다
## (사용자 확정). 지금 슬라임은 mat_slime_core만 있어 무관하지만, 엘리트를 숲에 넣을 때
## 그 .tres의 fragment 줄은 **일반 드롭이 아니라 퀘스트로** 빼야 한다 (BACKLOG).
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
		for drop: DropEntry in _def.drops:
			if randf() <= drop.chance:
				var n := drop.min_count
				if drop.max_count > drop.min_count:
					n += randi() % (drop.max_count - drop.min_count + 1)
				if n > 0:
					var pickup := DropPickup.instantiate()
					scene.add_child(pickup)
					# 여러 드롭이 겹치지 않게 살짝 흩뿌린 지점에서 심는다 — 픽업 자신이
					# 여기서 또 튀어나온다(scatter). 🔴 global_position은 add_child 뒤에 잡고,
					# setup은 그 뒤에 불러야 scatter가 올바른 자리에서 시작한다.
					pickup.global_position = global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
					pickup.setup(drop.item_id, n)
	# 🔴 처치 순간 1회 — GameState가 KILL 퀘스트를 센다 (세션36). `died` 로컬 시그널의
	# "킬카운트가 붙는 날의 자리표"가 마침내 수신자를 얻었다. enemy_id를 실어 특정 적 목표도 가능.
	EventBus.enemy_died.emit(enemy_id)
	died.emit()
	_spawn_death_puff()
	queue_free()


## 팝 — 흰 섬광 + 크기 펀치 (피격 손맛). 🔴 **scale은 _visual에만** 준다: 루트 scale은
## _apply_look가 쥔 덩치(=히트박스)라 건드리면 히트박스가 출렁인다.
func _pop() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(2.2, 2.2, 2.2)  # >1 = 밝게 튄다 (흰 섬광)
	_visual.scale = Vector2(POP_SCALE, POP_SCALE)
	var tween := create_tween()
	tween.set_parallel(true)
	# 🔴 팝의 복귀 목표도 **상태 틴트**다 — Color.WHITE로 돌리면 때릴 때마다 화상 색이 벗겨진다.
	tween.tween_property(_visual, "modulate", _status_tint(), 0.18)
	tween.tween_property(_visual, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
