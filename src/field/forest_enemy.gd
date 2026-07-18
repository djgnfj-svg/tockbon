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

@export var enemy_id: StringName = &"slime"

@onready var _visual: Polygon2D = $Visual

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


func _ready() -> void:
	add_to_group("enemies")
	_def = Db.get_enemy(enemy_id)
	if _def == null:
		# 조용히 죽지 않게 — .tres 이름을 틀리면 hp 0짜리 유령이 서 있게 된다.
		push_warning("EnemyDef '%s'를 못 찾았다 (data/enemies/ 확인) — 기본값으로 선다" % enemy_id)
	_hp = _def.hp if _def != null else 10.0
	_apply_look()


## 🔴 외형도 .tres가 쥔다 (`params.color`·`params.size`) — "새 적 = .tres 한 장"이 생김새까지
## 포함하게 하려는 것. 없으면 기본 초록·1배(슬라임 그대로).
## ⚠ 이건 **표시일 뿐 AI가 아니다** — 세션 30 "데이터만(리스킨)" 방침 그대로다. 행동(추격+접촉)은
## 한 가지뿐이고, 색·덩치만 .tres로 달라진다. 스키마를 안 늘리고 `params`에 얹은 이유 = enemy_def.gd
## 주석("스키마 확장 대신 params를 쓴다"). size는 루트 scale이라 **덩치가 곧 히트박스**가 된다.
func _apply_look() -> void:
	if _def == null or _visual == null:
		return
	var col: Variant = _def.params.get("color")
	if col is Color:
		_visual.color = col
	var s := float(_def.params.get("size", 1.0))
	if not is_equal_approx(s, 1.0):
		scale = Vector2(s, s)


## 쫓아오기 + 접촉 피해. **거리 하나로 둘 다 판정한다** — aggro_range 안이면 다가오고,
## attack_range 안이면 attack_cooldown 간격으로 때린다 (수치는 전부 .tres).
func _physics_process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	var player := _player()
	if player == null:
		velocity = Vector2.ZERO
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()

	if dist <= _param("aggro_range", 160.0) and dist > 1.0:
		velocity = to_player / dist * _param("move_speed", 55.0)
	else:
		velocity = Vector2.ZERO
	# 넉백은 추격 속도 위에 얹혀 빠르게 사그라든다 (피격 손맛)
	velocity += _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	if dist <= _param("attack_range", 18.0) and _cool <= 0.0:
		_cool = _param("attack_cooldown", 0.9)
		GameState.damage_player(_param("contact_damage", 4.0))


## 🔴 그룹 `"player"`가 유일한 조준 경로다 (player.gd가 `_ready`에서 넣는다).
## 빠지면 적이 **제자리에 굳는데 에러는 안 난다** — 세션 24·25의 침묵과 같은 종류다.
func _player() -> Node2D:
	var found := get_tree().get_first_node_in_group("player")
	return found as Node2D


func _param(key: String, fallback: float) -> float:
	if _def == null:
		return fallback
	return float(_def.params.get(key, fallback))


## 🔴 계약: `enemy_hit`는 **약점 배율을 반영한 최종 피해**로 발신한다 (dummy_target 주석).
## ⚠ `status`·`status_power`는 아직 안 쓴다 — 적의 상태이상(화상·젖음)은 미구현이다.
## 인자는 계약이라 시그니처에 그대로 남긴다 (받아 놓고 버리는 게 계약을 좁히는 것보다 낫다).
func take_hit(damage: float, rune_type: int, _status: int, _status_power: float) -> void:
	var mult := 1.0
	if _def != null and _def.has_counter and rune_type == _def.counter_rune:
		mult = _param("weakness_mult", 1.0)
	var dealt := damage * mult
	_hp -= dealt
	EventBus.enemy_hit.emit(self, dealt, rune_type)
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


## 🔴 죽으면 **드롭을 굴려 가방에 넣는다** (세션 27 — 사용자: *"드롭을 먼저"*).
## 인벤 흐름은 이미 다 배선돼 있다: `add_to_bag` → 귀환(extraction_success) 시 창고로 회수 ·
## 죽으면(bag_lost) 통째로 사라진다. 그래서 여기서 **넣기만 하면** 익스트랙션 루프가 산다
## ("주웠다, 살아 돌아가자").
##
## 🔴 룬 조각(fragment_*)은 이 풀에 **없어야 한다** — 룬은 드롭이 아니라 보스 퀘스트 보상이다
## (사용자 확정). 지금 슬라임은 mat_slime_core만 있어 무관하지만, 엘리트를 숲에 넣을 때
## 그 .tres의 fragment 줄은 **일반 드롭이 아니라 퀘스트로** 빼야 한다 (BACKLOG).
##
## 랜덤: Godot 전역 `randf()` — 부팅 시 자동 시드. 이 프로젝트의 첫 게임플레이 랜덤이다
## (세이브에 안 들어간다 — 드롭은 굴린 결과가 가방에 담길 뿐 RNG 상태를 저장하지 않는다).
func _die() -> void:
	var got_drop := false
	if _def != null:
		for drop: DropEntry in _def.drops:
			if randf() <= drop.chance:
				var n := drop.min_count
				if drop.max_count > drop.min_count:
					n += randi() % (drop.max_count - drop.min_count + 1)
				if n > 0:
					GameState.add_to_bag(drop.item_id, n)
					got_drop = true
	if got_drop:
		Audio.play(&"pickup")   # 뭔가 떨궜을 때만 — 빈손 처치는 조용히
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
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.18)
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
	puff.color = _visual.color if _visual != null else Color.WHITE
	puff.global_position = global_position
	puff.z_index = 50
	scene.add_child(puff)
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector2(2.4, 2.4), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "modulate:a", 0.0, 0.25)
	tween.set_parallel(false)
	tween.tween_callback(puff.queue_free)
