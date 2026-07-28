extends SceneTree
## 시야 안개(부채꼴 밖 어둡게) 자동 검증 (세104) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_vision_overlay_auto.gd
## 전 항목 통과 시 "TEST_VISION_OVERLAY_OK" 출력 후 종료 코드 0.
##
## 🔴🔴 **헤드리스가 못 재는 것과 재는 것을 갈라 놨다.**
##  못 잰다 = 「20%가 적당한가 · 부채꼴로 읽히나 · 경계가 오려 붙인 것 같지 않나」
##           → `scratch_shots/`의 실게임 스샷과 **F5**(사용자 손) 몫이다.
##  잰다   = 🔴 **「그린 부채꼴이 판정과 같은 모양인가」의 배선** · 어디에 붙나 · 무엇을 안 덮나.
##
## 🔴🔴 **이 그물의 심장 = [2]·[3]**: 셰이더가 **자기 부채꼴을 따로 계산하면**
##  「어두운 데 서 있는데 보이는 적」이 생기는데 **에러가 0이고 화면도 그럴듯하다**(감사 T5).
##  그래서 ⓐ uniform 값이 balance와 같은지 재고 ⓑ 셰이더 **소스에 그 숫자가 없는지** 훑는다.
##  ⚠ 값 대조만 하면 셰이더가 그 값을 **안 쓰고 상수로 그려도** 통과한다 — 그래서 둘 다 있다.
##
## ⚠ **못 잡는 것 하나를 여기 적어 둔다**: 「uniform은 맞는데 셰이더 수식이 틀렸다」(예: 각도를 또
##  반으로 나눔)는 헤드리스로는 못 잡는다. 리드가 **실게임 스샷으로 검증한 방법**이 정본이다 —
##  조준을 고정해 뽑은 PNG를 `Vision.is_seen`의 예측 마스크와 픽셀 단위로 대조했고(세104,
##  3방향 · 일치 15,849 / 21,326 / 21,397 · 불일치는 전부 「그 사이에 움직인 적」),
##  수식을 고치면 **그 대조를 다시 돌려라**.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

const ROOM := "res://src/field/boss_room.tscn"
const BASE := "res://src/base/base.tscn"
const OVERLAY := "res://src/actors/vision_overlay.tscn"
const SHADER_SRC := "res://src/actors/vision_overlay.gdshader"
const FOG_NODE := "VisionFog"

## 🔴 셰이더가 반드시 받아야 하는 uniform — 하나라도 없으면 모양이 셰이더 안에 굳어 있다는 뜻이다.
const REQUIRED_UNIFORMS: Array[String] = [
	"origin", "aim", "fan_deg", "fan_range", "near_radius",
	"rect_pos", "rect_size", "darkness",
]

## 🔴🔴 **어둡기의 「상한」을 잰다 — 정확한 값이 아니다**(세104에 바꿨다).
##
## 처음엔 정확한 값(0.20)을 박았는데, 사용자가 F5로 **0.30으로 올리자마자 빨개졌다.** 그때 드러난 것:
##  ⓐ 정확한 값을 박으면 **조일 때마다 두 곳을 고쳐야 한다** — 손맛 값은 원래 자주 움직인다.
##  ⓑ 그렇다고 `FOG_DARKNESS`에서 **파생시키면 아무것도 안 잡는다**(자기 자신과 비교하는 꼴).
##
## ⇒ 재는 것을 바꿨다: **「사용자가 조일 자유」는 열어 두고 「어두운 던전으로 가는 것」만 막는다.**
##  이 상한이 곧 **세73**(*"밝게할꺼고 조명만"* — 어두운 던전 각하)·**세99**(*"그냥 낮으로"* —
##  횃불 8개 삭제)의 방어선이다. 넘기려는 사람은 여기서 한 번 멈춰 서고, **왜 두 번 각하된 방향으로
##  가는지**를 이 주석에서 읽게 된다.
##
## 🔴 **올리려면 근거를 같이 가져와라** — 「실제 게임 줌 스샷에서 지형·드롭이 여전히 또렷하다」를
##  보이지 못하면 그 변경은 각하 대상이다(`vision_overlay.FOG_DARKNESS` 머리말과 짝이다).
## ⚠ 하한도 잰다 — 0이면 오버레이가 **살아는 있는데 아무 일도 안 한다**(에러 0 · 그물만 초록).
const DARKNESS_CEILING := 0.35
## 월드 연출의 최상단(감전 스파크 z 56 · VFX_SPEC §3)보다 위여야 안개가 그 위를 덮는다.
const MIN_Z_ABOVE_VFX := 60

var failures: int = 0
var _gs = null
var _bal = null
var _room = null


## 조준만 고정해서 돌려주는 「플레이어」 — 그물이 부채꼴 방향을 쥐는 유일한 방법이다
## (실플레이어의 조준은 `get_global_mouse_position()`에서 나와 리그마다 흔들린다).
class AimStub extends Node2D:
	var aim: Vector2 = Vector2.RIGHT
	func vision_dir() -> Vector2:
		return aim


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_VISION_OVERLAY_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame

	_gs = root.get_node("/root/GameState")
	_bal = load("res://data/balance.tres")

	await _test_where_it_lives()
	await _test_uniforms_match_balance()
	await _test_shader_has_no_hardcoded_shape()
	await _test_rect_follows_ground_and_player()
	await _test_not_over_hud()
	await _test_fail_open()
	await _test_lit_matches_vision()

	if failures == 0:
		print("TEST_VISION_OVERLAY_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_VISION_OVERLAY_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 **던전엔 있고 마을엔 없다.** 마을엔 시야 자체가 없다(허수아비는 늘 보인다) —
## 마을에 안개가 서면 「보이는 규칙은 없는데 화면만 어두운」 정반대가 된다.
func _test_where_it_lives() -> void:
	print("[1] 던전엔 안개가 있고 · 마을엔 없다")
	await _fresh_room(&"ch1")
	var fog = _room.get_node_or_null(FOG_NODE)
	_check(fog != null, "보스방에 안개가 선다(%s)" % FOG_NODE)
	_check(fog != null and fog.visible, "그리고 실제로 켜져 있다(플레이어가 조준 중)")
	_free_room()

	var base = (load(BASE) as PackedScene).instantiate()
	root.add_child(base)
	current_scene = base
	await process_frame
	await physics_frame
	_check(_find_fog(base) == null, "🔴 마을엔 안개가 **없다** (시야가 없는 무대다)")
	base.free()
	current_scene = null


## [2] 🔴🔴 **판정 두 벌 방지 — 셰이더가 받는 수치가 balance 그대로다.**
## `forest_enemy._judge_seen`이 `Vision.is_seen`에 넘기는 **바로 그 세 값**이다. 갈리는 순간
## 「어두운 데 서 있는데 보이는 적」·「밝은 데 있는데 안 보이는 적」이 생기고 에러는 0이다.
## ⚠ **`fan_deg`는 전체 각도다** — 반각(60)을 넘기면 화면의 부채꼴만 절반이 되는데 아무도 못 알아챈다.
##  그래서 「반각이 아님」을 따로 못 박는다(리터럴 60을 안 쓰고 balance의 절반과 **다름**을 잰다).
func _test_uniforms_match_balance() -> void:
	print("[2] 🔴 셰이더 uniform = balance의 vision_* 셋 (판정 두 벌 검출자)")
	await _fresh_room(&"ch1")
	var mat = _room.get_node(FOG_NODE).material
	_check(mat != null, "안개에 ShaderMaterial이 붙어 있다")
	if mat == null:
		_free_room()
		return
	var got_deg = mat.get_shader_parameter("fan_deg")
	var got_range = mat.get_shader_parameter("fan_range")
	var got_near = mat.get_shader_parameter("near_radius")
	_check(got_deg != null and is_equal_approx(float(got_deg), _bal.vision_fan_deg),
		"fan_deg = balance %.1f (셰이더 %s)" % [_bal.vision_fan_deg, str(got_deg)])
	_check(got_range != null and is_equal_approx(float(got_range), _bal.vision_fan_range),
		"fan_range = balance %.1f (셰이더 %s)" % [_bal.vision_fan_range, str(got_range)])
	_check(got_near != null and is_equal_approx(float(got_near), _bal.vision_near_radius),
		"near_radius = balance %.1f (셰이더 %s)" % [_bal.vision_near_radius, str(got_near)])
	_check(got_deg != null and not is_equal_approx(float(got_deg), _bal.vision_fan_deg * 0.5),
		"🔴 **전체 각도**를 넘긴다 — 반각(%.1f)이 아니다" % (_bal.vision_fan_deg * 0.5))
	var dark = mat.get_shader_parameter("darkness")
	var dv := float(dark) if dark != null else -1.0
	_check(dark != null and dv > 0.0,
		"어둡기가 0보다 크다 (실제 %s) — 0이면 오버레이가 살아는 있는데 아무 일도 안 한다" % str(dark))
	_check(dark != null and dv <= DARKNESS_CEILING,
		"🔴 어둡기가 상한 %.2f 이하다 (실제 %s) — 넘으면 세73(어두운 던전)으로 되돌아간다. 위 상수 주석을 읽어라"
			% [DARKNESS_CEILING, str(dark)])
	_free_room()


## [3] 🔴 **셰이더 소스에 부채꼴 수치가 없다** — [2]는 「값이 실렸나」만 보므로, 셰이더가 그 값을
## 무시하고 상수로 그려도 통과한다. 여기서 그 재발을 문자열로 막는다(`test_status_auto`의
## vfx.gd 스캔과 같은 관행). ⚠ **uniform이 다 선언돼 있는지도 같이** 본다 — 하나가 빠지면
## 그 축만 셰이더 안에 굳는다.
func _test_shader_has_no_hardcoded_shape() -> void:
	print("[3] 🔴 셰이더가 자기 부채꼴을 안 든다 (소스 스캔)")
	var f = FileAccess.open(SHADER_SRC, FileAccess.READ)
	_check(f != null, "셰이더 소스를 읽었다")
	if f == null:
		return
	var src: String = f.get_as_text()
	f.close()
	# 주석은 걷어낸다 — 머리말이 「120·560·220을 박지 마라」라고 **적어 두는 것**은 정상이다.
	var code := ""
	for line in src.split("\n"):
		var s: String = line.strip_edges()
		if s.begins_with("//"):
			continue
		code += line + "\n"
	for lit in [str(int(_bal.vision_fan_deg)), str(int(_bal.vision_fan_range)),
			str(int(_bal.vision_near_radius))]:
		_check(not code.contains(lit),
			"🔴 셰이더 코드에 '%s'가 없다 (balance 값을 박으면 판정이 두 벌이 된다)" % lit)
	for u in REQUIRED_UNIFORMS:
		_check(code.contains("uniform") and code.contains(u),
			"uniform '%s'를 밖에서 받는다" % u)


## [4] 🔴 **모양이 파생이다** — 사각형은 방의 `Ground`에서, 원점은 플레이어에서 온다.
##  ⓐ 좌표를 베끼면 방을 키우는 날 안개만 옛 크기로 남는다(`_clamp_camera_to_room`과 같은 계약).
##  ⓑ 🔴 원점이 플레이어를 **매 프레임** 따라와야 한다 — 안 따라오면 부채꼴이 입구에 굳는다.
func _test_rect_follows_ground_and_player() -> void:
	print("[4] 사각형 = Ground 파생 · 원점 = 플레이어 추종")
	await _fresh_room(&"ch1")
	var fog = _room.get_node(FOG_NODE)
	var ground = _room.get_node("Ground")
	_check(fog.position.is_equal_approx(ground.global_position) and fog.size.is_equal_approx(ground.size),
		"안개가 Ground 사각형과 정확히 같다 (%s %s / %s %s)"
			% [fog.position, fog.size, ground.global_position, ground.size])
	var mat = fog.material
	_check(Vector2(mat.get_shader_parameter("rect_size")).is_equal_approx(ground.size),
		"셰이더에도 같은 사각형이 실렸다 (월드↔UV 변환의 기준)")
	var player = _room.get_node("Player")
	player.global_position += Vector2(120.0, -240.0)
	await process_frame
	await process_frame
	var origin = mat.get_shader_parameter("origin")
	_check(origin != null and Vector2(origin).is_equal_approx(player.global_position),
		"원점이 플레이어를 따라온다 (셰이더 %s / 실제 %s)" % [str(origin), player.global_position])
	_free_room()


## [5] 🔴🔴 **HUD를 안 덮는다.** HP·마나·슬롯·대사가 어두워지면 안 된다.
##  구조로 잰다: 안개는 **기본 캔버스**(CanvasLayer 조상이 없다)에 있고, HUD·시트는 `layer >= 1`인
##  **별개 캔버스**다 ⇒ z를 아무리 올려도 그 아래다. 🔴 안개를 CanvasLayer 안으로 옮기거나
##  HUD의 layer를 0으로 내리면 여기가 빨개진다.
## ⚠ 동시에 **월드 연출보다는 위**여야 한다 — 안 그러면 착탄·스파크만 안개를 뚫고 밝게 남는다.
func _test_not_over_hud() -> void:
	print("[5] 🔴 HUD보다 아래 · 월드 연출보다 위")
	await _fresh_room(&"ch1")
	var fog = _room.get_node(FOG_NODE)
	var layer_owner: Node = null
	var n: Node = fog.get_parent()
	while n != null:
		if n is CanvasLayer:
			layer_owner = n
			break
		n = n.get_parent()
	_check(layer_owner == null,
		"🔴 안개가 CanvasLayer 안에 없다 = HUD·시트와 **다른 캔버스**다 (지금 %s)"
			% ("없음" if layer_owner == null else layer_owner.name))
	var hud_layer = _room.get_node_or_null("Hud")
	var sheet = _room.get_node_or_null("Sheet")
	_check(hud_layer != null and hud_layer is CanvasLayer and hud_layer.layer >= 1,
		"HUD 캔버스가 layer %s (>=1이라 안개 위다)" % (str(hud_layer.layer) if hud_layer != null else "?"))
	_check(sheet != null and sheet is CanvasLayer and sheet.layer >= 1,
		"시트(Tab) 캔버스가 layer %s (>=1)" % (str(sheet.layer) if sheet != null else "?"))
	_check(fog.z_index >= MIN_Z_ABOVE_VFX,
		"안개 z=%d — 월드 연출(감전 스파크 z 56)보다 위다" % fog.z_index)
	# 🔴 화면을 덮는 Control의 mouse_filter — STOP이면 좌클릭을 다 먹어 **발사가 조용히 죽는다**.
	#  헤드리스는 「클릭이 닿는가」를 못 재지만 **이 속성값은 잰다**(세25·26에 실제로 밟은 함정).
	_check(fog.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"🔴 mouse_filter = IGNORE — 좌클릭을 안 먹는다 (STOP이면 발사가 통째로 죽는다)")
	_free_room()


## [6] 🔴🔴 **판정 불가면 안개를 걷는다** (fail-open — `Vision.is_seen`과 **같은 방향의 실패**).
##  `is_seen`은 플레이어가 없거나 조준이 영벡터면 **「전부 보인다」**를 돌려준다. 그때 화면만
##  어두우면 **밝은 규칙과 어두운 화면이 정반대**가 된다 — *"모르면 어둡게"*는 취향이 아니라 버그다.
func _test_fail_open() -> void:
	print("[6] 🔴 fail-open — 판정 불가면 안개가 걷힌다")
	var fog = await _lone_fog()
	_check(not fog.visible, "ⓐ 플레이어가 아예 없으면 안개가 없다")

	var bare := Node2D.new()          # `vision_dir()`이 없는 맨몸 스텁(= `test_feel_auto`[3]의 그 리그)
	bare.add_to_group("player")
	root.add_child(bare)
	await process_frame
	await process_frame
	_check(not fog.visible, "ⓑ `vision_dir()`이 없는 플레이어면 안개가 없다")
	bare.free()

	var stub := AimStub.new()
	stub.aim = Vector2.ZERO           # 조준 불가(caster가 없는 상태) — `is_seen`이 fail-open으로 흘린다
	stub.add_to_group("player")
	root.add_child(stub)
	await process_frame
	await process_frame
	_check(not fog.visible, "ⓒ 조준이 영벡터면 안개가 없다")
	stub.aim = Vector2.RIGHT
	await process_frame
	await process_frame
	_check(fog.visible, "ⓓ 조준이 서면 다시 켜진다")
	stub.free()
	fog.free()


## [7] 🔴 **그물과 화면이 같은 문을 지난다** — `lit_at()`이 `Vision.is_seen`과 같은 답을 낸다.
##  설계 §7의 표 그대로다: 정면 안 ✅ · 정면 밖 ❌ · 옆 90° 멀리 ❌ · 뒤 가까이 ✅(주변시).
##  ⚠ 기대값을 리터럴로 안 적는다 — **balance에서 파생**시켜야 사용자가 조여도 거짓 빨강이 안 난다.
func _test_lit_matches_vision() -> void:
	print("[7] lit_at() = Vision.is_seen (부채꼴 ∪ 주변시)")
	var fog = await _lone_fog()
	var stub := AimStub.new()
	stub.aim = Vector2.RIGHT
	stub.add_to_group("player")
	root.add_child(stub)
	stub.global_position = Vector2.ZERO
	await process_frame
	await process_frame
	var rng: float = _bal.vision_fan_range
	var near: float = _bal.vision_near_radius
	var cases := [
		[Vector2(rng * 0.85, 0.0), true, "정면 사거리 안"],
		[Vector2(rng * 1.15, 0.0), false, "정면 사거리 밖"],
		[Vector2(0.0, -(near + rng) * 0.5), false, "옆 90° · 주변시 밖"],
		[Vector2(-near * 0.6, 0.0), true, "뒤쪽이라도 주변시 안"],
		[Vector2(-rng * 0.8, 0.0), false, "뒤쪽 멀리"],
	]
	for c in cases:
		_check(fog.lit_at(c[0]) == c[1],
			"%s → %s (%s)" % [str(c[0]), "밝다" if c[1] else "어둡다", c[2]])
	stub.free()
	fog.free()


# ── 헬퍼 ──

## 방 없이 안개만 세운다 — 실플레이어의 조준은 마우스에서 나와 리그마다 흔들리므로,
## 조준을 재는 항목은 **스텁만 있는 무대**에서 잰다.
func _lone_fog():
	var fog = (load(OVERLAY) as PackedScene).instantiate()
	root.add_child(fog)
	fog.fit_to(Rect2(Vector2(-600.0, -600.0), Vector2(1200.0, 1200.0)))
	await process_frame
	await process_frame
	return fog


func _fresh_room(chapter_id: StringName) -> void:
	_free_room()
	_gs.pending_chapter = chapter_id
	_room = (load(ROOM) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame


func _free_room() -> void:
	if _room != null and is_instance_valid(_room):
		_room.free()
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	_room = null
	current_scene = null


## 마을 쪽은 이름을 모른 채 **스크립트로** 찾는다 — 노드 이름만 보면 개명 한 번에 눈이 먼다.
func _find_fog(node: Node):
	var s = node.get_script()
	if s != null and s.resource_path == "res://src/actors/vision_overlay.gd":
		return node
	for c in node.get_children():
		var got = _find_fog(c)
		if got != null:
			return got
	return null


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
