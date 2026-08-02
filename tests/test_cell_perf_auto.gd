extends SceneTree
## 셀 격자 성능 실측 (설계 §11·§12).
##
## 🔴 **이 파일의 산출물은 통과/실패가 아니라 숫자다.** 설계의 CPU 추정치는
##  「GDScript VM ≈ 1,500만 연산/초」 가정 위에 있고 **불확실성이 ±3배**라, 그 표는
##  목표가 아니라 「어디를 재야 하는지의 지도」였다. 여기가 그 자리를 실측한다.
##
## 🔴 **평균과 최대를 둘 다 찍는다 — 프레임을 무너뜨리는 건 평균이 아니라 최대다.**
##
## ⚠ 벽시계(`Time.get_ticks_usec`)를 읽으므로 러너가 `--fixed-fps`를 **안 준다**. 그게 맞다.
## ⚠ 이 수치엔 렌더 업로드가 빠져 있다 — **상한이 아니라 하한이다.**
## ⚠ 판정 문턱은 설계 추정의 **10배**로 잡았다. 재앙적 회귀만 잡고, 기계 차이로는 안 흔들리게.

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
## 🔴 **실제 씬이 실제로 얼마를 쓰나** — 갇힌 픽스처의 수치는 실게임에 해당하지 않는다는 걸
##  한 번 크게 밟았다(리뷰 C2). 그래서 여기서 진짜 맵을 세워 잰다.
const LiquidSandbox := preload("res://src/sandbox/liquid_sandbox.gd")

const LIMIT_SWEEP_AVG_US := 50000  # 빈 전 격자 훑기 평균 (설계 추정 ~5ms)
const LIMIT_WORST_MAX_US := 500000  # 최악 시나리오 최대 (설계 추정 ~23ms)

## 🔴 **정작 중요한 숫자는 판정이 아니라 이것이다.** 틱 하나는 `_physics_process` 한 번 안에서
##  통째로 돌기 때문에, 60fps 프레임 예산 16,700μs를 넘는 순간 **그 프레임이 통째로 밀린다.**
##  문턱(위 둘)은 기계 차이를 피하려고 10배로 느슨하게 잡았다 — 그래서 **사람이 보는 숫자**로 찍는다.
const FRAME_BUDGET_US := 16700

var _pass := 0
var _fail := 0
var _toggle := false
var _probe: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("PERF ─ 단위 μs/틱. 20틱 기준 1틱 = 50,000μs 예산.")

	var sweep := _measure("빈 격자 전체 훑기", _build_empty, 300, true)
	var worst := _measure("최악 · 절반이 흐르는 물", _build_half_water, 400, false)
	var full := _measure("전 격자 물(꽉 참)", _build_full_water, 1000, false)
	var scene := _measure("실제 씬 맵", _build_real_map, 1000, false)
	var idle := _measure("정지 상태(전 청크 잠듦)", _build_idle, 300, false)

	_check("전 격자 훑기 평균", int(sweep["avg"]) < LIMIT_SWEEP_AVG_US,
		"%d μs (문턱 %d)" % [sweep["avg"], LIMIT_SWEEP_AVG_US])
	_check("최악 시나리오 최대", int(worst["max"]) < LIMIT_WORST_MAX_US,
		"%d μs (문턱 %d)" % [worst["max"], LIMIT_WORST_MAX_US])
	# 잠들지 않으면 설계 §11의 예산이 통째로 틀린다 — 성능 그물의 진짜 회귀 감지기가 이것이다.
	_check("정지 상태가 거의 공짜", int(idle["avg"]) < 2000, "%d μs" % idle["avg"])
	_check("꽉 찬 물은 잠든다", int(full["awake_end"]) == 0, "활성청크 %d" % full["awake_end"])
	# 🔴 실게임의 상시 지출. 예전엔 물이 영원히 진동해 **974μs가 영구**로 나갔다(리뷰 C1).
	#  이 둘이 그 회귀의 감지기다 — 「갇힌 픽스처에서 잰 1,200배」는 실게임에 해당하지 않았다.
	_check("실제 씬이 잠든다", int(scene["awake_end"]) == 0, "활성청크 %d" % scene["awake_end"])
	_check("실제 씬 상시 지출", int(scene["min"]) < 100, "정착 뒤 틱 %d μs" % scene["min"])

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_CELL_PERF_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_CELL_PERF_FAIL — %d개 실패" % _fail)
		quit(1)


func _check(label: String, cond: bool, detail: String) -> void:
	if cond:
		_pass += 1
		print("  ok  %s  %s" % [label, detail])
	else:
		_fail += 1
		print("FAIL: %s  %s" % [label, detail])


## `force_wake`면 매 틱 전에 청크마다 셀 하나를 토글해 **전 격자를 강제로 깨운다.**
## 설계 §11 첫 줄(「아무 일도 안 하는 데 드는 값」)을 재려면 이 길밖에 없다 —
## 시뮬에 테스트 전용 뒷문(`wake_all()`)을 뚫으면 그게 거짓 손잡이가 된다(SKILL.md T3).
func _measure(label: String, builder: Callable, ticks: int, force_wake: bool) -> Dictionary:
	var g: CellGrid = builder.call()
	var total := 0
	var mx := 0
	var mn := 1 << 40
	for _i in ticks:
		if force_wake:
			_poke_every_chunk(g)
		var t0 := Time.get_ticks_usec()
		g.step()
		var dt := Time.get_ticks_usec() - t0
		total += dt
		mx = maxi(mx, dt)
		mn = mini(mn, dt)
	var avg := total / maxi(1, ticks)
	print("PERF %-26s 틱%5d   평균 %7d   최대 %7d   최소 %7d   최대/프레임예산 %5.1f%%   끝활성 %3d/%d"
		% [label, ticks, avg, mx, mn, 100.0 * mx / FRAME_BUDGET_US, g.awake_count(), CellGrid.CHUNK_COUNT])
	return {"avg": avg, "max": mx, "min": mn, "awake_end": g.awake_count()}


## 커맨드 문을 통해서만 깨운다. 값이 실제로 바뀌어야 깨어나므로 매번 뒤집는다.
func _poke_every_chunk(g: CellGrid) -> void:
	_toggle = not _toggle
	var m := Mat.STONE if _toggle else Mat.EMPTY
	for i in _probe.size():
		var idx := _probe[i]
		var x := idx & CellGrid.X_MASK
		var y := idx >> CellGrid.X_SHIFT
		g.apply(CellGrid.cmd_fill(x, y, x, y, m))


func _build_empty() -> CellGrid:
	_probe = PackedInt32Array()
	for cy in CellGrid.CY:
		for cx in CellGrid.CX:
			var x := (cx << CellGrid.CHUNK_SHIFT) + 8
			var y := (cy << CellGrid.CHUNK_SHIFT) + 8
			_probe.append((y << CellGrid.X_SHIFT) | x)
	return CellGrid.new()


## 설계 §11의 위험선 — 화면 절반이 동시에 흐른다.
func _build_half_water() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 140, 255, 143, Mat.STONE))
	g.apply(CellGrid.cmd_fill(0, 0, 255, 71, Mat.WATER))
	return g


func _build_full_water() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 255, 143, Mat.WATER))
	return g


func _build_real_map() -> CellGrid:
	var g := CellGrid.new()
	LiquidSandbox.build_terrain_into(g)
	return g


func _build_idle() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 255, 143, Mat.STONE))
	for _i in 5:
		g.step()
	return g
