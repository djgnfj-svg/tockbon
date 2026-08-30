# **What all three candidates share, so the only difference on the sheet is the mechanism.**
#
# The same clump, the same picture of that clump, the same spots on the same island, the same wind.
# ⚠ **A throwaway.** The winner gets rebuilt in `tools/blender/props_build.py` and placed through the
# island file, the way every other prop is.
extends RefCounted

const DIR := "res://.prototypes/bush"
## The card is a render of the clump, so its shape is the clump's shape: 0.64 조각 wide, 0.34 high.
const CARD_W := 0.64
const CARD_H := 0.34
## How many 조각 wear a bush. **One clump per 조각** (2026-08-29, settled with the user) -- and the
## clump itself is three leaf lumps, because one lump reads as a button at this camera.
const PATCH := 16

static var _mesh: ArrayMesh = null
static var _tex: ImageTexture = null


## **The baked clump, read straight out of the `.glb` at run time.** ⚠ **Not `load()`**: a throwaway
## folder has no `.import` beside its assets, and `load()` on a bare `.glb` fails outside the editor.
static func bush_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var path := ProjectSettings.globalize_path(DIR + "/assets/bush.glb")
	if doc.append_from_file(path, state) != OK:
		push_error("bush: cannot read " + path)
		return null
	var scene := doc.generate_scene(state)
	for n in scene.get_children():
		var mi := n as MeshInstance3D
		if mi != null:
			_mesh = mi.mesh as ArrayMesh
			break
	scene.queue_free()
	return _mesh


## The picture of that same clump. Loaded off disk for the same reason the mesh is.
static func card_tex() -> ImageTexture:
	if _tex != null:
		return _tex
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(DIR + "/assets/bush_card.png")) != OK:
		push_error("bush: cannot read bush_card.png")
		return null
	_tex = ImageTexture.create_from_image(img)
	return _tex


## **One standing quad**, its foot on the origin, `yaw` degrees around the upright axis.
static func quad(st: SurfaceTool, yaw_deg: float) -> void:
	var a := deg_to_rad(yaw_deg)
	var right := Vector3(cos(a), 0.0, sin(a)) * (CARD_W * 0.5)
	var n := Vector3(-sin(a), 0.0, cos(a))
	var p := [-right, right, right + Vector3(0.0, CARD_H, 0.0), -right + Vector3(0.0, CARD_H, 0.0)]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for i in tri:
			st.set_normal(n)
			st.set_uv(uv[i])
			st.add_vertex(p[i])


## **Where the bushes stand, and it is the same list for every candidate.** A seeded scatter over the
## flat walkable 조각 nearest the body, so the patch sits where the camera is already looking.
static func spots(lab) -> Array:
	var grid = lab.grid
	var anchor: Vector2i = lab.body_tile()
	var lv := grid.level_of(grid.tile_index(anchor.x, anchor.y))
	var near: Array = []
	for ty in grid.h:
		for tx in grid.w:
			var t: int = ty * grid.w + tx
			if grid.passable[t] != 1 or grid.level_of(t) != lv:
				continue
			if Grid.is_stair_level(grid.level_of(t)):
				continue
			var d := Vector2(float(tx - anchor.x), float(ty - anchor.y)).length()
			if d < 1.2:
				continue        # the body's own 조각 and its neighbours stay clear
			near.append([d, tx, ty])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260829
	var out: Array = []
	for i in mini(PATCH, near.size()):
		var tx: int = near[i][1]
		var ty: int = near[i][2]
		var y := Islands.ground_h(grid.level_of(ty * grid.w + tx))
		var pos := Vector3(float(tx) + 0.5 + rng.randf_range(-0.2, 0.2), y,
				float(ty) + 0.5 + rng.randf_range(-0.2, 0.2))
		var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), pos)
		out.append(t.scaled_local(Vector3.ONE * rng.randf_range(0.82, 1.18)))
	return out
