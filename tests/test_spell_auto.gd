extends SceneTree
## 마법 시뮬 그물 — 설계 §10의 N-시리즈 중 **시뮬 것**(N1~N10 · N12).
##
## 🔴 「프로토타입이니까 그물은 나중에」는 **거꾸로다**(SKILL.md T7).
##  위력 비율 · 관통 통과/불통 · 터널링 · 패스 순서는 **눈으로 절대 못 가른다.**
##  한 프레임에 지나가거나, 숫자가 두 배인지 네 배인지가 화면에서 안 읽히거나 둘 중 하나다.
##
## ⚠ 이 그물이 전부 그린이어도 **「그래도 안 세 보인다」는 답은 나올 수 있고 그게 정당하다.**
##  그물은 「구현이 맞다」가 아니라 「구현이 일관되다」까지만 잰다(SKILL.md §3).
##
## `SpellSim`이 `RefCounted`라 씬 없이 전부 돈다 — `CellGrid`와 같은 배당금이다.

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
const SpellSim := preload("res://src/world/spell/spell_sim.gd")
const Tuning := preload("res://src/world/spell/spell_tuning.gd")

var _pass := 0
var _fail := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_net1_power_to_hole()
	_net2_power_to_pierce()
	_net3_power_to_residue()
	_net4_assembly_order_persists()
	_net5_pass_order()
	_net6_no_tunneling()
	_net7_limits()
	_net8_tier_table()
	_net9_sleeps_after_blast()
	_net10_public_surface()
	_net12_sim_source_is_integer_only()

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_SPELL_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_SPELL_FAIL — %d개 실패" % _fail)
		quit(1)


# ─── 도구 ─────────────────────────────────────────────────────────

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  ok  %s  %s" % [label, detail])
	else:
		_fail += 1
		print("FAIL: %s  %s" % [label, detail])


func _tick(g: CellGrid, n: int) -> void:
	for _i in n:
		g.step()


## 전 격자 돌. 폭발이 「무엇을 지웠나」를 세는 픽스처의 바닥이다.
func _solid_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	return g


## 폭발 중심. 🔴 최대 잔여 반경 36이 격자 안에 통째로 들어가야 비율이 안 잘린다
##  (가장자리에 놓으면 원이 잘려서 P3만 작게 나오고, 그게 「튜닝 문제」로 오독된다).
const CX := 128
const CY := 72


func _blast(g: CellGrid, tier: int, element: int) -> void:
	g.apply(SpellSim.blast_cmd(CX, CY, tier, element))


func _count_water_below(g: CellGrid, y0: int) -> int:
	var n := 0
	var mat := g.get_mat()
	for y in range(y0, CellGrid.H):
		var row := y << CellGrid.X_SHIFT
		for x in CellGrid.W:
			if mat[row | x] == Mat.WATER:
				n += 1
	return n


## 두 값의 비 — 앞이 0이면 -1(판정에서 걸러진다).
func _ratio(a: int, b: int) -> float:
	if a <= 0:
		return -1.0
	return float(b) / float(a)


# ─── N1. 위력 → 구멍 ──────────────────────────────────────────────
## 🔴🔴 **v1이 죽은 자리 그 자체다.** 위력이 78 → 157로 두 배가 되는데 화면에서 바뀐 게 0개였다.
##
## 🔴 **절대값이 아니라 비율을 잰다.** 표를 손으로 조여도 이 그물은 안 늙는다 —
##  누가 「밸런스」로 P2를 P1 수준까지 내리면 그때 빨개진다.
##
## 기대치는 **이론에서 나온다**: 단마다 반경 ×2 ⇒ 면적 ×4.
##  정수 원반 실제 칸수(113 / 437 / 1789)로 계산한 비는 3.87·4.09라 창 [3.5, 4.5] 안이다.
## ⚠ 원소는 **번개**를 쓴다 — 물이면 채우기 패스가 구멍에 물을 부어 「무엇이 사라졌나」와 섞인다.
const AREA_RATIO_MIN := 3.5
const AREA_RATIO_MAX := 4.5


func _net1_power_to_hole() -> void:
	var holes: Array[int] = []
	for tier in Tuning.SIM_TIERS.size():
		var g := _solid_grid()
		var before := g.count_material(Mat.STONE)
		_blast(g, tier, Tuning.ELEM_BOLT)
		holes.append(before - g.count_material(Mat.STONE))

	_check("1 구멍이 실제로 난다", holes[0] > 0, "P1 파괴 %d칸" % holes[0])
	for k in range(1, holes.size()):
		var r := _ratio(holes[k - 1], holes[k])
		_check("1-%d 파괴 면적 ×4" % (k + 1), r >= AREA_RATIO_MIN and r <= AREA_RATIO_MAX,
			"P%d→P%d = %d→%d칸 (비 %.2f · 창 %.1f~%.1f)"
			% [k, k + 1, holes[k - 1], holes[k], r, AREA_RATIO_MIN, AREA_RATIO_MAX])


# ─── N2. 위력 → 관통 ──────────────────────────────────────────────
## 🔴 **「종류가 다르다」의 자동 증명이다.** 관통은 통과/불통이 갈리는 축이라 스칼라가 아니다
##  (설계 §1.4). P1은 2타일 벽 앞에서 터지고, P2·P3는 **벽 속에서** 터져 뚫고 나간다.
##
## 🔴🔴 **폭발이 일어난 셀을 직접 잰다 — 「벽이 뚫렸나」로는 관통을 못 잰다.**
##  실측이다: 설계가 적은 대로 「P1은 못 뚫고 P2·P3는 뚫는다」만 재게 짰더니 **관통을 통째로
##  0으로 죽이는 뮤테이션이 그대로 통과했다.** P2의 반경(12)만으로도 두께 8셀 벽은 뚫리기 때문이다.
##  ⇒ 그 그물은 반경을 재고 있었지 관통을 재고 있지 않았다(SKILL.md §3 「전제가 틀리면
##   그물이 그 틀린 것을 굳힌다」의 교과서다).
##
## 관통의 **유일한 관측 가능한 서명**은 폭발 중심의 깊이다:
##   벽 진입 칸이 x=WALL_X0이고 예산이 p면 **폭발은 정확히 x = WALL_X0 + p에서** 난다.
##   P1은 벽 표면에서 터지고(반원 자국) P3는 **벽 속 6셀 지점에서** 터진다(벽 안에 방이 생긴다).
##
## 픽스처: 두께 8셀(2타일) 벽. 원점은 벽에서 50셀 왼쪽이라 진입 칸이 늘 WALL_X0다.
## ⚠ 번개를 쓴다 — 물이면 채운 물이 뚫린 구멍으로 흘러 판정을 흐린다.
const WALL_X0 := 100
const WALL_X1 := 107


func _net2_power_to_pierce() -> void:
	for tier in Tuning.SIM_TIERS.size():
		var g := CellGrid.new()
		g.apply(CellGrid.cmd_fill(WALL_X0, 0, WALL_X1, CellGrid.H - 1, Mat.STONE))
		var s := SpellSim.new()
		s.fire(SpellSim.cmd_fire(50, CY, 1, 0, tier, Tuning.ELEM_BOLT))
		var at := -1
		for _i in 30:
			g.step()
			for b: Dictionary in s.step(g):
				if at < 0:
					at = int(b["x"])
		var pierce := int(Tuning.SIM_TIERS[tier]["pierce"])
		_check("2-P%d 벽 속 %d셀에서 터진다" % [tier + 1, pierce], at == WALL_X0 + pierce,
			"폭발 x=%d (기대 %d = 진입 %d + 관통 %d)" % [at, WALL_X0 + pierce, WALL_X0, pierce])

		# 그 결과로 갈리는 게임플레이 사실 — 관통이 0인 P1만 2타일 벽을 못 넘긴다.
		var through := g.mat_at(WALL_X1, CY) == Mat.EMPTY
		_check("2-P%d 2타일 벽 %s" % [tier + 1, "뚫는다" if pierce > 0 else "못 뚫는다"],
			through == (pierce > 0), "뒷면(x=%d) %s" % [WALL_X1, "EMPTY" if through else "남음"])


# ─── N3. 위력 → 잔여 ──────────────────────────────────────────────
## 🔴 **`r_res > r_dest`가 아니면 잔여가 전부 EMPTY 위에 떨어져 조용히 0이 된다.**
##  `_wet_one`이 EMPTY·WATER를 건너뛰기 때문에 에러도 경고도 없다.
## ⇒ 「테두리에 실제로 상태가 남았나」를 먼저 재고, 그 다음 단마다 ×4인지 잰다.
##
## ⚠ **폭발 직후에 잰다 — 틱을 돌리면 채운 물이 흘러 젖음을 더 만든다**(재는 축이 섞인다).
func _net3_power_to_residue() -> void:
	var wets: Array[int] = []
	for tier in Tuning.SIM_TIERS.size():
		var t: Dictionary = Tuning.SIM_TIERS[tier]
		_check("3-P%d 잔여 반경 > 파괴 반경" % (tier + 1), int(t["rr"]) > int(t["rd"]),
			"rr=%d rd=%d" % [t["rr"], t["rd"]])
		var g := _solid_grid()
		_blast(g, tier, Tuning.ELEM_WATER)
		wets.append(g.count_flag(Mat.FLAG_WET))

	_check("3 테두리에 잔여가 남는다", wets[0] > 0, "P1 젖음 %d칸" % wets[0])
	for k in range(1, wets.size()):
		var r := _ratio(wets[k - 1], wets[k])
		_check("3-%d 잔여 면적 ×4" % (k + 1), r >= AREA_RATIO_MIN and r <= AREA_RATIO_MAX,
			"P%d→P%d = %d→%d칸 (비 %.2f)" % [k, k + 1, wets[k - 1], wets[k], r])


# ─── N4. 조립 순서가 세상에 남는다 ────────────────────────────────
## 🔴🔴 **이 게임의 테제를 헤드리스로 재는 유일한 그물이다.**
##  GDD 근거: *"타일이 젖음 그상테에서 번개날리면 전기물 막이런거"*
##
##  ⓐ 마른 돌에 P2 번개 → 전하 Na
##  ⓑ 같은 자리에 P2 **물** → 정착 → 같은 P2 번개 → 전하 Nb
##
## 🔴 **설계는 「Nb/Na ≥ K」를 적었지만 Na가 정확히 0이라 비가 정의되지 않는다.**
##  ⇒ 비 대신 **두 갈래를 따로** 잰다. 그게 더 세다 — 「마른 돌에는 아무 데도 안 간다」가
##   규칙의 핵심인데 비로 재면 Na가 1이든 0이든 통과해 버린다.
##
## Nb 문턱 200의 근거(이론): 채운 물 원반 r=6 ≈ 113칸 + 젖은 테두리 r 12~18 ≈ 565칸.
##  둘 다 r ≤ 18 안이라 번개 폭발의 `_strike`가 직접 닿는다 ⇒ 200은 그 절반도 안 되는 보수값이다.
const N4_MIN_CHARGED := 200
const N4_SETTLE_TICKS := 300
const N4_READ_TICKS := 10


func _net4_assembly_order_persists() -> void:
	# ⓐ 마른 돌
	var a := _solid_grid()
	_blast(a, 1, Tuning.ELEM_BOLT)
	_tick(a, N4_READ_TICKS)
	var na := a.count_flag(Mat.FLAG_CHARGED)

	# ⓑ 먼저 적신다
	var b := _solid_grid()
	_blast(b, 1, Tuning.ELEM_WATER)
	_tick(b, N4_SETTLE_TICKS)
	_blast(b, 1, Tuning.ELEM_BOLT)
	_tick(b, N4_READ_TICKS)
	var nb := b.count_flag(Mat.FLAG_CHARGED)

	_check("4 마른 돌 번개는 아무 데도 안 간다", na == 0, "전하 %d칸" % na)
	_check("4b 미리 적신 지형은 전하가 달린다", nb >= N4_MIN_CHARGED,
		"전하 %d칸 (문턱 %d · 마른 쪽 %d)" % [nb, N4_MIN_CHARGED, na])


# ─── N5. 폭발 패스 순서 ───────────────────────────────────────────
## 설계 §3의 계약: **파괴 → 채우기 → 잔여.**
##
## 🔴🔴 **정직하게 적는다 — 이 그물은 「파괴 ↔ 잔여」 뒤집기를 못 잡는다.**
##  현재 규칙에서는 두 순서의 최종 상태가 **같다**: 잔여를 먼저 붙여도 `_write_cell`이 지우고,
##  나중에 붙여도 `_wet_one`·`_strike`가 EMPTY를 건너뛴다. 관측 가능한 차이가 0이다.
##  ⇒ 주석의 순서 계약은 **미래 규칙**을 위한 것이고, 지금 기계가 잴 수 있는 건 아래 둘뿐이다.
##
## 🔴 반대로 **「채우기 ↔ 파괴」 뒤집기는 날카롭게 잡힌다** — 파괴 전에는 EMPTY가 하나도 없어서
##  채울 자리가 없다. 물 폭발인데 물이 0칸이면 빨개진다.
func _net5_pass_order() -> void:
	var g := _solid_grid()
	_blast(g, 2, Tuning.ELEM_WATER)

	var filled := g.count_material(Mat.WATER)
	_check("5 채우기가 파괴 뒤에 온다", filled > 0, "채운 물 %d칸" % filled)

	# 잔여는 **구멍 안이 아니라 테두리**에 있다. 안쪽에 젖음이 남아 있으면
	# `_write_cell`이 플래그를 지운다는 전제가 깨진 것이다.
	var rd := int(Tuning.SIM_TIERS[2]["rd"])
	var inside := 0
	var ring := 0
	var flag := g.get_flag()
	for y in range(CY - 40, CY + 41):
		var row := y << CellGrid.X_SHIFT
		for x in range(CX - 40, CX + 41):
			if (flag[row | x] & Mat.FLAG_WET) == 0:
				continue
			var dx := x - CX
			var dy := y - CY
			if dx * dx + dy * dy <= rd * rd:
				inside += 1
			else:
				ring += 1
	_check("5b 구멍 안엔 잔여가 안 남는다", inside == 0, "구멍 안 젖음 %d칸" % inside)
	_check("5c 테두리엔 잔여가 남는다", ring > 0, "테두리 젖음 %d칸" % ring)


# ─── N6. 터널링 없음 ──────────────────────────────────────────────
## 🔴 **DDA를 빼고 「도착 칸만 검사」로 짜면 빠른 투사체가 얇은 벽을 그냥 지나간다.**
##  한 프레임이라 **눈으로 절대 못 본다** — 사용자에게는 「가끔 안 터진다」로만 보인다.
##
## 픽스처: 1셀 벽 둘(x=100 · x=140). 원점 x=53이라 틱당 10셀 걸음이 x=100을 **걸음 안쪽**에
##  두고 지나간다(63 · 73 · 83 · 93 · 103). 도착 칸만 보면 두 벽을 다 건너뛴다.
## 🔴 원점을 50으로 두면 도착 칸이 정확히 100이 되어 **DDA 없이도 통과한다** — 그 픽스처는 헛것이다.
const THIN_A := 100
const THIN_B := 140


func _net6_no_tunneling() -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(THIN_A, 0, THIN_A, CellGrid.H - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(THIN_B, 0, THIN_B, CellGrid.H - 1, Mat.STONE))
	var s := SpellSim.new()
	s.fire(SpellSim.cmd_fire(53, CY, 1, 0, 0, Tuning.ELEM_BOLT))
	for _i in 30:
		g.step()
		s.step(g)

	_check("6 첫 벽에서 터진다", g.mat_at(THIN_A, CY) == Mat.EMPTY,
		"x=%d %s" % [THIN_A, "뚫림" if g.mat_at(THIN_A, CY) == Mat.EMPTY else "그대로(지나쳤다)"])
	_check("6b 두 번째 벽은 멀쩡하다", g.mat_at(THIN_B, CY) == Mat.STONE, "x=%d" % THIN_B)
	_check("6c 터진 투사체는 사라진다", s.active_count() == 0, "활성 %d발" % s.active_count())


# ─── N7. 상한 · 수명 ──────────────────────────────────────────────
## 안 지우면 **영원히 도는 투사체**가 생긴다. 배열이 노드가 아니라 에러도 안 난다.
func _net7_limits() -> void:
	var g := CellGrid.new()  # 빈 격자 — 맞을 게 없다
	var s := SpellSim.new()
	var accepted := 0
	for _k in Tuning.MAX_PROJECTILES + 1:
		if s.fire(SpellSim.cmd_fire(CX, CY, 1, 0, 0, Tuning.ELEM_BOLT)):
			accepted += 1
	_check("7 동시 상한", accepted == Tuning.MAX_PROJECTILES
		and s.active_count() == Tuning.MAX_PROJECTILES,
		"받아들임 %d · 활성 %d (상한 %d)" % [accepted, s.active_count(), Tuning.MAX_PROJECTILES])

	for _i in Tuning.LIFETIME_TICKS:
		g.step()
		s.step(g)
	_check("7b 격자 밖으로 나가면 사라진다", s.active_count() == 0, "활성 %d발" % s.active_count())

	# 원점을 그대로 클릭하면 방향이 0이다. **정상 입력**이라 조용히 버린다(에러가 아니다).
	_check("7c 방향 0은 발사가 아니다",
		not s.fire(SpellSim.cmd_fire(CX, CY, 0, 0, 0, Tuning.ELEM_BOLT)))

	# 🔴 수명은 지금 격자(256셀 폭)에서 **도달 불가한 가드다** — 횡단이 26틱인데 수명이 40틱이다.
	#  그래도 뺄 수 없다: 규칙이 하나만 바뀌어도(튕김·유도·더 큰 격자) 바로 살아난다.
	#  ⚠ **도달 불가라는 걸 알고 봐라**(SKILL.md T3) — 이 줄은 「가드가 가드로서 성립하나」만 잰다.
	var cross := CellGrid.W / Tuning.SPEED_CELLS + 2
	_check("7d 수명이 격자 횡단보다 길다", Tuning.LIFETIME_TICKS > cross,
		"수명 %d틱 · 횡단 %d틱" % [Tuning.LIFETIME_TICKS, cross])


# ─── N8. 위력 표 단조성 ───────────────────────────────────────────
## 🔴🔴 **T8 방어다 — 축이 1→N으로 느는데 표시부가 뒤처지는 것.** v1이 죽은 방식 그 자체다.
##  단을 늘리고 연출을 잊으면 여기가 빨개진다. 「P2의 섬광이 P1보다 크다」를 기계가 잰다.
## ⚠ **FX 블록은 B2가 채운다 — 그래도 자리와 그물은 여기 있다.** 그게 한 파일·두 블록의 요점이다.
func _net8_tier_table() -> void:
	var sim: Array[Dictionary] = Tuning.SIM_TIERS
	var fx: Array[Dictionary] = Tuning.FX_TIERS
	_check("8 SIM·FX 표 길이 일치", sim.size() == fx.size() and sim.size() >= 2,
		"SIM %d단 · FX %d단" % [sim.size(), fx.size()])
	if sim.size() != fx.size():
		return
	_monotonic("8a SIM", sim)
	_monotonic("8b FX", fx)


## 블록 하나가 ① 단마다 같은 필드를 갖고 ② 모든 필드가 **단조 증가**하는지.
## 🔴 ①이 없으면 오타 난 키가 새 축으로 조용히 늘어나고, 아무도 안 읽는다.
func _monotonic(label: String, block: Array[Dictionary]) -> void:
	var keys: Array = block[0].keys()
	for t in range(1, block.size()):
		var k2: Array = block[t].keys()
		if k2.size() != keys.size():
			_check("%s 필드 집합 일치" % label, false, "단%d 필드 %s vs %s" % [t, str(k2), str(keys)])
			return
		for key: String in keys:
			if not block[t].has(key):
				_check("%s 필드 집합 일치" % label, false, "단%d에 '%s'가 없다" % [t, key])
				return
	_check("%s 필드 집합 일치" % label, true, "%d필드 × %d단" % [keys.size(), block.size()])

	var bad: Array[String] = []
	for key: String in keys:
		for t in range(1, block.size()):
			var prev := int(block[t - 1][key])
			var cur := int(block[t][key])
			if cur <= prev:
				bad.append("%s: 단%d %d → 단%d %d" % [key, t, prev, t + 1, cur])
	_check("%s 전 필드 단조 증가" % label, bad.is_empty(), str(bad))


# ─── N9. 폭발이 **깨우고**, 그 다음 잠든다 ────────────────────────
## 🔴🔴 **깨우기와 재우기는 한 장부의 양변이라 같이 재야 한다.**
##  · 안 깨우면 → 구멍은 뚫렸는데 **호수가 안 쏟아진다.** 에러 없이 아무 일도 안 난다.
##  · 안 재우면 → 액체 리뷰 C1과 같은 병. 설계 §7의 예산이 통째로 틀린다.
##  ⚠ **한쪽만 재면 반대쪽 뮤테이션이 오히려 더 쉽게 통과한다** — 깨우기를 빼면 격자는
##   **더 빨리** 잠들어서 「잠들었나」 그물이 더 잘 통과한다. 실측이다(아래 9e가 그 자리다).
func _net9_sleeps_after_blast() -> void:
	# ① 마른 돌 P3 — 잔여가 아무 데도 안 붙으므로 즉시 잠들어야 한다.
	var a := _solid_grid()
	_blast(a, 2, Tuning.ELEM_BOLT)
	a.step()
	a.step()
	_check("9 마른 돌 P3 폭발 → 2틱에 잠듦", a.awake_count() == 0, "활성청크 %d" % a.awake_count())

	# ② 전하 잔여 — TTL 동안은 깨어 있는 게 맞고, **그 뒤에 잠들어야** 한다.
	var b := _solid_grid()
	_blast(b, 2, Tuning.ELEM_WATER)
	_tick(b, N4_SETTLE_TICKS)
	_check("9b 물 폭발 뒤 정착", b.awake_count() == 0, "활성청크 %d" % b.awake_count())
	_blast(b, 2, Tuning.ELEM_BOLT)
	var peak := 0
	for _i in CellGrid.CHARGE_TTL:
		b.step()
		peak = maxi(peak, b.count_flag(Mat.FLAG_CHARGED))
	_tick(b, CellGrid.CHARGE_TTL * 4)
	_check("9c 전하가 실제로 퍼졌다", peak > 20, "최대 전하 %d칸" % peak)
	_check("9d 전하 폭발도 결국 잠든다", b.awake_count() == 0 and b.count_flag(Mat.FLAG_CHARGED) == 0,
		"활성청크 %d · 전하 %d칸" % [b.awake_count(), b.count_flag(Mat.FLAG_CHARGED)])

	# ③ 🔴🔴 **깨우나.** 파괴 패스가 `_write_cell`을 우회해 `_mat`에 직접 쓰면 구멍은 뚫리는데
	#  청크가 안 깨어난다 — **에러 없이, 전 그물 그린으로.** 리드 뮤테이션이 실제로 그렇게 통과했다.
	#  ⇒ 「폭발 직후 `_awake_next`가 실제로 켜졌나」를 **틱을 돌리기 전에** 잰다. 이게 유일한 격리자다.
	var c := _solid_grid()
	_tick(c, 5)
	_check("9e 폭발 전 격자는 잠들어 있다", c.awake_count() == 0, "활성청크 %d" % c.awake_count())
	_blast(c, 0, Tuning.ELEM_BOLT)
	_check("9e-b 폭발이 청크를 깨운다", c.awake_count() > 0,
		"활성청크 %d — 0이면 구멍은 뚫려도 세상이 반응을 안 한다" % c.awake_count())

	# ④ 그 깨우기가 실제로 사는 자리 — **밑을 뚫으면 물이 쏟아진다**(설계 §5의 최고 장면).
	#  ⚠ 이 그물은 ③을 대신 못 한다: 잔여 패스도 깨우기 때문에 파괴 쪽 깨우기만 죽어도 통과한다.
	#   그래서 둘 다 있다.
	var d := CellGrid.new()
	d.apply(CellGrid.cmd_fill(0, 120, CellGrid.W - 1, 123, Mat.STONE))  # 바닥 슬래브
	d.apply(CellGrid.cmd_fill(60, 116, 90, 119, Mat.WATER))  # 그 위 웅덩이
	_tick(d, 300)
	_check("9f 웅덩이가 먼저 정착한다",
		d.awake_count() == 0 and _count_water_below(d, 124) == 0,
		"활성청크 %d · 슬래브 아래 물 %d칸" % [d.awake_count(), _count_water_below(d, 124)])
	d.apply(SpellSim.blast_cmd(75, 122, 0, Tuning.ELEM_BOLT))
	_tick(d, 200)
	var poured := _count_water_below(d, 124)
	_check("9f-b 밑을 뚫으면 쏟아진다", poured > 0, "슬래브 아래로 내려간 물 %d칸" % poured)


# ─── N10. 공개 표면 ───────────────────────────────────────────────
## `SpellSim`이 격자를 직접 만지거나, 시뮬 밖으로 새는 문을 열면 빨개진다.
## ⚠ **여기에 이름을 더하는 건 「문을 하나 더 축복한다」는 뜻이다.** 더하기 전에
##  기존 문으로 갈 수 있는지 먼저 봐라(`cell_grid.gd`의 `reset`이 그렇게 들어와 있었다).
const SPELL_PUBLIC_API: Array[String] = [
	"cmd_fire", "blast_cmd",
	"fire", "step", "reset", "active_count",
	# 🔴 렌더(B2)용 읽기 뷰. `CellGrid.get_mat()`과 같은 「살아 있는 뷰」다 — 쓰지 마라.
	"get_px", "get_py", "get_prev_px", "get_prev_py", "get_tier", "get_element", "get_id",
]


func _net10_public_surface() -> void:
	var s := SpellSim.new()
	var extra: Array[String] = []
	for m: Dictionary in s.get_script().get_script_method_list():
		var n := String(m["name"])
		if n.begins_with("_"):
			continue
		if not SPELL_PUBLIC_API.has(n):
			extra.append(n)
	_check("10 SpellSim 공개 표면", extra.is_empty(), "표 밖의 공개 메서드 %s" % str(extra))

	# 격자 밖으로 쏴도 아무 일이 안 나야 한다.
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	var before := g.get_mat().duplicate()
	var s2 := SpellSim.new()
	s2.fire(SpellSim.cmd_fire(-40, -40, -1, -1, 0, Tuning.ELEM_BOLT))
	for _i in 5:
		s2.step(g)
	_check("10b 격자 밖 발사 무해", g.get_mat() == before)


# ─── N12. 🔴🔴 소스 텍스트 그물 ───────────────────────────────────
## **기존 결정성 그물(`test_cell_grid_auto.gd`의 7번)은 「우리가 float을 썼다」를 원리적으로 못 잡는다.**
##  같은 프로세스의 두 인스턴스는 float도 **똑같은 답**을 낸다. 갈라지는 건 기계가 다를 때뿐이고,
##  그건 헤드리스 한 대로는 절대 안 보인다.
##
## ⇒ **소스를 텍스트로 읽어** 금지 토큰이 없는지 본다. 조잡하지만 **작동하는 유일한 감지기**이고,
##  이 리포에 선례가 있다(`_net10b_shader_constants`가 `.gdshader`를 텍스트로 읽는다).
##
## 🔴 **주석은 걷어내고 본다** — 주석에는 "float을 쓰지 마라" 같은 말이 당연히 나온다.
##  ⚠ 그래서 **금지 토큰을 주석에 적어 두는 것으로는 이 그물을 못 속인다**(코드만 본다).
const SIM_SOURCES: Array[String] = ["res://src/world/spell/spell_sim.gd"]
const TUNING_PATH := "res://src/world/spell/spell_tuning.gd"

## 🔴 `spell_tuning.gd`는 **반만** 계약이다(SIM 블록). FX 블록은 화면 전용이라 float이 허용된다.
##  ⇒ 마커로 잘라 앞쪽만 본다. **마커가 없으면 통과가 아니라 실패다** — 마커를 지우면
##   그물이 조용히 헛도는 게 정확히 T2(죽은 몸이 살아있는 그물을 갖는다)다.
const SIM_BEGIN := "SIM-BLOCK-BEGIN"
const SIM_END := "SIM-BLOCK-END"

const FORBIDDEN: Array[Dictionary] = [
	{"why": "float 타입", "re": "\\bfloat\\b"},
	{"why": "Vector2(32비트 float)", "re": "\\bVector2\\b"},
	{"why": "부동소수 리터럴", "re": "[0-9]\\.[0-9]"},
	{"why": "libm sqrt", "re": "(^|[^A-Za-z0-9_])sqrt\\s*\\("},
	{"why": "삼각함수(플랫폼마다 다르다)", "re": "\\b(sin|cos|tan|asin|acos|atan|atan2)\\s*\\("},
	{"why": "스트림 난수", "re": "\\brand[if]"},
	{"why": "벽시계", "re": "\\bTime\\s*\\."},
	{"why": "프레임 델타", "re": "\\bdelta\\b"},
	{"why": "float 보간", "re": "\\b(lerp|lerpf|smoothstep|remap)\\s*\\("},
	{"why": "실수 헬퍼", "re": "\\b(absf|maxf|minf|floorf|ceilf|roundf|clampf|snappedf|is_equal_approx)\\b"},
]


func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	f.close()
	return src


## 주석(`#` 이후)을 걷어낸다. ⚠ 전제 = **시뮬 소스의 문자열 리터럴에 `#`이 없다.**
##  전제가 깨지면 이 그물은 「덜 본다」 쪽으로 틀리므로, 시뮬 소스에 `#`을 쓰지 마라.
func _strip_comments(src: String) -> String:
	var out: Array[String] = []
	for line: String in src.split("\n"):
		var c := line.find("#")
		out.append(line if c < 0 else line.substr(0, c))
	return "\n".join(out)


func _scan(label: String, code: String) -> void:
	var hits: Array[String] = []
	for rule: Dictionary in FORBIDDEN:
		var re := RegEx.create_from_string(String(rule["re"]))
		if re == null:
			hits.append("정규식이 안 컴파일된다: %s" % rule["re"])
			continue
		var m := re.search(code)
		if m != null:
			hits.append("%s → '%s'" % [rule["why"], m.get_string()])
	_check("12 %s 정수 전용" % label, hits.is_empty(), str(hits))


func _net12_sim_source_is_integer_only() -> void:
	for path: String in SIM_SOURCES:
		var src := _read_text(path)
		if src.is_empty():
			_check("12 %s 읽기" % path, false, "파일을 못 연다")
			continue
		# 🔴 헛통과 방지 — 파일이 비었거나 통째로 주석이면 어떤 스캔도 그린이다(SKILL.md T2).
		var code := _strip_comments(src)
		_check("12 %s 코드가 실재한다" % path.get_file(), code.strip_edges().length() > 400,
			"주석 뺀 길이 %d자" % code.strip_edges().length())
		_scan(path.get_file(), code)

	var tune := _read_text(TUNING_PATH)
	# 🔴🔴 **마커는 정확히 한 번씩 나와야 한다.** 실제로 밟았다: 파일 머리 주석이 마커 문구를
	#  그대로 인용하고 있어서 `find`가 **그 주석**을 잡았고, 잘린 블록이 18자라 스캔이
	#  아무것도 안 보면서 **초록으로 통과했다.** 그물이 죽은 걸 아무도 모르는 상태였다(T2).
	var nb := tune.count(SIM_BEGIN)
	var ne := tune.count(SIM_END)
	_check("12b SIM 블록 마커가 정확히 하나씩", nb == 1 and ne == 1,
		"begin %d개 · end %d개 — 0개면 그물이 헛돌고, 2개면 엉뚱한 데를 자른다" % [nb, ne])
	if nb != 1 or ne != 1:
		return

	var b := tune.find(SIM_BEGIN)
	var e := tune.find(SIM_END)
	_check("12c SIM 블록 순서", e > b, "begin=%d end=%d" % [b, e])
	if e <= b:
		return
	var block := _strip_comments(tune.substr(b, e - b))
	# 🔴 헛통과 방지 — 자른 조각이 사실상 비었으면 어떤 스캔도 초록이다.
	_check("12d SIM 블록에 코드가 실재한다", block.strip_edges().length() > 400,
		"주석 뺀 길이 %d자" % block.strip_edges().length())
	_scan("spell_tuning.gd SIM 블록", block)
