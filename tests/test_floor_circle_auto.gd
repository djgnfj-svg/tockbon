extends SceneTree
## 발밑 바닥 마법진 + 착탄 등급 반영 자동 검증 (세98) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_floor_circle_auto.gd
## 전 항목 통과 시 "TEST_FLOOR_CIRCLE_OK" 출력 후 종료 코드 0.
##
## 🔴🔴 **헤드리스는 「보인다」를 못 잰다** — 이 파일이 재는 건 *그림이 예쁜가*가 아니라
## **「조립한 것이 실제로 그림에 들어갔나」**다. 손맛·색감은 `tools/vfx_shot.gd`와 F5가 판다.
##
## [1] vfx가 `ring_cast_started`·`ring_cast_canceled`에 연결돼 있다 (배선 침묵사 그물 —
##     핸들러 오타로 조용히 안 붙는 것. `test_spell_vfx_auto [1]`과 같은 패턴)
## [2] 🔴 바닥 마법진 **z_index == 1** (설계 ⓑ) — Ground·프롭 0 · 플레이어 2 · 지팡이 3 사이의
##     유일한 자리다. 음수로 내리면 Ground 뒤로 숨는다(세54에 실제로 밟았다)
## [3] 🔴 **크기가 점수에 단조 증가** — 맨 진 < 문양3 < 퍼펙트. `bounds_radius()`가 **점열에서**
##     재므로 "ro만 키우고 점열을 다시 안 만들었다"도 같이 잡힌다
## [4] 🔴🔴 **매핑표 없이 구성이 그림에 들어간다**(설계 §2의 심장) — 문양이 늘면 조각 수가 는다.
##     맨 진 2 < 문양3 5 < 문양8·2층 11. 🔴 이게 빨개지면 `band_defs_of`가 안 불렸거나
##     `rings`를 통째로 못 읽은 것이다(에러 0으로 조용히 「맨 진」만 그려진다)
## [5] 🔴 **색은 룬이 판다** — 물 진의 색이 `RuneDef.ui_color`(물)와 같다. 합성 `GlyphRingDef`의
##     `ui_color` **기본값이 불색 주황**이라, 그걸 읽으면 검게 나오는 게 아니라 **그럴듯하게**
##     틀린다(모든 마법진이 주황). + 융합진은 **룬 자리 색이 서로 다르다**
## [6] 🔴 취소가 바닥 마법진을 지운다 (설계 ⓝ) — 안 지우면 *"쐈는데 안 나갔다"*로 읽힌다
## [7] 발사(`ring_cast_requested`)도 지운다 + 🔴 시전이 겹쳐 들어와도 **하나만** 남는다(설계 ⓒ)
## [8] 🔴 착탄 데칼이 `score`에 단조 증가 — 세98 전엔 **모든 등급에서 똑같았다**(설계 §0)
## [9] 🔴🔴 원의 중심이 **발밑**이다(총구 `origin`이 아니다 · 확정 ③) + 시전 중 걸으면 **따라온다**(설계 ⓜ)
## [10] 🔴🔴 **홀드 동안 원이 안 사라진다**(세98 확정 ⑦) — `duration`은 「채우는 시간」이지 **수명이
##      아니다**. 안전망(`_SAFETY_MULT`)이 홀드를 수명으로 세면 오래 들고 있을 때 원이 **조용히
##      사라지고**, 그 자멸은 `push_warning`이라 `SCRIPT ERROR` grep에도 **안 걸린다**(감사 T6)
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일되므로 오토로드 식별자·모듈 preload 금지 —
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.
##
## 🔴 `vfx.gd`의 핸들러는 전부 `get_tree().current_scene`에 add_child한다 — **current_scene이
##   비어 있으면 조용히 아무것도 안 그려진다.** 그래서 무대를 짓고 `current_scene`으로 지정한다
##   (`tools/vfx_shot.gd`가 1번 함정으로 못 박아 둔 자리).

const GLYPH_NONE := -1
const RADIATE := 1     ## Enums.GlyphCode.RADIATE — 🔴 `-s` 컴파일 함정 회피용 지역 상수
const GATHER := 0      ## Enums.GlyphCode.GATHER
const R_FIRE := 0      ## Enums.RuneType.FIRE
const R_WATER := 2     ## 🔴 Enums.RuneType.WATER = **2**(1은 은퇴한 IMPACT 구멍 — 인덱스가 아니다)

## 조립 구성 셋 — 🔴 **세이브에서 오는 형태 그대로의 리터럴**이다(층 배열·칸 8개·빈칸 -1).
## 왕복 헬퍼로 만들지 않는 이유: 정방향 규칙이 바뀌면 입력까지 같이 밀려 「자기 자신과만 일치」한 채
## 그린이 된다(설계 §2-5의 구조적 사각지대).
const A_PLAIN := {
	"jin": &"jin_single", "rune": R_FIRE, "runes": [R_FIRE], "score": 0.70,
	"rings": [[-1, -1, -1, -1, -1, -1, -1, -1]],
}
const A_MID := {
	"jin": &"jin_single", "rune": R_WATER, "runes": [R_WATER], "score": 0.79,
	"rings": [[RADIATE, RADIATE, RADIATE, -1, -1, -1, -1, -1]],
}
const A_FULL := {
	"jin": &"jin_fuse", "rune": R_FIRE, "runes": [R_FIRE, R_WATER], "score": 0.99,
	"rings": [
		[RADIATE, RADIATE, RADIATE, RADIATE, RADIATE, -1, -1, -1],
		[GATHER, GATHER, GATHER, -1, -1, -1, -1, -1],
	],
}

var failures: int = 0
var _bus = null
var _stage: Node2D = null
var _player: Node2D = null
var _vfx = null
var _fc_script = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_FLOOR_CIRCLE_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_fc_script = load("res://src/actors/floor_circle.gd")

	# 🔴 무대 = current_scene. 없으면 vfx가 조용히 아무것도 안 그린다(위 머리말).
	_stage = Node2D.new()
	_stage.name = "Stage"
	root.add_child(_stage)
	current_scene = _stage
	# 🔴 `player.tscn`의 배치를 그대로 흉내낸다 — **Vfx는 Player의 자식**이고 Player는 그룹
	#   `"player"`에 있다. 그래야 vfx가 「발밑」을 찾는 경로(`_player_node`)가 실제와 같은 길로 돈다.
	#   ⚠ 이걸 stage 바로 아래 붙이면 앵커가 `origin` 폴백으로 떨어져 [9]가 자명 통과가 된다.
	_player = Node2D.new()
	_player.name = "Player"
	_player.add_to_group(&"player")
	_stage.add_child(_player)
	_vfx = (load("res://src/actors/vfx.gd") as GDScript).new()
	_player.add_child(_vfx)
	await process_frame

	_test_connected()
	await _test_z_and_size()
	await _test_composition()
	await _test_colors()
	await _test_cancel_and_release()
	await _test_impact_score()
	await _test_anchor_and_follow()
	await _test_survives_hold()

	if failures == 0:
		print("TEST_FLOOR_CIRCLE_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_FLOOR_CIRCLE_FAIL — %d개 실패" % failures)
		quit(1)


func _test_connected() -> void:
	print("[1] vfx가 ring_cast_started·ring_cast_canceled에 연결돼 있다")
	_check(_connected_to(_bus.ring_cast_started, _vfx), "ring_cast_started 연결 (바닥 마법진을 연다)")
	_check(_connected_to(_bus.ring_cast_canceled, _vfx), "ring_cast_canceled 연결 (끊기면 지운다)")


func _test_z_and_size() -> void:
	print("[2][3] z_index == 1 · 크기가 점수에 단조 증가")
	var r_plain := await _open_and_measure(A_PLAIN, "z")
	var r_mid := await _open_and_measure(A_MID, "")
	var r_full := await _open_and_measure(A_FULL, "")
	_check(r_plain > 0.0 and r_mid > r_plain and r_full > r_mid,
		"🔴 반지름 단조 증가 — 맨진 %.1f < 문양3 %.1f < 퍼펙트 %.1f" % [r_plain, r_mid, r_full])


func _test_composition() -> void:
	print("[4] 🔴 매핑표 없이 구성이 그림에 들어간다 — 문양이 늘면 조각이 는다")
	var n_plain := await _open_and_count(A_PLAIN)
	var n_mid := await _open_and_count(A_MID)
	var n_full := await _open_and_count(A_FULL)
	# 맨 진 = 진 윤곽 1 + 룬 1 (빈 층은 빈 서브패스라 안 센다)
	_check(n_plain == 2, "맨 진 = 조각 2 (진 윤곽 + 룬 1) — 실제 %d" % n_plain)
	# 문양3 = 진 윤곽 1 + 룬 1 + 발산 모티프 3
	_check(n_mid == 5, "문양3·1층 = 조각 5 (윤곽+룬+모티프3) — 실제 %d" % n_mid)
	# 문양8·2층 = 진 윤곽 1 + 룬 2 + 발산 5 + 응집 3
	_check(n_full == 11, "문양8·2층·융합 = 조각 11 (윤곽+룬2+5+3) — 실제 %d" % n_full)


func _test_colors() -> void:
	print("[5] 🔴 색은 룬이 판다 (합성 GlyphRingDef.ui_color 오염 그물) + 융합진은 두 색")
	var db = root.get_node("/root/Db")
	var water = db.get_rune(R_WATER)
	var fire = db.get_rune(R_FIRE)
	var fc = await _open(A_MID)
	var cols: PackedColorArray = fc.colors()
	# 🔴 물 진인데 주황이 나오면 합성 고리의 `ui_color`(기본값 = 불색)를 읽은 것이다.
	_check(water != null and cols.size() > 0 and cols[0].is_equal_approx(water.ui_color),
		"물 진의 색 = RuneDef(물).ui_color — 실제 %s" % [cols[0] if cols.size() > 0 else "없음"])
	_clear(fc)
	fc = await _open(A_FULL)
	cols = fc.colors()
	# 융합진 = [진 윤곽, 룬0, 룬1, 모티프…] — 룬 자리 둘이 서로 다른 색이어야 두 속성이 읽힌다.
	var two_tone := cols.size() >= 3 and not cols[1].is_equal_approx(cols[2])
	_check(two_tone, "🔴 융합진은 룬 자리가 두 색 (불/물)")
	_check(cols.size() >= 3 and cols[1].is_equal_approx(fire.ui_color)
		and cols[2].is_equal_approx(water.ui_color), "룬 자리 색 = 각 룬의 ui_color 그대로")
	_clear(fc)


func _test_cancel_and_release() -> void:
	print("[6][7] 취소·발사가 바닥 마법진을 지운다 · 겹쳐도 하나만")
	var fc = await _open(A_FULL)
	_check(fc != null, "시전 시작 → 바닥 마법진이 생겼다")
	# 🔴 겹치기: 취소·발사 없이 새 시전이 들어와도 원이 쌓이면 안 된다(설계 ⓒ)
	_bus.ring_cast_started.emit(A_MID, Vector2.ZERO, 0.5)
	await process_frame
	await process_frame
	_check(_all_circles().size() == 1, "겹쳐 시전해도 바닥 마법진은 1개 — 실제 %d" % _all_circles().size())

	_bus.ring_cast_canceled.emit()
	await _wait(0.30)   # cancel 트윈(0.10s) + queue_free
	_check(_all_circles().is_empty(),
		"🔴 취소하면 사라진다 — 실제 %d개 남음" % _all_circles().size())

	await _open(A_FULL)
	_bus.ring_cast_requested.emit(A_FULL, Vector2.ZERO, Vector2.RIGHT)
	await _wait(0.35)   # release 트윈(0.16s) + queue_free
	_check(_all_circles().is_empty(),
		"발사하면 사라진다 — 실제 %d개 남음" % _all_circles().size())


func _test_impact_score() -> void:
	print("[8] 🔴 착탄 데칼이 score에 단조 증가 (세98 전엔 모든 등급이 똑같았다)")
	var r_lo := await _impact_decal_radius(0.70)
	var r_hi := await _impact_decal_radius(1.00)
	_check(r_lo > 0.0 and r_hi > r_lo,
		"🔴 데칼 반지름 — 무난 %.1f < 퍼펙트 %.1f" % [r_lo, r_hi])


## 🔴🔴 확정 ③(발밑) + 설계 ⓜ(따라간다). 둘 다 **에러 0으로 조용히 어긋나는** 자리다:
##   ⓐ `origin`(= 지팡이 끝)을 그대로 쓰면 원이 몸 옆에 비껴 앉는다 → 「발밑」이 아니다.
##      그래서 **일부러 origin을 멀리(999,999) 준다** — 앵커가 origin이면 여기서 바로 빨개진다.
##   ⓑ 월드 고정이면 **가장 공들인 마법일수록 원이 발에서 제일 많이 벗어난다**(퍼펙트가 가장
##      오래·가장 느리다) → 시전 중 걸어 보고 따라오는지 잰다.
## ⚠ `floor_circle.FOLLOW_FEET`를 false로 뒤집으면 ⓑ가 빨개진다 — **그게 의도된 F5 비교 스위치**다.
##   그때 이 검사를 지우지 말고 기대값을 뒤집어라(스위치가 살아 있다는 증거가 그물에 남아야 한다).
func _test_anchor_and_follow() -> void:
	print("[9] 🔴 원의 중심이 발밑이다 · 시전 중 걸으면 따라온다 (확정 ③ · 설계 ⓜ)")
	_player.global_position = Vector2(40.0, 10.0)
	var fc = await _open(A_FULL, Vector2(999.0, 999.0))
	if fc == null:
		_check(false, "바닥 마법진이 안 생겼다")
		return
	_check(fc.global_position.is_equal_approx(_player.global_position),
		"🔴 중심 = 발밑이지 총구(origin)가 아니다 — 실제 %s" % fc.global_position)
	_player.global_position = Vector2(140.0, -60.0)
	await process_frame
	await process_frame
	_check(fc.global_position.is_equal_approx(_player.global_position),
		"🔴 시전 중 걸으면 따라온다 — 발 %s vs 원 %s"
			% [_player.global_position, fc.global_position])
	_clear(fc)
	_player.global_position = Vector2.ZERO


## 🔴🔴 확정 ⑦(떼면 나간다) — 다 차도 **발사·취소가 올 때까지** 원은 열린 채 머문다.
## 그래서 `duration`을 수명으로 재면 **오래 들고 있을 때 원이 에러 없이 사라진다**.
## 🔴 여기서 `duration`을 **짧게(0.2s)** 주는 게 검출의 핵심이다: 옛 안전망은 `0.2 × 4 = 0.8초`에
##   자멸하므로 1.2초를 기다리면 정확히 그 회귀만 빨개진다(넉넉한 5초를 주면 자명 통과다).
## ⚠ **안전망 자체를 지우는 것도 답이 아니다** — 그러면 release/cancel이 둘 다 안 오는 경로에서
##   원이 영원히 발을 따라다닌다. 계약은 「홀드를 수명으로 세지 않는다」이지 「안 죽는다」가 아니다.
func _test_survives_hold() -> void:
	print("[10] 🔴 홀드 동안 바닥 마법진이 살아 있다 — duration은 채우는 시간이지 수명이 아니다")
	var fc = await _open(A_FULL, Vector2.ZERO, 0.2)
	if fc == null:
		_check(false, "바닥 마법진이 안 생겼다")
		return
	await _wait(1.2)   # 옛 안전망(_dur × _SAFETY_MULT = 0.8s) + 꺼지는 트윈까지 훌쩍 넘긴다
	_check(is_instance_valid(fc) and not fc.is_queued_for_deletion(),
		"🔴 다 찬 뒤에도 원이 살아 있다 (죽었으면 안전망이 홀드를 수명으로 센 것)")
	_check(_all_circles().size() == 1, "무대에 원이 그대로 1개 — 실제 %d개" % _all_circles().size())
	# 🔴 그래도 발사는 여전히 원을 닫는다 — 「안 죽는다」가 아니라 「홀드를 안 센다」가 계약이다.
	_bus.ring_cast_requested.emit(A_FULL, Vector2.ZERO, Vector2.RIGHT)
	await _wait(0.35)
	_check(_all_circles().is_empty(),
		"홀드 뒤 발사해도 정상적으로 닫힌다 — 실제 %d개 남음" % _all_circles().size())


# ── 헬퍼 ──────────────────────────────────────────────────────────────────────────

## 시전을 걸고 그 바닥 마법진 노드를 돌려준다. `duration` 기본값은 넉넉히 줘 스트립 중간에 안 죽게.
func _open(assembly: Dictionary, origin: Vector2 = Vector2.ZERO, duration: float = 5.0):
	for c in _all_circles():
		c.free()
	_bus.ring_cast_started.emit(assembly, origin, duration)
	await process_frame
	var found := _all_circles()
	return found[0] if not found.is_empty() else null


func _open_and_measure(assembly: Dictionary, check_z: String) -> float:
	var fc = await _open(assembly)
	if fc == null:
		_check(false, "바닥 마법진이 안 생겼다 (current_scene·핸들러 확인)")
		return 0.0
	if check_z == "z":
		# 🔴 값이 곧 계약이다 — 렌더 없이 읽힌다(설계 ⓑ).
		_check(fc.z_index == 1, "🔴 z_index == 1 (Ground 0 · 플레이어 2 사이) — 실제 %d" % fc.z_index)
	var r: float = fc.bounds_radius()
	_clear(fc)
	return r


func _open_and_count(assembly: Dictionary) -> int:
	var fc = await _open(assembly)
	if fc == null:
		return -1
	var n: int = fc.subpath_count()
	_clear(fc)
	return n


## 착탄을 한 번 터뜨리고 **바닥 데칼**(가장 큰 Line2D 링)의 반지름을 잰다.
## 🔴 플레어는 Polygon2D라 안 섞인다 — 데칼만 Line2D다(머즐은 이 신호로 안 난다).
func _impact_decal_radius(score: float) -> float:
	for c in _stage.get_children():
		if c is Line2D:
			c.free()
	_bus.spell_impact.emit(Vector2.ZERO, R_FIRE, score)
	await process_frame
	var r := 0.0
	for c in _stage.get_children():
		if c is Line2D:
			for p: Vector2 in (c as Line2D).points:
				r = maxf(r, p.length())
	return r


func _all_circles() -> Array:
	var out: Array = []
	for c in _stage.get_children():
		if c.get_script() == _fc_script:
			out.append(c)
	return out


func _clear(fc) -> void:
	if fc != null and is_instance_valid(fc):
		fc.free()


## ⚠ 트윈(cancel 0.10s · release 0.16s)이 끝나고 `queue_free`가 실제로 회수될 때까지 기다린다 —
##   프레임 수로 세면 fps에 따라 흔들린다(`vfx_shot`이 시간 기준 샘플링을 쓰는 것과 같은 이유).
func _wait(sec: float) -> void:
	await create_timer(sec).timeout
	await process_frame


## 이 시그널에 이 객체의 콜백이 하나라도 붙어 있나 (test_spell_vfx_auto와 같은 수법).
func _connected_to(sig: Signal, obj: Object) -> bool:
	for c in sig.get_connections():
		if (c["callable"] as Callable).get_object() == obj:
			return true
	return false


## 🔴 실패할 때만 찍는다 — 침묵이 곧 통과다(전 스위트 grep이 `_FAIL`만 본다).
func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL: %s" % label)
