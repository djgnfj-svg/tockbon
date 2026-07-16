extends Node2D
## 거점 고리 시험 발사 — 이젤에서 맺은 고리를 마당 허수아비에 바로 쏠 수 있는가? (세션 21)
## 씬으로 돌린다(오토로드 필요): --headless --path . res://tests/test_base_ring_auto.tscn --quit-after 120
##
## 검증 대상 = 세션 21 배선: base.tscn의 RingSpellSystem + base_player.try_cast 고리 분기.
## 그 전에는 거점에 고리 발사 경로가 아예 없어서 필드로 나가야만 확인됐다.

var _hit_count: int = 0
var _ring_cast_seen: bool = false
var _fails: int = 0


func _ready() -> void:
	var eb := get_node(^"/root/EventBus")
	eb.connect(&"training_hit", func(_rune: int, _dmg: float) -> void: _hit_count += 1)
	eb.connect(&"ring_cast_requested",
		func(_a: Dictionary, _o: Vector2, _d: Vector2) -> void: _ring_cast_seen = true)
	await get_tree().create_timer(0.2).timeout
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _run() -> void:
	var gs := get_node(^"/root/GameState")
	var base := get_node_or_null(^"Base")
	_check(base != null, "거점 씬 로드")

	# ① RingSpellSystem이 거점에 붙어 있나 (세션 21 이전엔 SpellSystem만 있었다)
	var rss := base.get_node_or_null(^"RingSpellSystem")
	_check(rss != null, "거점에 RingSpellSystem 존재")

	# ② 허수아비가 있고 적 계약을 구현하나
	var dummy := base.get_node_or_null(^"TrainingDummy")
	_check(dummy != null and dummy.has_method("take_hit"), "허수아비 take_hit 계약")

	# ③ 고리를 장착한다 — 응집 8칸(전부 열림) 불 룬. ring_board 계약: 0=응집·1=발산·-1=빈칸
	var assembly := {
		"ring_count": 1,
		"rune": 0,
		"rings": [[0, 0, 0, 0, 0, 0, 0, 0]],
		"open": [0, 1, 2, 3, 4, 5, 6, 7],
	}
	var design: RingDesign = RingDesign.from_assembly(assembly, "프로브 진", 0.9)
	gs.ring_equipped[0] = design
	_check(gs.ring_equipped[0] != null, "슬롯1에 고리 장착")

	# ④ 거점 플레이어가 고리로 쏘는가 (핵심 — 옛 경로면 여기서 false/옛 시그널)
	var player := base.get_node_or_null(^"Player")
	_check(player != null, "거점 플레이어 존재")
	if player != null and dummy != null:
		player.global_position = dummy.global_position + Vector2(-60, 0)  # 허수아비 왼쪽에 세운다
		player._aim_dir = Vector2.RIGHT                                    # 허수아비를 향해 조준
		var ok: bool = player.try_cast(0)
		_check(ok, "base_player.try_cast(0) 발신 성공")
	await get_tree().create_timer(0.1).timeout
	_check(_ring_cast_seen, "ring_cast_requested 발신됨 (고리 경로를 탔다)")

	# ⑤ 탄이 실제로 날아가 허수아비를 때리는가 — 배선만이 아니라 명중까지
	await get_tree().create_timer(1.5).timeout
	_check(_hit_count > 0, "허수아비 피격 %d회 (거점에서 조립→확인 루프가 닫힌다)" % _hit_count)

	print("PROBE_RESULT fails=", _fails)
	get_tree().quit()
