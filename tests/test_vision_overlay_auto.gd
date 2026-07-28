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
const OVERLAY_SRC := "res://src/actors/vision_overlay.gd"
const SHADER_SRC := "res://src/actors/vision_overlay.gdshader"
const VISION_SRC := "res://src/core/vision.gd"
const FOG_NODE := "VisionFog"

## 🔴 셰이더가 반드시 받아야 하는 uniform — 하나라도 없으면 모양이 셰이더 안에 굳어 있다는 뜻이다.
## ⚠ 세105에 셋이 늘었다(차폐 그늘) — **그늘도 모양이라 밖에서 받아야 한다.**
const REQUIRED_UNIFORMS: Array[String] = [
	"origin", "aim", "fan_deg", "fan_range", "near_radius",
	"rect_pos", "rect_size", "darkness",
	"occluders", "occluder_count", "shadow_feather",
]

## 🔴🔴 **세105: 어둡기 상한(0.35)이 은퇴했다 — 사용자가 직접 뒤집었다.**
##
## 이력이 이 상수의 전부다. 세104엔 **0.35**였고 그 근거가 **세73**(*"밝게할꺼고 조명만"* — 어두운
## 던전 각하)·**세99**(*"그냥 낮으로"* — 횃불 8개 삭제)였는데, 세105에 사용자가
## *"**빛이 아예없어야하는데** 어렵나?"*로 **1.00**을 지시했다.
##
## 🔴 **그 지시는 세73·세99와 충돌하지 않는다 — 축이 다르다.** 그 둘이 각하한 건 「**방**이 어둡다」고
##  이건 「**시야 밖**이 없다」다. 방은 여전히 낮이고 **부채꼴·주변시 안은 원래 밝기 그대로**다.
##  ⇒ 상한으로는 그 구분을 못 잰다(0.35든 1.00이든 「밖」만 누르는 건 같다) — **상한은 죽은 방어선이다.**
##
## 🔴🔴 **그럼 세73은 이제 무엇이 지키나 = [7]이다.** *"부채꼴 안은 안 어둡다"*가 살아 있는 계약이고,
##  `lit_at()`이 그걸 좌표로 단언한다. 어두운 던전으로 가려면 **[7]을 깨야** 한다 —
##  ⚠ 상한을 되살리자는 제안이 오면 **[7]이 이미 그 일을 한다**고 답해라(같은 말 두 벌 = T5).
## ⚠ 하한은 그대로 잰다 — 0이면 오버레이가 **살아는 있는데 아무 일도 안 한다**(에러 0 · 그물만 초록).
const DARKNESS_MAX := 1.0
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
	await _test_occluder_shadow()
	await _test_overflow_is_observable()
	await _test_bake_after_props()

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
	_check(dark != null and dv <= DARKNESS_MAX,
		"어둡기가 알파 상한 %.2f 이하다 (실제 %s) — 넘으면 그냥 클램프되어 손잡이가 죽는다"
			% [DARKNESS_MAX, str(dark)])
	# 🔴 세105 신설 — 그늘 uniform이 실제로 **밖에서 실린다**. 셋 중 하나만 빠져도
	#  그 축이 셰이더 안에 굳는데 화면은 그럴듯하다(위 [2] 머리말과 같은 병).
	var feather = mat.get_shader_parameter("shadow_feather")
	_check(feather != null and float(feather) > 0.0,
		"🔴 그늘 반그림자 폭이 실렸다 (%s) — 0이면 그늘이 오려 붙인 것처럼 보인다" % str(feather))
	_check(mat.get_shader_parameter("occluder_count") != null,
		"🔴 엄폐물 개수가 실렸다 (안 실리면 셰이더가 루프를 안 돌아 **그늘이 통째로 없다**)")
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
	# 🔴🔴 **셰이더 배열 길이 = `vision_overlay.MAX_OCCLUDERS`.** 이 하나는 **두 벌로 둘 수밖에 없다**
	#  (GLSL 배열 길이는 컴파일 타임 상수여야 한다) — 그래서 여기서 대조한다.
	#  갈리면 어떻게 죽나: .gd가 더 크면 **넘친 엄폐물이 조용히 안 그려지고**(그늘이 없는 나무가 생긴다),
	#  셰이더가 더 크면 **안 채운 자리를 읽어** 원점 근처에 반경 0짜리 유령이 선다. 둘 다 에러 0이다.
	var want: int = load(OVERLAY_SRC).MAX_OCCLUDERS
	_check(code.contains("MAX_OCCLUDERS = %d;" % want),
		"🔴 셰이더 배열 길이가 vision_overlay.MAX_OCCLUDERS(%d)와 같다" % want)

	# 🔴🔴 **반그림자의 「방향」 계약** (세105 후반 · 사용자 *"자연스럽게 서서히 어두워 지도록"*).
	#  그늘이 **100%가 되는 선 = 판정(`_blocked`)이 「막힘」이라 답하기 시작하는 선(`r`)**이어야 한다.
	#  ⇒ 화면은 판정보다 **넓게** 어두워도 되지만 **좁아선 안 된다**:
	#     「어두운데 보였다」는 참을 수 있고, 「밝은데 안 보였다」는 **사용자가 이미 지적한 그 증상**이다.
	#
	# ⚠ **왜 문자열로 재나** — 이 방향은 값으로 못 잰다. 헤드리스는 렌더를 못 읽고,
	#  `lit_at()`은 `Vision.is_seen`을 **그대로 부르므로** 둘이 경계에서 어긋나는 일이 **구조적으로 없다**
	#  (그래서 *"경계에서 lit_at과 is_seen이 갈리는지 봐라"*는 검사는 **만들 수 없다**).
	#  ⇒ 최종 판정은 `tools/vfx_shot.gd` PNG와 F5다. 여기는 **뒤집기를 막는 빗장**일 뿐이다.
	_check(code.contains("smoothstep(r_sq,"),
		"🔴 원뿔 옆선 — 그늘 100%의 선이 `r_sq`다 (반그림자는 그 **바깥으로**만 번진다)")
	_check(code.contains(", max(r_sq,"),
		"🔴 밑동 테두리 — 그늘 100%의 선도 `r_sq`다 (그라디언트는 원 **안쪽으로**만 번진다)")


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


## [8] 🔴🔴 **이 그물의 새 심장 — 그늘을 그리는 화면과 판정이 같은 답을 낸다** (세105 차폐).
##
## 왜 여기가 심장인가: `vision_occlusion_design` ⓓ는 원래 *"차폐를 화면에 안 그린다"*였고 §2-5가
## 그래서 *"안개에 목록을 넘기지 마라"*고 못 박았다 — **넘기면 화면과 관측점이 갈리기 때문**이다.
## 세105에 사용자가 ⓓ를 뒤집었으므로(*"빛이 안가야하거든"*) 이제는 **안 넘기는 쪽이 갈라짐**이다.
## 🔴 그 문서가 조건을 미리 적어 뒀다: *"셰이더와 `lit_at`을 **같이** 열어라."* [8]이 그 「같이」를 잰다.
##
## 🔴🔴 **격자로 쓸어서 재는 게 핵심이다.** 점 몇 개만 찍으면 「필터가 너무 많이 걷어냈다」를 못 잡는다 —
##  `lit_at`은 **거른 목록**(`_live`)으로 답하고 여기 기대값은 **전량**으로 내므로, 거르기가 답을
##  한 점이라도 바꾸면 빨개진다. ⚠ 기대값을 손으로 적지 않는 것도 의도다(balance를 조여도 안 낡는다).
func _test_occluder_shadow() -> void:
	print("[8] 🔴 차폐 그늘 — lit_at() = Vision.is_seen(엄폐물 전량)")
	var vision = load(VISION_SRC)
	var fog = await _lone_fog()
	_check(fog.live_occluders().is_empty(),
		"ⓐ 엄폐물이 없으면 목록이 비어 있다 (= 세104 이전과 완전히 같은 동작)")

	var stub := AimStub.new()
	stub.aim = Vector2.RIGHT
	stub.add_to_group("player")
	root.add_child(stub)
	stub.global_position = Vector2.ZERO
	var near: float = _bal.vision_near_radius
	var rng: float = _bal.vision_fan_range
	# 🔴 자리는 **balance에서 파생**시킨다 — 리터럴로 박으면 사용자가 시야를 조일 때 거짓 빨강이 난다.
	#   ⓑ 앞쪽 중거리(부채꼴 한가운데) · ⓒ 주변시 **안**(①의 검출자) · ⓓ 아래쪽 비스듬히
	var mid := rng * 0.36
	# 🔴🔴 ⓖ **부채꼴 옆선에 걸친 놈이 하나 있어야 한다.** `_refresh_live`는 쐐기 밖 엄폐물을
	#  걷어내는데, 원은 **중심이 밖이어도 몸이 안으로 걸친다**(각 반폭 `asin(r/d)`). 그 항을 빼는
	#  뮤테이션이 **처음엔 안 잡혔다** — 판의 셋이 전부 쐐기 한가운데 있어서였다. 이 줄이 그 검출자다.
	var edge_deg: float = _bal.vision_fan_deg * 0.5 * 1.02   # 중심은 밖 · 몸은 안
	var occ := [
		_occluder(Vector2(mid, 0.0), 34.0),
		_occluder(Vector2(near * 0.5, 0.0), 34.0),
		_occluder(Vector2(mid * 1.2, mid * 0.7), 26.0),
		_occluder(Vector2.RIGHT.rotated(deg_to_rad(edge_deg)) * mid, 34.0),
	]
	fog.rebake_occluders()
	await process_frame
	await process_frame

	var live: PackedVector3Array = fog.live_occluders()
	_check(live.size() == occ.size(),
		"ⓑ 엄폐물 %d개가 실제로 실렸다 (%d) — 0이면 아래가 전부 **자명 통과**가 된다"
			% [occ.size(), live.size()])
	_check(fog.occluder_overflow() == 0, "ⓒ 상한에 안 걸렸다 (잘림 %d)" % fog.occluder_overflow())

	# 🔴 전량 목록 — 기대값은 **거르기를 안 거친** 이것으로 낸다(거르기 자체가 피검사체다).
	var all := PackedVector3Array()
	for n in occ:
		all.append(Vector3(n.global_position.x, n.global_position.y, float(n.get_meta("occlude_r"))))

	var bad := 0
	var first := ""
	var step := rng * 0.06
	for ix in range(-6, 17):
		for iy in range(-8, 9):
			var p := Vector2(float(ix) * step, float(iy) * step)
			var want: bool = vision.is_seen(stub.global_position, stub.aim, p,
				_bal.vision_fan_deg, rng, near, all)
			if fog.lit_at(p) != want:
				bad += 1
				if first.is_empty():
					first = "%s (화면 %s / 판정 %s)" % [str(p), str(fog.lit_at(p)), str(want)]
	_check(bad == 0,
		"🔴🔴 ⓓ 격자 391점이 **한 점도 안 갈린다** (불일치 %d%s)"
			% [bad, "" if first.is_empty() else " · 첫 어긋남 " + first])

	# 🔴🔴 ⓔ 판정 순서 ① — **주변시 안은 차폐 면제다.** 같은 나무가 「주변시 안 대상」은 안 가리고
	#  「주변시 밖 대상」은 가려야 한다. **둘 다** 재는 게 요점이다(한쪽만 재면 차폐가 통째로
	#  안 도는 것도 통과한다 · 설계 O1).
	var inside := Vector2(near * 0.9, 0.0)
	var beyond := Vector2(rng * 0.8, 0.0)
	_check(fog.lit_at(inside),
		"🔴 ⓔ-1 주변시 안(%s)은 정면에 나무가 있어도 밝다 — 이 줄이 O1의 유일한 검출자다" % str(inside))
	_check(not fog.lit_at(beyond),
		"ⓔ-2 같은 나무가 주변시 **밖**(%s)은 가린다 (차폐가 실제로 돈다)" % str(beyond))
	# 🔴 ⓕ 나무를 껴안은 자리 — 원 안이면 그 나무는 안 가린다(설계 O6).
	#  ⚠ **엄폐물 하나만 남기고 잰다.** 여럿을 둔 채로 재면 「그 나무 원 안」이 **옆 나무 그늘**에
	#   들어 빨개진다 — 첫 판에서 실제로 그랬고, 그건 O6이 깨진 게 아니라 판이 잘못 짜인 것이다.
	for n in occ:
		n.free()
	var lone := _occluder(Vector2(mid, 0.0), 34.0)
	fog.rebake_occluders()
	await process_frame
	await process_frame
	_check(fog.live_occluders().size() == 1, "ⓕ-0 판을 갈아 엄폐물 하나만 남겼다")
	_check(fog.lit_at(Vector2(mid, 0.0)),
		"🔴 ⓕ 엄폐물 원 **안**(%s)은 밝다 (「나무를 껴안으면 아무것도 안 보인다」 방지)"
			% str(Vector2(mid, 0.0)))
	_check(not fog.lit_at(Vector2(mid + 60.0, 0.0)),
		"ⓕ-2 그 나무 **바로 뒤**는 어둡다 (ⓕ가 「차폐가 아예 안 돈다」로 통과하지 않게)")

	# 🔴🔴 ⓖ **반그림자는 화면에만 있다 — 판정 경계를 한 픽셀도 못 움직인다** (세105 후반).
	#  그늘이 연속값이 되면서 생기는 새 위험이 *"반쯤 어두운 곳의 적은 보이나?"*이고, 그 답은
	#  **「보인다」**여야 한다(반그림자는 판정 밖 영역이다). 누가 그 어긋남을 「고치려고」
	#  `shadow_feather`를 판정에 끌어들이면 **부채꼴이 조용히 넓어진다** — 여기가 그 검출자다.
	#  ⚠ uniform을 극단으로 흔들어도 `lit_at`의 답이 **한 점도 안 변해야** 한다.
	var probes: Array[Vector2] = []
	for k in 24:
		probes.append(Vector2(mid + 60.0, (float(k) - 12.0) * 8.0))
	var before: Array[bool] = []
	for p in probes:
		before.append(fog.lit_at(p))
	fog.material.set_shader_parameter(&"shadow_feather", 500.0)
	await process_frame
	var moved := 0
	for i in probes.size():
		if fog.lit_at(probes[i]) != before[i]:
			moved += 1
	_check(moved == 0,
		"🔴 ⓖ `shadow_feather`를 500으로 흔들어도 판정이 안 움직인다 (움직인 점 %d)" % moved)
	# ⚠ 되돌려 놓는다 — 뒤 항목이 흔들린 uniform을 물려받지 않게(무대는 아래에서 free되지만 규율이다).
	fog.material.set_shader_parameter(&"shadow_feather", load(OVERLAY_SRC).SHADOW_FEATHER_PX)

	lone.free()
	stub.free()
	fog.free()


## [9] 🔴 **상한에 걸려 잘리면 그 사실이 밖에서 보인다** — 「조용히 잘림」이 이 설계의 유일한
##  근사(近似)라, 안 보이게 두면 **먼 나무 그늘이 사라진 채 아무도 모른다**.
## ⚠ 실무대에선 안 걸린다(사거리·쐐기 필터 뒤 기대값이 서넛) — 그래서 **일부러** 넘겨서 잰다.
func _test_overflow_is_observable() -> void:
	print("[9] 🔴 상한을 넘기면 잘린 수가 밖으로 나온다")
	var cap: int = load(OVERLAY_SRC).MAX_OCCLUDERS
	var fog = await _lone_fog()
	var stub := AimStub.new()
	stub.aim = Vector2.RIGHT
	stub.add_to_group("player")
	root.add_child(stub)
	stub.global_position = Vector2.ZERO
	var extra := 5
	var made: Array[Node2D] = []
	var rng: float = _bal.vision_fan_range
	for i in (cap + extra):
		# 정면 가까이 일렬로 — 전부 쐐기 안·사거리 안이라 필터가 하나도 못 걷어낸다.
		made.append(_occluder(Vector2(rng * 0.2 + float(i) * 12.0, 0.0), 8.0))
	fog.rebake_occluders()
	await process_frame
	await process_frame
	_check(fog.live_occluders().size() == cap,
		"실은 건 상한 %d개다 (%d)" % [cap, fog.live_occluders().size()])
	_check(fog.occluder_overflow() == extra,
		"🔴 잘린 %d개가 `occluder_overflow()`로 보인다 (%d)" % [extra, fog.occluder_overflow()])
	for n in made:
		n.free()
	stub.free()
	fog.free()


## [10] 🔴🔴 **언제 굽나 — 실무대에서만 드러나는 사고다** (설계 §3-2 · F5).
##
## `$VisionFog`는 **씬 자식**이라 그 `_ready`가 `boss_room._ready`보다 **먼저** 돈다.
## 거기서 구우면 `_spawn_props()`가 아직 안 돌아 **목록이 통째로 빈다** — 화면은 그냥
## 「그늘이 없는 숲」이고 **에러도 경고도 0이다.** 위 [8]·[9]는 스텁 무대라 이걸 **못 잡는다**
## (거기선 그물이 `rebake_occluders()`를 손으로 부른다) ⇒ 🔴 **이 항목이 유일한 검출자다.**
## ⚠ 선례가 같은 병이다: `forest_enemy._home`이 *"`_ready`가 아니라 첫 물리 틱"*인 이유.
func _test_bake_after_props() -> void:
	print("[10] 🔴 엄폐물을 **방이 프롭을 세운 뒤**에 굽는다")
	await _fresh_room(&"ch1")
	var fog = _room.get_node(FOG_NODE)
	var group: int = get_nodes_in_group(load(OVERLAY_SRC).OCCLUDER_GROUP).size()
	_check(group > 0,
		"방이 엄폐물을 실제로 세운다 (%d개) — 0이면 아래가 자명 통과가 된다" % group)
	_check(fog.baked_occluder_count() == group,
		"🔴🔴 구운 목록(%d)이 `occluders` 그룹 전량(%d)과 같다 — `_ready`에서 구우면 여기가 0이 된다"
			% [fog.baked_occluder_count(), group])
	# ⚠ **단언이 아니라 관측이다** — 실무대에서 필터가 실제로 몇 개까지 줄이나(= 상한 16이 넉넉한가).
	#  플레이어의 조준은 마우스에서 나와 리그마다 흔들리므로 값을 못 박지 않는다.
	print("  INFO: 구운 %d개 → 이번 프레임에 실은 %d개 (상한 %d · 잘림 %d)"
		% [fog.baked_occluder_count(), fog.live_occluders().size(),
			load(OVERLAY_SRC).MAX_OCCLUDERS, fog.occluder_overflow()])
	_free_room()


# ── 헬퍼 ──

## 엄폐물 스텁 — 방이 `_mark_occluder`에서 새기는 **그 두 줄**(그룹 + meta)을 그대로 흉내낸다.
## 🔴 키를 여기 안 적는다 — `vision_overlay`의 const를 읽는다(세 번째 사본을 만들면 그게 곧 T5다).
## ⚠ 프롭 씬을 안 띄우는 게 의도다: 재는 건 **선분↔원**이지 그림이 아니고, 씬을 띄우면 반경이
##  `boss_room.PROP_TABLE`에 묶여 배치를 조일 때마다 이 그물이 흔들린다.
func _occluder(at: Vector2, r: float) -> Node2D:
	var overlay = load(OVERLAY_SRC)
	var n := Node2D.new()
	n.add_to_group(overlay.OCCLUDER_GROUP)
	n.set_meta(overlay.OCCLUDE_R_META, r)
	root.add_child(n)
	n.global_position = at
	return n


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
