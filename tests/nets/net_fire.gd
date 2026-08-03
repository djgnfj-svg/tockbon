extends RefCounted
## 불 — 파면 목록 + 연료 (기획 판정 5: **번지고 · 돌에서 멈추고 · 결국 꺼진다**).
##
## 🔴🔴 **불의 총량을 상한으로 막지 않고 연료로 막는다**(GDD). 「탈 게 없으면 안 탄다」는
##  플레이어에게 **규칙**으로 읽히지만 「불이 N개를 넘으면 안 붙는다」는 같은 일을 하면서
##  **고장**으로 읽힌다. ⇒ 여기서 재는 것은 전부 「연료가 실제로 예산인가」다.
##
## ⚠ v1에서 번개가 안 꺼진 원인은 TTL이 아니라 **물의 왕복 버그**였다(움직이는 물이 매 틱
##  파면에 재등록됐다). 불은 안 움직이니 그 문제가 없고, **남은 원인은 「연료가 안 줄어드는 것」
##  하나뿐**이다 — 그래서 아래가 그걸 정면으로 잰다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## 나무 한 셀이 다 타는 데 걸리는 틱. 값을 여기 박지 않는다 — 둘 중 하나가 바뀌면
## 손으로 적은 숫자가 조용히 낡는다.
const BURN_TICKS := int(Mat.DEFS[Mat.WOOD]["fuel"]) / Tuning.FIRE_BURN_PER_TICK


func run(t) -> void:
	_ignite_rules(t)
	_fuel_drains(t)
	_spreads_through_wood(t)
	_stops_at_stone(t)
	_cannot_cross_air(t)
	_always_goes_out(t)
	_blast_lights_wood(t)
	_front_has_no_ghosts(t)
	_burn_slot_has_no_orphans(t)
	_reset_clears_front(t)


## 🔴🔴 **파면 = BURNING 칸의 집합.** 이 등식이 파면 자료구조의 전부다.
##
## ⚠ 폭발이 타는 칸을 지우면 `_flag`만 0이 되고 **인덱스는 파면에 남는다** —
##  실측으로 키 4에서 217칸 중 90칸(**41%**)이 유령이었다. 다음 틱에 스스로 빠지지만
##  그 자가 치유는 **「지워진 자리가 그대로 비어 있다」에 기대고 있다.**
## 🔴 물이나 지형 재생성이 들어와 그 자리가 나무로 다시 채워지면 유령이 진짜 버그가 된다:
##  새 나무가 `_aux` 0이라 다음 틱에 빈칸이 되고, 같은 칸이 파면에 두 번 들어간다.
## ⇒ 등식을 **그 틱 안에서** 잰다. 「다음 틱에 낫는다」로는 못 잰다.
func _front_has_no_ghosts(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 127, 63, Mat.WOOD))
	# 🔴 **폭발의 점화 고리로 태우면 안 된다** — 그 고리는 파괴 반경 **밖**(rd..ignite_r)에 있어서
	#  같은 자리에 다시 폭발해도 타는 칸을 안 덮는다. 그러면 이 검사가 통째로 헛돈다
	#  (처음에 그렇게 짰다가 유령을 되살려 놓고도 초록이 나왔다).
	#  ⇒ 폭발이 **덮을 자리**를 직접 태운다.
	for y in range(20, 45):
		for x in range(50, 80):
			g.ignite(x, y)
	var lit := g.burning_count()
	t.ok(lit > 0, "먼저 넓게 불이 붙는다 (%d칸)" % lit)
	t.eq(lit, _flagged(g), "붙인 직후 파면과 BURNING 칸 수가 같다")

	# 🔴 **타는 칸 한복판에 폭발을 얹는다.** 유령이 생기던 바로 그 순간이다.
	g.apply(CellGrid.cmd_blast(64, 32, Tuning.blast_rd(0), 0))
	t.ok(g.burning_count() < lit, "폭발이 타는 칸을 실제로 지웠다 (%d → %d)" % [lit, g.burning_count()])
	t.eq(g.burning_count(), _flagged(g), "타는 칸을 폭발로 지운 **그 틱에** 파면이 안 부푼다")

	# 한 틱 돌려도 등식이 유지되나(꺼짐 경로도 같은 문을 지나나).
	g.step()
	t.eq(g.burning_count(), _flagged(g), "한 틱 뒤에도 등식이 유지된다")


## 🔴🔴 **자리 표의 역방향 — 고아 슬롯.**
##  파면에 없는데 소속을 주장하는 칸은 `_ignite_cell`의 중복 가드에 막혀 **영영 다시 못 탄다.**
##  에러도 없고 화면에도 안 뜬다.
##
## ⚠ **`_flag` 등식으로는 못 잡는다.** `_write_cell`이 `_flag`는 제대로 지우므로 그쪽은 늘 맞고,
##  갈라지는 건 **세 번째 자료구조**인 자리 표뿐이다 — 실측으로 `_unburn`의 마지막 줄을 앞으로
##  옮기면 `_flag` 등식은 초록인 채 고아가 1 → 9 → 168칸으로 쌓였다.
## 🔴 **네 구간을 다 본다**: 붙인 직후 · 폭발로 지운 직후 · 다 타서 꺼진 뒤 · 리셋 뒤.
##  자기교환(`at == last`)은 「다 타서 꺼진 뒤」에서만 나온다.
func _burn_slot_has_no_orphans(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 127, 63, Mat.WOOD))
	for y in range(20, 45):
		for x in range(50, 80):
			g.ignite(x, y)
	t.eq(g.claimed_slot_count(), g.burning_count(), "붙인 직후 고아 슬롯이 없다")

	g.apply(CellGrid.cmd_blast(64, 32, Tuning.blast_rd(0), 0))
	t.eq(g.claimed_slot_count(), g.burning_count(), "폭발로 지운 직후 고아 슬롯이 없다")

	# 🔴 **다 태운다.** 마지막 한 칸이 빠질 때가 자기교환(`at == last`)이 도는 자리다.
	for _i in BURN_TICKS * 6:
		g.step()
		if g.burning_count() == 0:
			break
	t.eq(g.burning_count(), 0, "숲이 다 탄다")
	t.eq(g.claimed_slot_count(), 0, "다 타서 꺼진 뒤 고아 슬롯이 0이다")

	# 그리고 그 자리가 **다시 탈 수 있어야** 한다 — 고아가 남으면 중복 가드가 영영 막는다.
	g.apply(CellGrid.cmd_fill(60, 30, 70, 40, Mat.WOOD))
	t.ok(g.ignite(64, 32), "다 탔던 자리에 나무를 채우면 다시 붙는다")

	g.apply(CellGrid.cmd_reset())
	t.eq(g.claimed_slot_count(), 0, "리셋 뒤 고아 슬롯이 0이다")


## 격자에서 BURNING 비트가 선 칸 수. 🔴 파면 길이와 **독립적인** 측정이라 등식을 잴 수 있다.
func _flagged(g: CellGrid) -> int:
	var n := 0
	var flags := g.get_flag()
	for i in CellGrid.CELL_COUNT:
		if (flags[i] & Mat.FLAG_BURNING) != 0:
			n += 1
	return n


## 🔴 「탈 것이 있는 곳으로만」(GDD). 돌과 빈칸은 연료가 0이라 여기서 멈춘다.
func _ignite_rules(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 10, 10, Mat.WOOD))
	g.apply(CellGrid.cmd_fill(20, 10, 20, 10, Mat.STONE))

	t.ok(g.ignite(10, 10), "나무에는 불이 붙는다")
	t.eq(g.burning_count(), 1, "파면에 한 칸 올라간다")
	t.eq(g.flag_at(10, 10) & Mat.FLAG_BURNING, Mat.FLAG_BURNING, "타는 칸에 BURNING이 선다")
	t.eq(g.fuel_at(10, 10), int(Mat.DEFS[Mat.WOOD]["fuel"]), "연료가 재료 표에서 온다")

	t.ok(not g.ignite(20, 10), "돌에는 불이 안 붙는다")
	t.ok(not g.ignite(50, 50), "빈칸에는 불이 안 붙는다")
	t.ok(not g.ignite(10, 10), "이미 타는 칸에 두 번 안 올라간다")
	t.eq(g.burning_count(), 1, "파면 길이가 안 늘어난다")
	t.ok(not g.ignite(-1, 10), "격자 밖은 조용히 무시된다")


## 🔴🔴 **연료가 안 줄면 불이 영영 안 꺼진다.** 그게 v1이 남긴 유일한 후보다.
func _fuel_drains(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 10, 10, Mat.WOOD))
	g.ignite(10, 10)
	var before := g.fuel_at(10, 10)
	g.step()
	t.eq(g.fuel_at(10, 10), before - Tuning.FIRE_BURN_PER_TICK, "한 틱에 연료가 정확히 그만큼 준다")

	# 다 타면 목록에서 빠지고 **그 칸이 빈칸이 된다** — 안 그러면 불이 지나간 흔적이 화면에 0이다.
	for _i in BURN_TICKS:
		g.step()
	t.eq(g.burning_count(), 0, "연료가 0이면 파면에서 빠진다")
	t.eq(g.mat_at(10, 10), Mat.EMPTY, "다 탄 자리는 빈칸이 된다")
	t.eq(g.flag_at(10, 10) & Mat.FLAG_BURNING, 0, "꺼진 칸의 BURNING이 내려간다")
	t.eq(g.aux_at(10, 10), 0, "꺼진 칸의 연료 자리가 0으로 돌아간다")


func _spreads_through_wood(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 40, 10, Mat.WOOD))  # 가로 한 줄
	g.ignite(10, 10)
	var reach := 0
	for _i in BURN_TICKS:
		g.step()
		var x := 10
		while x <= 40 and (g.flag_at(x, 10) & Mat.FLAG_BURNING) != 0:
			x += 1
		reach = maxi(reach, x - 10)
	t.ok(reach > 1, "불이 이웃 나무로 번진다 (%d칸까지)" % reach)


## 🔴🔴 **판정 5의 본체.** 돌 한 칸이 불을 끊는다 — 「방마다 어떤 룬이 강한지가 지형으로
##  정해진다」(GDD)가 성립하려면 이게 참이어야 한다.
func _stops_at_stone(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 14, 10, Mat.WOOD))
	g.apply(CellGrid.cmd_fill(15, 10, 15, 10, Mat.STONE))   # 벽 한 칸
	g.apply(CellGrid.cmd_fill(16, 10, 20, 10, Mat.WOOD))    # 건너편 나무
	g.ignite(10, 10)
	for _i in BURN_TICKS * 3:
		g.step()
	t.eq(g.mat_at(15, 10), Mat.STONE, "돌은 안 탄다")
	# 🔴 건너편이 **한 칸도** 안 타야 한다. 대각까지 번지면 여기서 걸린다.
	var crossed := false
	for x in range(16, 21):
		if g.mat_at(x, 10) != Mat.WOOD:
			crossed = true
	t.ok(not crossed, "돌 건너편 나무는 안 탄다")
	t.eq(g.burning_count(), 0, "이쪽이 다 타고 나면 불이 0이다")


func _cannot_cross_air(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 14, 10, Mat.WOOD))
	g.apply(CellGrid.cmd_fill(16, 10, 20, 10, Mat.WOOD))    # 빈칸 한 칸 건너
	g.ignite(10, 10)
	for _i in BURN_TICKS * 3:
		g.step()
	var crossed := false
	for x in range(16, 21):
		if g.mat_at(x, 10) != Mat.WOOD:
			crossed = true
	t.ok(not crossed, "불이 허공을 못 건넌다 (이 단계에 물이 없어 연료가 유일한 규칙이다)")


## 🔴🔴 **반드시 꺼진다.** 나무를 통째로 채워도 유한하다 — 연료는 매 틱 줄고, 다 탄 칸은
##  빈칸이 되며, 빈칸은 연료가 0이라 **다시 못 붙는다.**
func _always_goes_out(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 63, 31, Mat.WOOD))
	var cells := g.count_material(Mat.WOOD)
	g.ignite(32, 16)

	var peak := 0
	var ticks := 0
	# 상한은 「번지는 데 걸리는 시간 + 한 칸이 타는 시간」보다 넉넉하게. 여기 걸리면 진짜 안 꺼진 것이다.
	var cap := 64 * Tuning.FIRE_SPREAD_TICKS + BURN_TICKS * 4
	while g.burning_count() > 0 and ticks < cap:
		g.step()
		peak = maxi(peak, g.burning_count())
		ticks += 1
	t.ok(g.burning_count() == 0, "나무 %d칸을 태우고도 %d틱 안에 꺼진다 (실제 %d틱)" % [cells, cap, ticks])
	t.ok(peak > 1, "한 번에 여러 칸이 탄다 (최대 %d칸)" % peak)
	# 🔴 안전망은 **평소에 도달하지 않아야 한다**(GDD). 여기 닿으면 값이 아니라 무대를 봐라.
	t.ok(peak < Tuning.MAX_BURNING,
		"총량 안전망(%d)에 평소엔 안 닿는다 (최대 %d)" % [Tuning.MAX_BURNING, peak])
	t.eq(g.count_material(Mat.WOOD), 0, "탈 것이 남지 않는다")


## 🔴🔴 **점화 반경이 파괴 반경보다 커야 한다.** 같으면 폭발이 자기가 태울 것을 먼저 지워서
##  **불이 원리적으로 안 붙고, 에러는 하나도 안 난다.**
func _blast_lights_wood(t) -> void:
	t.ok(Tuning.blast_ignite_r(0) > Tuning.blast_rd(0),
		"점화 반경 %d이 파괴 반경 %d보다 크다 (불의 유일한 진입로다)" % [
			Tuning.blast_ignite_r(0), Tuning.blast_rd(0)])

	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 127, 63, Mat.WOOD))
	g.apply(CellGrid.cmd_blast(64, 32, Tuning.blast_rd(0), Tuning.blast_ignite_r(0)))
	t.ok(g.burning_count() > 0, "폭발이 나무에 불을 붙인다 (%d칸)" % g.burning_count())
	# 구덩이 안은 이미 빈칸이라 안 탄다 — 타는 것은 **파괴 반경 밖의 고리**뿐이다.
	t.eq(g.flag_at(64, 32) & Mat.FLAG_BURNING, 0, "구덩이 한가운데는 안 탄다 (이미 빈칸이다)")
	t.eq(g.flag_at(64 + Tuning.blast_rd(0) + 2, 32) & Mat.FLAG_BURNING, Mat.FLAG_BURNING,
		"구덩이 바로 바깥 고리가 탄다")

	var stone := CellGrid.new()
	stone.apply(CellGrid.cmd_fill(0, 0, 127, 63, Mat.STONE))
	stone.apply(CellGrid.cmd_blast(64, 32, Tuning.blast_rd(0), Tuning.blast_ignite_r(0)))
	t.eq(stone.burning_count(), 0, "돌방에서는 폭발해도 불이 안 난다 (지형이 곧 룬의 세기다)")


## 🔴 리셋이 파면을 안 비우면, 새 지형의 **같은 인덱스**에 옛 불이 앉아 있다가
##  한 틱 뒤 그 칸을 빈칸으로 만든다 — R로 지은 새 무대에 구멍이 뚫린다.
func _reset_clears_front(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 20, 10, Mat.WOOD))
	g.ignite(10, 10)
	t.ok(g.burning_count() > 0, "먼저 불을 붙인다")

	g.apply(CellGrid.cmd_reset())
	t.eq(g.burning_count(), 0, "리셋이 파면을 비운다")

	g.apply(CellGrid.cmd_fill(10, 10, 20, 10, Mat.WOOD))
	var before := g.count_material(Mat.WOOD)
	g.step()
	t.eq(g.count_material(Mat.WOOD), before, "리셋 뒤 새 지형이 옛 불에 안 깎인다")
