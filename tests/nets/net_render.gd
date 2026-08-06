extends RefCounted
## 화면 쪽이 **설 수 있나.** 🔴 그물이 원리적으로 못 재는 「그려진 그림」이 아니라,
## **그리기도 전에 죽는 것**을 잰다.
##
## 🔴🔴 **왜 생겼나 — 실측이다.**
##  단계 5에서 `flag_tex` uniform을 추가하며 sampler를 함수 인자로 넘겼더니
##  (`l8_to_int(TEXTURE, …)`와 `l8_to_int(flag_tex, …)`) Godot 셰이더 컴파일러가
##  「같은 sampler 인자를 내장과 uniform 양쪽으로 부를 수 없다」며 **컴파일에 실패했다.**
##  그런데 **게임은 안 멈췄다** — 격자가 L8 원본 바이트값(돌 1 · 나무 2 · 빈칸 0)으로 그려져
##  거의 검은 화면이 됐고, `_draw()`로 그리는 캐릭터만 제 색으로 떠 있었다.
##  **그 상태에서 그물 534개가 전부 초록이었다.**
##
## ⇒ 이 리포의 대표 침묵사(「그물은 초록인데 화면이 안 뜬다」)가 정확히 그 모양이다.
##  셰이더는 **엔진이 조용히 포기하는 유일한 자산**이라 따로 잴 값어치가 있다.

const VIEW_DIR := "res://src/view"
const STAGE_SCENE := "res://src/stage/stage.tscn"
const STAGE_SCRIPT := "res://src/stage/stage.gd"
const STAGE_INPUT_SCRIPT := "res://src/stage/stage_input.gd"
const CIRCLE_WINDOW_SCRIPT := "res://src/view/circle_window.gd"
## 🔴 주석·문자열 스트리퍼를 **빌려 온다** — 소스 텍스트를 훑는 그물이 셋이라 스트리퍼는 하나여야 한다.
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## HUD의 `CanvasLayer`. 🔴 **좌클릭이 발사로 가느냐가 갈리는 층이 정확히 여기다.**
const HUD_PATH := "HUD"

## 🔴🔴 **클릭을 먹어도 되는 노드.** 여기 없는 `Control`이 `STOP`이면 좌클릭이 조용히 죽는다.
##  ⚠ **목록을 손으로 드는 것이 곧 계약이다.** 새 창을 붙이면서 여기 안 적으면 그물이 먼저 짖고,
##   적으면 「이건 일부러 먹는다」가 리포에 남는다. 자동으로 알아내면 그 선언이 사라진다.
const INTERACTIVE: Array[String] = ["HUD/CircleWindow"]

## ⚠ **옛 `WINDOW_SCREEN_FRAC`(각 축 90%)은 지웠다.** 계약이 크기였던 적이 없다 —
##  「캐릭터와 그 주변이 보인다」가 계약이고 90%는 그때 그걸 **유예**한 값이었다.
##  🔴 캐릭터가 다칠 수 있게 되면서 유예가 끝났다(사용자 판정, 2026-08-04) ⇒
##   아래 `_window_does_not_cover_*` 가 **덮나 안 덮나**를 잰다.
const Character := preload("res://src/actor/character.gd")
const Stage := preload("res://src/stage/stage.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")


func run(t) -> void:
	var shaders := _scan_shaders(VIEW_DIR)
	# 🔴 폴더 스캔 그물의 첫 줄. 빈 목록을 훑으면 아래가 하나도 안 돌고 초록으로 통과한다.
	t.ok(shaders.size() > 0, "%s 에서 셰이더를 찾았다 (%d개)" % [VIEW_DIR, shaders.size()])
	for path: String in shaders:
		_compiles(t, path)
	_injection_matches_shader(t)
	_palette_size_matches(t)
	_onready_paths_resolve(t)
	_mouse_filter_contract(t)
	_window_uses_the_tuning_rect(t)
	_input_actions_exist(t)
	_hud_counts_are_throttled(t)


## 🔴🔴 **입력 맵에 없는 액션을 부르면 엔진이 짖고, 화면에서는 「그 키만 안 먹는다」로만 보인다.**
##
## ⚠ **`has_action`만으로는 「Tab이 안 먹는다」를 못 지운다** — 실측이다:
##  액션에서 **키 바인딩만 비워도**(`events: []`) `has_action`은 여전히 참이고 그물이 전부 초록이었다.
##  ⇒ **이름이 있나**와 **키가 붙어 있나**를 **둘 다** 재야 그 원인 하나가 지워진다.
##
## 🔴 나머지 원인(포커스)은 여기가 아니라 `_mouse_filter_contract`가 `focus_mode`로 잰다.
##  ⚠ **둘을 다 재기 전에는 「이 검사가 원인 하나를 지운다」고 적지 마라** — 거짓 보증은
##   없느니만 못하다. 다음 세션이 그 문장을 읽고 진단을 반대 방향으로 판다.
##
## ⚠ 이름을 손으로 적지 않고 **소스에서 뽑는다.** 적으면 액션을 늘릴 때 조용히 낡는다.
## ⚠ 주석 안에 `is_action_pressed("...")` 꼴을 적으면 그것도 요구로 잡힌다 —
##  거짓 양성이지만 **빨갛게** 틀리므로 조용히 새지는 않는다.
func _input_actions_exist(t) -> void:
	var src := _read(STAGE_INPUT_SCRIPT)
	var wanted: Dictionary = {}
	for pattern: String in [
		"is_action[a-z_]*\\(\\s*\"([A-Za-z0-9_]+)\"",
		"get_axis\\(\\s*\"([A-Za-z0-9_]+)\"\\s*,\\s*\"([A-Za-z0-9_]+)\"",
	]:
		var re := RegEx.new()
		t.eq(re.compile(pattern), OK, "액션 패턴이 컴파일된다")
		for m: RegExMatch in re.search_all(src):
			for g in range(1, m.get_group_count() + 1):
				var nm := m.get_string(g)
				if nm != "":
					wanted[nm] = true
	# 🔴 하나도 못 찾으면 아래가 안 돌고 **초록이 된다.**
	t.ok(wanted.size() > 0, "껍데기가 부르는 입력 액션을 찾았다 (%d개)" % wanted.size())
	for nm: String in wanted.keys():
		t.ok(InputMap.has_action(nm), "입력 맵에 액션 `%s` 가 있다" % nm)
		# 🔴 이름만 있고 키가 안 붙은 액션은 **영원히 안 눌린다.** 위 `has_action`은 참이다.
		t.ok(InputMap.action_get_events(nm).size() > 0,
			"액션 `%s` 에 키가 붙어 있다 (이름만 있으면 영영 안 눌린다)" % nm)


## 🔴🔴 **이 껍데기가 죽는 1번 방식이다**(`stage.gd`가 스스로 적어 둔 것).
##  발사가 좌클릭인데 HUD가 `Control`이다 — 뒷판 하나를 기본값(`STOP`)으로 씌우는 순간
##  **좌클릭이 통째로 먹히고, 에러는 안 나고 전 그물이 초록이다.**
##
## ⚠ **양쪽이 다 위험하다:**
##  · 전부 `STOP`   → 발사가 죽는다. 화면은 멀쩡해 보인다
##  · 전부 `IGNORE` → **창을 클릭할 때마다 마법이 나간다**
##
## 🔴 그래서 한 방향만 재면 안 된다 — 아래는 **둘 다** 잰다:
##  선언 안 된 `Control`은 `IGNORE`여야 하고, 선언된 것은 `STOP`이어야 한다.
##
## ⚠ **HUD의 직계 자식만 본다. 그 근거를 정확히 적어 둔다:**
##  · `CircleWindow`의 자식은 **이미 상호작용 영역 안**이라 어느 값이든 발사에 안 닿는다 —
##    재귀로 훑으면 단계 3~5(층·룬 자리·팔레트)에서 거짓 경보만 는다
##  · **다른 HUD 자식의 자식은 아직 하나도 없다.** ⇒ 지금은 구멍이 아니다
##
## 🔴🔴 **다만 「부모가 IGNORE면 자식도 IGNORE」는 거짓이다.** `mouse_filter`는 안 물려받는다.
##  `HUD/Stats`(8,8~900,210) 아래에 크기 있는 `STOP` 자식이 생기면 **왼쪽 위 클릭이 통째로 죽고**
##  이 검사는 그걸 **못 본다.** ⇒ 그런 자식을 만드는 날 이 함수를 재귀로 열어라.
func _mouse_filter_contract(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	if scene == null or not scene.can_instantiate():
		# 🔴🔴 위와 같은 이유 — 조용히 빠져나가면 `mouse_filter` 계약이 **한 줄도 안 재진다.**
		t.ok(false, "무대 씬을 못 세워서 mouse_filter 계약을 **하나도 못 쟀다**")
		return
	var root := scene.instantiate()
	var hud := root.get_node_or_null(HUD_PATH)
	t.ok(hud != null, "씬에 %s 가 있다" % HUD_PATH)
	if hud == null:
		root.free()
		return

	# 🔴 폴더 스캔 그물의 첫 줄과 같은 이유 — 자식이 0이면 아래가 하나도 안 돌고 초록이 된다.
	var seen := 0
	for child in hud.get_children():
		if not (child is Control):
			continue
		seen += 1
		var ctl := child as Control
		var path := "%s/%s" % [HUD_PATH, ctl.name]
		if INTERACTIVE.has(path):
			t.eq(ctl.mouse_filter, Control.MOUSE_FILTER_STOP,
				"%s 는 클릭을 먹는다 (STOP — 여기 클릭은 발사가 아니다)" % path)
		else:
			t.eq(ctl.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s 는 클릭을 통과시킨다 (IGNORE — 좌클릭이 발사로 간다)" % path)
	t.ok(seen > 0, "%s 아래 Control이 있다 (%d개)" % [HUD_PATH, seen])
	# ⚠ 선언이 비면 위 루프가 「전부 IGNORE여야 한다」만 재고, 그러면 **창이 사라져도 초록이다.**
	t.ok(INTERACTIVE.size() > 0, "클릭을 먹는 노드가 선언돼 있다 (%d개)" % INTERACTIVE.size())
	for path: String in INTERACTIVE:
		t.ok(root.get_node_or_null(path) != null, "선언된 %s 가 씬에 실재한다" % path)

	# 🔴 창이 **닫힌 채로** 시작한다. 열린 채로 켜지면 첫 화면이 가려지고,
	#  그 상태를 사용자가 「창이 안 닫힌다」로 읽는다.
	var win := root.get_node_or_null("HUD/CircleWindow") as Control
	t.ok(win != null and not win.visible, "조립창이 닫힌 채로 시작한다")

	# 🔴🔴 **Tab이 안 먹는 두 번째 원인이 여기다.** 창 안 `Control`이 포커스를 잡으면
	#  Tab이 `ui_focus_next`로 **GUI에서 소비되어** `_unhandled_input`에 아예 안 온다.
	#  ⚠ 증상이 「입력 맵을 안 고쳤다」와 **똑같아서** 원인을 반대로 파기 쉽다 —
	#   그래서 입력 맵 쪽(`_input_actions_exist`)과 **둘 다** 재야 진단이 갈린다.
	#  ⚠ 실측: `focus_mode`를 ALL로 바꿔도 그물 50개가 전부 초록이었다.
	if win != null:
		t.eq(win.focus_mode, Control.FOCUS_NONE,
			"조립창이 포커스를 못 잡는다 (Tab이 GUI에 안 먹힌다)")

	_window_leaves_the_stage_visible(t, root)
	root.free()


## 🔴🔴 **창이 무대를 다 가리면 「세상이 안 멈춘다」를 눈으로 확인할 수가 없다**(계획 위험 11).
##  ⚠ 그리고 `HUD/Stats`와 겹치면 글씨가 섞인다(위험 12) — 둘 다 화면 문제라 **에러가 안 난다.**
## 🔴 치수의 단일 소스가 `fx_tuning`이므로 **그 값을 잰다.** 씬의 offset을 재면 두 곳이 된다.
func _window_leaves_the_stage_visible(t, root: Node) -> void:
	var r: Rect2 = Fx.WINDOW_RECT
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	t.ok(vw > 0.0 and vh > 0.0, "뷰포트 크기를 읽었다 (%dx%d)" % [int(vw), int(vh)])
	t.ok(r.size.x > 0.0 and r.size.y > 0.0, "조립창에 크기가 있다 (%dx%d)" % [
		int(r.size.x), int(r.size.y)])
	t.ok(r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= vw and r.end.y <= vh,
		"조립창이 화면 안에 들어간다 (%s ~ %s)" % [r.position, r.end])

	# 🔴🔴 **「창이 캐릭터를 안 가린다」 검사는 폐기됐다** — 아래 삭제 표시를 봐라.
	#  체력 쪽은 살아 있다: `HUD/Health` 는 `CanvasLayer` 위라 **창과 같은 화면 좌표계**이고,
	#  카메라가 어떻게 움직여도 자리가 안 바뀐다.
	_window_does_not_cover_the_health(t, root, r)

	# 🔴🔴 **90%면 `HUD/Stats`를 덮는다. 그게 안전한 이유는 창이 불투명해서다.**
	#  ⚠ 옛 검사는 「안 겹친다」였고 근거는 위험 12(「겹치면 글씨가 섞인다」)였는데,
	#   그 위험은 **반투명 창의 것**이다. 불투명 창은 섞지 않고 **가린다.**
	#  ⇒ 겹침을 금지하는 대신 **겹쳐도 되는 조건**을 잰다. 반투명으로 되돌리면 여기가 빨개진다.
	var stats := root.get_node_or_null("HUD/Stats") as Control
	t.ok(stats != null, "씬에 HUD/Stats 가 있다")
	t.eq(Fx.WINDOW_BG.a, 1.0, "창 배경이 불투명하다 (겹친 HUD 글씨가 안 섞인다)")


# ── 「창이 캐릭터를 안 가린다」 — **폐기됐다** ──────────────────────
# 🔴 **계약이 죽었다**(사용자 판정, 2026-08-04). 카메라 추종이 들어가며 캐릭터가 **항상 화면
#  한복판**에 오는데 창이 화면 90%라 그걸 덮는다. **사용자가 그 대가를 알고 「그대로 둔다」를 골랐다.**
#  ⇒ 없는 계약을 재는 검사는 가짜 그물이라 지웠다. 근거는 `fx_tuning.WINDOW_RECT` 주석에 있다.
#
# ⚠ **값으로 확인하고 지운 것이다.** 창 (48,12)~(912,384) vs 캐릭터 화면 자리:
#   스폰 (96,240)~(128,380) · 세상 한가운데 (464,146)~(496,286) — **둘 다 창 안**이다.
# 🔴 **검사가 틀린 게 아니라 계약이 죽은 것이다** — 대조군으로 창을 `Rect2(48,400,864,130)` 으로
#  옮기니 **초록**이었다. 검사는 멀쩡했다.
#
# 🔴🔴🔴 **그리고 이 검사는 지워지기 전까지 「거짓 초록」이었다. 그게 여기 남길 자산이다.**
#  옛 코드는 캐릭터의 **월드** 자리를 `WINDOW_RECT`(= `CanvasLayer` 위라 **화면** 좌표)와 맞댔다.
#  카메라가 항등일 때는 월드 = 화면이라 **우연히** 맞았고, **카메라가 움직이는 순간 두 좌표계가
#  갈라졌는데도 그물은 1328개가 전부 초록**이었다.
#  ⇒ **좌표계를 섞은 검사는 카메라가 움직이는 날 조용히 죽는다.** 화면 쪽 값을 월드 값과 맞대기
#   전에 이 줄을 읽어라.


## 🔴🔴 **창이 체력 표시를 안 덮는다.** `_toggle_assembly` 는 `HUD/Stats` 만 숨기고 `Health` 는
##  **숨는 게 아니라 덮인다** ⇒ 창이 그 자리를 비켜야 조립 중에도 체력이 보인다.
## ⚠ **크기를 먼저 재는 줄의 이유를 정확히 적는다** — 처음에 「크기가 0이면 `intersects` 가 늘
##  거짓이라 조용히 통과한다」고 적었는데 **그건 거짓이었다.** 실측(2026-08-04):
##  🔴 **`Rect2.intersects` 는 변끼리만 걸러서 퇴화 사각형이 안쪽에 있으면 `true` 를 준다** —
##   창 한복판의 크기 0 사각형은 **겹친 것으로 나온다.** 그리고 `Health` 는 `Label` 이라
##   크기가 최소 `(1,23)` 이라 **0을 만들 수도 없었다.**
##  ⇒ 이 줄이 실제로 잡는 것은 **「`Health` 가 크기를 잃었다」는 다른 결함**이고, 그건 여전히 값어치가 있다.
## 🔴 **「Rect2 는 크기 0이면 안 겹친다」로 읽지 마라** — 다른 데 그 전제로 검사를 짜면 거기가 헛돈다.
func _window_does_not_cover_the_health(t, root: Node, r: Rect2) -> void:
	var hp := root.get_node_or_null("HUD/Health") as Control
	t.ok(hp != null, "씬에 HUD/Health 가 있다")
	if hp == null:
		return
	t.ok(hp.visible, "체력 표시가 켜진 채로 시작한다")
	var box := Rect2(hp.position, hp.size)
	t.ok(box.size.x > 0.0 and box.size.y > 0.0,
		"체력 표시에 크기가 있다 (%dx%d — 0이면 아래 검사가 공짜로 통과한다)"
			% [int(box.size.x), int(box.size.y)])
	t.ok(not r.intersects(box),
		"조립창이 체력 표시(%s~%s)를 안 덮는다" % [box.position, box.end])


## 🔴🔴 **위 검사는 `Fx.WINDOW_RECT` 라는 상수만 잰다 — 창이 그걸 쓰는지는 안 본다.**
##  ⚠ 실측: 창이 `Rect2(0, 0, 10, 10)`을 쓰게 바꿔도 **전부 초록이었다.**
##   그러면 창이 10픽셀짜리 점이 되고 **클릭 영역도 거기로 간다** — 위 자리·넓이 검사가
##   재던 것이 통째로 거짓이 된다.
##
## ⇒ 실행으로는 못 잰다(창을 트리에 세워야 `_ready`가 돈다). **텍스트로 잰다** —
##  `net_circle._resize_is_table_driven`과 같은 이유·같은 장치다.
## 🔴 스트리퍼는 `net_determinism`의 것을 **빌려 쓴다.** 베끼면 두 벌이 되고 반드시 갈라진다.
func _window_uses_the_tuning_rect(t) -> void:
	var raw := _read(CIRCLE_WINDOW_SCRIPT)
	t.ok(not raw.contains("\"\"\""), "circle_window에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var src := NetDeterminism._strip(raw)
	t.ok(src.contains("WINDOW_RECT"), "창이 `Fx.WINDOW_RECT` 를 읽는다 (치수가 두 곳이 아니다)")
	# 🔴 반대쪽 — 숫자로 만든 `Rect2`가 있으면 그게 곧 두 번째 치수다.
	#  ⚠ `Rect2(Vector2.ZERO, size)` 처럼 **숫자로 시작 안 하는** 것은 안 문다.
	var re := RegEx.new()
	t.eq(re.compile("Rect2\\s*\\(\\s*[-.\\d]"), OK, "Rect2 숫자 패턴이 컴파일된다")
	t.ok(re.search(src) == null, "창이 숫자를 박은 Rect2를 안 만든다")


## 🔴🔴 **셰이더의 `palette[N]` 과 `Mat.SLOT_COUNT` 는 짝이다.**
##  ⚠ 실측: `palette[16]` 을 `palette[8]` 로 바꿔도 **580개가 전부 초록이고 stderr까지 깨끗하다.**
##   셰이더는 **정상 컴파일되고** `palette[mat_id]` 가 배열 밖을 읽는다 — GLSL에서 정의되지 않은
##   동작이라 **기계마다 다르게** 틀어진다. 짖는 사람이 아무도 없다.
##  🔴 `cell_materials.gd` 가 스스로 「셰이더의 `palette[16]` 과 같은 값이어야 한다」고 적어 뒀는데
##   그 문장을 지키는 코드가 없었다 — 주석이 계약을 대신할 수 없다는 표본이다.
func _palette_size_matches(t) -> void:
	var sh: Shader = load(CellRenderer.SHADER_PATH)
	if sh == null:
		return
	var re := RegEx.new()
	re.compile("uniform\\s+vec4\\s+palette\\s*\\[\\s*(\\d+)\\s*\\]")
	var m := re.search(sh.code)
	t.ok(m != null, "셰이더가 `palette[N]` 을 선언한다")
	if m == null:
		return
	t.eq(m.get_string(1).to_int(), Mat.SLOT_COUNT,
		"셰이더 팔레트 길이가 Mat.SLOT_COUNT와 같다")


## 🔴🔴 **`@onready var _x = $Path` 의 경로가 씬에 실재하나.**
##  ⚠ 노드 이름을 하나 바꾸면 게임은 `null` 참조로 죽는데 그물은 **파싱만 보므로 초록이다.**
##   씬은 지금까지 v1 경로 문자열 검사만 받고 있었다.
## ⚠ **여전히 못 잡는 것**: 함수 시그니처 불일치(예: `on_blasts` 인자 수)는 런타임 에러라
##  여기 안 걸린다. 씬을 세우기만 하고 **돌리지는 않는다.**
func _onready_paths_resolve(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세울 수 있다")
	if scene == null or not scene.can_instantiate():
		# 🔴🔴 **여기서 그냥 `return` 하면 검사가 「실패」가 아니라 통째로 사라진다** —
		#  통과 수만 줄고 **아무도 안 짖는다.** 「없어진 검사」는 「통과한 검사」와 로그에서 구별이 안 된다.
		t.ok(false, "무대 씬을 못 세워서 @onready 경로를 **하나도 못 쟀다**")
		return
	var root := scene.instantiate()
	var re := RegEx.new()
	re.compile("@onready\\s+var\\s+\\w+\\s*:[^=]+=\\s*\\$([A-Za-z0-9_/]+)")
	var found := 0
	for m: RegExMatch in re.search_all(_read(STAGE_SCRIPT)):
		found += 1
		t.ok(root.get_node_or_null(m.get_string(1)) != null,
			"씬에 `$%s` 가 있다" % m.get_string(1))
	t.ok(found > 0, "@onready 경로를 실제로 찾았다 (%d개)" % found)
	# ⚠ 트리 밖이라 `queue_free`가 아니라 `free`다.
	root.free()


## 🔴🔴 **`get_shader_uniform_list()`가 비면 컴파일 실패다.** 헤드리스에서 이 한 줄로 잡힌다.
##
## ⚠ 「비었나」가 아니라 **「선언한 수와 같나」**로 잰다. 「비었나」만 보면 uniform이 하나도 없는
##  셰이더가 늘 통과하고, 그때부터 이 검사는 그 파일에 대해 **영영 아무것도 안 재는 상태**가 된다.
func _compiles(t, path: String) -> void:
	var nm := path.get_file()
	var sh: Shader = load(path)
	t.ok(sh != null, "%s 를 읽는다" % nm)
	if sh == null:
		return
	var declared := _declared_uniforms(sh.code)
	t.ok(declared > 0, "%s 가 uniform을 선언한다 (%d개)" % [nm, declared])
	t.eq(sh.get_shader_uniform_list().size(), declared,
		"%s 가 컴파일된다 (uniform 목록이 선언과 일치한다)" % nm)


## 🔴🔴 **셰이더가 안 받는 이름으로 주입하면 아무 일도 안 일어난다 — 에러도 없다.**
##  팔레트를 넣었는데 이름이 한 글자 틀리면 화면이 마젠타도 아니고 그냥 검다.
## 🔴 반대쪽도 잰다: 선언만 하고 **아무도 안 넣는 uniform은 거짓 손잡이다**(CLAUDE.md).
func _injection_matches_shader(t) -> void:
	var sh: Shader = load(CellRenderer.SHADER_PATH)
	t.ok(sh != null, "렌더러가 가리키는 셰이더가 실재한다 (%s)" % CellRenderer.SHADER_PATH)
	if sh == null:
		return

	var declared: Dictionary = {}
	for u: Dictionary in sh.get_shader_uniform_list():
		declared[String(u["name"])] = true

	var src := _read("res://src/view/cell_renderer.gd")
	var re := RegEx.new()
	re.compile("set_shader_parameter\\s*\\(\\s*\"([A-Za-z0-9_]+)\"")
	var injected: Dictionary = {}
	for m: RegExMatch in re.search_all(src):
		injected[m.get_string(1)] = true
	t.ok(injected.size() > 0, "렌더러가 주입하는 이름을 찾았다 (%d개)" % injected.size())

	for nm: String in injected.keys():
		t.ok(declared.has(nm), "셰이더가 uniform `%s` 를 선언한다" % nm)
	for nm: String in declared.keys():
		t.ok(injected.has(nm), "uniform `%s` 에 주입하는 사람이 있다 (거짓 손잡이가 아니다)" % nm)


## 셰이더 코드에서 uniform 선언 수. ⚠ 줄 **첫머리**만 본다 — 주석에 「uniform」이라고 쓴 줄이
##  세지면 그 순간 이 검사가 조용히 헛돈다.
func _declared_uniforms(code: String) -> int:
	var n := 0
	for raw: String in code.split("\n"):
		if raw.strip_edges().begins_with("uniform "):
			n += 1
	return n


func _scan_shaders(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gdshader"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_scan_shaders(dir.path_join(sub)))
	out.sort()
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_render: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()


## 🔴🔴 **HUD의 재료 세기가 조여져 있나 — 그리고 조인 값이 따라잡나.**
##
## `count_material` 은 한 번에 **552μs**(4,128,768칸)이고 HUD가 셋을 센다. 매 프레임이면
## 60Hz × 3회 = **CPU의 9.9%** 다. ⚠ **에러도 화면 이상도 없이 그냥 사라지는 종류라**
## 아무도 안 짖는다 — 그래서 값으로 잰다.
##
## 🔴 **씬을 트리에 안 붙인다.** `_refresh_hud_counts()` 가 `@onready` 라벨을 하나도 안 만지도록
##  `_update_hud()` 에서 갈라져 있어서, **인스턴스만 만들어 직접 부를 수 있다.**
##  ⚠ 그래서 이 검사가 가능하다 — 안 갈랐으면 무대를 트리에 붙여야 했고 그건 이 리포가 안 하는 일이다.
##
## ⚠ **「조여졌나」만 재면 「영영 안 갱신」도 통과한다.** ⇒ **따라잡는 것을 같이 잰다.**
func _hud_counts_are_throttled(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	if scene == null or not scene.can_instantiate():
		# 🔴 조용히 `return` 하면 검사가 **없어진다** — 통과 수만 줄고 아무도 안 짖는다.
		t.ok(false, "무대 씬을 못 세워서 HUD 세기를 **하나도 못 쟀다**")
		return
	var root := scene.instantiate()
	var g: Variant = root.get("_grid")
	var ticks: Variant = root.get("HUD_COUNT_TICKS")
	t.ok(g != null and ticks is int, "껍데기가 `_grid` 와 `HUD_COUNT_TICKS` 를 든다")
	if g == null or not (ticks is int):
		root.free()
		return
	var period: int = ticks
	t.ok(period > 1, "세기 주기가 1보다 크다 (%d틱 — 1이면 조인 게 아니다)" % period)

	# 첫 호출은 곧바로 센다. ⚠ 안 그러면 사용자가 첫 1초 동안 0을 보고 「안 먹는다」로 읽는다.
	root.call("_refresh_hud_counts")
	t.eq(root.get("_stone_cells"), 0, "빈 격자에서 돌이 0이다 (기준선)")

	# 지형을 깐다. 🔴 **같은 틱에 다시 부르면 값이 안 바뀌어야 한다** — 그게 「조였다」의 뜻이다.
	g.call("apply", CellGrid.cmd_fill(0, 0, 99, 99, Mat.STONE))
	var poured: int = g.call("count_material", Mat.STONE)
	t.ok(poured > 0, "돌을 실제로 깔았다 (%d칸 — 검사의 전제)" % poured)
	root.call("_refresh_hud_counts")
	t.eq(root.get("_stone_cells"), 0, "같은 틱에는 다시 안 센다 (조여져 있다)")

	# 🔴 **주기가 지나면 따라잡아야 한다.** 안 재면 「영영 안 갱신」과 구별이 안 된다.
	for _i in period:
		g.call("step")
	root.call("_refresh_hud_counts")
	t.eq(root.get("_stone_cells"), poured, "%d틱 뒤에 따라잡는다" % period)

	# 🔴 **리셋(틱이 0으로 되돌아간다)도 따라잡아야 한다.** 안 그러면 R 뒤 20틱 동안
	#  옛 지형의 수가 화면에 남는다.
	g.call("apply", CellGrid.cmd_reset())
	root.call("_refresh_hud_counts")
	t.eq(root.get("_stone_cells"), 0, "리셋 뒤 곧바로 다시 센다 (틱이 되돌아가는 갈래)")

	# 🔴🔴 **조이는 것이 셋뿐인가 — 「활성 청크는 실시간이다」를 지키는 유일한 자리다.**
	#  ⚠ 활성 청크·타는 셀·FPS 는 **O(1) 질의라 안 조였다.** 그런데 그 사실을 지키는 검사가
	#   없었다 — **누가 활성 청크를 이 캐시로 옮겨도 아무도 안 짖고**, 그러면 판정 1(물이 멈췄나)이
	#   **최대 1초 낡은 숫자**를 읽게 된다. 「줄다가 잠기는 것」을 보는 판정이라 그게 곧 오독이다.
	#  🔴 그래서 **이 함수가 건드리는 필드 집합 자체**를 잰다. 넷째가 늘면 빨개진다.
	#  ⚠ **센티넬을 먼저 박는다.** 「값이 바뀐 필드」로 재면 **마침 값이 같은 필드가 빠진다** —
	#   실측으로 돌이 0 → 0 이라 목록에서 사라졌다(2026-08-07). 재려는 것은 「값이 변했나」가
	#   아니라 **「이 함수가 쓰는 자리가 어디까지인가」**다.
	for nm3 in ["_stone_cells", "_wood_cells", "_water_cells"]:
		root.set(nm3, -1)
	var before := {}
	for pd: Dictionary in root.get_property_list():
		if int(pd.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			before[pd["name"]] = root.get(pd["name"])
	#  🔴 **셈이 도는 순간에 활성 청크가 0이 아니어야 한다.** 새로 는 필드는 센티넬을 못 박으므로,
	#   **값이 우연히 같으면 안 걸린다** — 활성 청크를 캐시로 옮기는 뮤테이션이 실제로 그렇게
	#   빠져나갔다(0 → 0, 2026-08-07). ⇒ 마지막 틱에 지형을 깔아 **깨어 있는 채로** 세게 만든다.
	for _i in period - 1:
		g.call("step")
	g.call("apply", CellGrid.cmd_fill(0, 0, 199, 199, Mat.WOOD))
	g.call("step")
	t.ok(int(g.call("active_chunk_count")) > 0,
		"셈이 도는 순간 활성 청크가 0이 아니다 (이 검사의 전제)")
	root.call("_refresh_hud_counts")
	var touched: Array[String] = []
	for nm2: String in before:
		if root.get(nm2) != before[nm2]:
			touched.append(nm2)
	touched.sort()
	t.eq(touched, ["_hud_count_tick", "_stone_cells", "_water_cells", "_wood_cells"] as Array[String],
		"조이는 필드가 정확히 셋(+틱)이다 — 실시간 값이 여기 섞이면 빨개진다")

	root.free()
