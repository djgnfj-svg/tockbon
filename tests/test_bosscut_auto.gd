extends SceneTree
## 보스 등장 컷(boss_intro.gd) 자동 검증 — 첫 진입 재생·codex 1회 판정·busy 해제·재진입 스킵.
## 실행: Godot --headless --path . -s res://tests/test_bosscut_auto.gd
## 주의: -s 스크립트는 오토로드 전역 등록 전에 컴파일되므로,
## 오토로드는 root.get_node()로, 씬은 첫 프레임 이후 load()로 얻는다.

const UNLOCK_ID := &"cut_gale_intro"
const INTRO_TEXT := "바람이 글자를 삼켰다"

var _fails: int = 0
var _cut_emits: int = 0

# 오토로드 (첫 프레임에 바인딩)
var gs: Node      # GameState
var eb: Node      # EventBus
var clk: Node     # Clock

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)

func _find_gale() -> Variant:
	for e: Node in get_nodes_in_group("enemies"):
		var def: Variant = e.get("def")
		if def != null and def.get("id") == &"gale":
			return e
	return null

## _play가 트리거 아래 CanvasLayer/Label 오버레이를 얹는다 — 그 라벨을 찾는다
func _find_intro_label(trigger: Node) -> Label:
	for layer: Node in trigger.get_children():
		if layer is CanvasLayer:
			for c: Node in layer.get_children():
				if c is Label:
					return c as Label
	return null

func _run() -> void:
	gs = root.get_node(^"GameState")
	eb = root.get_node(^"EventBus")
	clk = root.get_node(^"Clock")
	eb.connect(&"codex_unlocked", func(unlock_id: StringName) -> void:
		if unlock_id == UNLOCK_ID:
			_cut_emits += 1)
	print("=== test_bosscut: 보스 등장 컷 자동 검증 시작 ===")

	# ── 1. 필드 로드 → 트리거 설치 확인
	var field_scene: PackedScene = load("res://src/field/field.tscn")
	var field: Node2D = field_scene.instantiate()
	root.add_child(field)
	await process_frame
	await process_frame
	var trigger: Variant = field.get_node_or_null("BossIntro")
	_check(trigger != null, "필드 로드 → BossIntro 트리거 설치")
	_check(not gs.call(&"is_unlocked", UNLOCK_ID), "초기 상태: cut_gale_intro 미해금")
	if trigger == null:
		_finish()
		return
	_check((trigger as Area2D).collision_mask == 1 << 1, "트리거 마스크 2 (player)")

	var player: Variant = get_first_node_in_group("player")
	var boss: Variant = _find_gale()
	_check(player != null, "플레이어 존재 (그룹 player)")
	_check(boss != null, "보스(gale) 존재 (그룹 enemies)")
	if player == null or boss == null:
		_finish()
		return
	var mod: Variant = field.get("_modulate_node")
	var start_color: Color = mod.color
	var phase0: Variant = clk.get("phase")

	# ── 2. 첫 진입 → 재생 시작 (codex 1회 발신 + 플레이어 잠금 + 보스 AI 정지 + 텍스트)
	trigger._on_body_entered(player)
	_check(_cut_emits == 1, "재생 시작 시 codex_unlocked(cut_gale_intro) 1회 발신")
	_check(gs.call(&"is_unlocked", UNLOCK_ID), "GameState 도감 등록: cut_gale_intro")
	_check(player.get("busy") == true, "연출 중 플레이어 busy 잠금")
	_check(boss.get("ai_enabled") == false, "연출 중 보스 AI 정지")
	var label: Label = _find_intro_label(trigger)
	_check(label != null and label.text == INTRO_TEXT, "한 줄 텍스트 오버레이: '%s'" % INTRO_TEXT)

	# ── 3. 재생 중 재진입 → 중복 재생 없음
	trigger._on_body_entered(player)
	_check(_cut_emits == 1, "재생 중 재진입: codex 재발신 없음")

	# ── 4. 연출 종료 (~2.4초) → 원상 복구 + 전투 개시
	await create_timer(3.2).timeout
	_check(player.get("busy") == false, "연출 종료 후 플레이어 busy 해제")
	_check(boss.get("ai_enabled") == true, "연출 종료 후 보스 AI 재개")
	_check(not is_instance_valid(trigger), "연출 종료 후 1회성 트리거 제거")
	var cam: Camera2D = null
	for c: Node in player.get_children():
		if c is Camera2D:
			cam = c
	_check(cam != null and cam.offset.is_equal_approx(Vector2.ZERO), "카메라 offset 원위치")
	if clk.get("phase") == phase0:
		_check((mod.color as Color).is_equal_approx(start_color), "CanvasModulate 원상 복구")
	else:
		print("SKIP: CanvasModulate 복구 비교 (테스트 중 페이즈 변경)")

	# ── 5. 해금 상태에서 필드 재진입 → 트리거 미설치 (재생 안 함)
	field.queue_free()
	await process_frame
	var field2: Node2D = field_scene.instantiate()
	root.add_child(field2)
	await process_frame
	await process_frame
	_check(field2.get_node_or_null("BossIntro") == null, "해금 상태 재진입: 트리거 미설치")
	var player2: Variant = get_first_node_in_group("player")
	_check(player2 != null and player2.get("busy") == false, "재진입 시 재생 없음 (busy 미잠금)")
	_check(_cut_emits == 1, "재진입 시 codex 재발신 없음")
	field2.queue_free()
	await process_frame

	_finish()

func _finish() -> void:
	print("=== test_bosscut 완료: FAIL %d건 ===" % _fails)
	if _fails == 0:
		print("TEST_BOSSCUT_OK")
	else:
		print("TEST_BOSSCUT_FAILED: ", _fails)
	quit(mini(_fails, 100))
