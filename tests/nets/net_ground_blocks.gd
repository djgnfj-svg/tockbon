extends RefCounted
## **The ground stood out of the kit instead of loaded as one baked mesh** — 티켓 08-01, stage 2.
##
## `IslandKit.plan` is `src/sim/`'s half and `net_island_kit` measures it. **This file measures the
## other half: that the view actually puts those blocks on the board**, at the seam `GLOSSARY.md`
## names for `src/view/` — **pooled node state**. How many `MeshInstance3D` the island subtree holds,
## which mesh each wears, where it sits and what material it carries. **Not one pixel is read**, and
## the picture is `tools/look/capture_ground.gd`'s job.
##
## ⚠⚠ **THE BAR IS THE DRAWN ISLAND AND NOTHING ELSE.** The board is `Islands.load_into(Grid.new())` —
## the island the user already approved by eye — and the assembled version of it is held against the
## baked mesh it replaces. **A generated board is measured by nobody here on purpose**: an island
## nobody has seen cannot say whether the look survived.
##
## ⚠ **A block is identified by its MESH and never by its node name.** Measured 2026-09-03: Godot
## renames every child after the first when siblings share a name — the second `KIT_0_solid_4` comes
## into the tree as `@MeshInstance3D@2`. **The mesh resource is shared across instantiations of the
## same `PackedScene`** (measured the same way), so a fresh `pieces.glb` gives a mesh → kit-name map
## that survives the renaming.


## **How far the assembled box may sit from the baked one, per axis, in 조각.**
##
## ⚠ **It is not zero, and the reason is measured**: the baked island's own box bottoms out at
## −0.122036 while every kit block bottoms out at −0.12, so the two disagree by 0.002 on the y floor
## before anything is placed at all. **0.01 is five times that and forty times under one 눈금 (0.5)**,
## so a block a whole storey or a whole 조각 out of place cannot hide under it.
const BOX_TOL := 0.01

## Every `FieldView` built here, freed at the end — an untreed `Node2D` left unfreed is a leaked RID
## on stderr, and the wrapper reads stderr as failure.
var _created: Array = []


func run(t) -> void:
	# ⚠⚠ **READ BEFORE ANYTHING BUILDS A VIEW, AND THAT ORDER IS THE WHOLE INVERSION.**
	# `_use_vertex_colours` mutates the material inside the cached `pieces.glb`, so once a board has
	# been stood there is no untouched material left in the process to compare against.
	var arrives_off := _a_kit_material_arrives_with_vertex_colour_off()

	_the_board_opens_on_the_blocks(t)
	_every_land_cell_gets_exactly_one_block(t)
	_every_block_stands_on_its_own_cell_at_ground_zero(t)
	_every_block_placed_is_one_the_kit_holds(t)
	_the_stair_cell_wears_a_staircase(t)
	_the_assembled_island_fills_the_baked_one(t)
	_the_yardstick_arm_still_loads_the_baked_mesh(t)
	_nothing_paints_white(t, arrives_off)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []
	t.done()


# == the rows =========================================================================================


## **The arm the game runs on is the blocks**, both as the field's own default and as what a real
## `setup()` leaves on the board.
##
## ⚠ **The second half is what bites.** A default nobody reads is a constant; the assertion that
## matters is that the island subtree after `setup` is the assembled one and carries no baked mesh.
func _the_board_opens_on_the_blocks(t) -> void:
	var fresh := FieldView.new()
	_created.append(fresh)
	t.eq(fresh.ground_source, FieldView.Ground.KIT_BLOCKS, "새 필드는 블록 팔로 열린다")

	var fv := _drawn_view()
	t.eq(String(fv._island.name), FieldView.BLOCKS_NODE, "판이 열리면 섬은 조립된 쪽이다")
	t.ok(fv._island.find_child("island", true, false) == null,
		"조립된 섬 안에는 구운 메시가 한 장도 없다")


## **Every land 칸 of the drawn island gets exactly one block**, counted three ways that have to agree:
## this file's own walk of the board, `IslandKit.plan`, and the nodes actually standing.
##
## ⚠⚠ **THE OWN WALK IS THE INVERSION.** Comparing the node count to `plan`'s size only proves the
## loop ran to the end of the list it was handed; it says nothing about the list being the board.
## **This file counts 칸 with at least one dry 조각 for itself**, which is `IslandKit`'s own reading of
## 「land」 — 「LAND IS DRY, NOT WALKABLE」 — arrived at without asking it.
func _every_land_cell_gets_exactly_one_block(t) -> void:
	var fv := _drawn_view()
	var g := fv.battle.grid
	var mine := _land_cells(g).size()
	t.ok(mine > 0, "그린 섬에 땅 칸이 있다 (%d 칸)" % mine)
	t.eq(IslandKit.plan(g).size(), mine, "IslandKit 이 땅 칸마다 한 줄을 답한다")
	t.eq(_blocks_of(fv).size(), mine, "선 블록이 땅 칸 수와 같다")


## **Each block stands on the centre of its own 칸, at ground zero.**
##
## ⚠ **The heights are asserted as EXACTLY zero and not near it.** A block carries its own storey
## (−0.12..0.21 at 눈금 0, −0.12..1.21 at 눈금 2), so a plateau lifted by a storey is the defect this
## row exists for, and it would be a whole 1.0 out — there is nothing here for a tolerance to absorb.
func _every_block_stands_on_its_own_cell_at_ground_zero(t) -> void:
	var fv := _drawn_view()
	var g := fv.battle.grid
	var want := {}
	for raw in IslandKit.plan(g):
		var d: Dictionary = raw
		want[d["centre"]] = true
	var got := {}
	var flat := true
	for mi in _blocks_of(fv):
		got[Vector2(mi.position.x, mi.position.z)] = true
		if mi.position.y != 0.0:
			flat = false
	t.eq(got.size(), want.size(), "블록이 칸마다 제 자리를 하나씩 차지한다")
	t.ok(_same_keys(got, want), "블록이 선 자리가 IslandKit 이 답한 칸 중심과 하나도 안 어긋난다")
	t.ok(flat, "블록은 하나도 안 들어올려졌다 — 전부 y 0 이다")


## **Every mesh standing on the board came out of `pieces.glb`**, and every name `IslandKit` answered
## really got a block.
##
## ⚠ **The second half is what catches a silent hole.** `_island_of_blocks` barks and skips a name the
## file does not hold; the bark reddens the wrapper, but a name that IS in the file and simply never
## got placed would leave a hole in the ground with nothing said.
func _every_block_placed_is_one_the_kit_holds(t) -> void:
	var fv := _drawn_view()
	var kit := _kit_names()
	var stood := {}
	var strangers := 0
	for mi in _blocks_of(fv):
		if not kit.has(mi.mesh):
			strangers += 1
			continue
		stood[kit[mi.mesh]] = true
	t.eq(strangers, 0, "판 위에 pieces.glb 밖에서 온 메시는 없다")

	var wanted := {}
	for raw in IslandKit.plan(fv.battle.grid):
		var d: Dictionary = raw
		wanted[str(d["name"])] = true
	t.ok(_same_keys(stood, wanted), "IslandKit 이 부른 블록 이름이 하나도 안 빠지고 섰다")


## **The drawn island's staircase gets a staircase block.**
##
## ⚠ **The 칸 is read out of the board and not written here.** 티켓 08-01 records the drawn stair at
## 조각 (6,6)–(7,7), but a re-bake that moves it must move this row with it rather than reddening it,
## so the stair 칸 is whichever one `Grid` says carries an odd 눈금.
func _the_stair_cell_wears_a_staircase(t) -> void:
	var fv := _drawn_view()
	var g := fv.battle.grid
	var kit := _kit_names()
	var stairs := 0
	var stair_cells := 0
	for cell in _land_cells(g):
		if Grid.is_stair_level(IslandKit.level_of_block(g, int(cell))):
			stair_cells += 1
	for mi in _blocks_of(fv):
		if kit.has(mi.mesh) and String(kit[mi.mesh]).contains("_stair_"):
			stairs += 1
	t.eq(stair_cells, 1, "그린 섬의 계단 칸은 하나다")
	t.eq(stairs, stair_cells, "계단 칸마다 계단 블록이 하나 섰다")


## ⚠⚠ **THE ROW THIS WHOLE STAGE EXISTS FOR: the island rebuilt out of blocks fills the same box the
## baked mesh filled.**
##
## **The 판 자국 is left out of the baked side on purpose.** It is a second object in the same file
## standing 0.02 proud of the ground (its box tops out at 1.23 against the island's 1.21), it is
## stage 3's subject, and the assembled side has no such object at all — folding it in would compare
## the ground against the ground plus a mat.
##
## ⚠ **The yardstick's own instrument is inverted below the comparison.** A box that agrees with
## everything is not a measurement, so the same comparison is handed the assembled box slid by one
## 조각 and has to refuse it.
func _the_assembled_island_fills_the_baked_one(t) -> void:
	var built := _box_of(_drawn_view(), "")
	var baked := _box_of(_drawn_view(FieldView.Ground.BAKED_MESH), "island")
	print("  [box] blocks %s .. %s" % [built.position, built.end])
	print("  [box] baked  %s .. %s" % [baked.position, baked.end])
	t.ok(_boxes_agree(built, baked), "블록으로 세운 섬이 구운 섬과 같은 상자를 채운다")

	var slid := built
	slid.position.x += 1.0
	t.ok(not _boxes_agree(slid, baked), "한 조각 밀린 상자는 이 잣대가 잡아낸다")


## **The baked mesh is still reachable**, which is what makes the row above a comparison rather than
## a claim.
func _the_yardstick_arm_still_loads_the_baked_mesh(t) -> void:
	var fv := _drawn_view(FieldView.Ground.BAKED_MESH)
	var one := fv._island.find_child("island", true, false) as MeshInstance3D
	t.ok(one != null, "구운 팔은 island.glb 의 섬 메시를 그대로 연다")
	t.ok(one != null and one.mesh != null and one.mesh.get_surface_count() == 1,
		"구운 섬은 여전히 표면 하나짜리 한 장이다")
	# ⚠ **And the 판 comes with it.** The assembled arm has none; this is where the difference is
	# written down rather than in a comment nobody runs — see `_adopt_the_pads`'s own note.
	t.ok(fv._pads != null, "구운 팔에서는 판 자국이 붙는다")
	t.ok(_drawn_view()._pads == null, "블록 팔에는 붙일 판 자국이 없다 — 08-01 3단계가 세운다")


## **Nothing paints white.** The kit blocks carry a colour per vertex and no UV; a material with
## `vertex_color_use_as_albedo` off multiplies that colour by nothing and the ground comes out flat
## white. `how-nets-lie` already carries this exact failure against the buildings.
##
## ⚠⚠ **`arrives_off` IS THE INVERSION AND IT HAD TO BE READ FIRST.** A row asserting only 「the flag
## is on」 stays green if the importer starts switching it on by itself, and then it measures the file
## rather than this code. **The control says the flag really does arrive off**, so the on below is
## something the view did.
func _nothing_paints_white(t, arrives_off: bool) -> void:
	t.ok(arrives_off, "kit 블록의 재질은 정점색이 꺼진 채로 들어온다 (이 검사의 반대 사례)")
	var fv := _drawn_view()
	var lit := 0
	var coloured := 0
	var total := 0
	for raw in _blocks_of(fv):
		var mi: MeshInstance3D = raw
		total += 1
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		if mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null:
			coloured += 1
		var m := mesh.surface_get_material(0) as StandardMaterial3D
		if m != null and m.vertex_color_use_as_albedo:
			lit += 1
	t.ok(total > 0, "잴 블록이 있다")
	t.eq(coloured, total, "선 블록은 전부 제 정점색을 들고 있다")
	t.eq(lit, total, "선 블록의 재질은 전부 그 정점색을 켜고 있다")


# == readers ==========================================================================================


## **A kit material as the importer hands it over**, before any view has touched one. See
## `_nothing_paints_white` for why this is read at the top of `run`.
func _a_kit_material_arrives_with_vertex_colour_off() -> bool:
	var packed := load(IslandKit.KIT_PATH) as PackedScene
	if packed == null:
		return false
	var lib := packed.instantiate()
	var off := true
	for mi in _meshes_under(lib):
		var m := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if m == null or m.vertex_color_use_as_albedo:
			off = false
	lib.free()
	return off


## **The drawn island, opened on a real `FieldView`.** ⚠ `Islands.keep_tiles()` goes in because the
## 성채 is what `_rebuild_buildings` stands, and a board without one exercises less of `setup`.
func _drawn_view(source: int = FieldView.Ground.KIT_BLOCKS) -> FieldView:
	var g := Grid.new()
	Islands.load_into(g)
	var b := Battle.new()
	b.setup(g, Army.new(), [], Islands.keep_tiles())
	var fv := FieldView.new()
	_created.append(fv)
	fv.ground_source = source
	fv.setup(b, b.army, Islands.rows())
	return fv


## **Every `MeshInstance3D` standing directly under the assembled island.**
func _blocks_of(fv: FieldView) -> Array:
	var out: Array = []
	if fv._island == null:
		return out
	for c in fv._island.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			out.append(mi)
	return out


## **Which kit block each mesh in `pieces.glb` is**, as `{Mesh: name}`. See this file's head for why
## the mesh and not the node name.
func _kit_names() -> Dictionary:
	var out := {}
	var packed := load(IslandKit.KIT_PATH) as PackedScene
	if packed == null:
		return out
	var lib := packed.instantiate()
	for mi in _meshes_under(lib):
		out[mi.mesh] = String(mi.name)
	lib.free()
	return out


func _meshes_under(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes_under(c))
	return out


## **Every 칸 of `grid` with at least one dry 조각** — this file's own reading of 「land」, kept
## independent of `IslandKit`'s on purpose. See `_every_land_cell_gets_exactly_one_block`.
func _land_cells(grid: Grid) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := {}
	for tile in grid.w * grid.h:
		if grid.water[tile] != 0:
			continue
		var cell := grid.block_of(tile)
		if cell < 0 or seen.has(cell):
			continue
		seen[cell] = true
		out.append(cell)
	return out


## **The box the island's meshes fill, in world units.** `want` narrows it to one child by name, or
## takes every mesh under the subtree when it is empty.
##
## ⚠ **Each box is carried through its node's whole `Transform3D` and then the island's**, not shifted
## by a position. The baked arm slides the whole scene by the board's height and the assembled arm
## does not; a comparison written as `+= position` would be right for one of them only.
func _box_of(fv: FieldView, want: String) -> AABB:
	var box := AABB()
	var first := true
	if fv._island == null:
		return box
	for mi in _meshes_under(fv._island):
		if want != "" and String(mi.name) != want:
			continue
		var one: AABB = fv._island.transform * (mi.transform * mi.get_aabb())
		box = one if first else box.merge(one)
		first = false
	return box


func _boxes_agree(a: AABB, b: AABB) -> bool:
	return _close(a.position, b.position) and _close(a.end, b.end)


func _close(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) < BOX_TOL and absf(a.y - b.y) < BOX_TOL and absf(a.z - b.z) < BOX_TOL


func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
	return true
