extends SceneTree
## 셀 격자 규칙 그물 10개 (설계 §12).
##
## 🔴 「프로토타입이니까 테스트는 나중에」는 **거꾸로다**(SKILL.md T7).
##  질량 보존 · 좌우 편향 · 청크 경계 · 결정성 · 순서 역전은 **눈으로 절대 못 가른다.**
##  프로토타입이라서 더 필요하다.
##
## ⚠ 이 그물이 전부 그린이어도 「4px 물이 어색하다」는 답은 나올 수 있고 **그게 정당한 결과다.**
##  그물은 「구현이 맞다」가 아니라 「구현이 일관되다」까지만 잰다(SKILL.md §3).
##
## 시뮬이 `RefCounted`라 씬 없이 전부 돈다 — 설계 §8 ①의 배당금이다.

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
## 🔴 껍데기를 재는 게 아니라 **실제로 도는 지형과 그 빌더**를 세운다(그물 6d).
##  맵을 여기로 복사하면 지형이 바뀔 때 그물이 같이 안 늙는다.
const LiquidSandbox := preload("res://src/sandbox/liquid_sandbox.gd")

var _pass := 0
var _fail := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_net1_mass()
	_net2_fall()
	_net3_level()
	_net4_no_bias()
	_net5_chunk_boundary()
	_net6_sleep()
	_net6c_open_floor_sleep()
	_net6d_real_map_sleep()
	_net7_determinism()
	_net8_charge_only_wet()
	_net8e_charge_expires()
	_net9_order_matters()
	_net10_command_door()
	_net10b_shader_constants()
	_net11_no_double_move()
	_net12_settle_wake_opposite_dir()

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_CELL_GRID_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_CELL_GRID_FAIL — %d개 실패" % _fail)
		quit(1)


# ─── 도구 ─────────────────────────────────────────────────────────

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  ok  %s  %s" % [label, detail])
	else:
		_fail += 1
		print("FAIL: %s  %s" % [label, detail])


func _fill(g: CellGrid, x0: int, y0: int, x1: int, y1: int, m: int) -> void:
	g.apply(CellGrid.cmd_fill(x0, y0, x1, y1, m))


func _tick(g: CellGrid, n: int) -> void:
	for _i in n:
		g.step()


## 열별 물 개수 최댓값 — 수면이 평평해졌나를 재는 값.
func _max_column_water(g: CellGrid, x0: int, x1: int) -> int:
	var best := 0
	for x in range(x0, x1 + 1):
		var n := 0
		for y in CellGrid.H:
			if g.mat_at(x, y) == Mat.WATER:
				n += 1
		best = maxi(best, n)
	return best


func _count_water_below(g: CellGrid, y0: int) -> int:
	var n := 0
	var mat := g.get_mat()
	for y in range(y0, CellGrid.H):
		var row := y << CellGrid.X_SHIFT
		for x in CellGrid.W:
			if mat[row | x] == Mat.WATER:
				n += 1
	return n


## 열별 물 높이. 수면 모양을 재는 데 쓴다.
func _column_heights(g: CellGrid, x0: int, x1: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for x in range(x0, x1 + 1):
		var n := 0
		for y in CellGrid.H:
			if g.mat_at(x, y) == Mat.WATER:
				n += 1
		out.append(n)
	return out


func _count_water_where(g: CellGrid, x0: int, x1: int) -> int:
	var n := 0
	var mat := g.get_mat()
	for y in CellGrid.H:
		var row := y << CellGrid.X_SHIFT
		for x in range(x0, x1 + 1):
			if mat[row | x] == Mat.WATER:
				n += 1
	return n


# ─── 1. 질량 보존 ─────────────────────────────────────────────────
## 🔴 CA의 1급 그물이다. 이동 규칙 버그가 거의 다 여기 걸린다.
##  격자 밖을 고체로 취급하기 때문에 **정확히** 성립한다(≈가 아니다).
func _net1_mass() -> void:
	var g := CellGrid.new()
	_fill(g, 0, 140, 255, 143, Mat.STONE)
	_fill(g, 40, 100, 120, 103, Mat.STONE)
	_fill(g, 150, 80, 220, 83, Mat.STONE)
	_fill(g, 60, 60, 90, 63, Mat.STONE)
	_fill(g, 30, 10, 100, 30, Mat.WATER)
	_fill(g, 160, 5, 200, 25, Mat.WATER)

	var n0 := g.count_material(Mat.WATER)
	_tick(g, 400)
	var n1 := g.count_material(Mat.WATER)
	_check("1 질량보존", n0 == n1, "%d → %d" % [n0, n1])

	# `_aux`는 물에서 안 쓰인다 — 거짓 손잡이가 되지 않게 0을 강제한다(SKILL.md T3).
	var mat := g.get_mat()
	var flag := g.get_flag()
	var aux := g.get_aux()
	var bad := 0
	for i in CellGrid.CELL_COUNT:
		if mat[i] == Mat.WATER and (flag[i] & Mat.FLAG_CHARGED) == 0 and aux[i] != 0:
			bad += 1
	_check("1b 물 aux=0", bad == 0, "위반 %d칸" % bad)


# ─── 2. 낙하 ──────────────────────────────────────────────────────
func _net2_fall() -> void:
	var g := CellGrid.new()
	_fill(g, 0, 143, 255, 143, Mat.STONE)
	# 1칸 수직 통로 — 착지 뒤 좌우로 미끄러지지 않게 가둔다.
	_fill(g, 127, 0, 127, 142, Mat.STONE)
	_fill(g, 129, 0, 129, 142, Mat.STONE)
	g.apply(CellGrid.cmd_paint(128, 0, 0, Mat.WATER))

	_tick(g, 200)
	_check("2 낙하", g.mat_at(128, 142) == Mat.WATER, "y=142에 물")
	_check("2b 낙하 질량", g.count_material(Mat.WATER) == 1, "%d칸" % g.count_material(Mat.WATER))


# ─── 3. 평탄화 ────────────────────────────────────────────────────
## 물에 「양(level)」을 안 두기 때문에 **이동 규칙 둘이 전적으로 이 일을 한다.**
##
## 🔴 **기대치는 이론에서 나온다 — 실측에 맞춰 사후에 늘린 값이 아니다.**
##  · 대각 규칙(2)은 인접 열 높이차가 **2 이상**일 때 발동한다 ⇒ 정착 수면의 **인접 계단은 ≤ 1**이다.
##    이건 SLIDE_MAX와 무관한 **딱 떨어지는 계약**이라 그대로 잰다.
##  · 미끄러짐(3)은 「내려갈 데」가 SLIDE_MAX 안에 있을 때만 발동한다(C1 수정) ⇒ 단조 구간에서
##    **SLIDE_MAX칸에 1칸** 기울기까지만 눕는다. 32칸 폭·평균 2칸이면 최대 기둥은 그래서 2보다 크다.
## ⚠ **C1 수정 전에는 3이었고 지금은 4다.** 수평 분산이 약해진 대가이고, 리드가 받아들인 값이다
##  (언덕을 무너뜨리는 건 원래 대각 몫이지 미끄러짐 몫이 아니다).
const LEVEL_MAX_COLUMN := 4
const LEVEL_MAX_STEP := 1


func _net3_level() -> void:
	var g := CellGrid.new()
	_fill(g, 99, 130, 132, 133, Mat.STONE)  # 바닥
	_fill(g, 99, 110, 99, 130, Mat.STONE)  # 왼 벽
	_fill(g, 132, 110, 132, 130, Mat.STONE)  # 오른 벽
	_fill(g, 115, 60, 115, 123, Mat.WATER)  # 한 열에 64칸

	var n0 := g.count_material(Mat.WATER)
	_tick(g, 400)
	# 🔴 **평형에 도달했는지 먼저 확인한다** — 아직 흐르는 중이면 위 문턱은 아무것도 안 재는 값이다.
	_check("3a 400틱에 평형", g.awake_count() == 0, "활성청크 %d" % g.awake_count())
	var h := _max_column_water(g, 100, 131)
	_check("3 평탄화 최대 기둥", h <= LEVEL_MAX_COLUMN,
		"%d (문턱 %d · 물 %d→%d)" % [h, LEVEL_MAX_COLUMN, n0, g.count_material(Mat.WATER)])

	var heights := _column_heights(g, 100, 131)
	var step := 0
	for k in range(1, heights.size()):
		step = maxi(step, absi(heights[k] - heights[k - 1]))
	_check("3b 수면에 절벽 없음", step <= LEVEL_MAX_STEP,
		"인접 열 최대 높이차 %d (문턱 %d)" % [step, LEVEL_MAX_STEP])


# ─── 4. 좌우 편향 없음 ────────────────────────────────────────────
## 🔴 순회 순서 편향의 **유일한** 자동 검출기다. 눈으로는 100틱쯤 지나야 보인다.
##
## 🔴🔴 **픽스처가 거울 대칭이어야 한다: `x0 + x1 == W - 1`.** 처음엔 `112..144`(합 256)로 짜서
##  오른쪽에 한 열이 더 있었고, **그 어긋남이 진짜 편향을 부분 상쇄해 편향을 낮게 보이게 했다.**
##  픽스처의 비대칭은 측정값을 「크게」가 아니라 「작게」 만들 수도 있다 — 그래서 조용하다.
##
## ⚠ **이전 주석의 「잔여 비대칭은 표본과 무관한 가장자리 효과」는 틀렸다.** 실측이 반대였고
##  (절대값이 표본에 비례했다 = 계통 편향의 서명), 그 모델 위에 세운 문턱 8%도 근거가 없었다.
##  실제 원인은 C1(진동)이었다 — 정착 위치가 마지막 틱의 `dir`에 좌우됐다.
##  C1을 고치고 픽스처를 대칭으로 맞추자 편향이 **4.27% → 0.7%**로 떨어졌다.
## 🔴🔴 **흐르는 동안의 최댓값을 잰다 — 정착한 뒤의 한 점만 재면 검출력이 날아간다.**
##  실측(`dir`을 오른쪽으로 고정한 뮤테이션): t=20에 **17.4%**인데 t=200에는 **6.3%**로 내려앉는다.
##  물이 정착하면서 편향이 스스로 지워지기 때문이다. **끝만 보면 3배를 잃는다.**
##
## 문턱 3%의 근거(전부 실측):
##   기준선 최대 **0.76%** · `dir` 고정 뮤테이션 최대 **17.4%** ⇒ 위로 4배 · 아래로 6배 여유.
const BIAS_LIMIT_PCT := 3.0
const BIAS_SAMPLE_EVERY := 10
const BIAS_TICKS := 200


func _net4_no_bias() -> void:
	var g := CellGrid.new()
	_fill(g, 0, 120, 255, 123, Mat.STONE)
	_fill(g, 112, 79, 143, 119, Mat.WATER)  # 정중앙 32칸 폭 (112 + 143 = 255 = W-1)

	var peak := 0.0
	var worst := ""
	for _s in BIAS_TICKS / BIAS_SAMPLE_EVERY:
		_tick(g, BIAS_SAMPLE_EVERY)
		var l := 0
		var r := 0
		var mat := g.get_mat()
		for y in CellGrid.H:
			var row := y << CellGrid.X_SHIFT
			for x in CellGrid.W:
				if mat[row | x] == Mat.WATER:
					if x < CellGrid.W / 2:
						l += 1
					else:
						r += 1
		var pct := 100.0 * absf(float(l - r)) / maxf(1.0, float(l + r))
		if pct > peak:
			peak = pct
			worst = "t=%d L=%d R=%d" % [g.get_tick(), l, r]
	_check("4 좌우편향", peak <= BIAS_LIMIT_PCT,
		"최대 %.2f%% (%s · 문턱 %.0f%%)" % [peak, worst, BIAS_LIMIT_PCT])


# ─── 5. 청크 경계 통과 ────────────────────────────────────────────
## 🔴 설계 §5의 **1급 버그** 검출기다. 자기 청크만 깨우면 물이 청크 경계에서 얼어붙는다.
##  청크 1(셀 x=16..31)에서 일어난 쓰기가 청크 2(x=32~)를 깨워야 한다.
##
## ⚠ 픽스처를 「수평 흐름」에서 「바닥 구멍」으로 바꿨다 — C1 수정(내려갈 데가 있을 때만 미끄러진다)
##  이후로는 평평한 바닥 위 수평 이동이 아예 안 일어나서, 옛 픽스처가 깨우기와 무관하게 빨개졌다.
##  구멍은 대각 낙하를 부르고, 그 물은 여전히 **청크 2에 있다.** 재는 것은 그대로다.
func _net5_chunk_boundary() -> void:
	var g := CellGrid.new()
	_fill(g, 0, 80, 255, 83, Mat.STONE)  # 바닥 슬래브
	_fill(g, 32, 79, 40, 79, Mat.WATER)  # 청크 2에 얹힌 물

	_tick(g, 100)
	_check("5a 정착 후 잠듦", g.awake_count() == 0, "활성청크 %d" % g.awake_count())
	_check("5b 구멍 전 아래층 물 없음", _count_water_below(g, 80) == 0)

	# 🔴 쓰기는 **청크 1에서만** 일어난다(셀 x=31). 3×3 깨우기가 없으면 청크 2는 영영 안 깨어나고,
	#  바로 옆(x=32)의 물은 구멍이 뚫린 줄도 모른 채 얼어붙는다.
	_fill(g, 31, 80, 31, 83, Mat.EMPTY)
	_tick(g, 100)
	var fell := _count_water_below(g, 80)
	_check("5 청크경계 통과", fell > 0, "구멍으로 내려간 물 %d칸" % fell)


# ─── 6. 재우기 ────────────────────────────────────────────────────
## 안 잠들면 성능 예산(설계 §11)이 통째로 틀린다.
func _net6_sleep() -> void:
	var g := CellGrid.new()
	_fill(g, 0, 0, 255, 143, Mat.STONE)
	_fill(g, 100, 60, 115, 67, Mat.WATER)  # 돌에 완전히 갇힌 물주머니

	_tick(g, 30)
	_check("6 재우기", g.awake_count() == 0, "활성청크 %d" % g.awake_count())
	_check("6b 잠든 뒤 처리 0", g.step() == 0)


## 🔴🔴 **벽에 안 갇힌 물이 정착하나.** 그물 1~9의 물 시나리오가 하나도 빠짐없이 벽에 갇혀 있어서,
##  「평평한 바닥의 물이 영원히 ±SLIDE_MAX칸 진동한다」가 전 스위트 그린 뒤에 숨어 있었다.
##  ⇒ SKILL.md §3 *"전제가 틀리면 그물이 그 틀린 것을 굳힌다"*가 정확히 났던 자리다.
## ⚠ 이 그물은 **고치기 전에 세웠고 빨간 것을 확인했다**(활성 8·11·12). 순서가 증거다.
func _net6c_open_floor_sleep() -> void:
	# 한 방울 — 사방이 트인 바닥 위
	var a := CellGrid.new()
	_fill(a, 0, 120, 255, 123, Mat.STONE)
	a.apply(CellGrid.cmd_paint(60, 119, 0, Mat.WATER))
	_tick(a, 200)
	_check("6c 한 방울 정착", a.awake_count() == 0, "활성청크 %d" % a.awake_count())

	# 얕은 물층 — 깊이 1·2. 어느 쪽도 벽에 안 닿는다.
	for depth: int in [1, 2]:
		var g := CellGrid.new()
		_fill(g, 0, 120, 255, 123, Mat.STONE)
		_fill(g, 40, 120 - depth, 200, 119, Mat.WATER)
		var n0 := g.count_material(Mat.WATER)
		_tick(g, 400)
		_check("6c 물층 깊이%d 정착" % depth, g.awake_count() == 0,
			"활성청크 %d (물 %d→%d)" % [g.awake_count(), n0, g.count_material(Mat.WATER)])


## 🔴 **실제 씬 지형이 잠드나** — 이걸 아무 그물도 안 재고 있었고, 실게임에서
##  물이 다 고인 뒤에도 활성청크가 10/144로 영원히 떠 있었다.
func _net6d_real_map_sleep() -> void:
	var g := CellGrid.new()
	LiquidSandbox.build_terrain_into(g)
	var n0 := g.count_material(Mat.WATER)
	_tick(g, 1000)
	_check("6d 실제 씬 맵 정착", g.awake_count() == 0,
		"활성청크 %d (물 %d→%d)" % [g.awake_count(), n0, g.count_material(Mat.WATER)])
	_check("6d-b 씬 맵 질량 보존", g.count_material(Mat.WATER) == n0,
		"%d → %d" % [n0, g.count_material(Mat.WATER)])


# ─── 7. 결정성 ────────────────────────────────────────────────────
## 🔴 멀티의 전제다(설계 §8 ④). `randi()`나 부동소수점이 새어 들어오면 여기서 잡힌다.
func _net7_determinism() -> void:
	var script: Array[Dictionary] = [
		{"tick": 1, "cmd": CellGrid.cmd_fill(0, 140, 255, 143, Mat.STONE)},
		{"tick": 1, "cmd": CellGrid.cmd_fill(60, 100, 140, 101, Mat.STONE)},
		{"tick": 2, "cmd": CellGrid.cmd_fill(80, 10, 120, 30, Mat.WATER)},
		{"tick": 150, "cmd": CellGrid.cmd_paint(100, 60, 6, Mat.WATER)},
		{"tick": 300, "cmd": CellGrid.cmd_strike(100, 139)},
		{"tick": 600, "cmd": CellGrid.cmd_fill(70, 120, 90, 121, Mat.EMPTY)},
	]
	var a := _run_scripted(script, 1000)
	var b := _run_scripted(script, 1000)
	_check("7 결정성 mat", a.get_mat() == b.get_mat())
	_check("7b 결정성 flag", a.get_flag() == b.get_flag())
	_check("7c 결정성 aux", a.get_aux() == b.get_aux())


func _run_scripted(script: Array[Dictionary], ticks: int) -> CellGrid:
	var g := CellGrid.new()
	for t in range(1, ticks + 1):
		for e: Dictionary in script:
			if int(e["tick"]) == t:
				g.apply(e["cmd"])
		g.step()
	return g


# ─── 8. 전기는 젖은 데로만 ────────────────────────────────────────
func _net8_charge_only_wet() -> void:
	var g := _make_two_pools()
	_tick(g, 40)  # 물 정착 + 벽 젖음
	g.apply(CellGrid.cmd_strike(50, 115))
	_tick(g, 20)  # TTL(30)이 끝나기 전에 잰다

	var mat := g.get_mat()
	var flag := g.get_flag()
	var charged := 0
	var illegal := 0
	var in_pool_b := 0
	var wet_stone_charged := 0
	for i in CellGrid.CELL_COUNT:
		if (flag[i] & Mat.FLAG_CHARGED) == 0:
			continue
		charged += 1
		var x := i & CellGrid.X_MASK
		var conducts := mat[i] == Mat.WATER or (mat[i] != Mat.EMPTY and (flag[i] & Mat.FLAG_WET) != 0)
		if not conducts:
			illegal += 1
		if mat[i] == Mat.STONE:
			wet_stone_charged += 1
		if x >= 150 and x <= 170:
			in_pool_b += 1

	_check("8 전기 퍼짐", charged > 20, "전하 %d칸" % charged)
	_check("8b 전도체에만", illegal == 0, "비전도 셀에 전하 %d칸" % illegal)
	_check("8c 젖은 지형이 전도", wet_stone_charged > 0, "젖은 돌 %d칸" % wet_stone_charged)
	_check("8d 떨어진 웅덩이엔 안 감", in_pool_b == 0, "구덩이 B 전하 %d칸" % in_pool_b)


## 🔴 「퍼진다」만 재고 **「꺼진다」를 아무도 안 쟀다.** 측정 ②는 「쳤다 → 퍼졌다 → 꺼졌다」의
##  셋이 다 보여야 손에 잡힌다. 영구 발광하는 웅덩이는 순서가 아니라 고장으로 읽힌다.
## ⚠ **두 픽스처를 다 넣어야** 한다 — 갇힌 웅덩이로는 원래 통과했고, 열린 바닥에서만 빨갰다.
##  움직이는 물이 매 틱 `_charge_front`에 재등록되면서 전하가 TTL을 무시하고 재점화되던 것이다.
func _net8e_charge_expires() -> void:
	# ① 벽에 갇힌 웅덩이
	var a := _make_two_pools()
	_tick(a, 40)
	a.apply(CellGrid.cmd_strike(50, 115))
	_tick(a, CellGrid.CHARGE_TTL * 4)
	_check("8e 갇힌 물 전하 소멸", a.count_flag(Mat.FLAG_CHARGED) == 0,
		"전하 %d칸 · 활성 %d" % [a.count_flag(Mat.FLAG_CHARGED), a.awake_count()])

	# ② 벽에 안 갇힌 물층 — C1의 파생 버그가 사는 자리다.
	var b := CellGrid.new()
	_fill(b, 0, 120, 255, 123, Mat.STONE)
	_fill(b, 40, 118, 200, 119, Mat.WATER)
	_tick(b, 200)
	b.apply(CellGrid.cmd_strike(120, 119))
	var peak := 0
	for _i in CellGrid.CHARGE_TTL:
		b.step()
		peak = maxi(peak, b.count_flag(Mat.FLAG_CHARGED))
	_tick(b, CellGrid.CHARGE_TTL * 4)
	_check("8e-b 열린 물 전하 퍼짐", peak > 20, "최대 전하 %d칸" % peak)
	_check("8e-c 열린 물 전하 소멸", b.count_flag(Mat.FLAG_CHARGED) == 0,
		"전하 %d칸 · 활성 %d" % [b.count_flag(Mat.FLAG_CHARGED), b.awake_count()])


## 서로 안 닿는 물웅덩이 둘 — 사이는 마른 돌이다.
func _make_two_pools() -> CellGrid:
	var g := CellGrid.new()
	_fill(g, 0, 0, 255, 143, Mat.STONE)
	_fill(g, 40, 100, 60, 120, Mat.EMPTY)
	_fill(g, 150, 100, 170, 120, Mat.EMPTY)
	_fill(g, 40, 110, 60, 120, Mat.WATER)
	_fill(g, 150, 110, 170, 120, Mat.WATER)
	return g


# ─── 9. 순서 역전 ─────────────────────────────────────────────────
## 🔴 **「순서가 다르면 결과가 다르다」의 자동 증명**이다(GDD 「세상 상태」).
##  체감은 못 재도 규칙은 잰다.
func _net9_order_matters() -> void:
	# A: 적신 다음 번개
	var a := _make_two_pools()
	_tick(a, 40)
	a.apply(CellGrid.cmd_strike(50, 115))
	_tick(a, 20)
	var ca := a.count_flag(Mat.FLAG_CHARGED)

	# B: 번개 먼저(마른 자리) → 그 다음 물
	var b := CellGrid.new()
	_fill(b, 0, 0, 255, 143, Mat.STONE)
	_fill(b, 40, 100, 60, 120, Mat.EMPTY)
	_fill(b, 150, 100, 170, 120, Mat.EMPTY)
	b.apply(CellGrid.cmd_strike(50, 115))
	_fill(b, 40, 110, 60, 120, Mat.WATER)
	_fill(b, 150, 110, 170, 120, Mat.WATER)
	_tick(b, 60)
	var cb := b.count_flag(Mat.FLAG_CHARGED)

	_check("9 순서 역전", ca > 20 and cb == 0, "먼저적심=%d · 먼저번개=%d" % [ca, cb])

	# 🔴 마른 돌에 그냥 치면 아무 일도 안 난다.
	#  ⚠ 위 A/B 비교만으로는 이걸 못 잰다 — B에서 물을 칠하면 `_write_cell`이 플래그를 지워서
	#   `_strike`의 전도 검사가 죽어 있어도 결과가 0으로 나온다(뮤테이션으로 확인한 사각이다).
	var c := CellGrid.new()
	_fill(c, 0, 0, 255, 143, Mat.STONE)
	c.apply(CellGrid.cmd_strike(100, 100))
	_tick(c, 5)
	_check("9b 마른 곳 번개 무효", c.count_flag(Mat.FLAG_CHARGED) == 0,
		"전하 %d칸" % c.count_flag(Mat.FLAG_CHARGED))


# ─── 10. 커맨드 문 ────────────────────────────────────────────────
## `apply()` 밖에서 격자를 못 바꾼다(설계 §8 ②).
##
## 🔴 처음엔 「`get_mat()`이 CoW 사본이라 밖에서 고쳐도 안전하다」로 짰는데 **틀렸다** —
##  돌려받은 `PackedByteArray`에 쓰면 격자가 실제로 바뀐다(이 그물이 잡았다).
##  ⇒ 언어가 안 막아주므로, **공개 표면에 커맨드 문을 우회하는 메서드가 생기는 것**을 잡는다.
##  누가 `set_cell()` 같은 걸 열면 여기가 빨개진다.
## ⚠ **여기에 이름을 더하는 건 「커맨드 문 밖의 쓰기 문을 하나 더 축복한다」는 뜻이다.**
##  `reset`이 정확히 그렇게 들어와 있었다 — 더하기 전에 `apply()`의 커맨드로 갈 수 있는지 먼저 봐라.
const PUBLIC_API: Array[String] = [
	"step", "apply",
	"cmd_paint", "cmd_fill", "cmd_strike", "cmd_reset",
	"get_mat", "get_flag", "get_aux", "get_tick", "awake_count",
	"mat_at", "flag_at", "aux_at", "conducts_at", "count_material", "count_flag",
]


func _net10_command_door() -> void:
	var g := CellGrid.new()
	_fill(g, 0, 140, 255, 143, Mat.STONE)

	var extra: Array[String] = []
	for m: Dictionary in g.get_script().get_script_method_list():
		var n := String(m["name"])
		if n.begins_with("_"):
			continue
		if not PUBLIC_API.has(n):
			extra.append(n)
	_check("10 공개 표면", extra.is_empty(), "커맨드 문 밖의 공개 메서드 %s" % str(extra))

	var before := g.get_mat().duplicate()
	g.apply(CellGrid.cmd_paint(-50, -50, 3, Mat.WATER))
	g.apply(CellGrid.cmd_fill(300, 200, 400, 300, Mat.WATER))
	g.apply(CellGrid.cmd_strike(-1, -1))
	_check("10c 격자 밖 커맨드 무해", g.get_mat() == before)

	# 재료 표가 팔레트·거동과 어긋나면 「쏘는 것 ≠ 보이는 것」이 조용히 난다(SKILL.md T8).
	var pal := Mat.bake_palette()
	var beh := Mat.bake_behavior()
	var missing := 0
	for id: int in Mat.ALL:
		if pal[id] == Mat.MISSING_COLOR:
			missing += 1
	_check("10d 팔레트 전원 정의됨", missing == 0, "빠진 재료 %d개" % missing)
	_check("10e 거동표", beh[Mat.WATER] == Mat.BEHAVIOR_LIQUID and beh[Mat.STONE] == Mat.BEHAVIOR_STATIC)
	_check("10f 팔레트 크기", pal.size() == Mat.SLOT_COUNT and Mat.SLOT_COUNT == 16)


## 🔴 셰이더에 **같은 상수가 두 벌** 있다 — 색은 주입해서 단일 소스지만 **비트 값은 손으로 맞춰져 있다.**
##  한쪽만 바꾸면 에러 없이 색만 틀어지고, 헤드리스에는 렌더러가 없어 아무도 못 본다.
##  ⇒ 셰이더를 **텍스트로** 읽어 값이 같은지 본다. 셰이더를 안 띄우고도 드리프트가 잡힌다.
const SHADER_PATH := "res://src/world/cells/cell_grid.gdshader"


func _net10b_shader_constants() -> void:
	var f := FileAccess.open(SHADER_PATH, FileAccess.READ)
	if f == null:
		_check("10g 셰이더 읽기", false, "파일을 못 연다: %s" % SHADER_PATH)
		return
	var src := f.get_as_text()
	f.close()
	var want_wet := "const int FLAG_WET = %d;" % Mat.FLAG_WET
	var want_chg := "const int FLAG_CHARGED = %d;" % Mat.FLAG_CHARGED
	var want_pal := "uniform vec4 palette[%d];" % Mat.SLOT_COUNT
	_check("10g 셰이더 FLAG_WET", src.contains(want_wet), want_wet)
	_check("10h 셰이더 FLAG_CHARGED", src.contains(want_chg), want_chg)
	_check("10i 셰이더 팔레트 크기", src.contains(want_pal), want_pal)


## 🔴🔴 **한 셀은 한 틱에 두 번 움직이지 않는다.** 「이동 플래그 없이 순회 순서만으로 된다」가
##  이 설계의 핵심 전제인데, 깨지면 **물이 몰래 빨라질 뿐 아무 그물도 안 울린다.**
##  ⚠ 실측이다: 행 순회를 뒤집는 뮤테이션이 나머지 그물 **전부를 통과**했다(예전엔 평탄화 문턱이
##   우연히 잡았는데, C1 수정으로 그 문턱이 3→4로 풀리면서 그 우연이 사라졌다).
##  ⇒ 우연에 기대지 말고 **변위를 직접 잰다.** 계단이 청크 열 경계(16셀)와 밴드 행 경계를 여러 번 지난다.
func _net11_no_double_move() -> void:
	var g := CellGrid.new()
	# 오른쪽으로 내려가는 계단 — 한 단이 폭 3셀 · 높이 2셀.
	for k in 30:
		var sx := 10 + k * 3
		var sy := 30 + k * 2
		_fill(g, sx, sy, sx + 2, CellGrid.H - 1, Mat.STONE)
	g.apply(CellGrid.cmd_paint(11, 0, 0, Mat.WATER))

	var prev := Vector2i(11, 0)
	var max_dx := 0
	var max_dy := 0
	var moved := 0
	for _i in 400:
		g.step()
		var p := _find_only_water(g)
		if p.x < 0:
			break
		var dx := absi(p.x - prev.x)
		var dy := absi(p.y - prev.y)
		if dx > 0 or dy > 0:
			moved += 1
		max_dx = maxi(max_dx, dx)
		max_dy = maxi(max_dy, dy)
		prev = p

	_check("11 한 틱 수평 변위 ≤ SLIDE_MAX", max_dx <= CellGrid.SLIDE_MAX,
		"최대 %d (SLIDE_MAX %d)" % [max_dx, CellGrid.SLIDE_MAX])
	_check("11b 한 틱 수직 변위 ≤ 1", max_dy <= 1, "최대 %d" % max_dy)
	# 🔴 헛통과 방지 — 물이 아예 안 움직이면 위 둘은 0으로 조용히 그린이다(SKILL.md T2).
	_check("11c 실제로 움직였다", moved > 50, "움직인 틱 %d" % moved)


## 🔴🔴 **정착한 물의 「반대 방향으로는 갈 수 있나」 검사가 살아 있나**(`_move_water` 규칙 4).
##
## ⚠ **재우기 그물(6c·6d)로는 이걸 구조적으로 못 잡는다** — 깨우기를 빼면 격자는 **더 빨리** 잠들어서
##  `awake_count() == 0`이 오히려 더 잘 통과한다. 리드 뮤테이션이 그 구멍을 찾았다.
##  ⇒ **「잠들었나」가 아니라 「물이 도착했나」를 재야 한다.**
##
## 픽스처: **한쪽으로만 내려갈 데가 있는** 얇은 선반. 물은 `dir`이 왼쪽인 틱에만 움직일 수 있다.
##  구멍을 뚫은 바로 다음 틱의 `dir`이 **오른쪽(불리)**이면 물은 그 틱에 아무것도 안 쓰고,
##  검사가 없으면 청크가 잠들어 **영영 그 자리에 굳는다.** 화면에는 「물이 좀 이상하게 걸렸네」로만 보인다.
## 🔴 **두 패리티를 다 돌린다** — 한쪽만 돌리면 앞의 틱 수를 하나만 바꿔도 조용히 무력해진다.
func _net12_settle_wake_opposite_dir() -> void:
	for parity: int in [0, 1]:
		var g := CellGrid.new()
		_fill(g, 90, 100, 120, 100, Mat.STONE)  # 아래가 허공인 얇은 선반
		g.apply(CellGrid.cmd_paint(102, 99, 0, Mat.WATER))
		_tick(g, 40 + parity)
		_check("12-%d 정착·잠듦" % parity,
			g.awake_count() == 0 and g.mat_at(102, 99) == Mat.WATER,
			"활성 %d · 제자리 %s" % [g.awake_count(), g.mat_at(102, 99) == Mat.WATER])

		# 왼쪽 3칸 아래에만 구멍을 뚫는다(같은 청크라 한 틱은 깨어난다).
		# 🔴 재는 것은 **그 다음 틱에도 깨어 있나**이고, 그게 정착 검사가 하는 일이다.
		_fill(g, 99, 100, 99, 100, Mat.EMPTY)
		_tick(g, 100)
		var fell := _count_water_below(g, 101)
		_check("12-%d 반대 방향으로 빠져나감" % parity, fell == 1,
			"구멍 아래 물 %d칸 (선반에 남음 %s)" % [fell, g.mat_at(102, 99) == Mat.WATER])


## 격자에 물이 딱 하나라는 전제. 없으면 (-1,-1).
func _find_only_water(g: CellGrid) -> Vector2i:
	var mat := g.get_mat()
	for i in CellGrid.CELL_COUNT:
		if mat[i] == Mat.WATER:
			return Vector2i(i & CellGrid.X_MASK, i >> CellGrid.X_SHIFT)
	return Vector2i(-1, -1)
