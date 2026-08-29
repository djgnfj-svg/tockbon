# **The negative: the ground you can walk on is left alone, and the ground you cannot is covered.**
#
# **Where the mark comes from**: the same walk of the rules as `04-reach`, read inside out. Every land
# tile the body cannot reach gets a dark scatter over it; everywhere else stays exactly the ground the
# island was painted with.
#
# ⚠ This is Bad North's other answer, in the developer's words: ***"on those unnavigable areas, we
# would instead place forests, which was an excellent solution because it made it visually obvious
# that you can't go there."*** **The forbidden ground is dressed, and the walkable ground is bare.**
#
# ⚠ **The scatter stands in for the forest.** Trees are `props` in the island file and a prototype may
# not re-bake the island; what is being judged here is 「덮어서 못 가는 곳을 말한다」, not the leaf.
extends RefCounted

const WASH := Color(0.16, 0.20, 0.16, 0.30)   # over the whole forbidden tile
const CLUMP := Color(0.10, 0.16, 0.11, 0.55)  # the scatter standing on it
const CLUMP_SIZE := 0.44


static func build(lab) -> Node3D:
	var from: Vector2i = lab.body_tile()
	var seen: Dictionary = lab.reach(from, 4096)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for ty in lab.grid.h:
		for tx in lab.grid.w:
			if not lab.is_land(tx, ty):
				continue
			if seen.has(lab.grid.tile_index(tx, ty)):
				continue
			any = true
			var y: float = lab.tile_y(tx, ty)
			lab.lay_quad(st, Vector3(float(tx) + 0.5, y, float(ty) + 0.5), 1.0, 1.0, WASH)
			# Two clumps per tile, thrown about by the tile's own number so the pattern does not
			# march in step with the grid it is covering.
			var r := float((tx * 73856093) ^ (ty * 19349663))
			for k in 2:
				var a := fmod(absf(r) * 0.618 + float(k) * 2.399, 1.0)
				var b := fmod(absf(r) * 0.379 + float(k) * 1.117, 1.0)
				var c := Vector3(float(tx) + 0.22 + a * 0.56, y, float(ty) + 0.22 + b * 0.56)
				lab.lay_quad(st, c, CLUMP_SIZE, CLUMP_SIZE, CLUMP)
	if not any:
		return null
	var holder := Node3D.new()
	holder.add_child(lab.one_mesh(st, lab.flat_mat(Color(1, 1, 1, 1))))
	return holder
