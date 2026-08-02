extends SceneTree
## 씬 배선 그물 — 🔴🔴 **이 그물이 없으면 연출을 통째로 지워도 전 스위트가 그린이다**(리뷰 MF4 실증).
##
## 🔴 **이 리포의 어떤 그물도 `.tscn`을 세우지 않았다.** 전부 스크립트만 preload해서 순수 객체를
##  돌린다 — 그 덕에 시뮬은 촘촘히 덮였지만 **껍데기·씬·입력은 통째로 무보호였다.**
##  ⇒ 여기가 재는 것은 「값이 맞나」가 아니라 **「연결돼 있나」**다.
##
## ⚠ B2가 이 확인을 일회성 스크립트로 한 번 하고 **지웠다.** 검증이 실재했는데 안 남았다 —
##  SKILL.md T7/T2가 정확히 그 자리다. 이 파일이 그 스크립트를 안 늙게 남긴 것이다.
##
## 🔴🔴 **헤드리스 뷰포트는 960×540이 아니다**(창이 없어 stretch가 다르게 잡힌다).
##  ⇒ 캔버스 변환 origin이 실게임(항등)과 다르다. **기대값을 숫자로 박지 말고
##   `get_canvas_transform()`에서 파생해라.** 박으면 그물이 실게임과 갈라진다.

const SCENE := "res://src/sandbox/liquid_sandbox.tscn"
const Tuning := preload("res://src/world/spell/spell_tuning.gd")
const CellRenderer := preload("res://src/world/cells/cell_renderer.gd")
const SpellSim := preload("res://src/world/spell/spell_sim.gd")

## 발사 원점 바로 아래 4셀 두께 돌 슬래브가 있다(맵 29행). 🔴 **아래로 쏘면 반드시 맞는다** —
##  클릭으로 쏘면 조준이 격자 밖으로 나가 「안 터졌다」가 되고 그물이 헛빨강을 낸다.
const FIRE_DOWN := Vector2i(0, 32)

var _pass := 0
var _fail := 0
var _cmds: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  ok  %s  %s" % [label, detail])
	else:
		_fail += 1
		print("FAIL: %s  %s" % [label, detail])


## 🔴 `push_input(ev, true)`의 `true` = **뷰포트 로컬 좌표**다. 빼면 창 stretch가 곱해져
##  클릭이 화면 밖으로 나가고, 그러면 이 그물이 **아무것도 안 재면서 초록으로 통과한다**(T2).
func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		root.push_input(ev, true)


## 🔴🔴 **뒤를 막아야 하는 Control은 여기 등록해라 — 이유와 함께.**
##  키 = 씬 루트 기준 노드 경로 · 값 = **왜 STOP이어야 하는가.**
##
## ⚠ **지금 비어 있고, 비어 있는 게 정답인 상태다** — 이 프로토타입은 전부 마우스로 돈다.
## 🔴 **여기에 이름을 올리는 건 「좌클릭이 저 영역에서 죽어도 된다」는 선언이다.** 이유를 한 줄로
##  못 적겠으면 그건 STOP이 아니라 IGNORE여야 한다는 뜻이다.
## 🔴 **범위를 좁혀서 통과시키지 마라** — 없는 미래(모달)를 위해 지금 있는 구멍을 남기는 게 T7이다.
##  모달이 생기는 날 이 그물이 빨개지는 건 **옳다.** 그때 여기 한 줄을 적어라.
const MOUSE_FILTER_ALLOWED: Dictionary = {}


## 씬 안의 모든 `Control` → `mouse_filter`. 경로는 **씬 루트 기준**이다.
func _collect_filters(scene_root: Node, n: Node, out: Dictionary) -> void:
	if n is Control:
		out[String(scene_root.get_path_to(n))] = (n as Control).mouse_filter
	for ch: Node in n.get_children():
		_collect_filters(scene_root, ch, out)


func _offenders(filters: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	for path: String in filters:
		if MOUSE_FILTER_ALLOWED.has(path):
			continue
		if int(filters[path]) != Control.MOUSE_FILTER_IGNORE:
			bad.append("%s filter=%d" % [path, int(filters[path])])
	return bad


## 화면 원점이 지금 어디로 그려지고 있나 — **흔들림을 「프로퍼티」가 아니라 「화면」에서 잰다.**
func _screen_origin() -> Vector2:
	return root.get_canvas_transform() * Vector2.ZERO


## 🔴 **앞 그물이 쏜 마법이 다 착탄할 때까지 기다린다.** 안 기다리면 남은 폭발이 임의의 프레임에
##  흔들림을 다시 걸어서 「멎었나」 판정이 무작위로 빨개진다(실제로 밟았다 — 한 프레임 차이로 -1px).
func _settle(node: Node) -> void:
	var view: Node2D = node.get_node("SpellView")
	var fx: Node2D = node.get_node("BlastFx")
	for _i in 300:
		await process_frame
		if view.trail_count() == 0 and fx.active_count() == 0 and fx.shake_amp_px() == 0:
			# 껍데기 `_process`가 0이 된 offset을 카메라에 옮길 한 프레임을 더 준다.
			await process_frame
			return


## 지금 떠 있는 연출 중 가장 큰 섬광 반경.
## 🔴 **총구와 폭발을 가르는 유일한 관측값이다** — 둘 다 같은 배열에 앉기 때문이다.
##  총구는 `MUZZLE_SCALE`이 곱해져 있어 **폭발의 최소 반경보다도 작다.**
func _max_flash(fx: Node2D) -> float:
	var m := 0.0
	for i in fx.active_count():
		m = maxf(m, fx.flash_radius(i))
	return m


func _run() -> void:
	var node: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(node)
	await process_frame
	await process_frame

	await _net1_nodes_exist(node)
	await _net2_click_reaches_fire(node)
	await _net3_click_maps_to_world_cell(node)
	await _net4_blast_shakes_the_screen(node)
	await _net5_reset_clears_the_view(node)
	await _net6_alpha_is_pushed_every_frame(node)
	await _net7_hud_reference_is_derived(node)

	node.queue_free()
	await process_frame

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_WIRING_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_WIRING_FAIL — %d개 실패" % _fail)
		quit(1)


# ─── W1. 노드가 실제로 씬에 있나 ──────────────────────────────────
## 🔴 `.tscn`에서 하나만 빠지거나 이름이 바뀌면 `@onready`가 null이 되고, 배선 전체가
##  「에러는 나는데 아무도 안 보는」 상태가 된다. 여기가 유일한 감지기다.
func _net1_nodes_exist(node: Node) -> void:
	for p: String in [
		"Camera2D", "CellRenderer", "SpellView", "BlastFx", "SandboxInput", "HUD/Stats",
	]:
		_check("1 %s 존재" % p, node.has_node(p))
	# 카메라가 실제로 화면을 잡고 있나 — `enabled=false`거나 다른 카메라가 이기면 흔들림이 죽는다.
	var cam: Camera2D = node.get_node("Camera2D")
	_check("1b 카메라가 현재 카메라다", cam.is_current(), "아니면 offset을 흔들어도 화면이 안 움직인다")
	await process_frame


# ─── W2. 🔴🔴 좌클릭이 발사가 되나 = `mouse_filter` 함정의 자동 감지기 ─
## SKILL.md는 이 함정을 *"헤드리스가 절대 못 잡는다"*로 적었는데 **절반은 잡힌다** —
##  `Viewport.push_input(ev, true)`는 GUI 라우팅을 헤드리스에서도 그대로 돌린다.
##  ⚠ **정확히 하자**: 잡히는 건 「씬 안의 Control이 이벤트를 먹나」다.
##   「OS가 창에 클릭을 주나 · 창 스케일이 맞나 · 마우스가 진짜 거기 있나」는 여전히 실게임 전용이다.
##   **다만 이 리포에서 실제로 밟은 사고는 전부 전자였다.**
func _net2_click_reaches_fire(node: Node) -> void:
	var inp: Node = node.get_node("SandboxInput")
	inp.command_requested.connect(func(c: Dictionary) -> void: _cmds.append(c))

	# 🔴 한 점만 찍지 마라 — 화면 일부만 덮는 Control은 그 점을 피해 가면 안 잡힌다.
	var dead: Array[String] = []
	for at: Vector2 in [
		Vector2(120.0, 80.0), Vector2(480.0, 120.0), Vector2(840.0, 260.0),
		Vector2(200.0, 460.0), Vector2(700.0, 500.0),
	]:
		_cmds.clear()
		_click(at)
		await process_frame
		if _cmds.size() != 1 or not _cmds[0].has("spell_kind"):
			dead.append("%s→%d" % [str(at), _cmds.size()])
	_check("2 좌클릭 다섯 점이 전부 발사가 된다", dead.is_empty(),
		"먹힌 자리 %s — 화면을 덮는 Control이 STOP이면 여기가 0이 된다" % str(dead))

	# ═══ 🔴🔴 여기부터가 **설정하는 쪽과 재는 쪽을 가른 자리**다 ═══════
	#
	#  `sandbox_hud._force_ignore()`가 `_ready`에서 **HUD 아래 Control을 전부 IGNORE로 덮는다.**
	#  ⇒ 살아 있는 씬을 읽으면 `.tscn`에 STOP이라고 **적혀 있어도 IGNORE로 보인다**(실측:
	#   `HUD/Stats`를 `mouse_filter = 0`으로 바꿔도 트리에 넣으면 2로 읽힌다).
	#
	# 🔴 그래서 셋을 **따로** 잰다. 하나라도 빼면 그 갈래가 통째로 무보호가 된다:
	#   2b  **적힌 값**(트리 밖) — 덮이기 전. `.tscn`의 mouse_filter가 거짓 손잡이가 되는 걸 막는다
	#   2c  **사는 값**(트리 안) — 덮인 뒤. 런타임에 붙거나 HUD 밖에 붙은 Control을 잡는다
	#   2d  **둘이 같은가** — 다르면 덮개가 **적힌 실수를 가리고 있다는 뜻**이다(T2)
	var live: Dictionary = {}
	_collect_filters(node, node, live)
	_check("2c 살아 있는 씬의 모든 Control이 IGNORE다", _offenders(live).is_empty(),
		"%s — 런타임에 붙었거나 HUD 밖이라 덮개가 못 닿는 자리다" % str(_offenders(live)))

	# 🔴 **트리에 넣지 않는다.** `_ready`는 트리에 들어갈 때 도는 것이라, 여기서는 `.tscn`에
	#  적힌 값이 그대로다. `_force_ignore`가 덮기 **전**을 보는 유일한 방법이다.
	var probe: Node = (load(SCENE) as PackedScene).instantiate()
	var authored: Dictionary = {}
	_collect_filters(probe, probe, authored)
	probe.free()
	_check("2b .tscn에 적힌 mouse_filter가 전부 IGNORE다", _offenders(authored).is_empty(),
		"%s — 덮개가 지금은 고쳐주지만, 덮개가 닿지 않는 곳으로 옮기는 순간 발사가 죽는다"
		% str(_offenders(authored)))

	var masked: Array[String] = []
	for path: String in authored:
		if live.has(path) and int(authored[path]) != int(live[path]):
			masked.append("%s: 적힘 %d → 삶 %d" % [path, int(authored[path]), int(live[path])])
	_check("2d 덮개가 적힌 실수를 가리고 있지 않다", masked.is_empty(),
		"%s — 이 차이가 있는 한 .tscn의 mouse_filter는 아무 의미가 없는 거짓 손잡이다" % str(masked))


# ─── W3. 🔴 카메라가 `_to_cell()`을 틀어뜨리는 자리 ───────────────
## B2가 실제로 밟고 고친 버그다. 🔴 **되돌려도 아무 그물이 안 빨개졌다**(리뷰 MF3).
## ⚠ **흔들리지 않을 때는 변환이 항등이라 버그가 안 보인다** — offset을 강제로 넣어야 드러난다.
##  ⇒ 껍데기 `_process`가 매 프레임 offset을 덮으므로 **껍데기 process를 꺼야** 잰다.
func _net3_click_maps_to_world_cell(node: Node) -> void:
	var inp: Node = node.get_node("SandboxInput")
	var cam: Camera2D = node.get_node("Camera2D")
	node.set_process(false)
	var org: Vector2i = inp.fire_origin
	var at := Vector2(400.0, 200.0)
	for off: Vector2 in [Vector2.ZERO, Vector2(40.0, 0.0), Vector2(0.0, -12.0), Vector2(-24.0, 20.0)]:
		cam.offset = off
		await process_frame
		_cmds.clear()
		_click(at)
		await process_frame
		if _cmds.is_empty():
			_check("3 offset%s 클릭이 닿는다" % str(off), false, "커맨드 0개")
			continue
		# 🔴 기대값을 숫자로 박지 마라 — 헤드리스 뷰포트가 실게임과 달라서 origin이 다르다.
		var w := root.get_canvas_transform().affine_inverse() * at
		var want := Vector2i(floori(w.x / CellRenderer.CELL_PX), floori(w.y / CellRenderer.CELL_PX))
		var got := Vector2i(org.x + int(_cmds[0]["adx"]), org.y + int(_cmds[0]["ady"]))
		_check("3 offset%s 클릭이 월드 셀로 간다" % str(off), got == want,
			"%s (기대 %s)" % [str(got), str(want)])
	cam.offset = Vector2.ZERO
	node.set_process(true)
	await process_frame


# ─── W4. 🔴🔴 폭발 → BlastFx → 카메라 → **화면**까지 사슬이 도나 ──
## 리뷰 MF4: `_note_blasts`의 `add_blast` 루프를 지우면 **섬광·스파크·흔들림이 영원히 안 뜨는데**
##  전 스위트가 그린이었다. B2 작업의 절반이 무보호였다는 뜻이다.
## ⚠ **`Camera2D.offset` 프로퍼티를 읽는 것으로는 부족하다** — 그건 사슬의 중간이다.
##  화면 원점이 실제로 움직였는지를 재야 「카메라가 현재 카메라가 아니다」까지 같이 잡힌다.
func _net4_blast_shakes_the_screen(node: Node) -> void:
	var fx: Node2D = node.get_node("BlastFx")
	var last := Tuning.FX_TIERS.size() - 1
	var amp := float(int(Tuning.FX_TIERS[last]["shake_px"]))
	await _settle(node)
	var base := _screen_origin()

	# ① 직접 걸었을 때 — FX → 카메라 → 화면.
	fx.add_blast(Vector2(400.0, 200.0), last, Tuning.ELEM_BOLT)
	var moved := 0
	var worst := 0.0
	for _i in 20:
		await process_frame
		var d := (_screen_origin() - base).length()
		worst = maxf(worst, d)
		if d > 0.5:
			moved += 1
	# ⚠ `== amp`로 재지 마라 — 각도 난수 + 감쇠 + 한 프레임 지연이라 관측 피크는 늘 amp보다 작다.
	_check("4 폭발 연출이 화면을 실제로 흔든다", moved > 0 and worst <= amp + 0.5,
		"움직인 프레임 %d/20 · 최대 %.1fpx (진폭 %d)" % [moved, worst, int(amp)])
	await _settle(node)
	_check("4b 흔들림이 멎으면 화면이 제자리로", (_screen_origin() - base).length() < 0.5,
		str(_screen_origin() - base))

	# ② 🔴🔴 **껍데기가 실제로 걸어주나** — MF4(`_note_blasts`의 `add_blast` 루프 제거)가 사는 자리다.
	#  ⚠ **`active_count() > 0`으로 재면 안 된다** — 총구 섬광이 같은 배열에 앉아서, `add_blast`가
	#   통째로 죽어도 발사만으로 1개가 뜬다. **반경으로 갈라야** 한다(`_max_flash` 주석).
	var view: Node2D = node.get_node("SpellView")
	var muzzle_ceiling := float(int(Tuning.FX_TIERS[last]["flash_px"])) * Tuning.MUZZLE_SCALE
	var seen_trail := 0
	var big := 0.0
	var streaked := false
	node.enqueue(SpellSim.cmd_fire(40, 108, FIRE_DOWN.x, FIRE_DOWN.y, last, Tuning.ELEM_BOLT))
	for _i in 60:
		await process_frame
		seen_trail = maxi(seen_trail, view.trail_count())
		big = maxf(big, _max_flash(fx))
		# 🔴 착탄 줄기의 시작점이 실려 왔나 — 껍데기가 `_view.last_trail_px()`를 꺼내 넘기고,
		#  그러려면 `_note_blasts`가 `_view.on_tick()`보다 **앞**이어야 한다(순서 계약).
		for i in fx.active_count():
			if fx.flash_radius(i) > muzzle_ceiling and fx.streak_from(i).is_finite():
				streaked = true
	_check("4c 발사가 자취를 만든다", seen_trail > 0,
		"자취 최대 %d — 0이면 껍데기가 `_view.on_tick()`을 안 부른다" % seen_trail)
	_check("4d 폭발이 껍데기를 거쳐 연출이 된다", big > muzzle_ceiling + 0.5,
		"최대 섬광 %.1fpx (총구 상한 %.1f) — 넘지 못하면 `_note_blasts`가 `add_blast`를 안 부른다"
		% [big, muzzle_ceiling])
	_check("4e 착탄 줄기의 시작점이 실려 온다", streaked,
		"안 실리면 탄이 벽 직전에 사라지고 그 앞쪽에서 터진다 — `_note_blasts`가 `on_tick` 뒤로 가면 이렇게 된다")


# ─── W5. 초기화가 뷰까지 비우나 ───────────────────────────────────
## 🔴 `_spell.reset()`은 id를 0부터 다시 준다. 뷰를 안 비우면 **없는 투사체의 옛 자취가**
##  새 투사체에 붙는다 — 에러 없이 화면만 이상해진다.
func _net5_reset_clears_the_view(node: Node) -> void:
	var view: Node2D = node.get_node("SpellView")
	var fx: Node2D = node.get_node("BlastFx")
	await _settle(node)
	node.enqueue(SpellSim.cmd_fire(40, 108, FIRE_DOWN.x, FIRE_DOWN.y, 0, Tuning.ELEM_WATER))
	for _i in 4:
		await process_frame
	fx.add_blast(Vector2(400.0, 200.0), Tuning.FX_TIERS.size() - 1, Tuning.ELEM_BOLT)
	_check("5 초기화 전에 실제로 무언가 있다",
		view.trail_count() > 0 or fx.active_count() > 0,
		"자취 %d · 연출 %d" % [view.trail_count(), fx.active_count()])
	node.get_node("SandboxInput").reset_requested.emit()
	await process_frame
	_check("5b 초기화가 자취·연출을 비운다",
		view.trail_count() == 0 and fx.active_count() == 0,
		"자취 %d · 연출 %d" % [view.trail_count(), fx.active_count()])


# ─── W6. 🔴 보간 알파가 **매 프레임** 밀려 들어오나 ────────────────
## `test_spell_fx_auto.gd`의 X6은 알파를 **손으로 넣어** 끝점을 잰다 — 그래서 껍데기가 알파를
##  아예 안 밀어도(=늘 0) 초록이다. 그러면 20Hz 시뮬이 60fps에서 **틱당 40px씩 순간이동한다.**
## ⇒ 여기가 재는 것은 「값이 맞나」가 아니라 **「프레임마다 갱신되나」**다.
##  ⚠ 틱 하나 = 3프레임이므로, 보간이 없으면 9프레임에 서로 다른 위치가 **3개**만 나온다.
func _net6_alpha_is_pushed_every_frame(node: Node) -> void:
	var view: Node2D = node.get_node("SpellView")
	await _settle(node)
	# 아래는 금방 맞으니 옆으로 길게 쏜다 — 9프레임 동안 살아 있어야 잰다.
	node.enqueue(SpellSim.cmd_fire(40, 60, 1, 0, 0, Tuning.ELEM_BOLT))
	for _i in 4:
		await process_frame
	var seen: Array[Vector2] = []
	for _i in 9:
		await process_frame
		if view.trail_count() == 0:
			break
		var p: Vector2 = view.head_px(0)
		if not seen.has(p):
			seen.append(p)
	_check("6 보간이 프레임마다 갱신된다", seen.size() >= 6,
		"9프레임에 서로 다른 위치 %d개 — 3개면 껍데기가 알파를 안 민다(틱당 40px 순간이동)"
		% seen.size())


# ─── W7. 🔴 HUD의 기준값이 표에서 **파생**되나 ────────────────────
## HUD가 「파괴 N칸」 옆에 찍는 기준값(P1 113 · P2 441 · …)은 `SIM_TIERS`의 `rd`에서 완전히
##  파생되는 값이다. **문자열에 박으면 `rd`를 조이는 순간 옛 숫자로 조용히 거짓말한다** —
##  하필 이 줄의 유일한 존재 이유가 「사용자가 화면과 숫자를 대조하는 것」이라 낡으면 독이 된다(T5).
## ⚠ 이 그물은 **「지금 값이 맞나」가 아니라 「표를 따라 움직이나」**를 잰다 — `rd`를 바꿔도
##  HUD가 안 따라오면 여기가 빨개진다. 박아 둔 상태로 `rd`만 바꾸면 그게 정확히 그 실패다.
func _net7_hud_reference_is_derived(node: Node) -> void:
	var hud: Label = node.get_node("HUD/Stats")
	# HUD는 20틱 주기의 특정 위상에서만 갱신된다 — 넉넉히 돌린다.
	for _i in 90:
		await process_frame
		if hud.text.contains("↳"):
			break
	var missing: Array[String] = []
	for t in Tuning.SIM_TIERS.size():
		var r := int(Tuning.SIM_TIERS[t]["rd"])
		var n := 0
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					n += 1
		if not hud.text.contains("P%d %d" % [t + 1, n]):
			missing.append("P%d 기대 %d칸" % [t + 1, n])
	_check("7 HUD 기준값이 SIM_TIERS에서 파생된다", missing.is_empty(),
		"%s — 안 맞으면 HUD가 옛 숫자로 거짓말하고 사용자는 그걸 시뮬 버그로 읽는다" % str(missing))
