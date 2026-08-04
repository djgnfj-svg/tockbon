extends RefCounted
## 표와 상수의 자기 정합성. 시뮬을 한 틱도 안 돌린다.
##
## 값싼 그물이 가치가 낮은 게 아니다. 여기가 잡는 것들은 전부
## "에러 없이 조용히 어긋나는" 종류다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Stage := preload("res://src/stage/stage.gd")
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const Fx := preload("res://src/view/fx_tuning.gd")


## 4이웃. 불도 점화도 4이웃이라 연결 성분도 같은 이웃으로 세야 한다.
const NB_DX: Array[int] = [1, -1, 0, 0]
const NB_DY: Array[int] = [0, 0, 1, -1]


## Color → 0xRRGGBB. 🔴 `bake_palette` 의 **역**이다 — 같은 식을 다시 쓰면 검사가 자기 자신이 된다.
static func _to_rgb(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8


func run(t) -> void:
	_grid_constants(t)
	_materials(t)
	_glyphs(t)
	_defs_and_all_agree(t)
	_view_follows_the_rune_axis(t)
	_gen_tables(t)
	_stage_map(t)
	_wood_clumps(t)


## 🔴🔴 **`DEFS`에 넣고 `ALL`에 안 넣으면 순회에서 빠진다.**
##  팔레트에 안 뜨고 · 그물의 `ALL` 순회에도 안 걸리고 · **에러가 하나도 안 난다.**
##  ⚠ 반대(`ALL`에 있는데 `DEFS`에 없다)는 표를 읽는 쪽이 죽는다.
##
## 🔴 이 리포는 「순회는 반드시 명시 리스트로만」을 세 곳에서 지킨다 — 그 규율의 **대가**가
##  정확히 이 구멍이다. ⚠ **개수만 재면 못 잡는다**(하나 빼고 하나 더하면 크기가 같다) —
##  ⇒ **집합으로 맞댄다.** 이건 「부르나만 보는 검사」가 아니라 **거동을 직접 가른다.**
##
## ⚠ 표를 늘리면 저절로 같이 는다 — 진이 1종이어도 지금 작동한다.
func _defs_and_all_agree(t) -> void:
	# [이름, DEFS, ALL]
	var pairs: Array[Array] = [
		["glyph_defs", Glyph.DEFS, Glyph.ALL],
		["circle_defs", CircleDefs.DEFS, CircleDefs.ALL],
		["sim_tuning(룬)", Tuning.ELEM_DEFS, Tuning.ELEM_ALL],
	]
	# ⚠ 목록이 비면 아래가 한 번도 안 돌고 **초록이 된다.**
	t.ok(pairs.size() > 0, "표와 목록 짝이 %d개다" % pairs.size())
	for p: Array in pairs:
		var nm: String = p[0]
		var defs: Dictionary = p[1]
		var all: Array = p[2]
		t.ok(all.size() > 0, "%s 의 ALL이 비어 있지 않다 (%d개)" % [nm, all.size()])
		# 🔴 **집합 비교다.** 정렬해 맞대면 순서 차이에 거짓 양성이 나고, 크기만 재면 못 잡는다.
		for id: int in all:
			t.ok(defs.has(id), "%s: ALL의 %d가 DEFS에 있다" % [nm, id])
		for id: int in defs.keys():
			t.ok(all.has(id), "%s: DEFS의 %d가 ALL에 있다 (순회에서 안 빠진다)" % [nm, id])


## 🔴🔴 **시뮬 축(`ELEM_ALL`)이 늘었는데 화면 축(`ELEM_FX`)이 안 따라오면 그물이 전부 초록이다.**
##  ⚠ 실측(2026-08-04, 무속성 룬을 넣던 날): 룬을 `ELEM_ALL`에 넣고 `ELEM_FX`에서 **색만 빼도
##   통과 1127개 · stderr 깨끗함**이었다. 아무도 안 짖는다.
##
## 🔴 이게 CLAUDE.md가 **이 리포의 대표 가짜**로 적은 「화면만 바뀌고 시뮬은 안 바뀌기(또는 그 반대)」이고,
##  **v1이 죽은 방식**이다 — 위력이 두 배가 됐는데 화면이 안 따라가서 아무도 강해진 걸 못 느꼈다.
##  ⚠ `sim_tuning`의 **세대 표에는** 그 짝(`FX_SIZES` 길이)이 아래 `_gen_tables`에 있는데
##   **룬 축에는 없었다.** 이 함수가 그 빈자리다.
##
## ⚠ **`ELEM_FX_MISSING`(마젠타 비명)을 대신하는 게 아니다.** 저건 화면 쪽 최후 방어선이라
##  **사람이 봐야** 하고, 이건 자동이다. 둘 다 필요하다.
func _view_follows_the_rune_axis(t) -> void:
	# ⚠ 목록이 비면 아래가 한 번도 안 돌고 초록이 된다.
	t.ok(Tuning.ELEM_ALL.size() > 0, "룬이 하나라도 있다 (%d개)" % Tuning.ELEM_ALL.size())
	for element: int in Tuning.ELEM_ALL:
		# 🔴 **색인(`ELEM_FX[element]`)으로 파지 마라** — 없으면 단언이 빨개지는 게 아니라
		#  함수가 중단돼 **검사가 통째로 없어진다.** `Variant`로 받고 타입을 먼저 잰다.
		var fx: Variant = Fx.ELEM_FX.get(element, null)
		t.ok(fx is Dictionary, "룬 %d의 색이 ELEM_FX에 있다" % element)
		if not (fx is Dictionary):
			continue
		for key: String in ["core", "glow"]:
			t.ok((fx as Dictionary).get(key, null) is Color,
				"룬 %d의 ELEM_FX에 `%s` 색이 있다" % [element, key])
		# 🔴 **표에 있나**와 **쓰는 쪽이 받나**는 다른 물음이다 — 소비자가 지나는 접근자로 한 번 더 본다.
		var got: Variant = Fx.elem_fx(element).get("glow", null)
		t.ok(got is Color and got != Fx.ELEM_FX_MISSING.get("glow", null),
			"룬 %d이 접근자에서 비명 색으로 안 떨어진다" % element)

	# 🔴 반대쪽. 화면에만 있고 시뮬에 없는 룬은 **아무도 못 쏘는 색**이다 — 거짓 손잡이다.
	for element: int in Fx.ELEM_FX.keys():
		t.ok(Tuning.ELEM_ALL.has(element),
			"ELEM_FX의 룬 %d이 ELEM_ALL에 있다 (아무도 못 쏘는 색이 아니다)" % element)


## 🔴🔴 **나무가 한 덩어리면 어디에 불이 붙든 결국 전부 탄다.**
## 실측으로 키 1(문양 없음)·키 4·키 5의 최종 나무가 셋 다 48로 수렴했다 —
## 「가라앉은 뒤」 축이 조합을 구별 못 하게 된다. 끊어 두면 몇 덩어리가 타느냐가 조합마다 갈린다.
##
## 🔴 **실제로 도는 지형을 세운다.** 맵 문자열을 여기서 다시 읽으면 지형이 바뀔 때 같이 안 늙는다.
func _wood_clumps(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)

	var label := PackedInt32Array()
	label.resize(CellGrid.CELL_COUNT)
	label.fill(-1)
	var clumps := 0
	for y in CellGrid.H:
		for x in CellGrid.W:
			if g.mat_at(x, y) != Mat.WOOD:
				continue
			if label[(y << CellGrid.X_SHIFT) | x] != -1:
				continue
			_flood(g, label, x, y, clumps)
			clumps += 1
	t.ok(clumps >= 4, "무대의 나무가 여러 덩어리로 끊겨 있다 (%d덩어리)" % clumps)

	# 🔴 간격 기준은 「폭발이 못 뚫는 두께」가 아니다 — 폭발이 뚫어도 그 자리는 빈칸이고
	#  불은 빈칸도 못 건넌다. 실제 기준은 **작은 점화원이 두 덩어리를 동시에 못 켜는 폭**이다.
	#  ⚠ 세대 0 폭발의 점화 반경은 일부러 뺐다 — 그건 건너가는 게 그 조합의 성격이다.
	var need := maxi(Tuning.rune_r(0), Tuning.blast_ignite_r(Tuning.SPLIT_MAX))
	var closest := _closest_gap(g, label)
	t.ok(closest > need,
		"덩어리 사이가 작은 점화원(%d셀)보다 넓다 (제일 좁은 곳 %d셀)" % [need, closest])


## 4이웃 연결 성분 하나를 칠한다. ⚠ 재귀가 아니라 스택이다 — 656칸짜리 덩어리에서
## GDScript 재귀는 깊이 제한에 걸린다.
func _flood(g: CellGrid, label: PackedInt32Array, sx: int, sy: int, id: int) -> void:
	var stack: Array[int] = [(sy << CellGrid.X_SHIFT) | sx]
	label[stack[0]] = id
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i & CellGrid.X_MASK
		var y := i >> CellGrid.X_SHIFT
		for k in 4:
			var nx: int = x + NB_DX[k]
			var ny: int = y + NB_DY[k]
			if nx < 0 or nx >= CellGrid.W or ny < 0 or ny >= CellGrid.H:
				continue
			var ni: int = (ny << CellGrid.X_SHIFT) | nx
			if label[ni] != -1 or g.mat_at(nx, ny) != Mat.WOOD:
				continue
			label[ni] = id
			stack.append(ni)


## 서로 다른 덩어리 사이의 제일 좁은 간격(셀). 행·열을 훑는다 —
## 불도 점화도 4이웃이라 축 방향 간격이 곧 건너갈 수 있는 거리다.
func _closest_gap(g: CellGrid, label: PackedInt32Array) -> int:
	var best := CellGrid.W
	for y in CellGrid.H:
		best = mini(best, _gap_along(label, y, true))
	for x in CellGrid.W:
		best = mini(best, _gap_along(label, x, false))
	return best


func _gap_along(label: PackedInt32Array, line: int, horizontal: bool) -> int:
	var best := CellGrid.W
	var last_id := -1
	var last_at := -1
	var n := CellGrid.W if horizontal else CellGrid.H
	for k in n:
		var i := (line << CellGrid.X_SHIFT) | k if horizontal else (k << CellGrid.X_SHIFT) | line
		var id := label[i]
		if id < 0:
			continue
		if last_id >= 0 and id != last_id:
			best = mini(best, k - last_at - 1)
		last_id = id
		last_at = k
	return best


## 🔴🔴 **시뮬 축만 늘고 화면이 안 따라가는 것이 v1이 죽은 방식이다.**
## 두 표의 길이와 단조를 **같이** 잰다 — 한쪽만 늘리면 여기서 빨개진다.
## ⚠ 단조 방향이 v1과 반대다: 세대가 깊어지면 **작아진다.**
func _gen_tables(t) -> void:
	var sim: Array[Dictionary] = Tuning.SIM_SIZES
	var fx: Array[Dictionary] = Fx.FX_SIZES
	t.ok(sim.size() > 0, "세대 표가 비어 있지 않다 (%d줄)" % sim.size())
	t.eq(fx.size(), sim.size(), "SIM_SIZES와 FX_SIZES의 길이가 같다")
	# 세대는 SPLIT_MAX 까지 실제로 올라간다. 표가 그보다 짧으면 클램프가 없는 줄을 가린다.
	t.ok(sim.size() >= Tuning.SPLIT_MAX + 1,
		"표가 SPLIT_MAX(%d)까지 덮는다 (%d줄)" % [Tuning.SPLIT_MAX, sim.size()])

	_strictly_decreasing(t, sim, "SIM_SIZES", ["speed", "rd", "ignite_r", "rune_r"])
	_strictly_decreasing(t, fx, "FX_SIZES", ["bolt_px", "trail_ticks", "flash_px", "shake_px"])

	# 🔴 점화 반경이 파괴 반경보다 커야 불이 붙는다 — **세대마다** 성립해야 한다.
	for gen in sim.size():
		t.ok(Tuning.blast_ignite_r(gen) > Tuning.blast_rd(gen),
			"세대 %d의 점화 반경이 파괴 반경보다 크다" % gen)
		# 🔴 룬 흔적이 0이면 착탄점(빈칸)에서 이웃에 못 닿아 **아무 일도 안 일어난다.**
		#  그러면 「폭발 → 확산」의 잔불이 다시 증발하고, 에러는 하나도 안 난다.
		t.ok(Tuning.rune_r(gen) > 0, "세대 %d의 룬 흔적 반경이 0이 아니다" % gen)
		# 🔴 흔적은 **폭발보다 작아야 한다.** 크면 확산이 폭발을 겸하는 것처럼 보여 두 조합이 뭉개진다.
		t.ok(Tuning.rune_r(gen) < Tuning.blast_rd(gen),
			"세대 %d의 룬 흔적이 폭발 반경보다 작다 (%d < %d)" % [
				gen, Tuning.rune_r(gen), Tuning.blast_rd(gen)])

	# 클램프가 실제로 도나. 표 밖 세대에서 죽으면 확산 상한을 올릴 때 그 자리가 터진다.
	var last := sim.size() - 1
	t.eq(Tuning.blast_rd(last + 5), Tuning.blast_rd(last), "표 밖 세대는 마지막 줄로 떨어진다")
	t.eq(Fx.bolt_px(last + 5), Fx.bolt_px(last), "연출도 같은 규칙으로 떨어진다")


## 🔴 값이 **같으면 실패다.** 같게 두면 그물이 「일부러 안 줄였다」와 「줄이는 걸 깜빡했다」를
## 구별하지 못한다 — 한 축을 끄고 싶으면 소비자 쪽에서 상수를 곱해라.
func _strictly_decreasing(t, rows: Array[Dictionary], nm: String, keys: Array) -> void:
	for key: String in keys:
		var ok := true
		var seen: Array = []
		for gen in rows.size():
			t.ok(rows[gen].has(key), "%s[%d]에 %s가 있다" % [nm, gen, key])
			var v: float = float(rows[gen].get(key, 0))
			seen.append(v)
			if gen > 0 and v >= float(rows[gen - 1].get(key, 0)):
				ok = false
		t.ok(ok, "%s의 %s가 세대마다 반드시 줄어든다 %s" % [nm, key, seen])


## 인덱싱이 통째로 틀리면 증상이 "격자가 이상하다"로만 나온다.
func _grid_constants(t) -> void:
	t.eq(1 << CellGrid.X_SHIFT, CellGrid.W, "X_SHIFT가 W와 맞는다")
	t.eq(CellGrid.X_MASK, CellGrid.W - 1, "X_MASK가 W와 맞는다")
	t.eq(CellGrid.CELL_COUNT, CellGrid.W * CellGrid.H, "CELL_COUNT가 W×H와 맞는다")
	# GDD 격자: 셀 4px · 지형 타일 16px = 4×4셀 · 캐릭터 16px.
	# 캐릭터와 타일 두께가 같은 게 "저 벽을 뚫으면 지나갈 수 있다"를 눈에 보이게 하는 장치다.
	t.eq(Tuning.CELL_PX, 4, "셀이 4px이다 (GDD 확정)")
	t.eq(Tuning.TILE_CELLS * Tuning.CELL_PX, 16, "지형 타일이 16px이다 (GDD 확정)")
	t.eq(60 % Tuning.TICK_DIVIDER, 0, "분주기가 60을 딱 나눈다")


func _materials(t) -> void:
	# 🔴 팔레트를 굽는 일은 src/view/ 가 한다 — Color 가 부동소수라 시뮬 폴더 계약에 걸린다.
	#  표는 여전히 단일 소스이고(DEFS 의 rgb 한 칸) 여기서는 그 파생이 맞는지만 본다.
	var pal := CellRenderer.bake_palette()
	t.eq(pal.size(), Mat.SLOT_COUNT, "팔레트 길이가 SLOT_COUNT")
	t.ok(Mat.ALL.size() > 0, "재료가 하나라도 있다 (%d개)" % Mat.ALL.size())
	for id: int in Mat.ALL:
		# 굽는 식을 여기서 베끼지 않고 **되돌려서** 잰다 — 베끼면 둘 다 같이 틀려도 초록이다.
		t.eq(_to_rgb(pal[id]), int(Mat.DEFS[id]["rgb"]),
			"%s 색이 DEFS의 rgb에서 나온다" % Mat.material_name(id))
	# 정의 없는 슬롯은 마젠타여야 한다. 얌전한 검정이면 재료를 늘렸을 때 조용히 안 보인다.
	t.eq(_to_rgb(pal[Mat.SLOT_COUNT - 1]), Mat.MISSING_RGB, "빈 슬롯은 마젠타 센티넬")
	t.eq(Mat.rgb_of(Mat.SLOT_COUNT - 1), Mat.MISSING_RGB, "정의 없는 id는 마젠타를 돌려준다")

	var beh := Mat.bake_behavior()
	t.eq(beh.size(), Mat.SLOT_COUNT, "거동 테이블 길이가 SLOT_COUNT")
	for id: int in Mat.ALL:
		t.eq(beh[id], int(Mat.DEFS[id]["behavior"]),
			"%s 거동이 DEFS에서 나온다" % Mat.material_name(id))

	# 연료는 _aux(PackedByteArray)에 들어간다. 255를 넘으면 말없이 하위 8비트로 잘린다.
	var fuel := Mat.bake_fuel()
	t.eq(fuel.size(), Mat.SLOT_COUNT, "연료 테이블 길이가 SLOT_COUNT")
	for id: int in Mat.ALL:
		var f := int(Mat.DEFS[id]["fuel"])
		t.ok(f >= 0 and f <= 255, "%s 연료가 바이트에 들어간다" % Mat.material_name(id))
		t.eq(fuel[id], f, "%s 연료가 DEFS에서 나온다" % Mat.material_name(id))
	# 돌은 안 탄다. 이게 깨지면 "불이 돌에서 멈추나"(판정 5)가 통째로 무의미해진다.
	t.eq(int(Mat.DEFS[Mat.STONE]["fuel"]), 0, "돌은 연료가 0이다")
	t.ok(int(Mat.DEFS[Mat.WOOD]["fuel"]) > 0, "나무는 연료가 있다")


## 문양 하나 추가 = DEFS 한 줄 + ALL 한 줄. 둘이 갈라지면 그 문양은 발사 검증에는
## 있는데 순회에는 없는(또는 그 반대) 유령이 된다.
## ⚠ 실제로 실행해 보는 것은 net_spell 이 한다 — 여기는 표가 자기와 맞나만 본다.
func _glyphs(t) -> void:
	# 0은 "목록 끝"으로 예약돼 있다. 이게 깨지면 빈 목록과 문양 하나가 구분이 안 된다.
	t.eq(Glyph.GLYPH_NONE, 0, "GLYPH_NONE이 0이다")
	t.eq(Glyph.MASK, (1 << Tuning.GLYPH_BITS) - 1, "니블 마스크가 GLYPH_BITS와 맞는다")
	# 4비트 × 7층 = 28비트. 8층째는 최상위 니블에 앉아 음수가 되고, `>> 4`가 산술 시프트라
	# 부호 확장으로 에러 없이 망가진다 — 무한 루프가 된다.
	t.ok(Tuning.GLYPH_BITS * Tuning.GLYPH_MAX_LAYERS <= 31,
		"문양 목록이 부호 비트를 안 건드린다 (%d비트)" % (Tuning.GLYPH_BITS * Tuning.GLYPH_MAX_LAYERS))

	t.eq(Glyph.ALL.size(), Glyph.DEFS.size(), "ALL과 DEFS의 문양 수가 같다 (%d개)" % Glyph.ALL.size())
	for id: int in Glyph.ALL:
		t.ok(Glyph.DEFS.has(id), "ALL의 문양 %d가 DEFS에 있다" % id)
		t.ok(id > Glyph.GLYPH_NONE and id <= Glyph.MASK, "문양 %d가 니블 범위 안이다" % id)
		var d: Dictionary = Glyph.DEFS[id]
		t.ok(d.has("name") and d.has("kind") and d.has("max_per_circle") and d.has("tick_budget"),
			"문양 %d 정의에 네 칸이 다 있다" % id)
		var kind := int(d["kind"])
		t.ok(kind == Glyph.KIND_SPAWN or kind == Glyph.KIND_TERMINAL,
			"문양 %s의 종류가 SPAWN/TERMINAL 중 하나다" % d["name"])
		# 0 = 무제한. 음수는 뜻이 없고, 조용히 "제한 없음"으로 읽힌다.
		t.ok(int(d["max_per_circle"]) >= 0, "문양 %s의 max_per_circle이 음수가 아니다" % d["name"])
		t.ok(int(d["tick_budget"]) >= 0, "문양 %s의 tick_budget이 음수가 아니다" % d["name"])

	# 🔴 룬 표도 같은 규율이다. `spell_sim._rune_trace` 가 `ELEM_DEFS[element]` 를 바로 인덱싱하는데,
	#  검증은 `ELEM_ALL` 로 한다 — 둘이 갈리면 발사는 통과하고 착탄에서 죽는다.
	t.eq(Tuning.ELEM_ALL.size(), Tuning.ELEM_DEFS.size(),
		"ELEM_ALL과 ELEM_DEFS의 룬 수가 같다 (%d개)" % Tuning.ELEM_ALL.size())
	for id: int in Tuning.ELEM_ALL:
		t.ok(Tuning.ELEM_DEFS.has(id), "ALL의 룬 %d가 DEFS에 있다" % id)
		t.ok(Tuning.ELEM_DEFS[id].has("trace"), "룬 %d 정의에 trace가 있다" % id)

	# 구운 표가 DEFS에서 나오나. 손으로 박으면 문양을 늘릴 때 한쪽만 늘어난다.
	var budget := Glyph.bake_tick_budget()
	t.eq(budget.size(), Glyph.MASK + 1, "예산 표 길이가 니블 범위와 같다")
	for id: int in Glyph.ALL:
		t.eq(budget[id], int(Glyph.DEFS[id]["tick_budget"]),
			"문양 %s 예산이 DEFS에서 나온다" % Glyph.DEFS[id]["name"])


## 무대가 화면 밖 여백에 걸치면 확산 8발 중 몇이 안 보이는 데서 터지고,
## 사용자에게는 "안 터졌다"로 읽힌다. v1이 바닥 슬래브로 정확히 그렇게 데였다.
func _stage_map(t) -> void:
	t.eq(Stage.MAP.size(), Stage.MAP_H, "맵 행 수가 MAP_H")
	t.ok(Stage.MAP_W * Tuning.TILE_CELLS <= CellGrid.W, "맵 폭이 격자 안에 들어간다")
	t.ok(Stage.MAP_H * Tuning.TILE_CELLS <= CellGrid.H, "맵 높이가 격자 안에 들어간다")

	# 🔴 뷰포트 크기를 손으로 박지 마라 — project.godot 이 바뀌면 박아 둔 숫자가 조용히 낡는다.
	#  "한 칸이라도 보이면 보이는 것"이라 올림이다(맨 아랫줄은 일부만 보인다 — 그건 받아들인다).
	var tile_px := Tuning.CELL_PX * Tuning.TILE_CELLS
	var vw := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var vis_cols := (vw + tile_px - 1) / tile_px
	var vis_rows := (vh + tile_px - 1) / tile_px
	var outside := 0
	for ty in Stage.MAP.size():
		var row: String = Stage.MAP[ty]
		t.eq(row.length(), Stage.MAP_W, "맵 %d행 폭이 MAP_W" % ty)
		for tx in row.length():
			if not Stage.MAP_CHARS.has(row[tx]):
				continue
			if tx >= vis_cols or ty >= vis_rows:
				outside += 1
	t.eq(outside, 0, "지형이 보이는 끝(타일 %dx%d) 밖에 없다" % [vis_cols, vis_rows])

	# 맵 문자가 실재하는 재료를 가리키나. 오타 하나면 그 지형이 조용히 안 지어진다.
	for ch: String in Stage.MAP_CHARS.keys():
		t.ok(Mat.ALL.has(int(Stage.MAP_CHARS[ch])), "맵 문자 '%s'가 실재 재료다" % ch)
