extends SceneTree
## 마을(base.tscn) 자동 검증 — 조립·발사·문 [E] 배선이 씬을 통과해 도나. 통과하면 TEST_BASE_OK.
## ⚠ 헤드리스는 「보이나」를 못 잰다 — z_index·렌더·마우스 히트 테스트는 F5 몫이다.
## ⚠ -s 모드는 오토로드 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.

const GLYPH_NONE := -1

## 사거리는 balance에서 읽는다 — 여기 베끼면 수치를 바꿀 때 이 그물만 조용히 낡는다.
var _range_px: float = 0.0

var failures: int = 0
var _bus = null
var _base = null
## 스폰 좌표를 붙자마자 찍어 둔다 — 뒤 항목들이 플레이어를 옮겼다 되돌리므로, 나중에 읽으면
var _spawn := Vector2.ZERO


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_BASE_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	var bal = load("res://data/balance.tres")
	_range_px = bal.projectile_base_speed * bal.projectile_lifetime_sec

	var scene := load("res://src/base/base.tscn") as PackedScene
	_base = scene.instantiate()
	root.add_child(_base)
	await process_frame
	_spawn = _player().global_position

	await _test_scene_wired()
	await _test_targets_in_range()
	await _test_my_body_does_not_block_my_spell()
	await _test_desk_does_not_eat_the_spell()
	await _test_desk_still_sees_the_player()
	await _test_hand_scoring_axis_alive()
	await _test_commit_gate_for_this_mode()
	await _test_rejection_notice_reaches_base()
	await _test_book_assembles_the_firing_contract()
	await _test_real_left_click_actually_fires()
	await _test_empty_slot_refuses_to_fire()
	await _test_forest_gate_leads_out()
	await _test_gate_light_breathes()
	await _test_station_gate_follows_codex()
	await _test_first_screen_composition()
	await _test_gate_claims_then_opens_chapters()
	await _test_desk_opens_the_workshop()
	await _test_gate_departs_without_choosing()

	if failures == 0:
		print("TEST_BASE_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_BASE_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 진입 씬에 연습장이 있다 — 과녁과 발사 시스템.
func _test_scene_wired() -> void:
	print("[1] 베이스캠프에 연습 과녁 + 발사 시스템이 있다")
	var targets := _targets()
	_check(targets.size() >= 3, "허수아비 3개 이상 (실제 %d)" % targets.size())
	_check(_player() != null, "플레이어(CharacterBody2D)를 찾았다")
	# 발사 시스템의 존재는 **행동으로** 확인한다 — 노드 이름이 아니라 "쏘면 진이 생기나".
	_bus.ring_cast_requested.emit(_assembly(1.0), Vector2(9000, 9000), Vector2(1, 0))
	await physics_frame
	_check(_carriers().size() == 1,
		"쏘니 진(캐리어)이 생긴다 = RingSpellSystem이 씬에 있다 (실제 %d)" % _carriers().size())
	_clear()


## [2] 🔴 과녁이 사거리 밖이면 연습장이 장식이다 — 걸어가기 전엔 한 발도 안 닿는다.
func _test_targets_in_range() -> void:
	print("[2] 연습 과녁이 플레이어 시작점 사거리(%.0fpx) 안에 있다" % _range_px)
	var from: Vector2 = _player().global_position
	for t in _targets():
		var d: float = from.distance_to(t.global_position)
		_check(d <= _range_px, "허수아비 %s — %.0fpx (사거리 %.0f)" % [t.name, d, _range_px])


## [3] 🔴 총구 자살 — 플레이어 자리에서 쏜 진이 **내 몸에 막히지 않고** 날아가 과녁을 때린다.
## 레이어를 되돌리면(Player → 기본 레이어 1) 여기서 잡힌다: 진이 스폰 즉시 죽어 영영 안 맞는다.
func _test_my_body_does_not_block_my_spell() -> void:
	print("[3] 내 몸이 내 마법을 막지 않는다 — 쏜 진이 허수아비에 닿는다")
	var player = _player()
	var target = _nearest_target(player.global_position)
	if target == null:
		_check(false, "과녁이 하나도 없다")
		return
	var aim: Vector2 = (target.global_position - player.global_position).normalized()
	_bus.ring_cast_requested.emit(_assembly(1.0), player.global_position, aim)
	var frames := 0
	while target.hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not target.hits.is_empty(),
		"허수아비 %s 피격 (%d 물리 프레임)" % [target.name, frames])
	_clear()


## [4] 🔴 책상 너머로 쏴도 진이 산다 — 책상(Area2D)이 world 레이어에 있으면 벽으로 읽혀 먹어 버린다.
func _test_desk_does_not_eat_the_spell() -> void:
	print("[4] 책상이 마법을 먹지 않는다 (책상 쪽으로 쏴도 진이 지나간다)")
	var player = _player()
	# 책상은 플레이어 위쪽에 있다 — 위로 쏘면 반드시 책상 영역을 지난다.
	_bus.ring_cast_requested.emit(_assembly(1.0), player.global_position, Vector2.UP)
	# 40 물리 프레임 ≈ 0.66초 ≈ 173px — 책상 한복판을 지나고도 남는 거리(수명 1.5초 안).
	for i in 40:
		await physics_frame
	_check(_carriers().size() == 1,
		"진이 책상을 통과해 살아 있다 (남은 %d)" % _carriers().size())
	_clear()


## [5] 🔴 레이어를 옮긴 대가를 확인한다 — 책상이 여전히 플레이어를 **감지**하나.
## 감지 못 하면 "[E] 탁본"이 안 뜨고 **책이 안 열린다** = 게임이 통째로 막힌다.
func _test_desk_still_sees_the_player() -> void:
	print("[5] 책상이 플레이어를 알아본다 (E 안내가 뜨려면 감지돼야 한다)")
	var desk = _zone(&"desk")
	if desk == null:
		_check(false, "책상(Area2D)을 못 찾았다")
		return
	var player = _player()
	var was: Vector2 = player.global_position
	player.global_position = desk.global_position   # 책상 위로 걸어간 셈
	# Area2D 겹침은 물리 프레임마다 갱신된다 — 한 프레임으로는 아직 비어 있다.
	var frames := 0
	while not desk.get_overlapping_bodies().has(player) and frames < 10:
		await physics_frame
		frames += 1
	_check(desk.get_overlapping_bodies().has(player),
		"책상이 플레이어를 감지 (%d 물리 프레임)" % frames)
	player.global_position = was


## [6] 맺기 게이트 — **모드마다 갈린다**(`balance.skip_drawing`).
##   그리기 모드 = 미달이면 거부하되 **이유를 화면에 띄운다**(침묵 금지) · 폐지 모드 = 조립만으로 맺힌다(펑 없음).
## 🔴 한 프로세스에서 두 모드를 다 못 돌린다 — `RingPower.skip_drawing()`은 const 폴딩이라 런타임에 안 흔들린다.
##   그래서 모드 무관 층을 따로 세운다: [6-A] 손 긋기 채점 축 · [6-C] 거부 → 화면 안내.
func _test_commit_gate_for_this_mode() -> void:
	if _skip_drawing():
		await _test_assemble_only_commits()
	else:
		await _test_rejected_commit_is_not_silent()


## [6-A] 🔴 **모드 무관** — 손 긋기 채점 축이 살아 있다(폐지 스위치를 되돌리면 정말 돌아오나).
##   폐지 모드는 이 값을 안 읽으므로, 이 그물이 없으면 채점기·합성 밑그림이 통째로 죽어도 전 스위트가 그린이다.
## ⚠ 수치를 안 박는다 — 기준선·정밀도 상수를 조율해도 안 부서지고, 축이 죽으면 즉시 빨개진다.
func _test_hand_scoring_axis_alive() -> void:
	print("[6-A] 🔴 모드 무관 — 손 긋기 채점 축이 살아 있다 (스위치를 되돌리면 돌아온다)")
	var RP: GDScript = load("res://src/core/ring_power.gd")
	_base.call(&"_open_drawing")
	await process_frame
	var forge = _base.get("_forge")
	if forge == null:
		_check(false, "책이 안 열렸다")
		return
	forge.call(&"_on_jin_selected", &"jin_single")
	forge.call(&"_on_rune_selected", 0)
	var board = forge.get_node("Stage/Spread/RingBoard")
	var g = board.call(&"guide_points")
	_check(g.size() > 0, "합성 밑그림이 점열로 선다 (%d점 — 0이면 그을 것이 없다)" % g.size())
	if g.size() == 0:
		_base.call(&"_close_drawing")
		return

	# 미달: 앞쪽 일부만, 게다가 밑그림에서 벗어나게 (완성도·정밀도 둘 다 낮게)
	board.call(&"begin_stroke")
	for i in range(0, int(g.size() * 0.3)):
		board.call(&"trace_stroke", g[i] + Vector2(9.0, 8.0))
	var poor := float(board.call(&"combined_total"))
	_check(not RP.is_stable(poor),
		"🔴 일부만·벗어나게 그은 궤적은 기준선 아래다 (%.2f) — 참이면 「대충 그려도 통과」로 돌아간 것" % poor)

	# 충분: 밑그림 전체를 정확히
	board.call(&"clear_stroke")
	board.call(&"begin_stroke")
	for pt in g:
		board.call(&"trace_stroke", pt)
	var good := float(board.call(&"combined_total"))
	_check(good > poor, "🔴 잘 그으면 점수가 오른다 (%.2f > %.2f — 같으면 채점 축이 죽었다)" % [good, poor])
	_check(RP.is_stable(good), "🔴 밑그림을 정확히 따라 그은 궤적은 기준선 위다 (%.2f)" % good)
	_base.call(&"_close_drawing")


## [6-C] 🔴 **모드 무관** — `commit_rejected`가 HUD 안내까지 닿는다(침묵 금지).
##   폐지 모드에선 거부 갈래가 도달 불가라 신호를 직접 쏴서 잰다. 끊기면 책은 덮이고 슬롯은 빈 채인데 이유가 화면에 없다.
func _test_rejection_notice_reaches_base() -> void:
	print("[6-C] 🔴 모드 무관 — commit_rejected가 HUD 안내까지 닿는다 (침묵 금지)")
	var RP: GDScript = load("res://src/core/ring_power.gd")
	var hud = _base.get("_hud")
	if hud == null:
		_check(false, "HUD를 못 찾았다")
		return
	_base.call(&"_open_drawing")
	await process_frame
	var forge = _base.get("_forge")
	if forge == null:
		_check(false, "책이 안 열렸다")
		return
	_check(forge.commit_rejected.get_connections().size() >= 1,
		"베이스가 commit_rejected를 받고 있다 (안 이으면 거부가 통째로 조용해진다)")
	hud.say("", false)
	var poor := 0.10
	forge.commit_rejected.emit(poor)
	await process_frame
	var line: String = String(hud.call(&"say_line"))
	_check(line != "", "🔴 거부하면 HUD에 한 줄이 뜬다 (빈 줄 = 세25의 그 침묵)")
	# 🔴 점수가 실려 간다 — 연결만 재면 핸들러가 페이로드를 버려도 그린이다.
	_check(line.contains(str(RP.score_display(poor))),
		"안내에 그 점수(%d)가 실려 있다 — 실제 안내: %s" % [RP.score_display(poor), line])
	_base.call(&"_close_drawing")


## [6] 그리기 모드 갈래 — 미달 조립본은 거부하되 **이유를 말한다**(침묵 금지).
func _test_rejected_commit_is_not_silent() -> void:
	print("[6] 미달 조립본을 거부할 땐 이유를 말해 준다 (세71 통째 흐름)")
	_base.call(&"_open_drawing")
	await process_frame
	var forge = _base.get("_forge")
	if forge == null:
		_check(false, "책이 안 열렸다")
		return
	forge.call(&"_on_jin_selected", &"jin_single")
	var board = forge.get_node("Stage/Spread/RingBoard")
	# 합성 밑그림을 **미달로** 그린다 (일부만·벗어나게 → 완성도·정밀도 둘 다 낮게)
	board.call(&"begin_stroke")
	var g = board.call(&"guide_points")
	for i in range(0, int(g.size() * 0.3)):
		board.call(&"trace_stroke", g[i] + Vector2(9.0, 8.0))
	var sc := float(board.call(&"combined_total"))
	_check(sc <= 0.65, "미달 조립본을 만들었다 (%.2f)" % sc)
	_check(bool(forge.call(&"can_commit")), "진 고르고 그렸으니 can_commit 참 — 그래서 조용히 거부됐었다")

	var rejected := []
	forge.commit_rejected.connect(func(s: float) -> void: rejected.append(s))
	var gs = root.get_node("/root/GameState")
	var before := (gs.ring_designs as Array).size()
	forge.call(&"close")
	await process_frame
	_check(rejected.size() == 1, "책을 덮으면 commit_rejected가 온다 (침묵 금지)")
	_check((gs.ring_designs as Array).size() == before, "미달 조립본은 여전히 안 맺힌다 (거부는 옳다)")
	_base.call(&"_close_drawing")


## [6-폐지] 그리기 폐지 모드 — 조립만으로 맺힌다. 계약 셋: ① 한 획도 안 그었는데 맺힌다
##   ② 펑(commit_rejected)이 없다 ③ 점수는 부품이 정한 값이라 기준선 위다.
## ⚠ ③이 없으면 `assemble_score_base`를 기준선 아래로 잘못 내려도 아무도 안 빨개진다.
func _test_assemble_only_commits() -> void:
	print("[6] 그리기 폐지 — 조립만으로 맺힌다 (펑 없음, 세83)")
	_base.call(&"_open_drawing")
	await process_frame
	var forge = _base.get("_forge")
	if forge == null:
		_check(false, "책이 안 열렸다")
		return
	forge.call(&"_on_jin_selected", &"jin_single")
	forge.call(&"_on_rune_selected", 0)          # 불 — 룬 자리를 채워야 조립이 끝난다
	var board = forge.get_node("Stage/Spread/RingBoard")
	_check(float(board.call(&"coverage")) <= 0.02, "한 획도 안 그었다 (폐지 모드의 전제)")
	_check(bool(forge.call(&"can_commit")), "🔴 안 그었어도 조립이 끝났으면 맺을 수 있다")

	# 🔴 **버튼 경로** — `close()` 자동 맺기만 재면 [마법진 완성 ✦]이 조용히 죽어도 그린이다(뮤테이션 실측).
	forge.call(&"_on_start_draw")
	await process_frame
	_check(forge.get_node("Stage/Spread/Report").visible,
		"🔴 [마법진 완성 ✦]을 누르면 리포트가 뜬다 (안 뜨면 버튼이 조용히 죽어 있다)")
	# 완성 연출 훅이 **실제로 불린다** — 실제 회귀 형태가 「훅이 조용히 안 불린다」였고 그동안 전 스위트가 그린이었다.
	# ⚠ 수명(FINISH_DUR)을 안 박는다 — 0 이상이면 돌고 있다(연출값을 조여도 거짓 빨강이 안 난다).
	_check(float(board.call(&"finish_progress")) >= 0.0,
		"🔴 완성 순간에 판 연출이 돈다 (실제 %.3f · -1 = 훅이 안 불렸다)"
			% float(board.call(&"finish_progress")))
	# 연출의 뜻 = 「안(룬) → 밖(진 윤곽)」 = 연산 순서. 그림은 못 봐도 **순서 관계는 순수 함수**라 잰다.
	# ⚠ 수명·색은 안 박는다(연출값 튜닝 자유).
	var bd = load("res://src/drawing/ring_board.gd")
	var t_mid := float(bd.finish_t_at_radius(0.5))
	_check(bd.finish_glow_at(0.0, t_mid) > 0.0 and bd.finish_glow_at(1.0, t_mid) <= 0.0,
		"🔴 파도 중간엔 룬(안쪽)이 이미 빛나고 진 윤곽(바깥)은 아직이다 (안→밖 순서)")
	_check(bd.finish_glow_at(1.0, float(bd.FINISH_SWEEP_T)) > 0.0,
		"파도가 끝에는 바깥 테두리까지 닿는다 (안 닿으면 진이 영영 안 빛난다)")

	var rejected := []
	forge.commit_rejected.connect(func(s: float) -> void: rejected.append(s))
	var gs = root.get_node("/root/GameState")
	var before := (gs.ring_designs as Array).size()
	forge.call(&"close")
	await process_frame
	_check(rejected.is_empty(), "🔴 폐지 모드엔 펑이 없다 (commit_rejected %d회)" % rejected.size())
	_check((gs.ring_designs as Array).size() == before + 1,
		"🔴 조립만으로 도안이 맺혔다 (%d → %d)" % [before, (gs.ring_designs as Array).size()])
	var asm: Dictionary = forge.call(&"get_assembly")
	var sc := float(asm.get("score", -1.0))
	_check(sc > 0.65, "🔴 부품이 정한 점수가 기준선 위다 (%.2f) — 아니면 조립하고도 펑이 난다" % sc)
	_base.call(&"_close_drawing")


## [6b] 해피패스 — 조립(진 + 층에 문양-고리) → 그리기 → `build_assembly`가 발사 계약을 싣는다:
##   **score**(없으면 조용히 기준 위력) + **flatten rings**(층→8칸).
## COMBINED 모드라 `_board.get_assembly()`는 빈 값 — 패널 `build_assembly`가 직접 조립해야 한다.
func _test_book_assembles_the_firing_contract() -> void:
	print("[6b] 책 조립본이 발사 계약을 싣는다 (score · flatten rings — 세26)")
	var gs = root.get_node("/root/GameState")
	gs.codex[&"gr_radiate5"] = true   # 보상 문양 링을 해금 상태로 (조립 목록에 뜨게 — 맨몸 시작이라 시드 아님)
	_base.call(&"_open_drawing")
	await process_frame
	var forge = _base.get("_forge")
	if forge == null:
		_check(false, "책이 안 열렸다")
		return
	var RP: GDScript = load("res://src/core/ring_power.gd")
	forge.call(&"_on_jin_selected", &"jin_single")
	forge.call(&"_on_rune_selected", 0)
	# 🔴 점수가 **무엇에서 오는지**를 모드마다 갈라 잰다 — `score > 0`만 보면 트레이스 루프를 통째로
	#   지워도 그린이다(폐지 모드는 점수가 부품에서 온다). 세 지점을 찍는다: 진만 → 문양 끼움 → 정확히 긋기.
	var score_jin_only := float((forge.call(&"build_assembly") as Dictionary).get("score", -1.0))
	forge.call(&"_on_band_selected", 0)
	forge.call(&"_on_ring_picked", &"gr_radiate5")   # 밴드0에 발산×5
	var score_with_glyphs := float((forge.call(&"build_assembly") as Dictionary).get("score", -1.0))
	# 합성 밑그림 전체를 **정확히** 따라 긋는다 (완성도·정밀도 높게)
	var board = forge.get_node("Stage/Spread/RingBoard")
	board.call(&"begin_stroke")
	var g = board.call(&"guide_points")
	for pt in g:
		board.call(&"trace_stroke", pt)
	var asm: Dictionary = forge.call(&"build_assembly")
	_check(asm.has("score"), "🔴 build_assembly가 score를 싣는다 (세26 — 없으면 조용히 기준 위력)")
	var score_traced := float(asm.get("score", -1.0))
	if _skip_drawing():
		# 🔴 폐지 모드 = 부품이 점수를 정한다 — 수치를 안 박고 `assembled_score`를 직접 부른다.
		_check(int(forge.call(&"assembled_parts").x) == 5 and int(forge.call(&"assembled_parts").y) == 1,
			"부품 수 = 문양 5·층 1 (실제 %s)" % str(forge.call(&"assembled_parts")))
		_check(is_equal_approx(score_traced, RP.assembled_score(5, 1)),
			"🔴 폐지 모드 점수 == assembled_score(5,1) (실제 %.4f / 기대 %.4f)"
				% [score_traced, RP.assembled_score(5, 1)])
		_check(score_with_glyphs > score_jin_only,
			"🔴 문양-고리를 끼우면 점수가 오른다 (%.3f > %.3f — 안 오르면 원정 보상이 위력과 무관해진다)"
				% [score_with_glyphs, score_jin_only])
		_check(is_equal_approx(score_traced, score_with_glyphs),
			"폐지 모드에선 그은 것이 점수를 안 바꾼다 (%.3f == %.3f — 그게 폐지의 정의다)"
				% [score_traced, score_with_glyphs])
	else:
		# 🔴 그리기 모드 = **손이 점수를 정한다.** 안 그은 대조군보다 커야 한다(수치 무기입).
		_check(score_traced > score_with_glyphs,
			"🔴 그은 게 도안 점수로 흘러간다 (%.3f > %.3f — 같으면 트레이스가 build_assembly에 안 닿는다)"
				% [score_traced, score_with_glyphs])
		_check(score_traced > 0.0, "정확히 그었으니 score>0 (실제 %.2f)" % score_traced)
	_check(asm.has("rings") and (asm["rings"] as Array).size() == 1, "rings 8칸 배열이 실린다")
	var flat: Array = asm["rings"][0]
	var radiate := 0
	for k in flat:
		if int(k) == 1:   # Enums.GlyphCode.RADIATE = 1
			radiate += 1
	_check(radiate == 5, "밴드에 발산×5 → flatten에 발산 코드가 5칸 (실제 %d)" % radiate)
	_check(StringName(asm.get("jin", &"")) == &"jin_single" and int(asm.get("rune", -1)) == 0,
		"jin=jin_single · rune=불(0)이 실린다")
	_base.call(&"_close_drawing")


## [7] 좌클릭이 발사까지 도달한다 — 뷰포트에 진짜 마우스 이벤트를 민다.
## 🔴🔴 **헤드리스에선 검출력이 0이다** — 렌더가 없어 Control 히트 테스트가 실제와 다르다
##   (`Ground.mouse_filter`를 도로 빼도 그냥 통과한다. 같은 코드가 실게임에선 발사 0회로 재현됐다).
##   `mouse_filter` 값 자체는 `test_scene_contract_auto`가 정적으로 잰다 — 실제 그물은 그쪽이다.
func _test_real_left_click_actually_fires() -> void:
	print("[7] 좌클릭이 발사에 닿는다 ⚠ 헤드리스에선 검출력 0 — 실제 게임에서 확인할 것")
	var gs = root.get_node("/root/GameState")
	gs.ring_equipped[0] = RingDesign.from_assembly(_assembly(1.0), "클릭 테스트")
	_player().caster.select_slot(0)

	# 🔴 `ring_cast_started`를 센다(`requested`가 아니라) — 시작 신호는 클릭과 **동기**라 시전 시간을
	#   조여도 안 낡는다. 완료 신호를 세면 프레임 대기가 시전 시간에 묶인다.
	var casts := []
	_bus.ring_cast_started.connect(func(_a, _p, _d) -> void: casts.append(1))

	# 🔴 실제 마우스 이벤트를 **뷰포트에** 민다 — 게임 창에 클릭한 것과 같은 경로다
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(480, 270)          # 화면 한복판 = Ground 위
	_base.get_viewport().push_input(press)
	await process_frame
	await process_frame

	_check(casts.size() == 1,
		"🔴 좌클릭이 발사에 닿는다 (실제 발사 %d회 — 0이면 Control이 클릭을 먹고 있다)" % casts.size())
	# 🔴 걸린 시전을 끊고 나간다 — 안 끊으면 다음 검사의 `fire()`가 **시전 중 차단**에 걸려 거짓 빨강이 난다.
	_player().caster.cancel_cast()


## [7-b] 빈 슬롯은 발사를 거부한다. 계약 셋: ① `ring_cast_requested`가 안 나간다
##   ② 마나를 안 태운다(거부는 공짜) ③ 거부가 조용하지 않다(notice).
## ⚠ 옛 도안(진 없음) 폴백은 `test_ring_spell_auto` [20] 소관 — 여기서 겹쳐 재지 마라.
func _test_empty_slot_refuses_to_fire() -> void:
	print("[7-b] 빈 슬롯 발사 거부 — 캐스트 0·마나 무소모·안내 발신 (매직볼 은퇴)")
	var gs = root.get_node("/root/GameState")
	# 🔴 `debug_free_cast`는 "editor" 피처라 **헤드리스 -s에서도 켜진다** — 켜진 채면 spend가
	#   통째로 스킵돼 ②가 자명 통과(검출력 0)가 된다. 꺼서 그물을 재점화한다.
	gs.debug_free_cast = false
	gs.ring_equipped[1] = null
	var caster = _player().caster
	caster.select_slot(1)

	var casts := []
	var cb := func(_a, _p, _d) -> void: casts.append(1)
	_bus.ring_cast_requested.connect(cb)
	var notices := []
	var ncb := func(text: String, warn: bool) -> void:
		if warn:
			notices.append(text)
	caster.notice.connect(ncb)
	var mana_before: float = gs.mana

	caster.fire()
	await process_frame

	_check(casts.is_empty(), "빈 슬롯 fire() = ring_cast_requested 0회 (실제 %d)" % casts.size())
	# ⚠ 동등 비교 금지 — 프레임 사이 마나 **자연 재생**이 올려서 갈라진다. 계약은 "안 깎는다"다.
	_check(gs.mana >= mana_before - 0.001,
		"거부에 마나를 안 태운다 (전 %.1f → 후 %.1f — 깎였으면 거부 전에 spend가 돈 것)" % [mana_before, gs.mana])
	_check(not notices.is_empty(), "거부가 조용하지 않다 — warn 안내가 나간다")
	_bus.ring_cast_requested.disconnect(cb)
	caster.notice.disconnect(ncb)
	caster.select_slot(0)


## [8] 챕터로 나가는 길 — 문이 있고 · 나를 감지하고([E]가 뜨려면) · 갈 곳이 실재한다.
## 🔴 씬 전환 자체는 여기서 안 시킨다 — 시키면 이 테스트가 딛고 선 `_base`가 통째로 날아간다.
func _test_forest_gate_leads_out() -> void:
	print("[8] 챕터로 나가는 길 — 문이 있고, 나를 알아보고, 갈 곳(보스방)이 실재한다")
	var gate = _zone(&"forest_gate")
	if gate == null:
		_check(false, "숲길(zone_id=forest_gate)을 못 찾았다")
		return
	# 여기선 연결만 잰다 — 실제로 나가는지는 스텁 경로를 쓰는 뒤 항목이 잰다.
	_check(gate.interacted.get_connections().size() >= 1,
		"숲길의 interacted를 베이스가 받고 있다 (안 이으면 E가 조용히 아무것도 안 한다)")

	var player = _player()
	var was: Vector2 = player.global_position
	player.global_position = gate.global_position
	var frames := 0
	while not gate.get_overlapping_bodies().has(player) and frames < 10:
		await physics_frame
		frames += 1
	_check(gate.player_in_range(), "숲길이 플레이어를 감지 = [E] 안내가 뜬다 (%d 물리 프레임)" % frames)
	player.global_position = was

	# ⚠ **경로**를 확인한다(PackedScene이 아니라) — base⇄boss_room 순환 preload를 피한 결과다.
	# 🔴 순환이면 상대가 빈 껍데기로 굳는데 **헤드리스는 못 잡는다**(여기선 base를 먼저 로드하니 멀쩡하다).
	var path: String = str(_base.get("boss_room_scene_path"))
	_check(ResourceLoader.exists(path),
		"갈 곳(%s)이 실재한다 — 경로가 깨지면 챕터를 골라도 아무 일도 안 난다" % path)


## [9] 문이 스스로 맥동한다 — 첫 화면에서 유일하게 빛을 가진 것이다.
## 🔴 **「살아 있다」로 읽히는지는 헤드리스가 못 잡는다**(F5 몫) — 여기서 재는 건 배선 셋이고,
##   셋 다 에러 없이 조용히 죽는다: ⓐ 빛 텍스처 로드(경로가 깨지면 빛이 통째로 사라진다)
##   ⓑ `energy`가 실제로 변한다(트윈이 없으면 밝은 정지 등) ⓒ 한 호흡 뒤에도 계속 돈다(원샷 아님).
func _test_gate_light_breathes() -> void:
	print("[9] 문이 스스로 맥동한다 — 빛 웅덩이가 숨 쉰다 (겉보기는 F5, 여기선 배선)")
	var gate = _zone(&"forest_gate")
	if gate == null:
		_check(false, "숲길(zone_id=forest_gate)을 못 찾았다")
		return
	var light = _find_light(gate)
	if light == null:
		_check(false, "문에 빛 웅덩이(PointLight2D)가 없다 — 첫 화면에서 문이 안 빛난다")
		return
	_check(light.texture != null,
		"빛 텍스처가 로드됐다 (light_soft.tres — 경로가 깨지면 빛이 조용히 사라진다)")
	if not light.has_method("breaths"):
		_check(false, "빛이 맥동 스크립트(light_pool.gd)를 안 물고 있다 — 값만 밝은 정지 등이다")
		return

	var mid: float = light.base_energy()
	_check(mid > 0.0, "맥동의 한가운데 밝기가 0보다 크다 (실제 %.2f)" % mid)

	# 🔴 **한 점씩 비교하지 않는다** — 두 샘플이 마루/골을 사이에 두고 대칭으로 걸리면 값이 **같아서**
	# 도는 맥동을 "멈췄다"로 오독한다. 대신 한 호흡(PULSE_TIME×2 = 3.0초)보다 긴 창을 훑어 진폭을 잰다.
	var lo: float = light.energy
	var hi: float = light.energy
	var before: int = light.breaths()
	for i in 16:
		await create_timer(0.25).timeout   # 16 × 0.25 = 4.0초 > 한 호흡 3.0초
		lo = minf(lo, light.energy)
		hi = maxf(hi, light.energy)
	_check(hi - lo > mid * 0.2,
		"4초 창에서 밝기가 %.3f~%.3f로 출렁였다 (폭 %.3f > %.3f — 평평하면 맥동이 아니라 상수다)"
			% [lo, hi, hi - lo, mid * 0.2])
	_check(lo > 0.0, "가장 어두울 때도 꺼지진 않는다 (실제 %.3f — 0이면 깜빡여 끊긴다)" % lo)
	_check(light.breaths() - before >= 1,
		"한 호흡을 마치고 다시 시작했다 (4초에 %d회 — 0이면 원샷이라 한 번 밝아지고 멈춘 것)"
			% (light.breaths() - before))


## [10] 🔴 마을 되살리기 게이트 — 잔해는 [E]가 안 먹는다.
##   `STATION_UNLOCKS`에 오른 건물은 codex 해금 전까지 잠기고, 해금 **그 자리에서** 열려야 한다
##   (마을을 나갔다 와야 열리면 = 시그널 수신이 없고 `_ready` 초기화만 있는 것이다).
## 🔴 잠금 손잡이 = `Area2D.monitoring` 하나 — 안내와 E 입력이 같이 닫힌다. 렌더 없이 읽히므로 잴 수 있다.
## 🔴 지금 표는 비어 있다 — ⓐ는 「표를 채우면 정말 살아나나」(배선·역방향 불변식)를 재고, ⓑ 전수 검사는
##   표가 차면 저절로 다시 돈다. 「비었으니 검사를 지운다」로 가면 되살리는 세션이 그물 없이 출발한다.
## ⚠ 잔해가 잔해로 **보이나**·색조가 회보라로 읽히나는 F5 몫이다. `monitoring`은 `set_deferred`라 한 프레임 넘겨야 한다.
func _test_station_gate_follows_codex() -> void:
	print("[10] 잔해/온전 게이트 — codex가 [E]를 연다 (세89 마을 되살리기 · 세90 표 비움)")
	var gs = root.get_node("/root/GameState")
	var gated: Dictionary = _base.STATION_UNLOCKS   # 🔴 표를 베끼지 않는다 — 라이브 스크립트를 읽는다
	print("     게이트 표 %d줄 %s" % [gated.size(), gated])

	# ── ⓐ 🔴 표가 비어도 **되살리는 길**은 살아 있어야 한다 ──
	#  🔴 배선이 이 그물의 심장이다 — 표가 비면 루프가 0회라, 누가 `codex_unlocked` 수신을 걷어도
	#    전 스위트가 그린이다.
	_check(_bus.codex_unlocked.is_connected(Callable(_base, "_on_station_unlocked")),
		"🔴🔴 codex_unlocked → _on_station_unlocked 배선이 산다 (없으면 표를 채워도 그 방문 내내 잔해다)")
	_check(_base.has_method("_refresh_stations") and _base.has_method("_apply_station_state"),
		"🔴 되살리기 기계(_refresh_stations · _apply_station_state)가 산다")
	#  🔴 역방향 불변식 — `Ruin` 자식이 있는데 표에 없으면 잔해/온전 전환을 아무도 안 돌린다
	#    (영영 잔해거나, 잔해가 안 켜진 채 온전하게 선다 — 어느 쪽이든 에러가 0이다).
	for child in _base.get_children():
		if child.get_node_or_null("Ruin") == null:
			continue
		_check(gated.has(String(child.name)),
			"🔴 %s에 Ruin(잔해)이 있으면 게이트 표에 올라야 한다 — 없으면 잔해/온전 전환이 아무도 안 돌린다"
				% child.name)

	# ── ⓑ 표에 오른 건물 전수 검사 (세89 원본 — 표가 비면 0회, 채우면 자동 가동) ──
	for node_name in gated:
		var unlock: StringName = gated[node_name]
		var zone = _base.get_node_or_null(node_name)
		if zone == null:
			_check(false, "게이트 대상 %s 노드가 씬에 없다 (표와 씬이 갈렸다)" % node_name)
			continue
		# ⚠ 자식 존재만 재면 안 된다 — 텍스처 경로가 깨지면 스프라이트는 살고 그림만 조용히 사라지고,
		#   `Ruin`에 온전한 PNG를 물리면 「되돌렸는데 처음부터 멀쩡했다」가 된다. 그래서 **둘이 다른 그림인지**까지 잰다.
		var ruin = zone.get_node_or_null("Ruin")
		var whole = zone.get_node_or_null("Sprite")
		var pool = zone.get_node_or_null("LightPool")
		_check(ruin != null and whole != null,
			"🔴 %s: 잔해(Ruin)와 온전(Sprite) 스프라이트가 둘 다 있다 (표에 올렸으면 잔해 아트가 있어야 한다)" % node_name)
		if ruin != null and whole != null:
			_check(ruin.texture != null,
				"🔴 %s: 잔해 PNG가 실제로 로드됐다 (경로가 깨지면 그림만 조용히 사라진다)" % node_name)
			_check(ruin.texture != whole.texture,
				"🔴 %s: 잔해와 온전이 **다른 그림**이다 (같으면 되돌려도 아무것도 안 바뀐다)" % node_name)

		var had: bool = gs.is_unlocked(unlock)
		gs.codex.erase(unlock)
		_base.call(&"_refresh_stations")
		await process_frame
		_check(not zone.monitoring,
			"🔴 %s: 미해금이면 잠긴다 — [E] 안내도 입력도 안 온다 (%s)" % [node_name, unlock])
		if ruin != null and whole != null:
			_check(ruin.visible and not whole.visible,
				"🔴 %s: 미해금이면 **잔해로 보인다** (잔해 %s · 온전 %s)"
					% [node_name, ruin.visible, whole.visible])
		# 🔴 폐허엔 빛이 없다 — 빛 웅덩이를 안 끄면 잔해가 환하게 빛난다(에러 0).
		if pool != null:
			_check(not pool.visible, "🔴 %s: 잔해엔 빛 웅덩이가 안 켜진다 (폐허엔 빛이 없다)" % node_name)
		# 🔴 **시그널 경로로** 연다 (직접 `_refresh_stations`를 부르지 않는다) — `codex_unlocked`
		#   수신이 빠지면 「퀘스트를 깼는데 그 방문 내내 잠긴 채」가 되는데 에러가 하나도 안 난다.
		_bus.codex_unlocked.emit(unlock)
		await process_frame
		_check(zone.monitoring,
			"🔴 %s: 해금 순간 **그 자리에서** 열린다 (%s)" % [node_name, unlock])
		if ruin != null and whole != null:
			_check(whole.visible and not ruin.visible,
				"🔴 %s: 되돌리면 **온전한 건물로 바뀐다** (잔해 %s · 온전 %s)"
					% [node_name, ruin.visible, whole.visible])
		if pool != null:
			_check(pool.visible, "🔴 %s: 되살아나면 발밑에 빛 웅덩이가 켜진다 (설계 §3)" % node_name)
			_check(pool.texture != null,
				"%s: 빛 텍스처가 로드됐다 (light_soft.tres — 깨지면 빛이 조용히 사라진다)" % node_name)
		if not had:
			gs.codex.erase(unlock)   # 뒷정리 — 원래 없던 해금은 되돌린다

	# 🔴 마을 색조 = 진행도. `Dusk` 조회가 실패하면 **조용히 no-op**이라 「값이 움직이나」를 잰다.
	# ⚠ 색을 안 박는다(연출값) — 계약은 둘뿐: ⓐ 되돌린 수에 따라 달라진다 ⓑ 폐허여도 밝다.
	var dusk = _base.get_node_or_null("Dusk")
	if dusk == null:
		_check(false, "Dusk(CanvasModulate)가 없다 — 마을 색조 축이 통째로 죽는다")
	elif gated.is_empty():
		# 되돌릴 건물이 0채라 색조는 씬 값에 고정이다 — ⓐ「움직인다」는 분모가 0이라 못 재고,
		#   ⓑ「폐허여도 밝다」만 잰다.
		var dim0: float = minf(minf(dusk.color.r, dusk.color.g), dusk.color.b)
		_check(dim0 >= 0.85,
			"🔴 폐허여도 밝기는 유지한다 — 어두운 폐허 각하 (최소 성분 %.2f · 표가 비어 고정값)" % dim0)
	else:
		var restore := {}
		for node_name in gated:
			restore[gated[node_name]] = gs.is_unlocked(gated[node_name])
			gs.codex.erase(gated[node_name])
		_base.call(&"_refresh_stations")
		var ruined: Color = dusk.color
		for node_name in gated:
			gs.codex[gated[node_name]] = true
		_base.call(&"_refresh_stations")
		var whole: Color = dusk.color
		_check(ruined != whole,
			"🔴 되돌린 건물 수에 따라 마을 색조가 움직인다 (폐허 %s → 완공 %s)" % [ruined, whole])
		var dim: float = minf(minf(ruined.r, ruined.g), ruined.b)
		_check(dim >= 0.85,
			"🔴 폐허여도 밝기는 유지한다 — 어두운 폐허 각하 (최소 성분 %.2f)" % dim)
		for uid in restore:
			if bool(restore[uid]):
				gs.codex[uid] = true
			else:
				gs.codex.erase(uid)

	_base.call(&"_refresh_stations")
	await process_frame


## [11] 🔴 첫 화면 구도 — 문·잔해·제작대가 통째로 든다.
## 🔴 겉보기는 못 봐도 **「무엇이 화면에 드나」는 순수 기하**라 잴 수 있다. 실패 형태가 늘
##   「좌표가 창 밖으로 밀린다」라서 카메라 창을 손으로 계산해 잡는다(옛 배치는 문이 950px 밖이었다).
## ⚠ 창은 **스폰에서 파생**한다 — 수치를 하나도 안 박으므로 월드·뷰포트를 바꿔도 거짓 빨강이 안 난다.
func _test_first_screen_composition() -> void:
	print("[11] 🔴 첫 화면 — 문·잔해·마을의 셋이 통째로 든다 (설계 §4 + 세90 마을 정리)")
	var ground = _base.get_node_or_null("Ground")
	if ground == null:
		_check(false, "Ground(월드 크기 정본)를 못 찾았다")
		return
	var world: Vector2 = ground.size
	var view := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var half := view * 0.5
	# 카메라는 `_setup_camera`가 월드에 물린다(limit 0..Ground) → 중심이 가장자리에서 클램프된다.
	var center := Vector2(
		clampf(_spawn.x, half.x, maxf(half.x, world.x - half.x)),
		clampf(_spawn.y, half.y, maxf(half.y, world.y - half.y)))
	var screen := Rect2(center - half, view)
	print("     스폰 %s → 첫 화면 %s" % [_spawn, screen])

	# ⓐ 🔴 문이 첫 화면의 주인공이다 — 발밑만이 아니라 **머리끝까지** 든다.
	#    (발밑만 재면 아치 위쪽이 잘려 「반만 보이는 문」이 그린으로 통과한다.)
	var gate = _zone(&"forest_gate")
	if gate == null:
		_check(false, "숲길(zone_id=forest_gate)을 못 찾았다")
		return
	_check(screen.has_point(gate.global_position),
		"🔴 문이 첫 화면 안에 있다 — 문 %s / 창 %s (밖이면 「어디로 가야 하는지」가 안 보인다)"
			% [gate.global_position, screen])
	var gate_top := _sprite_top(gate)
	_check(gate_top < 0.0 or gate_top >= screen.position.y,
		"🔴 문이 통째로 든다 (머리끝 y=%.0f ≥ 창 위 %.0f — 아니면 첫 화면의 주인공이 반만 보인다)"
			% [gate_top, screen.position.y])
	_check(_spawn.distance_to(gate.global_position) <= view.x * 0.5,
		"플레이어가 **문 앞에** 서 있다 (거리 %.0fpx — 막 소환된 자리다)"
			% _spawn.distance_to(gate.global_position))

	# ⓑ 🔴 잔해가 첫 화면에 든다. 목록을 **베끼지 않는다** — 게이트 표에서 파생하고,
	#    거기 안 드는 영구 잔해(기념비)만 이름으로 더한다.
	# ⚠ 개수를 안 박고 「목록 **전부**가 든다」로 잰다 — 잔해가 줄어도 거짓 빨강이 안 나고, 늘면 자동으로 그 수를 요구한다.
	var ruins: Array[String] = []
	for node_name in (_base.STATION_UNLOCKS as Dictionary):
		ruins.append(String(node_name))
	ruins.append("Monument")   # 영구 잔해 — 여는 열쇠가 없어 표에 못 든다(base.gd RUIN_PART 주석)
	var on_screen := 0
	for node_name in ruins:
		var n = _base.get_node_or_null(node_name)
		if n == null:
			_check(false, "잔해 %s 노드가 씬에 없다" % node_name)
			continue
		if screen.has_point(n.global_position):
			on_screen += 1
		else:
			print("     (창 밖 잔해: %s %s)" % [node_name, n.global_position])
	_check(on_screen == ruins.size() and on_screen >= 1,
		"🔴 잔해가 **전부** 첫 화면에 든다 (실제 %d/%d — 폐허가 화면에 안 보이면 「망한 마을」이 안 읽힌다)"
			% [on_screen, ruins.size()])

	# ⓒ 🔴 마을의 셋(캐릭 + 문 + 제작대)이 한 화면에 든다.
	#    🔴 좌표를 못 박지 않는다 — 누가 책상을 다시 동쪽으로 밀면 여기가 빨개진다.
	#    🔴 **머리끝까지 잰다** — `global_position`은 발밑이라, 발밑만 재면 지붕이 잘린 채로 그린이 난다(실측).
	for node_name in ["Desk"]:
		var n = _base.get_node_or_null(node_name)
		if n == null:
			_check(false, "🔴 %s 노드가 씬에 없다 (세90 정리 후 마을에 남는 셋 중 하나다)" % node_name)
			continue
		_check(screen.has_point(n.global_position),
			"🔴 %s가 첫 화면 안에 있다 — 실제 %s / 창 %s (밖이면 마을에 그것뿐인데 안 보인다)"
				% [node_name, n.global_position, screen])
		var top := _sprite_top(n)
		_check(top < 0.0 or top >= screen.position.y,
			"🔴 %s가 **통째로** 든다 (머리끝 y=%.0f ≥ 창 위 %.0f — 아니면 지붕이 잘린다)"
				% [node_name, top, screen.position.y])

	# ⓓ 🔴 **기념비는 영구 잔해다** — 되돌리는 퀘스트가 없으므로 게이트 표에 들면 영영 잠긴다.
	#    그림 자체가 잔해여야 한다(전환 대상이 아니다, base.gd `RUIN_PART` 주석).
	_check(not (_base.STATION_UNLOCKS as Dictionary).has("Monument"),
		"🔴 기념비는 게이트 표에 없다 (넣으면 여는 열쇠가 없어 영영 잔해 + 색조 분모만 커진다)")
	var monu = _base.get_node_or_null("Monument")
	if monu != null:
		var spr = monu.get_node_or_null("Sprite")
		_check(spr != null and spr.texture != null and String(spr.texture.resource_path).contains("ruin"),
			"🔴 기념비 스프라이트가 **잔해 그림**이다 (실제 %s — 깨진 마법진이 마을이 망한 발단이다)"
				% (String(spr.texture.resource_path) if spr != null and spr.texture != null else "없음"))

	# ⓔ 🔴 마법진 무늬가 기념비 발밑에 찍혔다. 바닥은 `.tscn`이 아니라 `_build_campus()`가 코드로 깔아
	#    **씬과 코드가 갈릴 수 있는 자리**다 — 갈리면 무늬만 잔디 한복판에 남는데 에러가 0이다.
	# ⚠ 셀 좌표를 안 박는다 — 기념비 위치에서 파생하므로 캠퍼스를 옮겨도 거짓 빨강이 안 난다.
	var road = _base.get_node_or_null("TileRoad")
	if monu != null and road != null:
		var ts: int = road.tile_set.tile_size.x
		var cell := Vector2i(floori(monu.position.x / ts), floori(monu.position.y / ts))
		_check(road.get_cell_atlas_coords(cell) == Vector2i(2, 1),
			"🔴 마법진 무늬가 기념비 발밑 셀 %s에 찍혔다 (실제 아틀라스 %s — 어긋나면 무늬만 옛 자리에 남는다)"
				% [cell, road.get_cell_atlas_coords(cell)])


## [12] 🔴 문 [E] 하나가 「정산」과 「원정」을 겸한다.
## 🔴 이 그물이 없으면 이 배선 전체가 무그물이다: `test_quests_auto`는 마을을 인스턴스화조차 안 하고,
##   [8]의 게이트 검사는 연결이 하나만 있으면 통과한다 — 즉 문이 **정산을 통째로 잃어도** 전 스위트가 그린이다.
##   그래서 씬을 통과하는 진짜 경로(`zone.interacted.emit()`)로 잰다.
## 재는 것 셋 — 전부 에러 0으로 조용히 깨진다:
##   ⓐ 정산 대기가 있으면 문 [E]가 실제로 정산한다 ⓑ 정산 대사가 끝나면 **저절로** 출발한다
##   (아니면 `ui_modal_open` 게이트 때문에 E를 두 번 눌러야 한다) ⓒ 정산할 게 없으면 대사 없이 바로 출발.
func _test_gate_claims_then_opens_chapters() -> void:
	print("[12] 🔴 문 [E] = 정산 + 출발 (세95 길잡이 은퇴 — 설계 §2)")
	var gs = root.get_node("/root/GameState")
	var db = root.get_node("/root/Db")
	var gate = _zone(&"forest_gate")
	if gate == null:
		_check(false, "숲길(zone_id=forest_gate)을 못 찾았다")
		return
	# 앞 항목들이 남긴 모달을 확실히 걷고 시작한다 (책은 [6b]에서 닫혔지만 플래그는 오토로드다).
	gs.ui_modal_open = false

	# ── ⓐ 정산 대기 상태를 만든다 ──
	#  q00은 DRAW 1장이라 도안이 하나라도 있으면 충족된다.
	#  🔴 완료 표시만 되돌린다 — DRAW는 **상태 판정**이라 진행 카운터를 건드릴 필요가 없다.
	var qid := &"q00_first_draw"
	var had_done: bool = gs.is_quest_done(qid)
	gs.quest_done.erase(qid)
	if (gs.ring_designs as Array).is_empty():
		gs.ring_designs.append(RingDesign.from_assembly(_assembly(1.0), "정산 테스트"))
	var q0 = db.get_quest(qid)
	if q0 == null or not gs.is_quest_claimable(q0):
		_check(false, "전제 실패: %s를 정산 대기로 못 만들었다 (도안 %d장)"
			% [qid, (gs.ring_designs as Array).size()])
		return
	_check(_base.get("_dialogue") == null, "전제: 모달이 안 떠 있다")
	# 🔴 여기부터 문 [E]가 **진짜로 씬을 바꾼다** — 갈 곳을 스텁으로 돌려 놓고 잰다(머리말 참조).
	#   ⚠ 위 전제 실패 `return`들보다 **뒤에** 무장한다(먼저 걸면 해제를 안 거치고 빠져나간다).
	var real_room: String = _arm_departure_stub()

	# ── 머리 위 마크가 문에 붙어 있다 ──
	#  🔴 **시그널 경로로** 흔든다 — `quest_ready` 수신이 빠지면 「달성했는데 [?]가 안 켜진다」인데 에러가 0이다.
	#  ⚠ 마크가 **보이나**(렌더·가림)는 헤드리스가 못 본다 — 리드의 MCP 스샷 몫이다.
	var mark = gate.get_node_or_null("Mark")
	_check(mark != null, "🔴 문 위에 마크(Mark) 라벨이 있다 — 길잡이가 은퇴했으니 [?]는 문이 진다")
	_bus.quest_ready.emit(qid)
	await process_frame
	if mark != null:
		_check(mark.visible and String(mark.text) == "?",
			"🔴 정산 대기면 문 위에 [?]가 켜진다 (보임 %s · 글자 %s)" % [mark.visible, mark.text])

	# 🔴 **씬 경로로** 누른다 — `_on_gate_talk`를 직접 부르면 「게이트에 그 함수가 이어져 있나」를
	#   안 재게 된다(연결을 `_depart_to_chapter`로 되돌려도 그린이 나온다 = 검출력 0).
	gate.interacted.emit()
	await process_frame
	_check(gs.is_quest_done(qid),
		"🔴🔴 문 [E]가 **정산한다** (%s 완료 %s — 거짓이면 문이 내보내기만 하고 정산을 잃은 것이다)"
			% [qid, gs.is_quest_done(qid)])
	_check(_base.get("_dialogue") != null,
		"🔴 정산하면 문이 말을 건다 (대사 상자 없음 = 조용히 보상만 주는 옛 병)")
	if mark != null:
			# 정산했으면 [?]는 내려간다 — 새 목표가 열렸으면 [!]로 바뀌고, 아니면 숨는다.
		_check(not mark.visible or String(mark.text) != "?",
			"🔴 정산하면 [?]가 내려간다 (실제 보임 %s · 글자 %s — 안 내려가면 영영 「가서 받아라」다)"
				% [mark.visible, mark.text])

	# ── ⓑ 대사가 끝나면 **저절로** 출발한다 (E를 두 번 누르게 하지 않는다) ──
	_push_action("ui_cancel")   # 건너뛰기 → finished
	await process_frame
	await process_frame
	_check(_base.get("_dialogue") == null, "대사가 끝나면 상자가 치워진다")
	_check(await _departed(),
		"🔴🔴 대사가 끝나면 **저절로** 나간다 (설계 §2 ⓐ — 안 나가면 E를 두 번 눌러야 한다)")

	# 뒷정리 — 스텁 씬을 치우고 모달을 푼다 (다음 갈래가 오염된 채로 시작하지 않게).
	_clear_departure()
	_check(not gs.ui_modal_open, "출발 뒤 모달이 안 잠겨 있다 (실제 모달 %s)" % gs.ui_modal_open)

	# ── ⓒ 정산할 게 없으면 **대사 없이 바로** 출발 ──
	#  🔴 죽으면 「나가려는데 자꾸 대사가 뜬다」거나 「E가 무반응」이 되는데, 둘 다 에러가 0이다.
	_check(not gs.has_claimable_quest(), "전제: 이제 정산할 게 없다")
	gate.interacted.emit()
	await process_frame
	_check(_base.get("_dialogue") == null,
		"🔴 정산할 게 없으면 대사를 안 띄운다 (설계 §2 — 나가려는데 대사가 뜨면 안 된다)")
	_check(await _departed(), "🔴 정산할 게 없으면 **바로** 나간다")
	_clear_departure()

	# ── ⓓ 🔴 소프트락 방지 — 대사가 **한 줄도 안 나올 수 있다**(`.tres` 침묵사) ──
	#  그때 `finished`가 영영 안 오므로 출발을 거기에**만** 걸면 마을 밖으로 못 나간다.
	#  🔴 `_start_turnin_dialogue`의 **반환값이 계약**이다 — 못 띄웠으면 false. 여기선 반환형을 잰다(`-> void`로 되돌리면 빨개진다).
	var shown = _base.call(&"_start_turnin_dialogue", [&"__ghost_quest__"])
	_check(typeof(shown) == TYPE_BOOL and not bool(shown),
		"🔴🔴 대사 줄이 비면 `_start_turnin_dialogue`가 **false**를 돌려준다 (실제 %s) — void로 되돌리면 소프트락이다"
			% str(shown))
	_check(_base.get("_dialogue") == null, "줄이 비면 상자를 안 띄운다 (빈 상자가 모달만 잡으면 안 된다)")

	# ── ⓔ 🔴 소프트락 리그 — 「대사 줄이 비는 경로」를 씬을 통과해 진짜로 재현한다 ──
	#  `quest_completed`는 `claim_ready_quests` 안에서 **동기로** 오므로, 그 수신자에서 `Db.quests`를
	#  지우면 정산 직후 `get_quest`가 null이 된다 = `.tres` 침묵사와 모양이 같다. 재는 건 결과다:
	#  「대사가 한 줄도 안 나와도 마을 밖으로 나가나」. ⚠ `Db.quests`는 전역이라 **같은 함수 안에서 즉시 되돌린다**.
	var qdef = db.get_quest(qid)
	gs.quest_done.erase(qid)
	var killer := func(done_id: StringName) -> void:
		if done_id == qid:
			(db.quests as Dictionary).erase(qid)
	_bus.quest_completed.connect(killer)
	gate.interacted.emit()
	_bus.quest_completed.disconnect(killer)
	(db.quests as Dictionary)[qid] = qdef   # 🔴 즉시 원상복구
	_check(_base.get("_dialogue") == null,
		"전제: 대사가 한 줄도 안 나왔다 (침묵사 재현 — 상자가 떴으면 리그가 안 먹은 것이다)")
	_check(await _departed(),
		"🔴🔴 대사가 **한 줄도 안 나와도** 마을 밖으로 나간다 (설계 §2 ⓑ — 여기가 빨개지면 소프트락이다)")

	_disarm_departure_stub(real_room)
	if had_done:
		gs.quest_done[qid] = true   # 뒷정리 — 원래 완료였으면 되돌린다
	# 🔴 뒷정리를 **끝까지** 기다린다 — 정산 SFX가 재생 중인 채로 `quit()`하면 엔진이 종료 시
	#   "ObjectDB instances were leaked"를 찍는다. ⚠ 그 줄은 **`SCRIPT ERROR` grep에 안 걸려**
	#   스위트는 그린인 채 노이즈만 쌓이고, 다음 세션이 진짜 엔진 ERROR를 흘려보낸다.
	await create_timer(1.5).timeout


# ── 헬퍼 ──

## 🔴 **출발 스텁** — 문 [E]가 진짜로 `change_scene_to_file`을 부르므로 갈 곳만 빈 씬으로 돌려 놓는다.
##  진짜 `boss_room`이 뜨면 마을 위에 두 번째 플레이어·적 무리가 얹혀 `_player()`가 조용히 다른 것을 집는다.
##  🔴 스텁이 `current_scene`이 되는 것 = 전환이 실제로 걸렸다는 증거다(`pending_chapter`만 재면 전환을 잃어도 그린).
const DEPARTURE_STUB := "res://tests/test_base_departure_stub.tscn"


## 갈 곳을 스텁으로 바꾸고 **원래 경로를 돌려준다**(해제할 때 그대로 되돌린다).
func _arm_departure_stub() -> String:
	var real: String = str(_base.get("boss_room_scene_path"))
	_base.set("boss_room_scene_path", DEPARTURE_STUB)
	return real


## 실제로 나갔나 — `change_scene_to_file`은 **프레임 끝으로 미뤄지므로** 몇 프레임 기다린다.
func _departed() -> bool:
	for i in 6:
		if current_scene != null and is_instance_valid(current_scene) \
				and String(current_scene.name) == "DepartureStub":
			return true
		await process_frame
	return false


## 전환된 스텁 씬을 치운다 — 안 치우면 다음 전환이 그걸 free하며 `current_scene`이 유령이 된다.
func _clear_departure() -> void:
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	current_scene = null


## 스텁 해제 — 씬을 치우고 **진짜 경로를 되돌린다**(안 되돌리면 뒤 항목이 스텁을 보고 그린이 된다).
func _disarm_departure_stub(real_room: String) -> void:
	_clear_departure()
	_base.set("boss_room_scene_path", real_room)
	root.get_node("/root/GameState").pending_chapter = &""


## 액션 이벤트를 뷰포트에 주입 → _unhandled_input의 is_action_pressed가 받는다.
## ⚠ 액션 주입은 **마우스 히트 테스트를 건너뛴다** — `mouse_filter` 함정은 이걸로 못 잡는다([7]).
func _push_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	root.push_input(ev)


## 그리기 폐지 모드인가 — `RingPower`의 술어를 그대로 부른다(직접 읽으면 스위치를 되돌릴 때 이 그물만 조용히 남는다).
func _skip_drawing() -> bool:
	return bool(load("res://src/core/ring_power.gd").skip_drawing())


## 빈 진 8칸 + 점수. 전개 없이 몸으로만 때려 결과가 깔끔하다.
func _assembly(score: float) -> Dictionary:
	var r := []
	for k in 8:
		r.append(GLYPH_NONE)
	return {"rings": [r], "score": score}


func _targets() -> Array:
	var out := []
	for n in get_nodes_in_group("enemies"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _nearest_target(from: Vector2):
	var best = null
	var best_d := INF
	for t in _targets():
		var d: float = from.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


func _carriers() -> Array:
	var out := []
	for n in get_nodes_in_group("player_projectiles"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


## 씬을 뒤져 플레이어를 찾는다 — 노드 이름이 아니라 **타입**으로 (이름은 바뀔 수 있다).
func _player():
	return _find_body(_base)


func _find_body(node):
	if node is CharacterBody2D:
		return node
	for c in node.get_children():
		var found = _find_body(c)
		if found != null:
			return found
	return null


## 상호작용 지점을 **zone_id로** 찾는다 — 날아다니는 진도 Area2D라 노드 순서에 기대면 조용히 다른 걸 집는다.
func _zone(id: StringName):
	for z in get_nodes_in_group("interact_zones"):
		if z.zone_id == id:
			return z
	return null


## 어느 프롭의 스프라이트 **머리끝** 월드 y. 잴 수 없으면 -1.0(호출부가 그때만 통과 처리한다).
## `Sprite2D`는 텍스처를 중심에 그리고 `offset`으로 민다 → 머리끝 = 위치 + offset − 높이/2.
func _sprite_top(node) -> float:
	var spr = node.get_node_or_null("Sprite")
	if spr == null or spr.texture == null:
		return -1.0
	return spr.global_position.y + spr.offset.y - spr.texture.get_height() * 0.5


## 어느 프롭의 빛 웅덩이 — 노드 **이름이 아니라 타입**으로 찾는다 (이름은 바뀔 수 있다, `_player`와 같은 규율).
func _find_light(node):
	if node is PointLight2D:
		return node
	for c in node.get_children():
		var found = _find_light(c)
		if found != null:
			return found
	return null


func _clear() -> void:
	for n in _carriers():
		n.queue_free()
	for n in get_nodes_in_group("pillars"):
		n.queue_free()


## [16] 🔴 책상 하나가 조립과 제작을 다 연다 — 공방 제작이 유일 경로인 해금 다섯의 문이다.
## 🔴 `test_workshop_auto`는 **패널을 직접 열어** 재므로 마을 진입점이 닫혀도 그린이다 —
##   「패널이 돈다」와 「플레이어가 거기 갈 수 있다」는 다른 계약이고, 이 검사가 뒤쪽을 맡는다.
## ⚠ 그래서 `_open_workshop_panel`을 직접 부르지 않는다 — **책의 버튼에서 출발**해야 끊긴 경로를 잡는다.
func _test_desk_opens_the_workshop() -> void:
	print("[16] 책상 → 책 → [⚒ 부품 제작] → 공방 (재료→부품 사슬의 유일한 문)")
	var gs = root.get_node("/root/GameState")
	if _base.get("_forge") == null:
		_base.call(&"_open_drawing")
		await process_frame
	var forge = _base.get("_forge")
	if forge == null:
		_check(false, "책이 열렸다")
		return

	# ── ⓐ 버튼이 실재하고, 조립 단계에서 보인다 ──
	var btn := forge.get_node_or_null(^"Stage/Spread/CraftBtn") as Button
	_check(btn != null, "🔴 책에 [⚒ 부품 제작] 버튼이 있다")
	if btn == null:
		return
	_check(btn.visible, "조립 단계에서 버튼이 보인다 (숨어 있으면 문이 없는 것과 같다)")

	# ── ⓑ 🔴 버튼을 **실제로 눌러** 공방이 열린다 (시그널→무대 연결이 살아 있나) ──
	btn.emit_signal(&"pressed")
	await process_frame
	var shop = _base.get("_workshop")
	_check(shop != null, "🔴 버튼 한 번에 공방이 열린다 (연결이 빠지면 아무 일도 안 난다 — 에러 0)")
	if shop == null:
		return
	_check(bool(shop.call(&"is_open")), "공방 패널이 실제로 보이는 상태다")

	# ── ⓒ 공방이 레시피를 들고 있다 = 다섯이 실제로 배울 수 있다 ──
	var db = root.get_node("/root/Db")
	var learnable := {}
	for r in db.call(&"all_recipes"):
		if r.reward_unlock != &"":
			learnable[r.reward_unlock] = true
	for want in [&"rune_bolt", &"rune_earth", &"jin_plain_g2", &"jin_fuse", &"gr_condense2"]:
		_check(learnable.has(want),
			"🔴 %s가 공방에서 배울 수 있다 (세97 이전엔 경로가 이것뿐인데 문이 닫혀 있었다)" % want)

	# ── ⓓ 🔴 닫아도 책이 살아 있고 모달이 풀리지 않는다 ──
	# 공방의 close()가 `ui_modal_open`을 내리는데, 책이 아직 열려 있으므로 무대가 되세워야 한다.
	# 안 되세우면 [I]·[Tab]이 **책 위로 겹쳐** 열린다(에러 없이 화면만 깨진다).
	shop.call(&"close")
	await process_frame
	_check(_base.get("_workshop") == null, "공방을 닫으면 정리된다")
	_check(_base.get("_forge") != null, "🔴 공방을 닫아도 책은 그대로 열려 있다 (조립하던 자리로 복귀)")
	_check(bool(gs.ui_modal_open),
		"🔴 공방을 닫아도 모달 플래그가 살아 있다 (풀리면 [I]·[Tab]이 책 위로 겹친다)")
	_base.call(&"_close_drawing")
	await process_frame


## [17] 🔴 문 [E]가 「고르는 화면」 없이 바로 첫 챕터로 보낸다.
## 🔴 재는 것 넷 — 전부 에러 0으로 조용히 깨진다:
##   ⓐ `pending_chapter`가 첫 챕터로 채워진다(비면 `boss_room`이 마을로 되돌려 「무반응」이 된다).
##      🔴 값을 하드코딩하지 않고 `Db.chapters_sorted()[0]`에서 파생시킨다.
##   ⓑ 🔴 **전환이 실제로 걸린다** — 여기가 심장이다. 「패널이 없다」만 재면 출발이 죽어도 그린이다.
##   ⓒ 모달이 안 뜬다(챕터 선택이 되살아나면 잡힌다) ⓓ 챕터가 0장이면 나가지 않고 **말한다**.
func _test_gate_departs_without_choosing() -> void:
	print("[17] 🔴 문 [E] = 챕터 선택 없이 바로 첫 챕터 (세112 1d)")
	var gs = root.get_node("/root/GameState")
	var db = root.get_node("/root/Db")
	var gate = _zone(&"forest_gate")
	if gate == null:
		_check(false, "숲길(zone_id=forest_gate)을 못 찾았다")
		return
	var chapters: Array = db.call(&"chapters_sorted")
	if chapters.is_empty():
		_check(false, "전제 실패: 챕터가 0장이다 (data/chapters/*.tres 침묵사?)")
		return
	var first: StringName = chapters[0].id

	gs.ui_modal_open = false
	gs.pending_chapter = &""
	var real_room: String = _arm_departure_stub()

	# 🔴 정산이 끼면 대사 갈래로 새므로([12]가 그쪽을 잰다) **정산 대기가 없는 상태**에서 누른다.
	_check(not gs.has_claimable_quest(), "전제: 정산 대기가 없다 (있으면 대사 갈래다 = [12] 소관)")
	gate.interacted.emit()

	# ⓐ 대입은 **같은 프레임에** 끝난다 (전환만 프레임 끝으로 미뤄진다).
	_check(StringName(gs.pending_chapter) == first,
		"🔴🔴 pending_chapter가 첫 챕터(%s)로 채워진다 (실제 %s — 비면 boss_room이 도로 마을로 보낸다)"
			% [first, gs.pending_chapter])
	# ⓒ 고르는 화면이 안 뜬다 — 되살아나면 모달 플래그가 켜진다.
	_check(not gs.ui_modal_open,
		"🔴 고르는 화면이 안 뜬다 (모달 %s — 켜졌으면 챕터 선택이 되살아난 것이다)" % gs.ui_modal_open)
	_check(_base.get("_dialogue") == null, "대사도 안 뜬다 (정산 대기가 없으므로)")
		# ⓑ 🔴 전환이 실제로 걸린다 — 여기가 이 항목의 심장이다.
	_check(await _departed(),
		"🔴🔴 문 [E]가 **실제로 씬을 바꾼다** (대입만 하고 전환을 잃으면 마을에 갇힌다)")
	_clear_departure()

	# ── ⓓ 🔴 챕터가 0장이면 나가지 않고 「말한다」 ──
	#  빈 `pending_chapter`로 나가면 `boss_room`이 마을로 되돌려 **무반응과 화면상 구별이 안 되고**,
	#  침묵하면 「[E]가 죽었다」와도 구별이 안 된다. ⚠ `Db.chapters`는 전역이라 비운 뒤 **즉시 되돌린다**.
	var saved: Dictionary = (db.chapters as Dictionary).duplicate()
	var hud = _base.get("_hud")
	if hud != null:
		hud.call(&"say", "")   # 앞 안내를 지우고 시작한다 (남은 줄을 새 경고로 오독하지 않게)
	gs.pending_chapter = &""
	(db.chapters as Dictionary).clear()
	gate.interacted.emit()
	var line: String = str(hud.call(&"say_line")) if hud != null else ""
	for k in saved:
		(db.chapters as Dictionary)[k] = saved[k]   # 🔴 즉시 원상복구
	var went_nowhere: bool = not await _departed()
	_check(String(gs.pending_chapter) == "",
		"🔴 챕터가 0장이면 `pending_chapter`를 안 채운다 (실제 %s)" % gs.pending_chapter)
	_check(went_nowhere,
		"🔴🔴 챕터가 0장이면 **안 나간다** (빈 채 나가면 boss_room이 도로 마을로 보내 「무반응」과 구별이 안 된다)")
	_check(line != "",
		"🔴🔴 그리고 **이유를 말한다** — 침묵하면 「[E]가 죽었다」와 구별이 안 된다 (실제 안내 %s)"
			% ("(없음)" if line == "" else "「%s」" % line))

	_disarm_departure_stub(real_room)
	await process_frame


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
