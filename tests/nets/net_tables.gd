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
## 🔴 카메라가 「내 주변」을 보여 주는지 재려면 **내가 얼마나 큰지**가 필요하다.
const Character := preload("res://src/actor/character.gd")
const Palette := preload("res://tools/stage/terrain_palette.gd")
const Baker := preload("res://tools/stage/terrain_baker.gd")


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
	_terrain_brush_follows_the_material_table(t)


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


## 🔴🔴 **옛 계약이 여기로 옮겨 왔다. 지운 게 아니라 뜻이 바뀐 것이다.**
##
## 전: 「**무대 전체가 한 화면에 들어온다**」 — 정적 카메라 전제였다.
##  그 이유는 「무대가 여백에 걸치면 **확산 8발 중 몇이 안 보이는 데서 터지고** 사용자에게는
##  「안 터졌다」로 읽힌다 — v1이 바닥 슬래브로 정확히 그렇게 데였다」.
##
## 🔴 **카메라가 캐릭터를 따라가면서 그 단언이 원리적으로 성립할 수 없게 됐다** — 무대(2048×1152)가
##  화면(960×540)보다 크다. ⇒ **이유는 살리고 단언을 좁힌다: 「내 주변만은 반드시 보인다」.**
##
## **N을 무엇으로 잡았나 — 세대 0 섬광 반경(`flash_px(0)`)이다. 근거는 셋:**
##  ① **내 발밑 폭발이 실전의 주 피격 경로다**(기획 「발밑을 쏘면 바닥에서 터진 폭발이 나를 때린다」).
##    그 폭발의 섬광이 화면 밖으로 잘리면 **「터졌다」가 화면에서 안 읽힌다** — 옛 이유와 같은 것이다
##  ② 섬광이 **화면에서 제일 큰 연출**이다. 구멍(반경 24셀 = 96px)보다 크고(216px) 흔들림보다 오래 남는다
##  ③ 🔴 **상수에서 파생시킨다.** 타일 수를 손으로 박으면 섬광을 키우는 날 이 검사만 조용히 낡는다
##
## ⚠ **세상 밖까지 요구하지 않는다** — 요구 범위를 세상과 교집합한다. 클램프된 카메라는 세상 밖을
##  안 보여 주는 게 **맞는** 거동이라, 안 자르면 무대 구석에서 영원히 빨갛다.
## 🔴 **여기가 재는 것은 「카메라가 그만큼 보여 준다」까지다.** 확산 탄이 30타일 밖에 착탄하는 것은
##  **여전히 안 보이고**, 그건 `stage.gd` 의 `MAP` 주석에 「잃은 것」으로 적어 뒀다.
func _camera_always_shows_my_surroundings(t) -> void:
	var view := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var world := Stage.world_size()
	t.ok(view.x > 0.0 and view.y > 0.0, "뷰포트 크기를 읽었다 (%dx%d)" % [int(view.x), int(view.y)])
	t.ok(world.x > 0.0 and world.y > 0.0, "세상 크기가 격자에서 나온다 (%dx%d)" % [
		int(world.x), int(world.y)])

	var need := Fx.flash_px(0)
	# ⚠ 요구가 화면보다 크면 **어디에 서도 못 지킨다** — 그때는 아래가 전부 빨개지는데 원인이
	#  카메라가 아니라 이 값이다. 먼저 재서 진단을 가른다.
	t.ok(need * 2.0 + float(Character.W_PX) <= view.x
			and need * 2.0 + float(Character.H_PX) <= view.y,
		"요구 반경(섬광 %dpx)이 화면에 애초에 들어간다" % int(need))

	# 🔴 **구석까지 본다.** 가운데만 재면 클램프가 도는 자리를 한 번도 안 지난다 —
	#  클램프는 **가장자리에서만** 걸리므로 거기가 이 검사의 전부다.
	var w := float(Character.W_PX)
	var h := float(Character.H_PX)
	var spots: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(world.x - w, 0.0),
		Vector2(0.0, world.y - h), Vector2(world.x - w, world.y - h),
		Vector2(world.x * 0.5, world.y * 0.5),
		Vector2(float(Stage.SPAWN_TILE.x), float(Stage.SPAWN_TILE.y))
			* float(Tuning.CELL_PX * Tuning.TILE_CELLS),
	]
	t.ok(spots.size() > 0, "재 볼 자리가 %d곳이다" % spots.size())

	var world_rect := Rect2(Vector2.ZERO, world)
	for at: Vector2 in spots:
		var box := Rect2(at, Vector2(w, h))
		var center := Stage.camera_center(box.position + box.size * 0.5, view, world)
		var seen := Rect2(center - view * 0.5, view)
		# 요구 범위 = 상자를 `need` 만큼 넓힌 것 **∩ 세상**.
		var want := box.grow(need).intersection(world_rect)
		t.ok(seen.encloses(want),
			"캐릭터가 %s 에 있을 때 주변 %dpx 가 보인다 (화면 %s~%s ⊇ %s~%s)" % [
				at, int(need), seen.position, seen.end, want.position, want.end])
		# 🔴🔴 **클램프가 실제로 도나.** ⚠ 위 줄만으로는 **클램프를 통째로 지워도 안 걸린다** —
		#  클램프가 없으면 보이는 범위가 오히려 넓어져서 「주변이 보인다」는 더 잘 성립한다.
		#  ⇒ **세상 밖을 안 보여 준다**를 따로 잰다. 격자 밖은 아무것도 안 그려져 「세상이 잘렸다」로 보인다.
		t.ok(world_rect.encloses(seen),
			"캐릭터가 %s 에 있어도 화면이 세상 밖을 안 보여 준다 (%s~%s)" % [
				at, seen.position, seen.end])

	# 🔴 **안 도는 갈래를 직접 잰다.** 지금 세상이 화면보다 커서 「좁은 세상」 갈래가 한 번도 안 도는데,
	#  **안 도는 갈래는 틀려도 아무도 안 짖는다.** 무대를 줄이는 날 여기가 먼저 말한다.
	var tiny := view * 0.5
	t.eq(Stage.camera_center(Vector2.ZERO, view, tiny), tiny * 0.5,
		"세상이 화면보다 좁으면 세상 한가운데에 둔다 (한쪽 끝에 안 붙는다)")


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

	# 🔴🔴 **열을 늘리면 이 목록에도 이름을 더해야 한다.** 안 더하면 아무도 안 재는데
	#  통과 수는 그대로 초록이다 — 이 파일이 `damage` 열로 실측해서 그렇게 적어 뒀다.
	#  ⚠ `water_r` 은 2026-08-07에 물 룬이 서면서 늘었다.
	_strictly_decreasing(t, sim, "SIM_SIZES",
		["speed", "rd", "ignite_r", "rune_r", "carve_r", "water_r"])
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
		# 🔴 파는 반경이 0이면 「마법이 벽을 판다」(GDD)가 통째로 없어지는데 **에러가 안 난다** —
		#  그게 정확히 2026-08-05 이전 상태였고 그물은 내내 초록이었다.
		t.ok(Tuning.carve_r(gen) > 0, "세대 %d가 실제로 판다 (반경 %d)" % [
			gen, Tuning.carve_r(gen)])
		# 🔴 파기는 폭발보다 **훨씬** 작아야 두 개가 화면에서 갈린다. 부등식은 그 하한이다.
		t.ok(Tuning.carve_r(gen) < Tuning.blast_rd(gen),
			"세대 %d의 파는 반경이 폭발보다 작다 (%d < %d)" % [
				gen, Tuning.carve_r(gen), Tuning.blast_rd(gen)])
		# 🔴🔴 **파기(①)가 룬 흔적(②)보다 먼저다** ⇒ 같거나 크면 **불 룬이 태울 연료를
		#  파기가 먼저 지운다.** 위 `ignite_r > rd` 와 정확히 같은 함정의 축소판이고,
		#  「파고 그 자리에 불」에서 **불만 조용히 사라지며 에러가 안 난다.**
		#  ⚠ 세대 1의 여유가 **1칸뿐**이다(1 < 2).
		t.ok(Tuning.carve_r(gen) < Tuning.rune_r(gen),
			"세대 %d의 파는 반경이 룬 흔적보다 작다 (%d < %d)" % [
				gen, Tuning.carve_r(gen), Tuning.rune_r(gen)])
		# 🔴 **물 흔적도 같은 계약을 진다.** 파기가 먼저라 같거나 크면 **물이 놓일 자리를
		#  파기가 먼저 지운다** — 불 쪽 함정의 물 판이고 똑같이 조용하다.
		t.ok(Tuning.water_r(gen) > 0, "세대 %d의 물 흔적 반경이 0이 아니다" % gen)
		t.ok(Tuning.carve_r(gen) < Tuning.water_r(gen),
			"세대 %d의 파는 반경이 물 흔적보다 작다 (%d < %d)" % [
				gen, Tuning.carve_r(gen), Tuning.water_r(gen)])

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
	# GDD 격자: 셀 4px · 지형 타일 32px = 8×8셀 · 캐릭터 32px.
	# 캐릭터와 타일 두께가 같은 게 "저 벽을 뚫으면 지나갈 수 있다"를 눈에 보이게 하는 장치다.
	# 🔴 32px 전환에서 타일만 두꺼워졌다 — **셀 4px은 안 건드렸다**(GDD: 셀을 키우면 위력 구분이 뭉개진다).
	t.eq(Tuning.CELL_PX, 4, "셀이 4px이다 (GDD 확정)")
	t.eq(Tuning.TILE_CELLS * Tuning.CELL_PX, 32, "지형 타일이 32px이다 (GDD 확정)")
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


## 맵이 격자 안에 들어가고 행 폭이 고르나.
func _stage_map(t) -> void:
	t.eq(Stage.MAP.size(), Stage.MAP_H, "맵 행 수가 MAP_H")
	t.ok(Stage.MAP_W * Tuning.TILE_CELLS <= CellGrid.W, "맵 폭이 격자 안에 들어간다")
	t.ok(Stage.MAP_H * Tuning.TILE_CELLS <= CellGrid.H, "맵 높이가 격자 안에 들어간다")

	for ty in Stage.MAP.size():
		t.eq(String(Stage.MAP[ty]).length(), Stage.MAP_W, "맵 %d행 폭이 MAP_W" % ty)

	_camera_always_shows_my_surroundings(t)

	# 맵 문자가 실재하는 재료를 가리키나. 오타 하나면 그 지형이 조용히 안 지어진다.
	for ch: String in Stage.MAP_CHARS.keys():
		t.ok(Mat.ALL.has(int(Stage.MAP_CHARS[ch])), "맵 문자 '%s'가 실재 재료다" % ch)


## 🔴🔴 **에디터 붓이 재료 표를 따라오나 — 「조용히 낡는다」의 유일한 그물이다.**
##
## `docs/design/지형-굽기.md` 가 이 위험을 이름으로 적어 뒀다: 붓 그림과 타일셋 표가 `DEFS` 와
## 갈라져도 **게임 화면은 안 틀린다**(화면은 셀 격자가 그린다) ⇒ **아무도 눈치 못 챈다.**
## 붓을 집을 때만 헷갈리고, 그때는 이미 잘못 그린 맵이 남는다.
##
## ⚠ **재료를 늘렸을 때 「고칠 곳 넷」 중 셋을 여기서 잰다.** 넷째(`DEFS` 자체)는 원본이라 잴 게 없다.
const TILESET_PATH := "res://src/stage/terrain_tileset.tres"
const ATLAS_PATH := "res://assets/stage/terrain_tiles.png"

func _terrain_brush_follows_the_material_table(t) -> void:
	var ids := Palette.paintable()
	# 🔴 폴더 스캔 그물의 첫 줄과 같은 이유 — 목록이 비면 아래가 하나도 안 돌고 초록이 된다.
	t.ok(ids.size() > 0, "붓이 되는 재료가 있다 (%d개)" % ids.size())
	# 🔴 **빈칸은 붓이 아니다** — 타일을 안 놓는 것이 빈칸이다.
	t.ok(not ids.has(Mat.EMPTY), "빈칸은 붓 목록에 없다")
	t.eq(ids.size(), Mat.ALL.size() - 1, "빈칸 말고 전부 붓이 된다")

	# ── ① 붓 그림 ─────────────────────────────────────────────────
	var tex: Texture2D = load(ATLAS_PATH)
	t.ok(tex != null, "붓 그림을 읽는다")
	if tex == null:
		return
	var px := Palette.tile_px()
	t.eq(tex.get_width(), px * ids.size(), "붓 그림의 폭이 붓 수와 맞는다")
	t.eq(tex.get_height(), px, "붓 그림의 높이가 타일 한 변이다")

	var img := tex.get_image()
	t.ok(img != null, "붓 그림의 픽셀을 읽는다")
	if img != null:
		var wrong := 0
		for i in ids.size():
			var at := Palette.atlas_of(i)
			# 칸 한가운데를 찍는다 — 가장자리는 임포트 필터에 흔들릴 수 있다.
			var got := img.get_pixel(at.x * px + px / 2, at.y * px + px / 2)
			var rgb := Mat.rgb_of(ids[i])
			var want := Color8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
			if not got.is_equal_approx(want):
				wrong += 1
				t.ok(false, "%s 붓 색이 DEFS와 다르다 (그림 %s · 표 #%06X)" % [
					Mat.material_name(ids[i]), got.to_html(false), rgb])
		t.eq(wrong, 0, "붓 %d개의 색이 전부 DEFS의 rgb와 같다" % ids.size())

	# ── ② 타일셋 ─────────────────────────────────────────────────
	var tileset: TileSet = load(TILESET_PATH)
	t.ok(tileset != null, "타일셋을 읽는다")
	if tileset == null:
		return
	var src := tileset.get_source(0) as TileSetAtlasSource
	t.ok(src != null, "타일셋에 atlas 소스가 있다")
	if src == null:
		return
	t.eq(src.get_tiles_count(), ids.size(), "타일 수가 붓 수와 같다 (남는 타일도 모자란 타일도 없다)")
	for i in ids.size():
		var at := Palette.atlas_of(i)
		var data := src.get_tile_data(at, 0)
		t.ok(data != null, "%s 자리(%d,%d)에 타일이 있다" % [Mat.material_name(ids[i]), at.x, at.y])
		if data != null:
			t.eq(int(data.get_custom_data("material")), ids[i],
				"%s 타일에 붙은 재질이 맞다" % Mat.material_name(ids[i]))

	# 🔴 **uid 가 살아 있나.** `stage.tscn` 이 이 리소스를 **uid 로 참조한다** —
	#  `ResourceSaver.save` 가 uid 를 지우는 것을 2026-08-07에 실제로 봤다.
	#  ⚠ 지금은 `path` 도 같이 적혀 있어 게임이 안 깨지지만, 에디터가 새 uid 를 발급해 **씬 diff 가 난다.**
	var head := FileAccess.get_file_as_string(TILESET_PATH).split("
")[0]
	t.ok(head.contains("uid://"), "타일셋 .tres 가 uid 를 들고 있다 (씬이 그걸로 참조한다)")

	# ── ③ 글자표 ─────────────────────────────────────────────────
	# 🔴 빠지면 **굽기가 짖고 멈춘다** — 넷 중 유일하게 큰 소리로 죽지만, 그물이 먼저 잡는 게 낫다.
	var seen := {}
	for id: int in ids:
		var has: bool = Baker.CHAR_BY_MAT.has(id)
		t.ok(has, "%s 에 맵 글자가 있다" % Mat.material_name(id))
		if not has:
			continue
		var ch: String = Baker.CHAR_BY_MAT[id]
		t.eq(ch.length(), 1, "%s 의 맵 글자가 한 글자다 (한 칸이 한 글자다)" % Mat.material_name(id))
		# ⚠ 겹치면 구운 맵을 되심을 때 **두 재료가 하나로 합쳐진다.**
		t.ok(not seen.has(ch), "맵 글자 `%s` 가 %s 에만 쓰인다" % [ch, Mat.material_name(id)])
		seen[ch] = id
	t.eq(seen.size(), ids.size(), "붓마다 서로 다른 글자가 하나씩이다")

	# ── ④ 구워진 산출물이 글자표를 따라왔나 ─────────────────────────
	# 🔴🔴 **코드의 파생은 「굽는 순간」만 고치고 「체크인된 산출물」은 안 고친다.**
	#  ⚠ 2026-08-07에 실제로 어긋난 채 커밋돼 있었다 — `CHAR_BY_MAT` 에 `~` 를 넣고
	#   **맵을 다시 안 구웠다.** 그러면 구운 맵에 새 글자가 있어도 게임이 그 글자를 모르고,
	#   `MAP_CHARS.has(ch)` 가 false라 **그 칸이 에러 없이 빈칸이 된다.**
	#  🔴 문서가 「파생으로 고쳤다」고 적은 그 고장이 **현재형으로** 있었다는 뜻이다 —
	#   파생은 도구를 고친 것이고, 산출물은 **다시 구워야** 따라온다.
	# ⇒ **양방향으로 맞댄다.** 한쪽만 보면 「글자가 남아도는 것」과 「모자란 것」 중 하나를 놓친다.
	var baked: Dictionary = Stage.MAP_CHARS
	for id: int in ids:
		if not Baker.CHAR_BY_MAT.has(id):
			continue
		var ch: String = Baker.CHAR_BY_MAT[id]
		t.ok(baked.has(ch),
			"구운 맵이 `%s`(%s) 를 안다 — 아니면 그 칸이 빈칸이 된다. **다시 구워라**" % [
				ch, Mat.material_name(id)])
		if baked.has(ch):
			t.eq(int(baked[ch]), id, "구운 맵의 `%s` 가 %s 를 가리킨다" % [ch, Mat.material_name(id)])
	# 반대쪽 — 산출물에만 있는 글자는 **지워진 재료**의 흔적이다.
	for ch2: String in baked:
		t.ok(seen.has(ch2), "구운 맵의 글자 `%s` 가 지금도 붓에 있다 (은퇴한 재료가 안 남았다)" % ch2)
	t.eq(baked.size(), Baker.CHAR_BY_MAT.size(), "구운 맵의 글자 수가 글자표와 같다")

	# 🔴🔴 **숨어 있던 다섯째 표.** `bake()` 안의 지역 변수라 그물이 못 보던 것을 상수로 올렸다.
	#  ⚠ 빠지면 **붓은 생기고 타일도 놓이는데 굽기가 죽는다** — 물을 더할 때 실제로 그랬다
	#   (`CHAR_BY_MAT` 만 늘리고 이건 안 늘렸더니 「재질 id 4의 상수 이름을 모른다」).
	#  🔴 그리고 그건 **맵에 그 재료를 실제로 그려야** 드러난다 — 안 그리면 영영 안 걸린다.
	for id2: int in ids:
		t.ok(Baker.NAME_BY_MAT.has(id2),
			"%s 에 GDScript 상수 이름이 있다 (굽기가 `Mat.<이름>` 으로 뱉는다)" % Mat.material_name(id2))
	# 그리고 그 이름이 진짜 상수여야 한다 — 오타면 생성 파일이 파스 에러를 낸다.
	var consts := (Mat as GDScript).get_script_constant_map()
	for id2: int in ids:
		if not Baker.NAME_BY_MAT.has(id2):
			continue
		var nm: String = Baker.NAME_BY_MAT[id2]
		t.ok(consts.has(nm) and int(consts[nm]) == id2,
			"`Mat.%s` 가 실재하고 값이 %d다 (오타면 생성 파일이 파스 에러다)" % [nm, id2])
